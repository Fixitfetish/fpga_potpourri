-------------------------------------------------------------------------------
-- FILE    : signed_mult8_accu_chain.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 22/Jan/2017
-- VERSION : 0.20
-- VHDL    : 1993
-- LICENSE : MIT License
-------------------------------------------------------------------------------
-- Copyright (c) 2017 Fixitfetish
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library fixitfetish;
 use fixitfetish.ieee_extension.all;

-- This implementation uses two chained instances of 'signed_mult4_accu'.
-- (which actually are four chained instances of 'signed_mult2_accu'.)
-- Hence, it is not HW specific and can be used for simulation and synthesis
-- based on the 'signed_mult2_accu' implementation.
--
-- Input Data      : 8x2 signed values
-- Input Register  : optional, strongly recommended
-- Accu Register   : width is implementation specific, always enabled
-- Rounding        : optional half-up
-- Output Data     : 1x signed value, max width is implementation specific
-- Output Register : optional, after rounding, shift-right and saturation
-- Overall pipeline stages : 4,5,6,.. dependent on configuration

architecture chain of signed_mult8_accu is

  -- chain width in bits - implementation and HW specific !
  signal chain : signed(chainout'length-1 downto 0);
  signal dummy : signed(chainout'length-1 downto 0);

begin

  -- first instance performs just sum of four products without accumulation
  i1 : entity fixitfetish.signed_mult4_accu
  generic map(
    NUM_SUMMAND        => 4, -- irrelevant because chain output is used
    USE_CHAININ        => USE_CHAININ,
    NUM_INPUT_REG      => NUM_INPUT_REG,
    OUTPUT_REG         => false, -- irrelevant because chain output is used
    OUTPUT_SHIFT_RIGHT => 0,     -- irrelevant because chain output is used
    OUTPUT_ROUND       => false, -- irrelevant because chain output is used
    OUTPUT_CLIP        => false, -- irrelevant because chain output is used
    OUTPUT_OVERFLOW    => false  -- irrelevant because chain output is used
  )
  port map (
   clk      => clk,
   rst      => rst,
   clr      => '1', -- disable accumulation
   vld      => vld,
   sub      => sub(0 to 3),
   x0       => x0,
   y0       => y0,
   x1       => x1,
   y1       => y1,
   x2       => x2,
   y2       => y2,
   x3       => x3,
   y3       => y3,
   r_vld    => open,  -- irrelevant because chain output is used
   r_out    => dummy, -- irrelevant because chain output is used
   r_ovf    => open,  -- irrelevant because chain output is used
   chainin  => chainin,
   chainout => chain,
   PIPE     => open
  );

  -- second instance with accumulator
  i2 : entity fixitfetish.signed_mult4_accu
  generic map(
    NUM_SUMMAND        => NUM_SUMMAND,
    USE_CHAININ        => true,
    NUM_INPUT_REG      => NUM_INPUT_REG+2, -- two more pipeline registers because of chaining
    OUTPUT_REG         => OUTPUT_REG,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => OUTPUT_ROUND,
    OUTPUT_CLIP        => OUTPUT_CLIP,
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
  )
  port map (
   clk      => clk,
   rst      => rst,
   clr      => clr,
   vld      => vld,
   sub      => sub(4 to 7),
   x0       => x4,
   y0       => y4,
   x1       => x5,
   y1       => y5,
   x2       => x6,
   y2       => y6,
   x3       => x7,
   y3       => y7,
   r_vld    => r_vld,
   r_out    => r_out,
   r_ovf    => r_ovf,
   chainin  => chain,
   chainout => chainout,
   PIPE     => PIPE
  );

end architecture;
