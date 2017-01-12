-------------------------------------------------------------------------------
-- FILE    : signed_mult_accu.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 06/Jan/2017
-- VERSION : 0.70
-- VHDL    : 1993
-- LICENSE : MIT License
-------------------------------------------------------------------------------
-- Copyright (c) 2016-2017 Fixitfetish
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;

-- Signed Multiply and Accumulate
--
-- The delay depends on the configuration and the underlying hardware. The
-- number pipeline stages is reported as constant at output port PIPE.
--
--   reset accumulator    : if vld=0 and clr=1  then  r = 0
--   restart accumulation : if vld=1 and clr=1  then  r = +/- (x * y)
--   hold accumulator     : if vld=0 and clr=0  then  r = r  
--   proceed accumulation : if vld=1 and clr=0  then  r = r +/- (x * y)
--
-- If just multiplication is required but not any further accumulation then
-- constantly set clr='1'.
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

entity signed_mult_accu is
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
  NUM_SUMMAND : natural := 0;
  -- Use additional input register (strongly recommended)
  -- If available the input register within the DSP cell is used.
  INPUT_REG : boolean := true;
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
  -- standard system clock
  clk   : in  std_logic;
  -- clear accumulator (mark first two valid input factors of accumulation sequence)
  clr   : in  std_logic;
  -- data valid input
  vld   : in  std_logic;
  -- add/subtract, '0'=> +(x*y), '1'=> -(x*y)
  sub   : in  std_logic;
  -- first signed factor input 
  x     : in  signed;
  -- second signed factor input 
  y     : in  signed;
  -- result valid output
  r_vld : out std_logic;
  -- resulting product/accumulator output (optionally rounded and clipped)
  r_out : out signed;
  -- output overflow/clipping detection
  r_ovf : out std_logic;
  -- number of pipeline stages, constant, depends on configuration and hardware
  PIPE : out natural := 0
);
end entity;

