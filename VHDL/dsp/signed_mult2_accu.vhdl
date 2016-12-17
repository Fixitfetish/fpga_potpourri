-------------------------------------------------------------------------------
-- FILE    : signed_mult2_accu.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 17/Dec/2016
-- VERSION : 0.60
-- VHDL    : 1993
-- LICENSE : MIT License
-------------------------------------------------------------------------------
-- Copyright (c) 2016 Fixitfetish
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;

-- Two signed multiplications and accumulate both
--
-- The delay depends on the configuration and the underlying hardware. The
-- number pipeline stages is reported as constant at output port PIPE.
--
--   reset accumulator    : if vld=0 and clr=1  then  r = undefined 
--   restart accumulation : if vld=1 and clr=1  then  r = +/- (ax*ay) +/- (bx*by)
--   hold accumulator     : if vld=0 and clr=0  then  r = r
--   proceed accumulation : if vld=1 and clr=0  then  r = r +/- (ax*ay) +/- (bx*by)
--
-- This entity can be used for example
--   * for complex multiplication and accumulation
--   * to calculate the mean square of a complex numbers
--
-- If just two multiplications and the sum of both is required but not any further
-- accumulation then constantly set clr='1'.
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
-- PRODUCT WIDTH = ax'length+ay'length-1 = bx'length+by'length-1
-- GUARD BITS = number additional guard bits required for accumulation
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
-- GUARD BITS = OUTPUT WIDTH + OUTPUT SHIFT RIGHT - PRODUCT WIDTH + 1

entity signed_mult2_accu is
generic (
  -- Number of additional guard bits (maximum possible depends on hardware)
  -- The setting is relevant to save logic especially when saturation/clipping
  -- and/or overflow detection is enabled.
  --  -1 => maximum possible (worst case, hardware dependent)
  --   0 => no accumulation, just one multiplication
  --   1 => accumulate up to 2 products
  --   2 => accumulate up to 4 products
  --   3 => accumulate up to 8 products
  --   and so on ...
  -- Note that every single accumulated product counts, not the pair of products!
  GUARD_BITS : integer range -1 to 255 := -1;
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
  -- reset result data output (optional)
  rst   : in  std_logic := '0'; 
  -- clear accumulator (mark first four valid input factors of accumulation sequence)
  clr   : in  std_logic;
  -- data valid input
  vld   : in  std_logic;
  -- first product add/subtract, '0'=> +(ax*ay), '1'=> -(ax*ay)
  a_sub : in  std_logic;
  -- first product, first signed factor
  a_x   : in  signed;
  -- first product, second signed factor
  a_y   : in  signed;
  -- second product add/subtract, '0'=> +(bx*by), '1'=> -(bx*by)
  b_sub : in  std_logic;
  -- second product, first signed factor
  b_x   : in  signed;
  -- second product, second signed factor
  b_y   : in  signed;
  -- result valid output
  r_vld : out std_logic;
  -- resulting product/accumulator output (optionally rounded and clipped)
  r_out : out signed;
  -- output overflow/clipping detection
  r_ovf : out std_logic;
  -- number of pipeline stages, constant, depends on configuration and hardware
  PIPE : out natural := 0
);
begin

  assert (a_x'length+a_y'length)=(b_x'length+b_y'length)
    report "ERROR signed_mult2_accu : Both products must result in same size."
    severity failure;

  assert (not OUTPUT_ROUND) or (OUTPUT_SHIFT_RIGHT>0)
    report "WARNING signed_mult2_accu : Disabled rounding because OUTPUT_SHIFT_RIGHT is 0."
    severity warning;

end entity;

