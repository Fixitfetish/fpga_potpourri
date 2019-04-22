-------------------------------------------------------------------------------
--! @file       prbs_3gpp.vhdl
--! @author     Fixitfetish
--! @date       22/Apr/2019
--! @version    0.10
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
library siglib;

--! @brief Generation of Pseudo Random Bit Sequence (Gold) according to 3GPP TS 36.211
--!
entity prbs_3gpp is
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
  dout      : out std_logic_vector(30 downto 0)
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of prbs_3gpp is

  -- shift registers
  signal x1, x2 : std_logic_vector(30 downto 0);

begin

  i_x1 : entity siglib.lfsr
  generic map(
    EXPONENTS      => (31,28),
    BITS_PER_CYCLE => BITS_PER_CYCLE,
    OFFSET         => 1600, -- Nc
    FIBONACCI      => true
  )
  port map (
    rst        => rst,
    clk        => clk,
    clk_ena    => clk_ena,
    seed       => (0=>'1', others=>'0'), -- constant seed
    dout       => x1
  );

  i_x2 : entity siglib.lfsr
  generic map(
    EXPONENTS      => (31,30,29,28),
    BITS_PER_CYCLE => BITS_PER_CYCLE,
    OFFSET         => 1600, -- Nc
    FIBONACCI      => true
  )
  port map (
    rst        => rst,
    clk        => clk,
    clk_ena    => clk_ena,
    seed       => seed,
    dout       => x2
  );

  -- final output
  dout <= x1 xor x2;

end architecture;
