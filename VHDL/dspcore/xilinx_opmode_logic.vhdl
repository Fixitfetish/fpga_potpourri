-------------------------------------------------------------------------------
--! @file       xilinx_opmode_logic.vhdl
--! @author     Fixitfetish
--! @date       15/Jan/2022
--! @version    0.10
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Code comments are optimized for SIGASI and DOXYGEN.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension.all;

--! @brief This entity implements a generic opmode logic for Xilinx Devices.
--!
--! Special handling of CLR=1 and VLD=0
--!
--! The P accumulator register will not be cleared and/or preset with the rounding bit immediately.
--! Instead the clear operation will be postponed to the next valid cycle.
--! This can save power because unnecessary toggling of the P register is avoided,
--! especially when accumulation is not needed and CLR is constant 1.
--!
--! **ACCU Mode**
--! * Only PCIN or C can accumulated in addition to XY.
--!
--! | CLR_Q(out) | CLR | VLD |  CLR_Q(in) | Operation P                 | Comment                                      |
--! |------------|-----|-----|------------|-----------------------------|----------------------------------------------|
--! |    0 / 1   |  1  |  0  |     1      | P = P                       | Hold output register P, set CLR pending bit  |
--! |    0 / 1   |  0  |  0  | CLR_Q(out) | P = P                       | Hold output register P, keep CLR pending bit |
--! |    0 / 1   |  1  |  1  |     0      | P = RND + XY + (PCIN or C)  | Restart Accumulation, clear CLR pending bit  |
--! |      1     |  0  |  1  |     0      | P = RND + XY + (PCIN or C)  | Restart Accumulation, clear CLR pending bit  |
--! |      0     |  0  |  1  |     0      | P = P + XY + (PCIN or C)    | Proceed Accumulation, clear CLR pending bit  |
--!
--! **SUM Mode** (always CLR=1)
--! * Adding round bit RND not possible when PCIN and C are used.
--!
--! | CLR | VLD | Operation P                     | Comment                  |
--! |-----|-----|---------------------------------|--------------------------|
--! |  1  |  0  | P = P                           | Hold output register P   |
--! |  1  |  1  | P = XY + (2 of RND, PCIN or C)  |                          |
--!
--! Refer to 
--! * Xilinx UltraScale Architecture DSP48E2 Slice, UG579 (v1.11) August 30, 2021
--! * Xilinx Versal ACAP DSP Engine, Architecture Manual, AM004 (v1.1.2) July 15, 2021
--!
--! VHDL Instantiation Template:
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
--! I1 : entity work.xilinx_opmode_logic
--! generic map(
--!   USE_PCIN_INPUT => boolean,
--!   USE_C_INPUT    => boolean,
--!   USE_P_REG      => boolean
--! )
--! port map(
--!   clk    => in  std_logic,
--!   rst    => in  std_logic,
--!   clkena => in  std_logic,
--!   clr    => in  std_logic, -- clear
--!   vld    => in  std_logic, -- valid
--!   opmode => out std_logic_vector(8 downto 0)
--! );
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--!
entity xilinx_opmode_logic is
generic (
  --! Enable Chain input
  USE_PCIN_INPUT : boolean := false;
  --! Enable C input
  USE_C_INPUT : boolean := false;
  --! Enable P output and accumulation register
  ENABLE_P_REG : boolean := true
);
port (
  --! Clock
  clk    : in  std_logic;
  --! Synchronous reset
  rst    : in  std_logic;
  --! Clock enable
  clkena : in  std_logic;
  --! Clear P
  clr    : in  std_logic;
  --! Data inputs valid
  vld    : in  std_logic;
  --! Resulting OPMODE
  opmode : out std_logic_vector(8 downto 0)
);
end entity;

-------------------------------------------------------------------------------

architecture macc of xilinx_opmode_logic is

  alias opmode_xy is opmode(3 downto 0);
  alias opmode_z  is opmode(6 downto 4);
  alias opmode_w  is opmode(8 downto 7);

  signal clr_q : std_logic := '0';

begin

  -- CLR pending bit
  pclr : process(clk) begin
    if rising_edge(clk) then
      if rst/='0' then
        clr_q <= '0';
      elsif clkena='1' then
        if clr='1' and vld='0' then
          clr_q <= '1';
        elsif vld='1' then
          clr_q <= '0';
        end if;
      end if;
    end if;
  end process;


  -- XY input is always used for product M
  opmode_xy <= "0101";

  -- Z input is preferably used for chain input
  opmode_z  <= "001" when USE_PCIN_INPUT else -- PCIN
               "011" when USE_C_INPUT else -- Input C
               "000"; -- unused

  -- W input is preferably used for P feedback and round bit.
  -- Only used for C input when chain input is enabled in addition.
  opmode_w  <= "11" when (USE_PCIN_INPUT and USE_C_INPUT) else -- input C
               "10" when (clr='1' or clr_q='1') else -- clear P and initialize P with rounding constant
               "00" when (not ENABLE_P_REG) else -- add zero when P register disabled
               "01"; -- feedback P accumulator register output

end architecture;
