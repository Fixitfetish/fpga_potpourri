-------------------------------------------------------------------------------
-- FILE    : signed_mult4_sum.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 22/Jan/2017
-- VERSION : 0.20
-- VHDL    : 1993
-- LICENSE : MIT License
-------------------------------------------------------------------------------
-- Copyright (c) 2017 Fixitfetish
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;

-- Four signed multiplications and sum all product results.
--
-- The delay depends on the configuration and the underlying hardware. The
-- number pipeline stages is reported as constant at output port PIPE.
--
--   hold last result : if vld=0  then  r = r
--   calculate sum    : if vld=1  then  r = +/-(x0*y0) +/-(x1*y1) +/-(x2*y2) +/-...
--
--    <----------------------------------- ACCU WIDTH ------------------------>
--    |        <-------------------------- ACCU USED WIDTH ------------------->
--    |        |              <----------- PRODUCT WIDTH --------------------->
--    |        |              |                                               |
--    +--------+---+----------+-------------------------------+---------------+
--    | unused |  GUARD BITS  |                               |  SHIFT RIGHT  |
--    |SSSSSSSS|OOO|ODDDDDDDDD|DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD|Rxxxxxxxxxxxxxx|
--    +--------+---+----------+-------------------------------+---------------+
--             |   |                                          |
--             |   <------------- OUTPUT WIDTH --------------->
--             <--------- ACCU USED SHIFTED WIDTH ------------>
--
-- ACCU WIDTH = accumulator width (depends on hardware/implementation)
-- PRODUCT WIDTH = ax'length+ay'length = bx'length+by'length
-- NUM_SUMMANDS = number of accumulated products
-- GUARD BITS = ceil(log2(NUM_SUMMANDS))
-- ACCU USED WIDTH = PRODUCT WIDTH + GUARD BITS <= ACCU WIDTH
-- OUTPUT SHIFT RIGHT = number of LSBs to prune
-- OUTPUT WIDTH = r'length
-- ACCU USED SHIFTED WIDTH = ACCU USED WIDTH - OUTPUT SHIFT RIGHT
--
-- S = irrelevant sign extension MSBs
-- O = overflow detection sign bits, all O must be identical otherwise overflow
-- D = output data bits
-- R = rounding bit (+0.5 when round 'nearest' is enabled)
-- x = irrelevant LSBs
--
-- Optimal settings for overflow detection and/or saturation/clipping :
-- GUARD BITS = OUTPUT WIDTH + OUTPUT SHIFT RIGHT + 1 - PRODUCT WIDTH

entity signed_mult4_sum is
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
  -- Enable chain input from other DSP cell, i.e. additional accumulator input
  USE_CHAININ : boolean := false;
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
  -- add/subtract for all products n=0..3 , '0'=> +(x(n)*y(n)), '1'=> -(x(n)*y(n))
  sub      : in  std_logic_vector(0 to 3);
  -- 1st product, signed factors
  x0, y0   : in  signed;
  -- 2nd product, signed factors
  x1, y1   : in  signed;
  -- 3rd product, signed factors
  x2, y2   : in  signed;
  -- 4th product, signed factors
  x3, y3   : in  signed;
  -- Result valid output
  r_vld    : out std_logic;
  -- Resulting product/accumulator output (optionally rounded and clipped)
  -- The standard result output might be unused when chain output is used instead.
  r_out    : out signed;
  -- Output overflow/clipping detection
  r_ovf    : out std_logic;
  -- Input from other chained DSP cell (optional, only used when input enabled and connected)
  -- The input width is HW specific.
  chainin  : in  signed;
  -- Result output to other chained DSP cell (optional)
  -- The output width is HW specific.
  chainout : out signed;
  -- number of pipeline stages, constant, depends on configuration and hardware
  PIPE     : out natural := 0
);
begin

  assert (     (x0'length+y0'length)=(x1'length+y1'length)
           and (x0'length+y0'length)=(x2'length+y2'length)
           and (x0'length+y0'length)=(x3'length+y3'length) )
    report "ERROR signed_mult4_sum : All products must result in same size."
    severity failure;

  assert (not OUTPUT_ROUND) or (OUTPUT_SHIFT_RIGHT>0)
    report "WARNING signed_mult4_sum : Disabled rounding because OUTPUT_SHIFT_RIGHT is 0."
    severity warning;

end entity;

