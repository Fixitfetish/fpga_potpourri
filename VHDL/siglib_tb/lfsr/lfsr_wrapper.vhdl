-------------------------------------------------------------------------------
--! @file       lfsr_wrapper.vhdl
--! @author     Fixitfetish
--! @date       04/May/2019
--! @version    0.10
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;

entity lfsr_wrapper is
generic (
  TAPS : integer_vector := (40,38,21,19);
  SHIFTS_PER_CYCLE : positive := 64;
  --! @brief In the default request mode one valid value is output one cycle after the request.
  --! In acknowledge mode the output always shows the next value which must be acknowledged to
  --! get a new value in next cycle.
  ACKNOWLEDGE_MODE : boolean := true;
  --! @brief Number required output bits.
  OUTPUT_WIDTH : positive := 64;
  --! Enable additional output register
  OUTPUT_REG : boolean := true
);
port (
  --! Synchronous reset
  rst       : in  std_logic;
  --! Clock
  clk       : in  std_logic;
  --! Clock enable
  req_ack   : in  std_logic := '1';
  --! Initial contents of X2 shift register after reset.
  seed      : in  std_logic_vector(TAPS(TAPS'left)-1 downto 0);
  --! Shift register output, right aligned. Is shifted right by BITS_PER_CYCLE bits in each cycle.
  dout      : out std_logic_vector(OUTPUT_WIDTH-1 downto 0)
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of lfsr_wrapper is

  signal seed_q : std_logic_vector(seed'range);
  signal dout_i : std_logic_vector(OUTPUT_WIDTH-1 downto 0);

begin

  seed_q <= seed when rising_edge(clk);

  i_lfsr : entity siglib.lfsr
  generic map(
    TAPS             => TAPS,
    FIBONACCI        => true,
    SHIFTS_PER_CYCLE => SHIFTS_PER_CYCLE,
    ACKNOWLEDGE_MODE => ACKNOWLEDGE_MODE,
    OFFSET           => 0,
    OFFSET_LOGIC     => "input",
    TRANSFORM_SEED   => false,
    OUTPUT_WIDTH     => OUTPUT_WIDTH,
    OUTPUT_REG       => OUTPUT_REG 
  )
  port map (
    clk          => clk,
    load         => rst,
    req_ack      => req_ack,
    seed         => seed_q,
    dout         => dout_i,
    dout_vld_rdy => open,
    dout_first   => open
  );

  dout <= dout_i(dout'range) when rising_edge(clk);

end architecture;
