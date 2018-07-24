-------------------------------------------------------------------------------
--! @file       slv_pack.vhdl
--! @author     Fixitfetish
--! @date       12/Jun/2018
--! @version    0.10
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

--! @brief Pack several sequential small SLVs into one big SLV. 
--!
--! RATIO_LOG2 | RATIO | Input Data Width
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
--! Filling the complete data output word requires RATIO cycles, hence
--! the minimum dout_ena period is RATIO cycles.
--!
--! Set MIN_RATIO_LOG2 and MAX_RATIO_LOG2 carefully to not waste FPGA logic resources.
--! If only one static ratio is required set MIN_RATIO_LOG2 = MAX_RATIO_LOG2 = ratio_log2.
--!
--! Please refer to slv_unpack for reverse operation.
--!
--! Implementation requirements
--! * Output must be registered, i.e. all required multiplexers before output register.
--! * Low latency and efficient FPGA logic resource usage.
--!
--! @image html slv_pack.svg "" width=1000px
--!

entity slv_pack is
generic (
  --! Output data width must be a multiple of 2**MAX_RATIO_LOG2
  DATA_WIDTH : positive := 48;
  --! @brief Minimum output-to-input ratio. LOG2 enforces ratio with power of 2.
  --! To not waste FPGA logic choose as large as possible but <=MAX_RATIO_LOG2.
  MIN_RATIO_LOG2 : natural := 0;
  --! @brief Maximum output-to-input ratio. LOG2 enforces ratio with power of 2.
  --! To not waste FPGA logic choose as small as possible but >=MIN_RATIO_LOG2.
  MAX_RATIO_LOG2 : natural := 4;
  --! @brief If enabled provide input in DATA_WIDTH/(2**ratio_log2) MSBs. 
  --! By default only the DATA_WIDTH/(2**ratio_log2) LSBs are relevant.
  MSB_BOUND_INPUT : boolean := false;
  --! @brief First input goes into MSBs of output.
  --! By default first input goes into LSBs of output.
  MSB_BOUND_OUTPUT : boolean := false
);
port (
  --! Clock
  clk        : in  std_logic;
  --! Synchronous reset
  rst        : in  std_logic;
  --! @brief Output-to-input ratio. LOG2 ensures power of 2.
  --! Must be in range MIN_RATIO_LOG2 to MAX_RATIO_LOG2. 
  --! Do not change while frame is active.
  ratio_log2 : in  unsigned;
  --! Data input frame. Start with rising edge. Stop and flush with falling edge.
  din_frame  : in  std_logic;
  --! Data input enable. Only considered when din_frame='1'.
  din_ena    : in  std_logic;
  --! Input data, either LSB or MSB bound. See MSB_BOUND_INPUT.
  din        : in  std_logic_vector(DATA_WIDTH-1 downto 0);
  --! Data output frame. Falling edge after flush is completed.
  dout_frame : out std_logic;
  --! Data output enable
  dout_ena   : out std_logic;
  --! Output data, always full width, either LSB or MSB bound
  dout       : out std_logic_vector(DATA_WIDTH-1 downto 0)
);
begin
  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert MIN_RATIO_LOG2<=MAX_RATIO_LOG2
    report "ERROR in " & slv_pack'INSTANCE_NAME & 
           " MIN_RATIO_LOG2 cannot exceed MAX_RATIO_LOG2."
    severity failure;
  assert (DATA_WIDTH mod 2**MAX_RATIO_LOG2)=0
    report "ERROR in " & slv_pack'INSTANCE_NAME & 
           " DATA_WIDTH is not a multiple of the maximum output-to-input ratio."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)
end entity;

-------------------------------------------------------------------------------

