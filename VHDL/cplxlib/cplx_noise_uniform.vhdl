-------------------------------------------------------------------------------
--! @file       cplx_noise_uniform.vhdl
--! @author     Fixitfetish
--! @date       12/May/2019
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
library siglib;
library cplxlib;
  use cplxlib.cplx_pkg.all;

--! @brief Complex uniform noise generator
--!
--! The noise is generated based on two maximum-length LFSRs,
--! one 40-bit LFSR and one 41-bit LFSR. 
--!
--! VHDL Instantiation Template:
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
--! I1 : cplx_noise_uniform
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
entity cplx_noise_uniform is
generic (
  --! Resolution of real and imaginary component in number of bits
  RESOLUTION : integer range 4 to 40;
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

architecture rtl of cplx_noise_uniform is

  constant TAPS_RE : integer_vector := (40,37,36,35);
  constant TAPS_IM : integer_vector := (41,40,39,38);

--  constant SEED_RE : std_logic_vector(TAPS_RE(TAPS_RE'left)-1 downto 0) := (INSTANCE_IDX=>'1',others=>'0');
--  constant SEED_IM : std_logic_vector(TAPS_IM(TAPS_IM'left)-1 downto 0) := (INSTANCE_IDX=>'1',others=>'0');

  function SEED_RE return std_logic_vector is
    variable s : std_logic_vector(TAPS_RE(TAPS_RE'left)-1 downto 0);
  begin s:=(others=>'0'); s(INSTANCE_IDX):='1'; return s; end function;

  function SEED_IM return std_logic_vector is
    variable s : std_logic_vector(TAPS_IM(TAPS_IM'left)-1 downto 0);
  begin s:=(others=>'0'); s(INSTANCE_IDX):='1'; return s; end function;

  signal dout_re, dout_im : std_logic_vector(RESOLUTION-1 downto 0);
  signal dout_vld : std_logic;
  signal dout_i : cplx(re(RESOLUTION-1 downto 0),im(RESOLUTION-1 downto 0));

begin

  i_lfsr_re : entity siglib.lfsr
  generic map(
    TAPS             => TAPS_RE,
    FIBONACCI        => false,
    SHIFTS_PER_CYCLE => RESOLUTION + INSTANCE_IDX/2,
    ACKNOWLEDGE_MODE => ACKNOWLEDGE_MODE,
    OFFSET           => open, -- unused
    OFFSET_LOGIC     => open, -- unused
    TRANSFORM_SEED   => open, -- unused
    OUTPUT_WIDTH     => RESOLUTION,
    OUTPUT_REG       => false
  )
  port map (
    clk        => clk,
    load       => rst,
    seed       => SEED_RE,
    req_ack    => req_ack,
    dout       => dout_re,
    dout_vld   => dout_vld,
    dout_first => open
  );

  i_lfsr_im : entity siglib.lfsr
  generic map(
    TAPS             => TAPS_IM,
    FIBONACCI        => false,
    SHIFTS_PER_CYCLE => RESOLUTION + INSTANCE_IDX/2,
    ACKNOWLEDGE_MODE => ACKNOWLEDGE_MODE,
    OFFSET           => open, -- unused
    OFFSET_LOGIC     => open, -- unused
    TRANSFORM_SEED   => open, -- unused
    OUTPUT_WIDTH     => RESOLUTION,
    OUTPUT_REG       => false
  )
  port map (
    clk        => clk,
    load       => rst,
    seed       => SEED_IM,
    req_ack    => req_ack,
    dout       => dout_im,
    dout_vld   => open,
    dout_first => open
  );

  dout_i.rst <= rst;
  dout_i.ovf <= '0';
  dout_i.vld <= dout_vld;
  dout_i.re  <= signed(dout_re);
  dout_i.im  <= signed(dout_im);

  dout <= dout_i;
  PIPESTAGES <= 1;

end architecture;
