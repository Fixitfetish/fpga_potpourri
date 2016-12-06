-------------------------------------------------------------------------------
-- FILE    : signed_mult2_accu.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 03/Dec/2016
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
 use fixitfetish.ieee_extension.all;

-- Two Signed Multiplications and Accumulate both
-- The delay is one clock cycle when the additional input and output registers are
-- disabled.
--   reset accumulator    : if vld=0 and clr=1  then  r = undefined 
--   restart accumulation : if vld=1 and clr=1  then  r = +/- (ax*ay) +/- (bx*by)
--   hold accumulator     : if vld=0 and clr=0  then  r = r
--   proceed accumulation : if vld=1 and clr=0  then  r = r +/- (ax*ay) +/- (bx*by)
--
-- If just two multiplications and the sum of both is required but not accumulation
-- then set clr='1'. 
--

entity signed_mult2_accu is
generic (
  -- use additional input register (strongly recommended)
  INPUT_REG : boolean := true;
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
  -- second product, second sigend factor
  b_y   : in  signed;
  -- result valid output
  r_vld : out std_logic;
  -- resulting product/accumulator output (optionally rounded and clipped)
  r_out : out signed;
  -- output overflow/clipping detection
  r_ovf : out std_logic
);
begin
  assert (a_x'length+a_y'length)=(b_x'length+b_y'length)
    report "ERROR signed_mult2_accu : Both products must result in same size."
    severity failure;
end entity;

