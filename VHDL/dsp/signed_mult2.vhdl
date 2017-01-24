-------------------------------------------------------------------------------
-- FILE    : signed_mult2.vhdl
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

-- Two independent signed multiplications
--
-- The delay depends on the configuration and the underlying hardware. The
-- number pipeline stages is reported as constant at output port PIPE.
--
--   hold previous   : if vld=0  then  r(n) = r(n)
--   multiply        : if vld=1  then  r(n) = x(n)*y(n)
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

entity signed_mult2 is
generic (
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
  vld      : in  std_logic_vector(0 to 1);
  -- add/subtract for all products n=0..1 , '0'=> +(x(n)*y(n)), '1'=> -(x(n)*y(n))
  sub      : in  std_logic_vector(0 to 1);
  -- 1st product, signed factors
  x0, y0   : in  signed;
  -- 2nd product, signed factors
  x1, y1   : in  signed;
  -- Result valid output
  r_vld    : out std_logic_vector(0 to 1);
  -- Resulting product/accumulator output (optionally rounded and clipped)
  -- The standard result output might be unused when chain output is used instead.
  r0_out, r1_out : out signed;
  -- Output overflow/clipping detection
  r_ovf    : out std_logic_vector(0 to 1);
  -- Number of pipeline stages, constant, depends on configuration and hardware
  PIPE     : out natural := 0
);
begin

  assert (x0'length+y0'length)=(x1'length+y1'length)
    report "ERROR signed_mult2 : Both products must result in same size."
    severity failure;

  assert (not OUTPUT_ROUND) or (OUTPUT_SHIFT_RIGHT>0)
    report "WARNING signed_mult2 : Disabled rounding because OUTPUT_SHIFT_RIGHT is 0."
    severity warning;

end entity;

