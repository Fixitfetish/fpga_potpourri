-------------------------------------------------------------------------------
-- FILE    : signed_mult2_add_stratixv.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 17/Dec/2016
-- VERSION : 0.30
-- VHDL    : 1993
-- LICENSE : MIT License
-------------------------------------------------------------------------------
-- Copyright (c) 2016 Fixitfetish
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library stratixv;
 use stratixv.stratixv_components.all;
library fixitfetish;
 use fixitfetish.ieee_extension.all;

-- This implementation requires a single Variable Precision DSP Block.
-- Please refer to the Altera Stratix V Device Handbook.

architecture stratixv of signed_mult2_add is
begin

  -- NOTE: - subset of ACCU implementation
  --       - clear accumulator with every valid input data

  i_dsp : entity fixitfetish.signed_mult2_accu
  generic map(
    GUARD_BITS => 1,
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
