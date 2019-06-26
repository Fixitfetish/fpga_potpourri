-------------------------------------------------------------------------------
--! @file       cplx_noise_normal.vhdl
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
library cplxlib;
  use cplxlib.cplx_pkg.all;

--! @brief Complex noise generator with normal distribution
--!
--! The mean is zero and the peak power is always +3dBfs.
--!
--! In this preliminary first version the average complex noise power is -12dBfs.
--! Some parameters are still fixed and/or the range is very limited.
--! Further improvements are planned already.
--!
--! The noise is generated based on the entity siglib.noise_normal .
--!
--! VHDL Instantiation Template:
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
--! I1 : cplx_noise_normal
--! generic map (
--!   RESOLUTION       => integer, -- Resolution of real and imaginary component in number of bits
--!   ACKNOWLEDGE_MODE => boolean,
--!   INSTANCE_IDX     => integer
--! )
--! port map (
--!   clk        => in  std_logic, -- clock
--!   rst        => in  std_logic, -- synchronous reset
--!   req_ack    => in  std_logic, 
--!   dout       => out cplx
--!   PIPESTAGES => out natural -- constant number of pipeline stages
--! );
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--!
entity cplx_noise_normal is
generic (
  --! Resolution of real and imaginary component in number of bits
  RESOLUTION : integer range 12 to 20;
  --! @brief In the default request mode a valid value is output with a fixed delay after the request.
  --! In acknowledge mode (first word fall through) the output always shows the next value 
  --! which must be acknowledged to get a new value in next cycle.
  ACKNOWLEDGE_MODE : boolean := false;
  --! @brief The optional instance index has an influence on the seed and the number
  --! of bit shifts per cycles to avoid noise correlation between multiple instances.
  INSTANCE_IDX : integer range 0 to 39 := 0
);
port (
  --! Clock for read and write port
  clk        : in  std_logic;
  --! Synchronous reset
  rst        : in  std_logic := '0';
  --! Request or Acknowledge according to selected mode
  req_ack    : in  std_logic := '1';
  --! Complex noise output.
  dout       : out cplx;
  --! Number of pipeline stages, constant
  PIPESTAGES : out natural := 1
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of cplx_noise_normal is

  signal dout_re, dout_im : signed(RESOLUTION-1 downto 0);
  signal dout_vld : std_logic;
  signal dout_i : cplx(re(RESOLUTION-1 downto 0),im(RESOLUTION-1 downto 0));

begin

  i_wgn_re : entity siglib.noise_normal
  generic map(
    RESOLUTION       => RESOLUTION,
    ACKNOWLEDGE_MODE => ACKNOWLEDGE_MODE,
    INSTANCE_IDX     => 2*INSTANCE_IDX
  )
  port map (
    clk        => clk,
    rst        => rst,
    req_ack    => req_ack,
    dout       => dout_re,
    dout_vld   => dout_vld,
    dout_first => open,
    PIPESTAGES => PIPESTAGES -- same for both WGN instances
  );

  i_wgn_im : entity siglib.noise_normal
  generic map(
    RESOLUTION       => RESOLUTION,
    ACKNOWLEDGE_MODE => ACKNOWLEDGE_MODE,
    INSTANCE_IDX     => 2*INSTANCE_IDX+1
  )
  port map (
    clk        => clk,
    rst        => rst,
    req_ack    => req_ack,
    dout       => dout_im,
    dout_vld   => open,
    dout_first => open,
    PIPESTAGES => open
  );


  dout_i.rst <= rst;
  dout_i.ovf <= '0';
  dout_i.vld <= dout_vld;
  dout_i.re  <= dout_re;
  dout_i.im  <= dout_im;

  dout <= dout_i;

end architecture;
