-------------------------------------------------------------------------------
--! @file       ram_arbiter_write_data_width_adapter.vhdl
--! @author     Fixitfetish
--! @date       29/May/2018
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
--! Data valid towards arbiter is generated after every RAM_ARBITER_DATA_WIDTH/USER_DATA_WIDTH
--! user data valid cycles.

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
  --! Arbiter-IF, User output signals (from user to arbiter)
  arb_usr_out_wr_port : out r_ram_arbiter_usr_out_wr_port;
  --! Arbiter-IF, User input signals (from arbiter to user)
  arb_usr_in_wr_port  : in  r_ram_arbiter_usr_in_wr_port;
  --! User output signals (from user)
  usr_out_wr_port     : in  r_ram_arbiter_usr_out_wr_port;
  --! bypass from input port arb_to_usr_wr_port
  usr_in_wr_port      : out r_ram_arbiter_usr_in_wr_port
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

  constant SIZE_FRAGMENT : positive := USER_DATA_WIDTH;
  constant NUM_FRAGMENT : positive := RAM_ARBITER_DATA_WIDTH / SIZE_FRAGMENT;

  constant FRAGMENT_CNT_WIDTH : positive := log2ceil(NUM_FRAGMENT);
  signal cnt : unsigned(FRAGMENT_CNT_WIDTH-1 downto 0); 

  signal shift_reg : std_logic_vector(RAM_ARBITER_DATA_WIDTH-1 downto 0);
  signal shift_reg_active : std_logic;

begin

  p_input_arbiter : process(clk)
    variable v_shift : std_logic;
    variable v_fragment : std_logic_vector(USER_DATA_WIDTH-1 downto 0);
  begin
    if rising_edge(clk) then

      if rst='1' then
        shift_reg_active <= '0';
        shift_reg <= (others=>'0');
        cnt <= (others=>'0');
        arb_usr_out_wr_port.cfg_addr_first <= (usr_out_wr_port.cfg_addr_first'range=>'-');
        arb_usr_out_wr_port.cfg_addr_last <= (usr_out_wr_port.cfg_addr_last'range=>'-');
        arb_usr_out_wr_port.cfg_single_shot <= '0';
        arb_usr_out_wr_port.frame <= '0';
        arb_usr_out_wr_port.data_vld <= '0'; -- default

      else

        -- bypass
        arb_usr_out_wr_port.cfg_addr_first <= usr_out_wr_port.cfg_addr_first;
        arb_usr_out_wr_port.cfg_addr_last <= usr_out_wr_port.cfg_addr_last;
        arb_usr_out_wr_port.cfg_single_shot <= usr_out_wr_port.cfg_single_shot;

        arb_usr_out_wr_port.data_vld <= '0'; -- default

        if usr_out_wr_port.frame='1' then
          if usr_out_wr_port.data_vld='1' then
            v_fragment := usr_out_wr_port.data;
          end if;
          v_shift := usr_out_wr_port.data_vld;
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
          shift_reg(RAM_ARBITER_DATA_WIDTH-SIZE_FRAGMENT-1 downto 0) <= shift_reg(RAM_ARBITER_DATA_WIDTH-1 downto SIZE_FRAGMENT);
          shift_reg(RAM_ARBITER_DATA_WIDTH-1 downto RAM_ARBITER_DATA_WIDTH-SIZE_FRAGMENT) <= v_fragment;
      
          if cnt=to_unsigned(NUM_FRAGMENT-1,cnt'length) then
            arb_usr_out_wr_port.data_vld <= '1';
            cnt <= (others=>'0');
          else
            cnt <= cnt + 1;
          end if;

        end if;
        
        arb_usr_out_wr_port.frame <= usr_out_wr_port.frame or shift_reg_active;
        
      end if; --reset 
    end if; --clock
  end process;

  arb_usr_out_wr_port.data <= shift_reg;

  -- bypass
  usr_in_wr_port <= arb_usr_in_wr_port;
  
end architecture;