architecture rtl of slv_pack is
  
  signal din_ena_q : std_logic;

  signal cnt : unsigned(MAX_RATIO_LOG2 downto 0);
  alias  cnt_sft is cnt(MAX_RATIO_LOG2-1 downto 0);
  
  signal shift_ena : std_logic_vector(MAX_RATIO_LOG2 downto 0);
  alias  din_last is shift_ena(shift_ena'high);

  signal sr : std_logic_vector(DATA_WIDTH-1 downto 0) := (others=>'0');
  
  signal flush : std_logic;

begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (ratio_log2>=MIN_RATIO_LOG2) and (ratio_log2<=MAX_RATIO_LOG2)
    report "ERROR in " & slv_pack'INSTANCE_NAME & 
           " Input ratio_log2 must be in range MIN_RATIO_LOG2 to MAX_RATIO_LOG2."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)


  -- Flush is only activated after falling edge of din_frame when din values remain in SR.  
  flush <= not din_frame when cnt_sft/=0 else '0';
  
  p_shift : process(clk)
    constant W : positive := DATA_WIDTH;
    constant MR : natural := 2**MAX_RATIO_LOG2; -- maximum ratio
    constant MW : positive := W / MR; -- minimum input data width
    variable v_cnt_next : unsigned(MAX_RATIO_LOG2 downto 0);
  begin
    if rising_edge(clk) then
      din_ena_q <= '0'; -- default
      
      if rst='1' or (din_frame='0' and cnt_sft=0) then
        dout_frame <= '0';
        cnt <= (others=>'0');
        shift_ena <= (others=>'0');

      elsif (din_frame='1' and din_ena='1') or flush='1' then
        din_ena_q <= '1';
        
        -- shift register feed
        for n in MIN_RATIO_LOG2 to MAX_RATIO_LOG2 loop
          if ratio_log2=n then
            if MSB_BOUND_OUTPUT then
              -- feed shift register LSBs
              if flush='1' then
                -- flush LSBs with zeros
                sr(W/(2**n)-1 downto 0) <= (others=>'0');
              elsif MSB_BOUND_INPUT then
                -- input MSBs to shift register LSBs
                sr(W/(2**n)-1 downto 0) <= din(W-1 downto W-W/(2**n));
              else
                -- input LSBs to shift register LSBs
                sr(W/(2**n)-1 downto 0) <= din(W/(2**n)-1 downto 0);
              end if;
            else
              -- feed shift register MSBs
              if flush='1' then
                -- flush MSBs with zeros
                sr(W-1 downto W-W/(2**n)) <= (others=>'0');
              elsif MSB_BOUND_INPUT then
                -- input MSBs to shift register MSBs
                sr(W-1 downto W-W/(2**n)) <= din(W-1 downto W-W/(2**n));
              else
                -- input LSBs to shift register MSBs
                sr(W-1 downto W-W/(2**n)) <= din(W/(2**n)-1 downto 0);
              end if;
            end if;
            v_cnt_next := cnt + to_unsigned(MR/(2**n),v_cnt_next'length);
          end if;
        end loop;

        -- shift register
        for n in 0 to MAX_RATIO_LOG2-1 loop
          if shift_ena(n)='1' then
            if MSB_BOUND_OUTPUT then
              -- shift left
              sr((2**(n+1))*MW-1 downto (2**(n))*MW) <= sr((2**n)*MW-1 downto 0);
            else
              -- shift right
              sr((MR-2**n)*MW-1 downto (MR-2**(n+1))*MW) <= sr(W-1 downto (MR-2**n)*MW);
            end if;
          end if;
        end loop; 

        for n in MIN_RATIO_LOG2 to MAX_RATIO_LOG2 loop
          if ratio_log2=n then
            v_cnt_next := cnt + to_unsigned(MR/(2**n),v_cnt_next'length);
          end if;
        end loop;

        -- predicting shift stage enables (for next din_ena)
        shift_ena <= std_logic_vector(cnt) xor std_logic_vector(v_cnt_next);

        cnt <= v_cnt_next;

        dout_frame <= din_frame or flush;

     end if; --reset 
    end if; --clock
  end process;
 
  dout_ena <= din_last and din_ena_q;
  dout <= sr;

end architecture;
