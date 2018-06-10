-------------------------------------------------------------------------------
--! @file       ram_arbiter_read_data_width_adapter.vhdl
--! @author     Fixitfetish
--! @date       10/Jun/2018
--! @version    0.10
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;
library ramlib;
  use ramlib.ram_arbiter_pkg.all;

--! @brief Entity that adapts user data width to the arbiter data width using a shift register.
--!
--! The user can request data of width USER_DATA_WIDTH every cycle. Always
--! N = RAM_ARBITER_DATA_WIDTH/USER_DATA_WIDTH requests are collected before an arbiter request is generated.
--! The resulting minimum arbiter request period is N cycles.
--!
--! Corresponding to the arbiter request period the arbiter read completions are auto-acknowledged
--! with a minimum period od N cycles. Hence, the extracted read data for the user can be provided every cycle. 

entity ram_arbiter_read_data_width_adapter is
generic(
  --! RAM Data Width (must be a multiple of the USER_DATA_WIDTH)
  RAM_ARBITER_DATA_WIDTH : positive;
  --! RAM Address Width (RAM arbiter data word address)
  RAM_ARBITER_ADDR_WIDTH : positive;
  --! User Data Width (must be smaller or equal the RAM_ARBITER_DATA_WIDTH)
  USER_DATA_WIDTH : positive
);
port(
  --! System clock
  clk                 : in  std_logic;
  --! Synchronous reset
  rst                 : in  std_logic;
  --! start address (must be valid at rising edge of frame signal)
  usr_cfg_addr_first  : in  unsigned(RAM_ARBITER_ADDR_WIDTH-1 downto 0); 
  --! last address before wrap (must be valid at rising edge of frame signal)
  usr_cfg_addr_last   : in  unsigned(RAM_ARBITER_ADDR_WIDTH-1 downto 0); 
  --! '1'=single-shot mode , '0'=continuous with wrap (must be valid at rising edge of frame signal)
  usr_cfg_single_shot : in  std_logic;
  --! request frame, start=rising edge, stop=falling edge 
  usr_req_frame       : in  std_logic;
  --! request enable
  usr_req_ena         : in  std_logic;
  --! request overflow reported by arbiter
  usr_req_ovfl        : out std_logic;
  --! request FIFO overflow reported by arbiter
  usr_req_fifo_ovfl   : out std_logic;
  --! read completion data
  usr_cpl_data        : out std_logic_vector(USER_DATA_WIDTH-1 downto 0);
  --! read completion data valid
  usr_cpl_data_vld    : out std_logic;
  --! read completion data end of frame
  usr_cpl_data_eof    : out std_logic;
  --! Arbiter output signals (from arbiter to user)
  arb_out             : in  r_ram_arbiter_usr_in_port;
  --! Arbiter input signals (from user to arbiter)
  arb_in              : out r_ram_arbiter_usr_out_port
);
begin
  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert USER_DATA_WIDTH<=RAM_ARBITER_DATA_WIDTH
    report "ERROR in " & ram_arbiter_read_data_width_adapter'INSTANCE_NAME & 
           " USER_DATA_WIDTH must be smaller or equal the RAM_ARBITER_DATA_WIDTH."
    severity failure;
  assert (RAM_ARBITER_DATA_WIDTH mod USER_DATA_WIDTH)=0
    report "ERROR in " & ram_arbiter_read_data_width_adapter'INSTANCE_NAME & 
           " RAM_ARBITER_DATA_WIDTH must be a multiple of the USER_DATA_WIDTH."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)
end entity;

-------------------------------------------------------------------------------

architecture rtl of ram_arbiter_read_data_width_adapter is

  constant RAM_REQ_PERIOD : positive := RAM_ARBITER_DATA_WIDTH/USER_DATA_WIDTH;

  signal arb_in_req_frame : std_logic;
  signal arb_in_req_ena : std_logic;

  signal cpl_ack : std_logic;
  
  signal arb_out_data : std_logic_vector(RAM_ARBITER_DATA_WIDTH-1 downto 0);
  signal arb_out_data_vld : std_logic;
  signal arb_out_data_eof : std_logic;
  signal arb_out_data_ack : std_logic;

  signal shift_reg_data : std_logic_vector(RAM_ARBITER_DATA_WIDTH-1 downto 0);
  signal shift_reg_eof : std_logic_vector(RAM_REQ_PERIOD-1 downto 0);

