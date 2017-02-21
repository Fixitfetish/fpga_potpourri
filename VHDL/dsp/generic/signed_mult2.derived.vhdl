-------------------------------------------------------------------------------
--! @file       signed_mult2.derived.vhdl
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

--! @brief This implementation uses two parallel instances of
--! @link signed_mult1 signed_mult1 @endlink .
--! Hence, this implementation is not device specific and can be used for
--! simulation and synthesis based on the @link signed_mult1 signed_mult1 @endlink
--! implementation.
--!
--! * Input Data      : 2x2 signed values
--! * Input Register  : optional, at least one is strongly recommended
--! * Rounding        : optional half-up
--! * Output Data     : 2x signed values
--! * Output Register : optional, after shift-right and saturation
--! * Pipeline stages : 1,2,3,... dependent on configuration

architecture derived of signed_mult2 is
begin

  dsp0 : entity fixitfetish.signed_mult1
  generic map(
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
    vld        => vld,
    neg        => neg(0),
    x          => x0,
    y          => y0,
    result     => result0,
    result_vld => result_vld(0),
    result_ovf => result_ovf(0),
    PIPESTAGES => PIPESTAGES
  );

  dsp1 : entity fixitfetish.signed_mult1
  generic map(
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
    vld        => vld,
    neg        => neg(1),
    x          => x1,
    y          => y1,
    result     => result1,
    result_vld => result_vld(1),
    result_ovf => result_ovf(1),
    PIPESTAGES => open  -- same as for result0
  );

end architecture;
