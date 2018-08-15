-------------------------------------------------------------------------------
--! @file       slv_unpack.vhdl
--! @author     Fixitfetish
--! @date       12/Aug/2018
--! @version    0.20
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

--! @brief Unpack one big SLV into several sequential small SLVs. 
--!
--! RATIO_LOG2 | RATIO | Output Data Width
--! :---------:|:-----:|:-----------------:
--!      0     |   1   | DATA_WIDTH (bypass)
--!      1     |   2   | DATA_WIDTH/2
--!      2     |   4   | DATA_WIDTH/4
--!      3     |   8   | DATA_WIDTH/8
--!      4     |  16   | DATA_WIDTH/16
--!     ...    |  ...  | ...
--!
--! @image html slv_pack_unpack_format.svg "" width=800px
--!
--! Converting a single data input word requires RATIO cycles, hence
--! the allowed minimum din_ena period is RATIO cycles.
--!
--! Set MIN_RATIO_LOG2 and MAX_RATIO_LOG2 carefully to not waste FPGA logic resources.
--! If only one static ratio is required set MIN_RATIO_LOG2 = MAX_RATIO_LOG2 = ratio_log2.
--!
--! Please refer to slv_pack for reverse operation.
--!
--! Implementation requirements
--! * Output must be registered, i.e. all required multiplexers before output register.
--! * Low latency and efficient FPGA logic resource usage.
--!
--! TODO : MSB_BOUND_OUTPUT not yet supported by slv_unpack
--!

entity slv_unpack is
generic (
  --! Input data width must be a multiple of 2**MAX_RATIO_LOG2
  DATA_WIDTH : positive := 48;
  --! @brief Minimum input-to-output ratio. LOG2 enforces ratio with power of 2.
  --! To not waste FPGA logic choose as large as possible but <=MAX_RATIO_LOG2.
  MIN_RATIO_LOG2 : natural := 0;
  --! @brief Maximum input-to-output ratio. LOG2 enforces ratio with power of 2.
  --! To not waste FPGA logic choose as small as possible but >=MIN_RATIO_LOG2.
  MAX_RATIO_LOG2 : natural := 4;
  --! @brief First output is taken from MSBs of input.
  --! By default first output is taken from LSBs of input.
  MSB_BOUND_INPUT : boolean := false
);
port (
  --! Clock
  clk        : in  std_logic;
  --! Synchronous reset
  rst        : in  std_logic;
  --! @brief Input-to-output ratio. LOG2 ensures power of 2.
  --! Must be in range MIN_RATIO_LOG2 to MAX_RATIO_LOG2. 
  --! Do not change while frame is active.
  ratio_log2 : in  unsigned;
  --! Data input frame. Start with rising edge.
  din_frame  : in  std_logic;
  --! Data input enable. Only considered when din_frame='1'.
  din_ena    : in  std_logic;
  --! Data input end of frame. Only considered when din_frame='1'. Optional.
  din_eof    : in  std_logic := '0';
  --! Input data, always full width, either LSB or MSB bound
  din        : in  std_logic_vector(DATA_WIDTH-1 downto 0);
  --! Ready for input data in next cycle
  din_rdy    : out std_logic;
  --! Input overflow occurs when din_ena='1' though unpacking of previous input is not completed. 
  din_ovfl   : out std_logic;
  --! Data output frame. Falling edge after flush is completed.
  dout_frame : out std_logic;
  --! Data output enable
  dout_ena   : out std_logic;
  --! Data output end of frame according to data input end of frame. Optional.
  dout_eof   : out std_logic;
  --! Output data, LSB-bound. Relevant are only the DATA_WIDTH/(2**ratio_log2) LSBs.
  dout       : out std_logic_vector(DATA_WIDTH-1 downto 0)
);
begin
  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert MIN_RATIO_LOG2<=MAX_RATIO_LOG2
    report "ERROR in " & slv_unpack'INSTANCE_NAME & 
           " MIN_RATIO_LOG2 cannot exceed MAX_RATIO_LOG2."
    severity failure;
  assert (DATA_WIDTH mod 2**MAX_RATIO_LOG2)=0
    report "ERROR in " & slv_unpack'INSTANCE_NAME & 
           " DATA_WIDTH is not a multiple of the maximum input-to-output ratio."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)
