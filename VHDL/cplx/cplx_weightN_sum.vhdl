-------------------------------------------------------------------------------
--! @file       cplx_weightN_sum.vhdl
--! @author     Fixitfetish
--! @date       25/Mar/2017
--! @version    0.10
--! @copyright  MIT License
--! @note       VHDL-1993
-------------------------------------------------------------------------------
-- Copyright (c) 2017 Fixitfetish
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library fixitfetish;
 use fixitfetish.ieee_extension_types.all;
 use fixitfetish.cplx_pkg.all;

--! @brief N complex values are weighted (scaled) with one scalar or N scalar
--! values. Finally the weighted results are summed.
--!
--! @image html cplx_weightN_sum.svg "" width=600px
--!
--! For pure scaling use this entity instead of @link cplx_multN_sum @endlink
--! because less multiplications are required than with the entity cplx_multN_sum.
--! Two operation modes are supported:
--! 1. result = +/-x(0)*w(0) +/-x(1)*w(1) ...     # separate weighting factor w for each element of x
--! 2. result = ( +/-x(0) +/-x(1) +/- ... ) * w   # weighting factor w is the same for all elements of x
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
--!   WIDTH = x.re'length + w'length + ceil(log2(2*N)).
--! Note that the width increases dependent on the number of summands.
--!
--! Dependent on result.re'length a shift right is required to avoid overflow or clipping.
--!   OUTPUT_SHIFT_RIGHT = WIDTH - result.re'length .
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
--! * cplx_weightN
--! * cplx_weightN_accu
--! * cplx_multN
--! * cplx_multN_accu
--! * cplx_multN_sum
--!
--! VHDL Instantiation Template:
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
--! I1 : cplx_weightN_sum
--! generic map(
--!   NUM_INPUT_REG      => natural,  -- number of input registers
--!   NUM_OUTPUT_REG     => natural,  -- number of output registers
--!   OUTPUT_SHIFT_RIGHT => natural,  -- number of right shifts
--!   m                  => cplx_mode -- options
--! )
--! port map(
--!   clk        => in  std_logic, -- clock
--!   clk2       => in  std_logic, -- clock x2
--!   sub        => in  std_logic_vector, -- add/subtract
--!   x          => in  cplx_vector, -- complex values
--!   w          => in  signed_vector, -- weighting factors
--!   result     => out cplx, -- product/sum result
--!   PIPESTAGES => out natural -- constant number of pipeline stages
--! );
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--!

entity cplx_weightN_sum is
generic (
  --! @brief Number of additional input registers in system clock domain.
  --! At least one is strongly recommended.
  --! If available the input registers within the DSP cell are used.
  NUM_INPUT_REG : natural := 1;
  --! @brief Number of additional result output registers in system clock domain.
  --! At least one is recommended when logic for rounding and/or clipping is enabled.
  --! Typically all output registers are implemented in logic and are not part of a DSP cell.
  NUM_OUTPUT_REG : natural := 0;
  --! Number of bits by which the product result output is shifted right
  OUTPUT_SHIFT_RIGHT : natural := 0;
  --! Supported operation modes 'R','O','N' and 'S'
  m : cplx_mode := "-"
);
port (
  --! Standard system clock
  clk        : in  std_logic;
  --! Optional double rate clock (only relevant when a DDR implementation is used)
  clk2       : in  std_logic := '0';
  --! Add/Subtract of all N inputs, '0' -> +(x(n)*w(n)), '1' -> -(x(n)*w(n)). Requires 'TO' range.
  sub        : in  std_logic_vector;
  --! x(n) are the complex values to be weighted with w. Use 'TO' range.
  x          : in  cplx_vector;
  --! weighting factor (either one for all elements of X or one per each element of X). Requires 'TO' range.
  w          : in  signed_vector;
  --! Resulting product output vector (optionally rounded and clipped)
  result     : out cplx;
  --! Number of pipeline stages, constant, depends on configuration and device specific implementation
  PIPESTAGES : out natural := 0
);
begin
  assert (x'left<=x'right)
    report "ERROR in cplx_weightN_sum : Input vector X must have 'TO' range."
    severity failure;

  assert (sub'length=x'length and sub'left<=sub'right)
    report "ERROR in cplx_weightN_sum : Input vector SUB must have 'TO' range with same length as input vector X."
    severity failure;

  assert ((w'length=1 or w'length=x'length) and (w'left<=w'right))
    report "ERROR in cplx_weightN_sum : Input vector W must have length of 1 or 'TO' range with same length as input X."
    severity failure;

  assert (m/='U' and m/='Z' and m/='I')
    report "ERROR in cplx_weightN_sum : Rounding options 'U', 'Z' and 'I' are not supported."
    severity failure;
end entity;

