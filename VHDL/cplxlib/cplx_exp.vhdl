-------------------------------------------------------------------------------
--! @file       cplx_exp.vhdl
--! @author     Fixitfetish
--! @date       07/Nov/2024
--! @version    0.52
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

--! @brief Complex exponential function
--!
--! The phase input can be either signed or unsigned 
--! * SIGNED with range -N/2 to N/2-1 (i.e. -pi to pi)
--! * UNSIGNED with range 0 to N-1 (i.e. 0 to 2pi)
--!
--! If PHASE_MINOR_WIDTH=0 then the sine and cosine values are precalculated
--! for all phases and stored in a look-up table ROM (LUT). The required ROM
--! becomes larger when PHASE_MAJOR_WIDTH increases. In this case an additional
--! interpolation/approximation is not needed.
--! 
--! Interpolation/approximation is enabled when PHASE_MINOR_WIDTH>0 .
--!
--! The overall number of pipeline stages is reported at the constant output
--! port PIPESTAGES.
--!
--! For more details please refer to @link sincos siglib.sincos @endlink .
--! 
--! VHDL Instantiation Template:
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
--! I1 : cplx_exp
--! generic map(
--!   PHASE_MAJOR_WIDTH  => positive, -- Major phase resolution in bits
--!   PHASE_MINOR_WIDTH  => natural,  -- Minor phase resolution in bits
--!   OUTPUT_WIDTH       => positive, -- Output resolution of real and imaginary component in bits
--!   FRACTIONAL_SCALING => real,     -- Static fractional down-scaling
--!   OPTIMIZATION       => string    -- optional optimization setting
--! )
--! port map(
--!   clk        => in  std_logic, -- clock
--!   rst        => in  std_logic, -- reset
--!   clkena     => in  std_logic, -- clock enable
--!   phase_vld  => in  std_logic, -- Valid signal for input
--!   phase      => in  std_logic_vector, -- Phase input, either unsigned or signed
--!   dout       => out cplx, -- Complex result output
--!   PIPESTAGES => out natural -- constant number of pipeline stages
--! );
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--!
entity cplx_exp is
generic (
  --! @brief Major phase resolution in bits (MSBs of the phase input).
  --! This resolution influences the depth of generated look-up table ROM.
  PHASE_MAJOR_WIDTH : positive := 11;
  --! @brief Minor phase resolution in bits (LSBs of the phase input).
  --! This resolution defines the granularity of the interpolation/approximation.
  PHASE_MINOR_WIDTH : natural := 0;
  --! @brief Output resolution of real and imaginary component in bits. 
  --! This resolution influences the width of the generated look-up table ROM.
  OUTPUT_WIDTH : positive := 18;
  --! @brief Static fractional down-scaling influences the values in the LUT-ROM.
  --! For values below 0.5 consider reduction of OUTPUT_WIDTH with potential FPGA resource savings.
  FRACTIONAL_SCALING : std.standard.real range 0.0 to 1.0 := 1.0;
  --! Valid values for the optimization are "" or "TIMING"
  OPTIMIZATION : string := ""
);
port (
  --! Standard system clock
  clk        : in  std_logic;
  --! Reset result output (optional)
  rst        : in  std_logic := '0';
  --! clock enable (optional)
  clkena     : in  std_logic := '1';
  --! Valid signal for input, high-active
  phase_vld  : in  std_logic;
  --! Phase input, either unsigned (range 0 to 2**N-1) or signed (range -(2**(N-1)) to 2**(N-1)-1)
  phase      : in  std_logic_vector(PHASE_MAJOR_WIDTH+PHASE_MINOR_WIDTH-1 downto 0);
  --! Complex result output
  dout       : out cplx;
  --! Number of pipeline stages, constant, depends on configuration
  PIPESTAGES : out natural := 1
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of cplx_exp is

  signal dout_i : cplx(re(OUTPUT_WIDTH-1 downto 0),im(OUTPUT_WIDTH-1 downto 0));

begin

  dout_i.rst <= rst;
  dout_i.ovf <= '0';

  i_sincos : entity siglib.sincos
  generic map (
    PHASE_MAJOR_WIDTH  => PHASE_MAJOR_WIDTH,
    PHASE_MINOR_WIDTH  => PHASE_MINOR_WIDTH,
    OUTPUT_WIDTH       => OUTPUT_WIDTH,
    FRACTIONAL_SCALING => FRACTIONAL_SCALING,
    OPTIMIZATION       => OPTIMIZATION
  )
  port map (
    clk        => clk,
    rst        => rst,
    clkena     => clkena,
    phase_vld  => phase_vld,
    phase      => phase,
    dout_vld   => dout_i.vld,
    dout_cos   => dout_i.re,
    dout_sin   => dout_i.im,
    PIPESTAGES => PIPESTAGES
  );

  dout <= dout_i;

end architecture;
