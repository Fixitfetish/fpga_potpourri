-------------------------------------------------------------------------------
-- FILE    : cplx_mult_accu.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 17/Dec/2016
-- VERSION : 0.40
-- VHDL    : 1993
-- LICENSE : MIT License
-------------------------------------------------------------------------------
-- Copyright (c) 2016 Fixitfetish
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library fixitfetish;
 use fixitfetish.cplx_pkg.all;

-- Complex Multiply and Accumulate
-- In general this multiplier can be used when FPGA DSP cells are used which
-- are capable to run with the double rate of the standard system clock.
-- Hence, a complex multiplication can be performed within one system clock
-- cycle but only half the amount of multiplier resources.
--
-- The delay depends on the configuration and the underlying hardware. The
-- number pipeline stages is reported as constant at output port PIPE.
--
--   vld = x.vld and y.vld
--   reset accumulator    : if vld=0 and clr=1  then  r = undefined
--   restart accumulation : if vld=1 and clr=1  then  r = +/- (x * y)
--   hold accumulator     : if vld=0 and clr=0  then  r = r
--   proceed accumulation : if vld=1 and clr=0  then  r = r +/- (x * y)
--
-- If just multiplication is required but not accumulation then set clr='1'. 
--
-- Without accumulation the result width in the accumulation register LSBs is
--   W = x'length + y'length 
-- Dependent on dout'length and additional N accumulations bits a shift right
-- is required to avoid overflow or clipping.
--   OUTPUT_SHIFT_RIGHT = W - dout'length - N
--
-- The Double Data Rate (DDR) clock 'clk2' input is only relevant when a DDR
-- implementation of this module is used.
-- Note that the double rate clock 'clk2' must have double the frequency of
-- system clock 'clk' and must be synchronous and related to 'clk'.
 
entity cplx_mult_accu is
generic (
  -- The number of summands is important to calculate the number of additional
  -- guard bits (MSBs) required for the accumulation process.
  -- The setting is relevant to save logic especially when saturation/clipping
  -- and/or overflow detection is enabled.
  --   0 => maximum possible, not recommended (worst case, hardware dependent)
  --   1 => just one complex multiplication without accumulation
  --   2 => accumulate up to 2 complex products
  --   3 => accumulate up to 3 complex products
  --   and so on ...
  NUM_SUMMAND : natural := 0;
  -- additional input register in system clock domain (typically using logic elements)
  INPUT_REG : boolean := false;
  -- additional output register in system clock domain (typically using logic elements)
  OUTPUT_REG : boolean := false;
  -- number of bits by which the product/accumulator result is shifted right
  OUTPUT_SHIFT_RIGHT : natural := 0;
  -- supported operation modes 'R','O','N' and 'S'
  m : cplx_mode := "-"
);
port (
  -- standard system clock
  clk  : in  std_logic;
  -- optional double rate clock (only relevant when a DDR implementation is used)
  clk2 : in  std_logic := '0';
  -- clear accumulator, marks first pair of valid input factors of accumulation sequence
  clr  : in  std_logic;
  -- add/subtract, '0'=> +(x*y), '1'=> -(x*y)
  sub  : in  std_logic;
  -- first complex factor 
  x    : in  cplx;
  -- second complex factor 
  y    : in  cplx;
  -- resulting product/accumulator output (optionally rounded and clipped)
  r    : out cplx;
  -- number of pipeline stages, constant, depends on configuration and hardware
  PIPE : out natural := 0
);
begin

  assert (m/='U' and m/='Z' and m/='I')
    report "ERROR in cplx_mult_accu : Rounding options 'U', 'Z' and 'I' are not supported."
    severity failure;

  assert (x.re'length=x.im'length) and (y.re'length=y.im'length) and (r.re'length=r.im'length)
    report "ERROR in cplx_mult_accu : Real and imaginary components must have same size."
    severity failure;

end entity;

