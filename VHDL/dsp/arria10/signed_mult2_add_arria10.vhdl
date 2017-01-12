-------------------------------------------------------------------------------
-- FILE    : signed_mult2_add_arria10.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 06/Jan/2017
-- VERSION : 0.40
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
-- Please refer to Arria 10 Native Fixed Point DSP IP Core User Guide.
-- UG-01163,  2016.06.10 
--
-- Input Data      : 2x2 signed values, each max 18 bits
-- Input Register  : optional, strongly recommended
-- Accu Register   : 64 bits, always enabled
-- Rounding        : optional half-up, within DSP cell
-- Output Data     : 1x signed value, max 64 bits
-- Output Register : optional, after shift-right and saturation
-- Overall pipeline stages : 1..3 dependent on configuration

architecture arria10 of signed_mult2_add is
begin

  -- NOTE: - subset of ACCU implementation
  --       - clear accumulator with every valid input data

  i_dsp : entity fixitfetish.signed_mult2_accu
  generic map(
    NUM_SUMMAND => 2,
    INPUT_REG => INPUT_REG,
    OUTPUT_REG => OUTPUT_REG,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND => OUTPUT_ROUND,
    OUTPUT_CLIP => OUTPUT_CLIP,
    OUTPUT_OVERFLOW => OUTPUT_OVERFLOW
  )
  port map(
    clk   => clk,
    rst   => rst,
    clr   => vld,
    vld   => vld,
    a_sub => a_sub,
    a_x   => a_x,
    a_y   => a_y,
    b_sub => b_sub,
    b_x   => b_x,
    b_y   => b_y,
    r_vld => r_vld,
    r_out => r_out,
    r_ovf => r_ovf,
    PIPE  => PIPE
  );

end architecture;
