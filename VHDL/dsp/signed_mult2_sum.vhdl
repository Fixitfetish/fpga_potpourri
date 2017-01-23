-------------------------------------------------------------------------------
-- FILE    : signed_mult2_sum.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 22/Jan/2017
-- VERSION : 0.50
-- VHDL    : 1993
-- LICENSE : MIT License
-------------------------------------------------------------------------------
-- Copyright (c) 2016-2017 Fixitfetish
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;

-- Two Signed Multiplications and sum of both
--
-- The delay depends on the configuration and the underlying hardware. The
-- number pipeline stages is reported as constant at output port PIPE.
--
--   if vld=0  then  r = r
--   if vld=1  then  r = +/-(x0*y0) +/-(x1*y1)

entity signed_mult2_sum is
generic (
  -- The number of summands is important to determine the number of additional
  -- guard bits (MSBs) that are required for the accumulation process.
  -- The setting is relevant to save logic especially when saturation/clipping
  -- and/or overflow detection is enabled.
  --   0 => maximum possible, not recommended (worst case, hardware dependent)
  --   1 => just one multiplication without accumulation
  --   2 => accumulate up to 2 products
  --   3 => accumulate up to 3 products
  --   and so on ...
  -- Note that every single accumulated product counts!
  NUM_SUMMAND : natural := 0;
  -- Number of additional input register (at least one is strongly recommended)
  -- If available the input registers within the DSP cell are used.
  NUM_INPUT_REG : natural := 1;
  -- Additional data output register (recommended when logic for rounding and/or clipping is enabled)
  -- Typically the output register is implemented in logic. 
  OUTPUT_REG : boolean := false;
  -- Number of bits by which the accumulator result output is shifted right
  OUTPUT_SHIFT_RIGHT : natural := 0;
  -- Round data output (only relevant when OUTPUT_SHIFT_RIGHT>0)
  OUTPUT_ROUND : boolean := true;
  -- Enable clipping when right shifted result exceeds output range
  OUTPUT_CLIP : boolean := true;
  -- Overflow/clipping detection 
  OUTPUT_OVERFLOW : boolean := true
);
port (
  -- Standard system clock
  clk      : in  std_logic;
  -- Reset result data output (optional)
  rst      : in  std_logic := '0';
  -- Data valid input
  vld      : in  std_logic;
  -- add/subtract for all products n=0..1 , '0'=> +(x(n)*y(n)), '1'=> -(x(n)*y(n))
  sub      : in  std_logic_vector(0 to 1);
  -- 1st product, signed factors
  x0, y0   : in  signed;
  -- 2nd product, signed factors
  x1, y1   : in  signed;
  -- Result valid output
  r_vld    : out std_logic;
  -- Resulting product/accumulator output (optionally rounded and clipped)
  -- The standard result output might be unused when chain output is used instead.
  r_out    : out signed;
  -- Output overflow/clipping detection
  r_ovf    : out std_logic;
  -- Result output to other chained DSP cell (optional)
  -- The output width is HW specific.
  chainout : out signed;
  -- Number of pipeline stages, constant, depends on configuration and hardware
  PIPE     : out natural := 0
);
begin

  assert (x0'length+y0'length)=(x1'length+y1'length)
    report "ERROR signed_mult2_sum : Both products must result in same size."
    severity failure;

  assert (not OUTPUT_ROUND) or (OUTPUT_SHIFT_RIGHT>0)
    report "WARNING signed_mult2_sum : Disabled rounding because OUTPUT_SHIFT_RIGHT is 0."
    severity warning;

end entity;

