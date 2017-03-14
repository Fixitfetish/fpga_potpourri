-------------------------------------------------------------------------------
--! @file       signed_mult1.derived.vhdl
--! @author     Fixitfetish
--! @date       08/Feb/2017
--! @version    0.20
--! @copyright  MIT License
--! @note       VHDL-1993
-------------------------------------------------------------------------------
-- Copyright (c) 2017 Fixitfetish
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library fixitfetish;
 use fixitfetish.ieee_extension.all;

--! @brief This implementation is a subset of the ACCU implementation.
--! The accumulator is cleared with every valid input data. Hence, this
--! implementation is not device specific and can be used for simulation
--! and synthesis based on the @link signed_mult1_accu signed_mult1_accu @endlink
--! implementation.
--!
--! * Input Data      : 2 signed values
--! * Input Register  : optional, at least one is strongly recommended
--! * Rounding        : optional half-up
--! * Output Data     : 1x signed value
--! * Output Register : optional, after shift-right and saturation
--! * Pipeline stages : 1,2,3,... dependent on configuration

architecture derived of signed_mult1 is
begin

  dsp : entity fixitfetish.signed_mult1_accu
  generic map(
    NUM_SUMMAND => 1,
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
    sub        => neg,
    x          => x,
    y          => y,
    result     => result,
    result_vld => result_vld,
    result_ovf => result_ovf,
    chainin    => open, -- unused
    chainout   => open, -- unused
    PIPESTAGES => PIPESTAGES
  );

end architecture;
