-------------------------------------------------------------------------------
--! @file       prbs_3gpp_wrapper.vhdl
--! @author     Fixitfetish
--! @date       23/Apr/2019
--! @version    0.10
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;

entity prbs_3gpp_wrapper is
generic (
  --! @brief Number of shifts/bits per cycle. Cannot exceed the length of the shift register.
  BITS_PER_CYCLE : positive range 1 to 31 := 1
);
port (
  --! Synchronous reset
  rst       : in  std_logic;
  --! Clock
  clk       : in  std_logic;
  --! Clock enable
  clk_ena   : in  std_logic := '1';
  --! Initial contents of X2 shift register after reset.
  seed      : in  std_logic_vector(30 downto 0);
  --! Shift register output, right aligned. Is shifted right by BITS_PER_CYCLE bits in each cycle.
  dout      : out std_logic_vector(BITS_PER_CYCLE-1 downto 0)
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of prbs_3gpp_wrapper is

  signal seed_q, dout_3gpp : std_logic_vector(30 downto 0);

begin

  seed_q <= seed when rising_edge(clk);

  i_3gpp : entity work.prbs_3gpp
  generic map(
    BITS_PER_CYCLE => BITS_PER_CYCLE
  )
  port map (
    rst        => rst,
    clk        => clk,
    clk_ena    => clk_ena,
    seed       => seed_q,
    dout       => dout_3gpp
  );

  dout <= dout_3gpp(dout'range) when rising_edge(clk);

end architecture;
