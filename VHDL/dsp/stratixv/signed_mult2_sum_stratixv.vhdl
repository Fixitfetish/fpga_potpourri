-------------------------------------------------------------------------------
-- FILE    : signed_mult2_sum_stratixv.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 24/Jan/2017
-- VERSION : 0.60
-- VHDL    : 1993
-- LICENSE : MIT License
-------------------------------------------------------------------------------
-- Copyright (c) 2016-2017 Fixitfetish
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library fixitfetish;
 use fixitfetish.ieee_extension.all;

-- This implementation requires a single Variable Precision DSP Block.
-- Please refer to the Altera Stratix V Device Handbook.
--
-- Input Data      : 2x2 signed values, each max 18 bits
-- Input Register  : optional, strongly recommended
-- Accu Register   : 64 bits, always enabled
-- Rounding        : optional half-up, within DSP cell
-- Output Data     : 1x signed value, max 64 bits
-- Output Register : optional, after shift-right and saturation
-- Overall pipeline stages : 1,2,3,... dependent on configuration

architecture stratixv of signed_mult2_sum is
begin

  -- NOTE: - subset of ACCU implementation
  --       - clear accumulator with every valid input data

  dsp : entity fixitfetish.signed_mult2_accu
  generic map(
    NUM_SUMMAND => 2,
    USE_CHAININ => false,
    NUM_INPUT_REG => NUM_INPUT_REG,
    OUTPUT_REG => OUTPUT_REG,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND => OUTPUT_ROUND,
    OUTPUT_CLIP => OUTPUT_CLIP,
    OUTPUT_OVERFLOW => OUTPUT_OVERFLOW
  )
  port map(
    clk      => clk,
    rst      => rst,
    clr      => vld,
    vld      => vld,
    sub      => sub,
    x0       => x0,
    y0       => y0,
    x1       => x1,
    y1       => y1,
    r_vld    => r_vld,
    r_out    => r_out,
    r_ovf    => r_ovf,
    chainin  => open, -- unused
    chainout => chainout,
    PIPE     => PIPE
  );

end architecture;
