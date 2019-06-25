-------------------------------------------------------------------------------
--! @file       cplx_noise_wrapper.vhdl
--! @author     Fixitfetish
--! @date       24/Jun/2019
--! @version    0.20
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library cplxlib;
  use cplxlib.cplx_pkg.all;

entity cplx_noise_wrapper is
generic (
  --! @brief Number required output bits.
  RESOLUTION : positive := 16;
  --! @brief In the default request mode one valid value is output one cycle after the request.
  --! In acknowledge mode the output always shows the next value which must be acknowledged to
  --! get a new value in next cycle.
  ACKNOWLEDGE_MODE : boolean := true
);
port (
  --! Synchronous reset
  rst       : in  std_logic;
  --! Clock
  clk       : in  std_logic;
  --! clock enable
  clkena    : in  std_logic;
  --! Clock enable
  req_ack   : in  std_logic := '1';
  --! Shift register output, right aligned. Is shifted right by SHIFTS_PER_CYCLE bits in each cycle.
  dout_re   : out signed(RESOLUTION-1 downto 0);
  dout_im   : out signed(RESOLUTION-1 downto 0);
  --! clock enable
  dout_vld  : out std_logic
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of cplx_noise_wrapper is

  signal req_ack_q : std_logic;
  signal dout_i : cplx(re(RESOLUTION-1 downto 0),im(RESOLUTION-1 downto 0));

begin

  req_ack_q <= req_ack when rising_edge(clk);

  i_wgn : entity cplxlib.cplx_noise_normal
  generic map(
    RESOLUTION       => RESOLUTION,
    ACKNOWLEDGE_MODE => ACKNOWLEDGE_MODE,
    INSTANCE_IDX     => 0
  )
  port map (
    clk         => clk,
    rst         => rst,
    req_ack     => req_ack_q,
    dout        => dout_i,
    PIPESTAGES  => open
  );

  dout_re <= dout_i.re when rising_edge(clk);
  dout_im <= dout_i.im when rising_edge(clk);
  dout_vld <= dout_i.vld;

end architecture;
