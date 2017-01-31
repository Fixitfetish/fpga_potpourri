-------------------------------------------------------------------------------
--! @file       signed_mult2_sum_derived.vhdl
--! @author     Fixitfetish
--! @date       30/Jan/2017
--! @version    0.20
--! @copyright  MIT License
--! @note       VHDL-1993
-------------------------------------------------------------------------------
-- Copyright (c) 2016-2017 Fixitfetish
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library fixitfetish;
 use fixitfetish.ieee_extension.all;

--! @brief This implementation subset of ACCU implementation. The accumulator is
--! cleared with every valid input data. Hence, this implementation is not device
--! specific and can be used for simulation and synthesis based on the
--! @link signed_mult2_accu signed_mult2_accu @endlink implementation.
--!
--! * Input Data      : 2x2 signed values
--! * Input Register  : optional, at least one is strongly recommended
--! * Rounding        : optional half-up
--! * Output Data     : 1x signed value
--! * Output Register : optional, after shift-right and saturation
--! * Pipeline stages : 1,2,3,... dependent on configuration

architecture derived of signed_mult2_sum is
begin

  dsp : entity fixitfetish.signed_mult2_accu
  generic map(
    NUM_SUMMAND => 2,
    USE_CHAIN_INPUT => false,
    NUM_INPUT_REG => NUM_INPUT_REG,
    NUM_OUTPUT_REG => NUM_OUTPUT_REG,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND => OUTPUT_ROUND,
    OUTPUT_CLIP => OUTPUT_CLIP,
    OUTPUT_OVERFLOW => OUTPUT_OVERFLOW
  )
  port map(
    clk        => clk,
    rst        => rst,
    clr        => vld,
    vld        => vld,
    sub        => sub,
    x0         => x0,
    y0         => y0,
    x1         => x1,
    y1         => y1,
    result     => result,
    result_vld => result_vld,
    result_ovf => result_ovf,
    chainin    => open, -- unused
    chainout   => chainout,
    PIPESTAGES => PIPESTAGES
  );

end architecture;
