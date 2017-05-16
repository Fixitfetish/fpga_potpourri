-------------------------------------------------------------------------------
--! @file       signed_mult1add1_sum.stratixv.vhdl
--! @author     Fixitfetish
--! @date       17/Mar/2017
--! @version    0.10
--! @copyright  MIT License
--! @note       VHDL-1993
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension.all;
library dsplib;

library stratixv;
  use stratixv.stratixv_components.all;

--! @brief This is an implementation of the entity
--! @link signed_mult1add1_sum signed_mult1add1_sum @endlink
--! for Altera Stratix-V.
--! A product of two signed values is added or subtracted to/from a third signed value.
--! Optionally the chain input can be added as well.
--!
--! Here the DSP primitive is not used. The implementation is derived from the Stratix-V
--! implementation of @link signed_mult1add1_accu signed_mult1add1_accu @endlink .
--!
--! * Input Data X,Y  : 2 signed values, x<=18 bits, y<=18 bits
--! * Input Data Z    : 1 signed value, z<=36 bits
--! * Input Register  : optional, at least one is strongly recommended
--! * Input Chain     : optional, 64 bits
--! * Result Register : 64 bits, enabled when NUM_OUTPUT_REG>0
--! * Rounding        : optional half-up, within DSP cell
--! * Output Data     : 1x signed value, max 64 bits
--! * Output Register : optional, at least one strongly recommend, another after shift-right and saturation
--! * Output Chain    : optional, 64 bits
--! * Pipeline stages : NUM_INPUT_REG_XY + NUM_OUTPUT_REG (main data path through multiplier)
--!
--! This implementation can be chained multiple times.

architecture stratixv of signed_mult1add1_sum is
begin

  -- derive from instance with accumulator
  i_accu : entity dsplib.signed_mult1add1_accu
  generic map(
    NUM_SUMMAND        => NUM_SUMMAND,
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    NUM_INPUT_REG_XY   => NUM_INPUT_REG_XY,
    NUM_INPUT_REG_Z    => NUM_INPUT_REG_Z,
    NUM_OUTPUT_REG     => NUM_OUTPUT_REG,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => OUTPUT_ROUND,
    OUTPUT_CLIP        => OUTPUT_CLIP,
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
  )
  port map (
    clk        => clk,
    rst        => rst,
    clr        => '1', -- disable accumulation
    vld        => vld,
    sub        => sub,
    x          => x,
    y          => y,
    z          => z,
    result     => result,
    result_vld => result_vld,
    result_ovf => result_ovf,
    chainin    => chainin,
    chainout   => chainout,
    PIPESTAGES => PIPESTAGES
  );

end architecture;

