-------------------------------------------------------------------------------
--! @file       dsp_opmode_logic.dsp58.vhdl
--! @author     Fixitfetish
--! @date       29/Dec/2021
--! @version    0.00-draft
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Code comments are optimized for SIGASI and DOXYGEN.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

--! @brief This entity implements a generic DSP input logic for Xilinx Versal.
--!
--! Refer to Xilinx Versal ACAP DSP Engine, Architecture Manual, AM004 (v1.1.2) July 15, 2021
--!
entity dsp_opmode_logic_dsp58 is
generic (
  NUM_INPUT_REG    : natural := 1;
  --! Cascade Chain Input PCIN Enable.
  USE_CHAIN_INPUT  : boolean := false;
  --! Input C Enable.
  USE_C_INPUT      : boolean := false;
  --! DSP internal P output register enable
  ENABLE_P_REG     : boolean := true
);
port (
  --! Standard system clock
  clk     : in  std_logic;
  --! Global synchronous reset (optional, only connect if really required!)
  rst     : in  std_logic := '0';
  --! Clock enable (optional)
  clkena  : in  std_logic := '1';
  clr     : in  std_logic := '1';
  vld     : in  std_logic;
  opmode  : out std_logic_vector(8 downto 0)
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of dsp_opmode_logic_dsp58 is

  signal pipe_clr : std_logic_vector(NUM_INPUT_REG downto 0);
  signal pipe_vld : std_logic_vector(NUM_INPUT_REG downto 0);

  signal clr_q, clr_i : std_logic;

  alias opmode_xy is opmode(3 downto 0);
  alias opmode_z  is opmode(6 downto 4);
  alias opmode_w  is opmode(8 downto 7);

begin

  pipe_clr(NUM_INPUT_REG) <= clr;
  pipe_vld(NUM_INPUT_REG) <= vld;

  -- control signal input pipeline
  g_ctrl : if NUM_INPUT_REG>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if rst/='0' then
          pipe_clr(NUM_INPUT_REG-1 downto 0) <= (others=>'1');
          pipe_vld(NUM_INPUT_REG-1 downto 0) <= (others=>'0');
        elsif clkena='1' then
          pipe_clr(NUM_INPUT_REG-1 downto 0) <= pipe_clr(NUM_INPUT_REG downto 1);
          pipe_vld(NUM_INPUT_REG-1 downto 0) <= pipe_vld(NUM_INPUT_REG downto 1);
        end if;
      end if;
    end process;
  end generate;

  -- hold clear until next valid
  p_clr : process(clk)
  begin
    if rising_edge(clk) then
      if rst/='0' then
        clr_q<='1';
      elsif clkena='1' then
        if pipe_clr(0)='1' and pipe_vld(0)='0' then
          clr_q<='1';
        elsif pipe_vld(0)='1' then
          clr_q<='0';
        end if;
      end if;
    end if;
  end process;
  clr_i <= pipe_clr(0) or clr_q;

  -- control signal inputs
  opmode_xy <= "0101"; -- constant, always multiplier result M
  opmode_z  <= "001" when USE_CHAIN_INPUT else -- PCIN
               "011" when USE_C_INPUT else -- Input C
               "000"; -- unused
  opmode_w  <= "11" when (USE_CHAIN_INPUT and USE_C_INPUT) else -- input C
               "10" when clr_i='1' else -- add rounding constant with clear signal
               "00" when (not ENABLE_P_REG) else -- add zero when P register disabled
               "01"; -- feedback P accumulator register output

end architecture;
