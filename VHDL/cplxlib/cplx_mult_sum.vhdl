-------------------------------------------------------------------------------
--! @file       cplx_mult_sum.vhdl
--! @author     Fixitfetish
--! @date       16/Jun/2017
--! @version    0.50
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

--! @brief N complex multiplications and sum all product results.
--!
--! This entity can be used for :
--! * scalar product (dot product) of two complex vectors x and y
--! * complex matrix multiplication
--!
--! If just weighting (only real factor) and summation is required then use the
--! entity cplx_weight_sum instead because less multiplications and resources are
--! needed in this case.
--!
--! The first operation mode is:
--! * vld = (x0.vld and y0.vld) and (x1.vld and y1.vld) and ...
--! * VLD=1  ->  r = +/-(x0*y0) +/-(x1*y1) +/-...    # calculate sum
--! * VLD=0  ->  r = r                               # hold previous result
--!
--! The second operation mode is (single y factor):
--! * vld = (x0.vld and x1.vld and ...) and y0.vld
--! * VLD=1  ->  r = +/-(x0*y0) +/-(x1*y0) +/-...    # calculate sum
--! * VLD=0  ->  r = r                               # hold previous result
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
--!   W = x'length + y'length + ceil(log2(2*NUM_MULT)) .
--! (Note that a complex multiplication requires two signed multiplication, hence
--!  an additional guard bit.)
--!
--! Dependent on result'length a shift right is required to avoid overflow or clipping.
--!   OUTPUT_SHIFT_RIGHT = W - result'length .
--! The number right shifts can also be smaller with the risk of overflows/clipping.
--!
--! The number of delay cycles depend on the configuration and the underlying hardware.
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
--! @image html cplx_mult_sum.svg "" width=600px
--!
--! Also available are the following entities:
--! * cplx_mult
--! * cplx_mult_accu
--! * cplx_weight
--! * cplx_weight_accu
--! * cplx_weight_sum
--!
--! VHDL Instantiation Template:
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
--! I1 : cplx_mult_sum
--! generic map(
--!   NUM_MULT           => positive, -- number of parallel multiplications
--!   HIGH_SPEED_MODE    => boolean,  -- enable high speed mode
--!   USE_NEGATION       => boolean,  -- enable negation port
--!   NUM_INPUT_REG      => natural,  -- number of input registers
--!   NUM_OUTPUT_REG     => natural,  -- number of output registers
--!   OUTPUT_SHIFT_RIGHT => natural,  -- number of right shifts
--!   MODE               => cplx_mode -- options
--! )
--! port map(
--!   clk        => in  std_logic, -- clock
--!   clk2       => in  std_logic, -- clock x2
--!   neg        => in  std_logic_vector(0 to NUM_MULT-1), -- negation
--!   x          => in  cplx_vector(0 to NUM_MULT-1), -- first factors
--!   y          => in  cplx_vector, -- second factor(s)
--!   result     => out cplx, -- product result
--!   PIPESTAGES => out natural -- constant number of pipeline stages
--! );
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--!

entity cplx_mult_sum is
generic (
  --! Number of parallel multiplications - mandatory generic!
  NUM_MULT : positive;
  --! Enable high speed mode with more pipelining for higher clock rates
  HIGH_SPEED_MODE : boolean := false;
  --! @brief Enable negation port. If enabled then dynamic negation of partial
  --! products is implemented (preferably within the DSP cells otherwise in logic). 
  --! Enabling the negation might have negative side effects on pipeline stages,
  --! input width limitations and timing.
  --! Disable negation if not needed and the negation port input is ignored.
  USE_NEGATION : boolean := false;
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
  --! Negation is disabled by default.
  --! Dependent on the DSP cell type some implementations might not fully support
  --! the subtraction feature. Either additional logic is required or subtraction
  --! of certain input indices is not supported. Please refer to the description of
  --! vendor specific implementation.
  neg        : in  std_logic_vector(0 to NUM_MULT-1) := (others=>'0');
  --! x(n) are the first complex factors of the N multiplications.
  x          : in  cplx_vector(0 to NUM_MULT-1);
  --! y(n) are the second complex factors of the N multiplications. Requires 'TO' range.
  y          : in  cplx_vector;
  --! Resulting product/accumulator output (optionally rounded and clipped).
  result     : out cplx;
  --! Number of pipeline stages, constant, depends on configuration and device specific implementation
  PIPESTAGES : out natural := 0
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert ((y'length=1 or y'length=x'length) and y'ascending)
    report "ERROR in " & cplx_mult_sum'INSTANCE_NAME & 
           " Input vector Y must have length of 1 or 'TO' range with same length as input X."
    severity failure;

  assert (x(x'left).re'length=x(x'left).im'length) and (y(y'left).re'length=y(y'left).im'length)
     and (result.re'length=result.im'length)
    report "ERROR in " & cplx_mult_sum'INSTANCE_NAME & 
           " Real and imaginary components must have same size."
    severity failure;

  assert (MODE/='U' and MODE/='Z' and MODE/='I')
    report "ERROR in " & cplx_mult_sum'INSTANCE_NAME & 
           " Rounding options 'U', 'Z' and 'I' are not supported."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;
