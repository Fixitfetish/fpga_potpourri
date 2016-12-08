-------------------------------------------------------------------------------
-- FILE    : signed_mult_accu.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 08/Dec/2016
-- VERSION : 0.41
-- VHDL    : 1993
-- LICENSE : MIT License
-------------------------------------------------------------------------------
-- Copyright (c) 2016 Fixitfetish
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;

-- Signed Multiply and Accumulate
-- The delay is one clock cycle when the additional input and output registers are
-- disabled.
--   reset accumulator    : if vld=0 and clr=1  then  r = 0
--   restart accumulation : if vld=1 and clr=1  then  r = +/- (x * y)
--   hold accumulator     : if vld=0 and clr=0  then  r = r  
--   proceed accumulation : if vld=1 and clr=0  then  r = r +/- (x * y)
--
-- If just multiplication is required but not accumulation then set clr='1'. 
--

entity signed_mult_accu is
generic (
  -- use additional input register (strongly recommended)
  INPUT_REG : boolean := false;
  -- additional data output register (recommended when logic for rounding and/or clipping is enabled)
  OUTPUT_REG : boolean := false;
  -- number of bits by which the accumulator result output is shifted right
  OUTPUT_SHIFT_RIGHT : natural := 0;
  -- round data output (only relevant when OUTPUT_SHIFT_RIGHT>0) 
  OUTPUT_ROUND : boolean := true;
  -- enable clipping when right shifted result exceeds output range
  OUTPUT_CLIP : boolean := true;
  -- overflow/clipping detection 
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
  r_ovf : out std_logic
);
end entity;

