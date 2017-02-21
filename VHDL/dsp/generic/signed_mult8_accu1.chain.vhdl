-------------------------------------------------------------------------------
--! @file       signed_mult8_accu1.chain.vhdl
--! @author     Fixitfetish
--! @date       30/Jan/2017
--! @version    0.30
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

--! @brief This implementation uses two chained instances of signed_mult4_accu1.
--! (which actually are four chained instances of signed_mult2_accu1.)
--! Hence, this implementation is not device specific and can be used for
--! simulation and synthesis based on the signed_mult2_accu1 implementation.
--!
--! * Input Data      : 8x2 signed values
--! * Input Register  : optional, at least one is strongly recommended
--! * Accu Register   : width is implementation specific, always enabled
--! * Rounding        : optional half-up
--! * Output Data     : 1x signed value, max width is implementation specific
--! * Output Register : optional, after rounding, shift-right and saturation
--! * Pipeline stages : NUM_INPUT_REG + NUM_PIPELINE_REG + NUM_OUTPUT_REG
--!
--! This implementation can be chained multiple times.
--! @image html signed_mult8_accu1.chain.svg "" width=800px

architecture chain of signed_mult8_accu1 is

  -- chain width in bits - implementation and device specific !
  signal chain : signed(chainout'length-1 downto 0);
  signal dummy : signed(17 downto 0);

  -- dummy sink to avoid warnings
  procedure signed_sink(d:in signed) is
    variable b : boolean := false;
  begin b := (d(d'right)='1') or b; end procedure;

begin

  -- first instance performs just sum of four products without accumulation
  i1 : entity fixitfetish.signed_mult4_accu1
  generic map(
    NUM_SUMMAND        => 4, -- irrelevant because chain output is used
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    NUM_INPUT_REG      => NUM_INPUT_REG,
    NUM_OUTPUT_REG     => 1,     -- use first output register as pipeline register
    OUTPUT_SHIFT_RIGHT => 0,     -- irrelevant because chain output is used
    OUTPUT_ROUND       => false, -- irrelevant because chain output is used
    OUTPUT_CLIP        => false, -- irrelevant because chain output is used
    OUTPUT_OVERFLOW    => false  -- irrelevant because chain output is used
  )
  port map (
   clk        => clk,
   rst        => rst,
   clr        => '1', -- disable accumulation
   vld        => vld,
   sub        => sub(0 to 3),
   x0         => x0,
   y0         => y0,
   x1         => x1,
   y1         => y1,
   x2         => x2,
   y2         => y2,
   x3         => x3,
   y3         => y3,
   result     => dummy, -- irrelevant because chain output is used
   result_vld => open,  -- irrelevant because chain output is used
   result_ovf => open,  -- irrelevant because chain output is used
   chainin    => chainin,
   chainout   => chain,
   PIPESTAGES => open
  );

  signed_sink(dummy);

  -- second instance with accumulator
  i2 : entity fixitfetish.signed_mult4_accu1
  generic map(
    NUM_SUMMAND        => NUM_SUMMAND,
    USE_CHAIN_INPUT    => true,
    NUM_INPUT_REG      => NUM_INPUT_REG+2, -- two more pipeline registers because of chaining
    NUM_OUTPUT_REG     => NUM_OUTPUT_REG,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => OUTPUT_ROUND,
    OUTPUT_CLIP        => OUTPUT_CLIP,
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
  )
  port map (
   clk        => clk,
   rst        => rst,
   clr        => clr,
   vld        => vld,
   sub        => sub(4 to 7),
   x0         => x4,
   y0         => y4,
   x1         => x5,
   y1         => y5,
   x2         => x6,
   y2         => y6,
   x3         => x7,
   y3         => y7,
   result     => result,
   result_vld => result_vld,
   result_ovf => result_ovf,
   chainin    => chain,
   chainout   => chainout,
   PIPESTAGES => PIPESTAGES
  );

end architecture;
