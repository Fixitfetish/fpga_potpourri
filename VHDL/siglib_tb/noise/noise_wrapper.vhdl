-------------------------------------------------------------------------------
--! @file       noise_wrapper.vhdl
--! @author     Fixitfetish
--! @date       26/Jun/2019
--! @version    0.30
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library siglib;

entity noise_wrapper is
generic (
  --! @brief In the default request mode one valid value is output one cycle after the request.
  --! In acknowledge mode the output always shows the next value which must be acknowledged to
  --! get a new value in next cycle.
  ACKNOWLEDGE_MODE : boolean := true;
  --! @brief Number required output bits.
  OUTPUT_WIDTH : positive := 18
);
port (
  --! Synchronous reset
  rst       : in  std_logic;
  --! Clock
  clk       : in  std_logic;
  --! Clock enable
  req_ack   : in  std_logic := '1';
  --! Shift register output, right aligned. Is shifted right by SHIFTS_PER_CYCLE bits in each cycle.
  dout      : out signed(OUTPUT_WIDTH-1 downto 0);
  --! clock enable
  dout_vld  : out std_logic
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of noise_wrapper is

  signal req_ack_q : std_logic;
  signal dout_i : signed(OUTPUT_WIDTH-1 downto 0);
  signal dout_vld_i : std_logic;

begin

  req_ack_q <= req_ack when rising_edge(clk);

  i_wgn : entity siglib.noise_normal
  generic map(
    RESOLUTION       => OUTPUT_WIDTH,
    ACKNOWLEDGE_MODE => ACKNOWLEDGE_MODE,
    INSTANCE_IDX     => 0
  )
  port map (
    clk        => clk,
    rst        => rst,
    req_ack    => req_ack_q,
    dout       => dout_i,
    dout_vld   => dout_vld_i,
    dout_first => open,
    PIPESTAGES => open
  );

  dout <= dout_i(dout'range) when rising_edge(clk);
  dout_vld <= dout_vld_i;

end architecture;
