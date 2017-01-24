-------------------------------------------------------------------------------
-- FILE    : cplx_mult4_accu.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 24/Jan/2017
-- VERSION : 0.10
-- VHDL    : 1993
-- LICENSE : MIT License
-------------------------------------------------------------------------------
-- Copyright (c) 2017 Fixitfetish
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library fixitfetish;
 use fixitfetish.cplx_pkg.all;

-- Four complex multiplications and accumulate all complex product results.
-- In general, this multiplier is a good choice when FPGA DSP cells shall be used.
--
-- The delay depends on the configuration and the underlying hardware. The
-- number pipeline stages is reported as constant at output port PIPE.
--
--   vld = x0.vld and y0.vld and x1.vld and y1.vld
--   reset accumulator    : if vld=0 and clr=1  then  r = undefined
--   restart accumulation : if vld=1 and clr=1  then  r = +/-(x0*y0) +/-(x1*y1) +/-...
--   hold accumulator     : if vld=0 and clr=0  then  r = r
--   proceed accumulation : if vld=1 and clr=0  then  r = r +/-(x0*y0) +/-(x1*y1) +/-...
--
-- If just multiplication and the sum of products is required but not accumulation
-- then set clr='1'. 
--
-- The size of the real and imaginary part of a complex input must be identical.
-- Without sum and accumulation the maximum result width in the accumulation
-- register LSBs is
--   W = x'length + y'length + 1  (complex multiplication requires additional guard bit)
-- Dependent on r_out'length and NUM_SUMMAND a shift right is required to avoid
-- overflow or clipping.
--   OUTPUT_SHIFT_RIGHT = W + ceil(log2(NUM_SUMMAND)) - r_out'length
--
-- The Double Data Rate (DDR) clock 'clk2' input is only relevant when a DDR
-- implementation of this module is used.
-- Note that the double rate clock 'clk2' must have double the frequency of
-- system clock 'clk' and must be synchronous and related to 'clk'.
 
entity cplx_mult4_accu is
generic (
  -- The number of summands is important to determine the number of additional
  -- guard bits (MSBs) that are required for the accumulation process.
  -- The setting is relevant to save logic especially when saturation/clipping
  -- and/or overflow detection is enabled.
  --   0 => maximum possible, not recommended (worst case, hardware dependent)
  --   1 => just one complex multiplication without accumulation
  --   2 => accumulate up to 2 complex products
  --   3 => accumulate up to 3 complex products
  --   and so on ...
  -- Note that every single accumulated complex product counts, not the pair of complex products!
  NUM_SUMMAND : natural := 0;
  -- Number of additional input register in system clock domain (typically using logic elements)
  NUM_INPUT_REG : natural := 0;
  -- Additional output register in system clock domain (typically using logic elements)
  OUTPUT_REG : boolean := false;
  -- Number of bits by which the product/accumulator result is shifted right
  OUTPUT_SHIFT_RIGHT : natural := 0;
  -- Supported operation modes 'R','O','N' and 'S'
  m : cplx_mode := "-"
);
port (
  -- Standard system clock
  clk  : in  std_logic;
  -- Optional double rate clock (only relevant when a DDR implementation is used)
  clk2 : in  std_logic := '0';
  -- Clear accumulator, marks first pair of valid input factors of accumulation sequence
  clr  : in  std_logic;
  -- Add/subtract ,  sub(n)='0' => +(x(n)*y(n)) ,  sub(n)='1' => -(x(n)*y(n))
  sub  : in  std_logic_vector(0 to 3);
  -- x(n) are the first complex factors of the n multiplications
  x    : in  cplx_vector(0 to 3);
  -- y(n) are the second complex factors of the n multiplications
  y    : in  cplx_vector(0 to 3);
  -- Resulting product/accumulator output (optionally rounded and clipped)
  r    : out cplx;
  -- Number of pipeline stages, constant, depends on configuration and hardware
  PIPE : out natural := 0
);
begin

  assert (m/='U' and m/='Z' and m/='I')
    report "ERROR in cplx_mult2_accu : Rounding options 'U', 'Z' and 'I' are not supported."
    severity failure;

  assert (x(0).re'length=x(0).im'length) and (y(0).re'length=y(0).im'length) and (r.re'length=r.im'length)
    report "ERROR in cplx_mult2_accu : Real and imaginary components must have same size."
    severity failure;

end entity;