end entity;

-------------------------------------------------------------------------------

architecture rtl of slv_unpack is
  
  signal sr : std_logic_vector(DATA_WIDTH-1 downto 0) := (others=>'0');
  signal sr_eof : std_logic := '0';
  
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  p_assert : process(clk)
  begin
    -- consider clock and reset to avoid issues during simulation initialization
    if rising_edge(clk) then
      assert rst/='0' or (ratio_log2>=MIN_RATIO_LOG2 and ratio_log2<=MAX_RATIO_LOG2)
        report "ERROR in " & slv_unpack'INSTANCE_NAME & 
               " Input ratio_log2 must be in range MIN_RATIO_LOG2 to MAX_RATIO_LOG2."
        severity failure;
    end if;
  end process;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)


  p_shift : process(clk)
    constant W : positive := DATA_WIDTH;
    variable v_cnt_next : unsigned(MAX_RATIO_LOG2 downto 0);
  begin
    if rising_edge(clk) then
      din_ovfl <= '0'; -- default
      dout_eof <= '0'; -- default
      
      if rst='1' then
        dout_ena <= '0';
        dout_frame <= '0';
        din_rdy <= '0';
        v_cnt_next := (others=>'0');

      else
        din_rdy <= '1'; -- by default always ready

        if (din_frame='1' and din_ena='1') then
          -- load shift register
          if v_cnt_next/=0 then
            din_ovfl <= '1';
          end if;

          -- shift register feed
          if (not MSB_BOUND_INPUT) or ratio_log2=0 then
            sr <= din;
          else
            for n in MIN_RATIO_LOG2 to MAX_RATIO_LOG2 loop
              if ratio_log2=n then
                -- cyclic pre-shift: input MSBs to output LSBs
                sr(W/(2**n)-1 downto 0) <= din(W-1 downto W-W/(2**n));
                sr(W-1 downto W/(2**n)) <= din(W-W/(2**n)-1 downto 0);
              end if;
            end loop;
          end if;
        
          for n in MIN_RATIO_LOG2 to MAX_RATIO_LOG2 loop
            if ratio_log2=n then
              v_cnt_next := to_unsigned(2**n-1,v_cnt_next'length);
            end if;
          end loop;

          
          if ratio_log2=0 then
            dout_eof <= din_eof;
          else
            sr_eof <= din_eof;
            din_rdy <= '0';
          end if;
          dout_ena <= '1';
          dout_frame <= '1';
          
        elsif v_cnt_next/=0 then
          -- shifting
          for n in MIN_RATIO_LOG2 to MAX_RATIO_LOG2 loop
            if ratio_log2=n then
              if MSB_BOUND_INPUT then
                -- cyclic shift up/left into LSBs
                sr(W/(2**n)-1 downto 0) <= sr(W-1 downto W-W/(2**n));
                sr(W-1 downto W/(2**n)) <= sr(W-W/(2**n)-1 downto 0);
              else
                -- shift down/right into LSBs
                sr(W-W/(2**n)-1 downto 0) <= sr(W-1 downto W/(2**n));
              end if;
            end if;
          end loop;

          if v_cnt_next=1 then
            dout_eof <= sr_eof;
          else
            din_rdy <= '0';
          end if;
          dout_ena <= '1';
          dout_frame <= '1';

          v_cnt_next := v_cnt_next - 1;

        else
          -- wait for next din_ena or end of frame
          dout_ena <= '0';
          -- Set dout_frame with first valid dout data.
          -- Reset dout_frame after the last input has been unpacked.
          if din_frame='0' then
            dout_frame <= '0';
          end if;

        end if;

     end if; --reset 
    end if; --clock
  end process;
 
  dout <= sr;

end architecture;
