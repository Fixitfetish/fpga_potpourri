-------------------------------------------------------------------------------
--! @file       cplx_mult.vhdl
--! @author     Fixitfetish
--! @date       16/Jun/2017
--! @version    0.40
--! @note       VHDL-1993
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

--! @brief N complex multiplications.
--!
--! @image html cplx_mult.svg "" width=600px
--!
--! Use this entity for full complex multiplications or scalar multiplications. 
--!
--! If just weighting (only real factor) is required use the entity cplx_weight
--! instead because less multiplications and resources are required in this case.
--! Two operation modes are supported:
--! 1. result(n) = +/- x(n) * y(n)  # separate factor y for each element of x
--! 2. result(n) = +/- x(n) * y(0)  # factor y is the same for all elements of x
--!
--! The length of the input factors is flexible.
--! The input factors are automatically resized with sign extensions bits to the
--! maximum possible factor length needed.
--! The maximum length of the input factors is device and implementation specific.
--! The size of the real and imaginary part of a complex input must be identical.
--! The maximum result width is
--!   W = x.re'length + y.re'length + 1 .
--! (Note that a complex multiplication requires two signed multiplication, hence
--!  an additional guard bit is needed.)
--!
--! Dependent on result.re'length a shift right is required to avoid overflow or clipping.
--!   OUTPUT_SHIFT_RIGHT = W - result.re'length .
--! The number right shifts can also be smaller with the risk of overflows/clipping.
--!
--! The delay depends on the configuration and the underlying hardware.
--! The number pipeline stages is reported as constant at output port PIPESTAGES.
--! Note that the number of input register stages should be chosen carefully
--! because dependent on the number of inputs the number resulting registers
--! in logic can be very high. If just more delay is needed use additional
--! output registers instead of input registers.
--!
--! The Double Data Rate (DDR) clock 'clk2' input is only relevant when a DDR
--! implementation of this module is used.
--! Note that the double rate clock 'clk2' must have double the frequency of
--! system clock 'clk' and must be synchronous and related to 'clk'.
--!
--! Also available are the following entities:
--! * cplx_mult_accu
--! * cplx_mult_sum
--! * cplx_weight
--! * cplx_weight_accu
--! * cplx_weight_sum
--!
--! VHDL Instantiation Template:
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
--! I1 : cplx_mult
--! generic map(
--!   NUM_MULT              => positive, -- number of parallel multiplications
--!   HIGH_SPEED_MODE       => boolean,  -- enable high speed mode
--!   NUM_INPUT_REG         => natural,  -- number of input registers
--!   NUM_OUTPUT_REG        => natural,  -- number of output registers
--!   OUTPUT_SHIFT_RIGHT    => natural,  -- number of right shifts
--!   MODE                  => cplx_mode -- options
--! )
--! port map(
--!   clk        => in  std_logic, -- clock
--!   clk2       => in  std_logic, -- clock x2
--!   neg        => in  std_logic_vector(0 to NUM_MULT-1), -- negation per input x
--!   x          => in  cplx_vector(0 to NUM_MULT-1), -- first factors
--!   y          => in  cplx_vector, -- second factors
--!   result     => out cplx_vector(0 to NUM_MULT-1), -- product results
--!   PIPESTAGES => out natural -- constant number of pipeline stages
--! );
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--!

entity cplx_mult is
generic (
  --! Number of parallel multiplications - mandatory generic!
  NUM_MULT : positive;
  --! Enable high speed mode with more pipelining for higher clock rates
  HIGH_SPEED_MODE : boolean := false;
  --! @brief Number of additional input registers in system clock domain.
  --! At least one is strongly recommended.
  --! If available the input registers within the DSP cell are used.
  NUM_INPUT_REG : natural := 1;
  --! @brief Number of additional result output registers in system clock domain.
  --! At least one is recommended when logic for rounding and/or clipping is enabled.
  --! Typically all output registers are implemented in logic and are not part of a DSP cell.
  NUM_OUTPUT_REG : natural := 0;
  --! Number of bits by which the result output is shifted right
  OUTPUT_SHIFT_RIGHT : natural := 0;
  --! Supported operation modes 'R','O','N','S' and 'X'
  MODE : cplx_mode := "-"
);
port (
  --! Standard system clock
  clk        : in  std_logic;
  --! Optional double rate clock (only relevant when a DDR implementation is used)
  clk2       : in  std_logic := '0';
  --! @brief Negation of partial products , '0' -> +(x(n)*y(n)), '1' -> -(x(n)*y(n)).
  --! By default negation is disabled.
  --! Dependent on the DSP cell type some implementations might not fully support
  --! the negation feature. Either additional logic is required or negation
  --! of certain input indices is not supported. Please refer to the description of
  --! vendor specific implementation.
  neg        : in  std_logic_vector(0 to NUM_MULT-1) := (others=>'0');
  --! x(n) are the complex inputs of the N multiplications.
  x          : in  cplx_vector(0 to NUM_MULT-1);
  --! complex factor (either one for all elements of X or one per each element of X). Requires 'TO' range.
  y          : in  cplx_vector;
  --! Resulting product output vector (optionally rounded and clipped).
  result     : out cplx_vector(0 to NUM_MULT-1);
  --! Number of pipeline stages, constant, depends on configuration and device specific implementation
  PIPESTAGES : out natural := 0
);
begin

  assert ((y'length=1 or y'length=x'length) and y'ascending)
    report "ERROR in " & cplx_mult'INSTANCE_NAME & 
           " Input vector Y must have length of 1 or 'TO' range with same length as input X."
    severity failure;

  assert (x(x'left).re'length=x(x'left).im'length) and (y(y'left).re'length=y(y'left).im'length)
     and (result(result'left).re'length=result(result'left).im'length)
    report "ERROR in " & cplx_mult'INSTANCE_NAME & 
           " Real and imaginary components must have same size."
    severity failure;

  assert (MODE/='U' and MODE/='Z' and MODE/='I')
    report "ERROR in " & cplx_mult'INSTANCE_NAME & 
           " Rounding options 'U', 'Z' and 'I' are not supported."
    severity failure;

end entity;