begin

  -- debug
  arb_in_req_frame <= arb_in.req_frame;
  arb_in_req_ena <= arb_in.req_ena;

  -- request generation
  p_req : process(clk)
    variable v_cnt : integer;
  begin
    if rising_edge(clk) then
      arb_in.req_ena <= '0'; -- default

      if rst='1' or usr_req_frame='0' then
        arb_in.cfg_addr_first <= (RAM_ARBITER_ADDR_WIDTH-1 downto 0 => '-');
        arb_in.cfg_addr_last <= (RAM_ARBITER_ADDR_WIDTH-1 downto 0 => '-');
        arb_in.cfg_single_shot <= '0';
        arb_in.req_frame <= '0';
        v_cnt := RAM_REQ_PERIOD;

      else
        arb_in.cfg_addr_first <= usr_cfg_addr_first;
        arb_in.cfg_addr_last <= usr_cfg_addr_last;
        arb_in.cfg_single_shot <= usr_cfg_single_shot;
        arb_in.req_frame <= '1';
        if usr_req_ena='1' then
          if v_cnt=RAM_REQ_PERIOD then
            arb_in.req_ena <= '1';
            v_cnt := 1;
          else
            v_cnt := v_cnt + 1;
          end if;
        end if;
        
      end if; --reset 
    end if; --clock
  end process;

  -- request data is irrelevant (only required for write)
  arb_in.req_data <= (RAM_ARBITER_DATA_WIDTH-1 downto 0 => '-');

  -- error reporting (with pipeline register)
  usr_req_ovfl <= arb_out.req_ovfl when rising_edge(clk);
  usr_req_fifo_ovfl <= arb_out.req_fifo_ovfl when rising_edge(clk);

  -- completion acknowledge
  arb_in.cpl_ack <= arb_out.cpl_rdy and cpl_ack;  

  -- completion acknowledge rate according to RAM request rate
  -- (i.e. according to data width conversion factor)
  p_cpl_ack : process(clk)
    variable v_cnt : integer;
  begin
    if rising_edge(clk) then
      cpl_ack <= '0'; -- default
      if rst='1' then
        v_cnt := RAM_REQ_PERIOD;
      else
        if arb_out.cpl_rdy='1' and v_cnt=RAM_REQ_PERIOD then
          cpl_ack <= '1';
          v_cnt := 1;
        elsif v_cnt/=RAM_REQ_PERIOD then
          v_cnt := v_cnt + 1;
        end if;
      end if;

    end if;
  end process;


  -- completion data buffer is needed as
  -- + user specific pipeline register after the common CPL FIFO output register
  -- + additional one-stage FIFO to compensate cpl_ack delays 
  p_cpl_buffer : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        arb_out_data <= (others=>'-');
        arb_out_data_vld <= '0';
        arb_out_data_eof <= '0';
      else
        -- hold data until acknowledged
        if arb_out.cpl_data_vld='1' then
          arb_out_data <= arb_out.cpl_data;
        end if;
        arb_out_data_vld <= arb_out.cpl_data_vld or (arb_out_data_vld and (not arb_out_data_ack));
        arb_out_data_eof <= arb_out.cpl_data_eof or (arb_out_data_eof and (not arb_out_data_ack));
      end if;
    end if;
  end process;


  g_out_adapt_false : if RAM_REQ_PERIOD=1 generate
    -- disable completion data width adaptation
    -- (pass through completion data with full RAM data width)
    usr_cpl_data <= arb_out_data;
    usr_cpl_data_vld <= arb_out_data_vld;
    usr_cpl_data_eof <= arb_out_data_eof;
    arb_out_data_ack <= arb_out_data_vld;
  end generate;

  
  g_out_adapt_true : if RAM_REQ_PERIOD>=2 generate
    -- enabled completion data width adaptation
    
    p_cpl_data : process(clk)
      variable v_cnt : integer;
    begin
      if rising_edge(clk) then
        usr_cpl_data_vld <= '0'; -- default
        arb_out_data_ack <= '0'; -- default
    
        if rst='1' then
          shift_reg_data <= (others=>'-');
          shift_reg_eof <= (others=>'0');
          v_cnt := RAM_REQ_PERIOD;
        else
          if v_cnt=RAM_REQ_PERIOD and arb_out_data_vld='1' then
            -- acknowledge buffered completion data and load shift register
            arb_out_data_ack <= '1';
            shift_reg_data <= arb_out_data; 
            shift_reg_eof(RAM_REQ_PERIOD-1) <= arb_out_data_eof; 
            usr_cpl_data_vld <= '1'; 
            v_cnt := 1;
          elsif v_cnt/=RAM_REQ_PERIOD then
            -- shift next user data to LSBs 
            usr_cpl_data_vld <= '1';
            shift_reg_data(RAM_ARBITER_DATA_WIDTH-USER_DATA_WIDTH-1 downto 0) <= 
              shift_reg_data(RAM_ARBITER_DATA_WIDTH-1 downto USER_DATA_WIDTH);
            shift_reg_eof(RAM_REQ_PERIOD-2 downto 0) <= shift_reg_eof(RAM_REQ_PERIOD-1 downto 1); 
            shift_reg_eof(RAM_REQ_PERIOD-1) <= '0'; 
            v_cnt := v_cnt + 1;
          else
            -- wait for next completion data
            shift_reg_eof <= (others=>'0');
          end if;
        end if;
    
      end if;
    end process;
    
    -- provide user data at output port
    usr_cpl_data <= shift_reg_data(USER_DATA_WIDTH-1 downto 0);
    usr_cpl_data_eof <= shift_reg_eof(0);

  end generate;

end architecture;
