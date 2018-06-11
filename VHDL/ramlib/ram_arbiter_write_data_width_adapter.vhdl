-------------------------------------------------------------------------------
--! @file       ram_arbiter_write_data_width_adapter.vhdl
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

entity ram_arbiter_write_data_width_adapter is
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
  --! request data (write)
  usr_req_data        : in  std_logic_vector(USER_DATA_WIDTH-1 downto 0); 
  --! request overflow reported by arbiter
  usr_req_ovfl        : out std_logic;
  --! request FIFO overflow reported by arbiter
  usr_req_fifo_ovfl   : out std_logic;
  --! Arbiter output signals (from arbiter to user)
  arb_out             : in  r_ram_arbiter_usr_in_port;
  --! Arbiter input signals (from user to arbiter)
  arb_in              : out r_ram_arbiter_usr_out_port
);
begin
  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert USER_DATA_WIDTH<=RAM_ARBITER_DATA_WIDTH
    report "ERROR in " & ram_arbiter_write_data_width_adapter'INSTANCE_NAME & 
           " USER_DATA_WIDTH must be smaller or equal the RAM_ARBITER_DATA_WIDTH."
    severity failure;
  assert (RAM_ARBITER_DATA_WIDTH mod USER_DATA_WIDTH)=0
    report "ERROR in " & ram_arbiter_write_data_width_adapter'INSTANCE_NAME & 
           " RAM_ARBITER_DATA_WIDTH must be a multiple of the USER_DATA_WIDTH."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)
end entity;

-------------------------------------------------------------------------------

architecture rtl of ram_arbiter_write_data_width_adapter is

  constant RAM_REQ_PERIOD : positive := RAM_ARBITER_DATA_WIDTH/USER_DATA_WIDTH;

  signal arb_in_req_frame : std_logic;
  signal arb_in_req_ena : std_logic;

  constant FRAGMENT_CNT_WIDTH : positive := log2ceil(RAM_REQ_PERIOD);
  signal cnt : unsigned(FRAGMENT_CNT_WIDTH-1 downto 0); 

  signal shift_reg_data : std_logic_vector(RAM_ARBITER_DATA_WIDTH-1 downto 0);
  signal shift_reg_active : std_logic;

begin

  -- debug
  arb_in_req_frame <= arb_in.req_frame;
  arb_in_req_ena <= arb_in.req_ena;

  -- request generation
  p_req : process(clk)
    variable v_shift : std_logic;
    variable v_fragment : std_logic_vector(USER_DATA_WIDTH-1 downto 0);
  begin
    if rising_edge(clk) then
      arb_in.req_ena <= '0'; -- default

--      if rst='1' or usr_req_frame='0' then
      if rst='1' then
        arb_in.cfg_addr_first <= (RAM_ARBITER_ADDR_WIDTH-1 downto 0 => '-');
        arb_in.cfg_addr_last <= (RAM_ARBITER_ADDR_WIDTH-1 downto 0 => '-');
        arb_in.cfg_single_shot <= '0';
        arb_in.req_frame <= '0';
        shift_reg_active <= '0';
        shift_reg_data <= (others=>'0');
        cnt <= (others=>'0');

      else
        arb_in.cfg_addr_first <= usr_cfg_addr_first;
        arb_in.cfg_addr_last <= usr_cfg_addr_last;
        arb_in.cfg_single_shot <= usr_cfg_single_shot;

        if usr_req_frame='1' then
          if usr_req_ena='1' then
            v_fragment := usr_req_data;
          end if;
          v_shift := usr_req_ena;
          shift_reg_active <= '1';

        elsif shift_reg_active='1' then
          
          -- flush at end of frame
          if cnt=0 then
            -- nothing to flush, stop immediately
            shift_reg_active <= '0';
            v_shift := '0';
          else
            v_fragment := (others=>'0');
            v_shift := '1';
          end if;
           
        else
          v_shift := '0';
        end if;
      
        if v_shift='1' then
          -- NOTE: First word is placed into MSBs and then shifted to the LSBs.
          -- when writing to RAM the first word must be in LSBs.
          shift_reg_data(RAM_ARBITER_DATA_WIDTH-USER_DATA_WIDTH-1 downto 0) <= 
            shift_reg_data(RAM_ARBITER_DATA_WIDTH-1 downto USER_DATA_WIDTH);
          shift_reg_data(RAM_ARBITER_DATA_WIDTH-1 downto RAM_ARBITER_DATA_WIDTH-USER_DATA_WIDTH) <= v_fragment;
      
          if cnt=to_unsigned(RAM_REQ_PERIOD-1,cnt'length) then
            arb_in.req_ena <= '1';
            cnt <= (others=>'0');
          else
            cnt <= cnt + 1;
          end if;

        end if;
        
        arb_in.req_frame <= usr_req_frame or shift_reg_active;
        
      end if; --reset 
    end if; --clock
  end process;

  -- request data
  arb_in.req_data <= shift_reg_data;

  -- error reporting (with pipeline register)
  usr_req_ovfl <= arb_out.req_ovfl when rising_edge(clk);
  usr_req_fifo_ovfl <= arb_out.req_fifo_ovfl when rising_edge(clk);

  -- completion acknowledge is irrelevant (only required for read)
  arb_in.cpl_ack <= '0';

end architecture;
