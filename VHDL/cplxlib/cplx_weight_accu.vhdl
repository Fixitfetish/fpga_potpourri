-------------------------------------------------------------------------------
--! @file       cplx_weight_accu.vhdl
--! @author     Fixitfetish
--! @date       16/Jun/2017
--! @version    0.20
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;
library cplxlib;
  use cplxlib.cplx_pkg.all;

--! @brief N complex values are weighted (scaled) with one scalar or N scalar
--! values. Finally the weighted results are accumulated.
--!
--! @image html cplx_weight_accu.svg "" width=600px
--!
--! For pure weighting use this entity instead of @link cplx_mult_accu @endlink
--! because less multiplications are required than with the entity cplx_mult_accu.
--!
--! First operation mode (separate weighting factor w for each element of x)
--! * vld = x0.vld and x1.vld and ...
--! * CLR=1  VLD=0  ->  r = undefined                       # reset accumulator
--! * CLR=1  VLD=1  ->  r = +/-(x0*w0) +/-(x1*w1) +/-...    # restart accumulation
--! * CLR=0  VLD=0  ->  r = r                               # hold accumulator
--! * CLR=0  VLD=1  ->  r = r +/-(x0*w0) +/-(x1*w1) +/-...  # proceed accumulation
--!
--! Second operation mode (weighting factor w is the same for all elements of x):
--! * vld = x0.vld and x1.vld and ...
--! * CLR=1  VLD=0  ->  r = undefined                       # reset accumulator
--! * CLR=1  VLD=1  ->  r = +/-(x0*w0) +/-(x1*w0) +/-...    # restart accumulation
--! * CLR=0  VLD=0  ->  r = r                               # hold accumulator
--! * CLR=0  VLD=1  ->  r = r +/-(x0*w0) +/-(x1*w0) +/-...  # proceed accumulation
--!
--! Note that for the second mode a more efficient implementation might be possible
--! because only one multiplication after summation is required.
--!
--! The length of the input factors is flexible.
--! The input factors are automatically resized with sign extensions bits to the
--! maximum possible factor length needed.
--! The maximum length of the input factors is device and implementation specific.
--! The size of the real and imaginary part of a complex input must be identical.
--! The maximum result width is
--!   WIDTH = x.re'length + w'length + ceil(log2(NUM_SUMMAND)).
--! Note that the width increases dependent on the number of summands.
--!
--! Dependent on result.re'length a shift right is required to avoid overflow or clipping.
--!   OUTPUT_SHIFT_RIGHT = WIDTH - result.re'length .
--! The number right shifts can also be smaller with the risk of overflows/clipping.
--!
--! If just multiplication and the sum of products is required but not further
--! accumulation then set CLR to constant '1' or use the entity cplx_weight_sum
--! instead.
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
--! * cplx_mult
--! * cplx_mult_accu
--! * cplx_mult_sum
--! * cplx_weight
--! * cplx_weight_sum
--!
--! VHDL Instantiation Template:
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
--! I1 : cplx_weight_accu
--! generic map(
--!   NUM_MULT              => positive, -- number of parallel multiplications
--!   NUM_SUMMAND           => natural,  -- number of overall summands
--!   NUM_INPUT_REG         => natural,  -- number of input registers
--!   NUM_OUTPUT_REG        => natural,  -- number of output registers
--!   OUTPUT_SHIFT_RIGHT    => natural,  -- number of right shifts
--!   MODE                  => cplx_mode -- options
--! )
--! port map(
--!   clk        => in  std_logic, -- clock
--!   clk2       => in  std_logic, -- clock x2
--!   clr        => in  std_logic, -- clear accumulator
--!   neg        => in  std_logic_vector(0 to NUM_MULT-1), -- negation
--!   x          => in  cplx_vector(0 to NUM_MULT-1), -- complex values
--!   w          => in  signed_vector, -- weighting factors
--!   result     => out cplx, -- product sum result
--!   PIPESTAGES => out natural -- constant number of pipeline stages
--! );
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--!

entity cplx_weight_accu is
generic (
  --! Number of parallel multiplications - mandatory generic!
  NUM_MULT : positive;
  --! @brief The number of summands is important to determine the number of additional
  --! guard bits (MSBs) that are required for the accumulation process. @link NUM_SUMMAND More...
  --!
  --! The setting is relevant to save logic especially when saturation/clipping
  --! and/or overflow detection is enabled.
  --! * 0 => maximum possible, not recommended (worst case, hardware dependent)
  --! * 1 => just one multiplication without accumulation
  --! * 2 => accumulate up to 2 products
  --! * 3 => accumulate up to 3 products
  --! * and so on ...
  --!
  --! Note that every single accumulated complex product result counts!
  NUM_SUMMAND : natural := 0;
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
  --! @brief Clear accumulator (mark first valid input factors of accumulation sequence).
  --! If accumulation is not wanted then set constant '1'.
  clr        : in  std_logic;
  --! @brief Negation of partial products , '0' -> +(x(n)*w(n)), '1' -> -(x(n)*w(n)).
  --! Negation is disabled by default.
  neg        : in  std_logic_vector(0 to NUM_MULT-1) := (others=>'0');
  --! x(n) are the complex values to be weighted with w.
  x          : in  cplx_vector(0 to NUM_MULT-1);
  --! weighting factor (either one for all elements of X or one per each element of X). Requires 'TO' range.
  w          : in  signed_vector;
  --! Resulting product sum output (optionally rounded and clipped).
  result     : out cplx;
  --! Number of pipeline stages, constant, depends on configuration and device specific implementation
  PIPESTAGES : out natural := 0
);
begin

  assert ((w'length=1 or w'length=x'length) and w'ascending)
    report "ERROR in " & cplx_weight_accu'INSTANCE_NAME & 
           " Input vector W must have length of 1 or 'TO' range with same length as input X."
    severity failure;

  assert (x(x'left).re'length=x(x'left).im'length)
     and (result.re'length=result.im'length)
    report "ERROR in " & cplx_weight_accu'INSTANCE_NAME & 
           " Real and imaginary components must have same size."
    severity failure;

  assert (MODE/='U' and MODE/='Z' and MODE/='I')
    report "ERROR in " & cplx_weight_accu'INSTANCE_NAME & 
           " Rounding options 'U', 'Z' and 'I' are not supported."
    severity failure;

end entity;
