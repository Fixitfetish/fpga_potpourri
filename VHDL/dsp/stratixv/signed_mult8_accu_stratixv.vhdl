-------------------------------------------------------------------------------
-- FILE    : signed_mult8_accu_stratixv.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 24/Jan/2017
-- VERSION : 0.10
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

-- This implementation uses a chain of the two instances 'signed_mult4_sum' and
-- 'signed_mult4_accu' and requires one pipeline register less than the chaining
-- of two 'signed_mult4_accu' instances. But, the chain input is not supported
-- and the maximum possible frequency is lower.
--
-- Input Data      : 8x2 signed values
-- Input Register  : optional, strongly recommended
-- Accu Register   : width is implementation specific, always enabled
-- Rounding        : optional half-up
-- Output Data     : 1x signed value, max width is implementation specific
-- Output Register : optional, after rounding, shift-right and saturation
-- Overall pipeline stages : 3,4,5,.. dependent on configuration

architecture stratixv of signed_mult8_accu is

  -- chain width in bits - implementation and device specific !
  signal chain : signed(chainout'length-1 downto 0);
  signal dummy : signed(17 downto 0);

  -- dummy sink to avoid warnings
  procedure signed_sink(d:in signed) is
    variable b : boolean := false;
  begin b := (d(d'right)='1') or b; end procedure;

begin

  assert USE_CHAIN_INPUT=false
    report "ERROR signed_mult8_accu(stratixv) : Chain input is not supported. " &
           "Check if other architectures are available that support chain input."
    severity failure;

  -- first instance performs just sum of four products without accumulation
  i1 : entity fixitfetish.signed_mult4_sum
  generic map(
    NUM_SUMMAND        => 4, -- irrelevant because chain output is used
    USE_CHAIN_INPUT    => false,
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

  signed_sink(dummy);

  -- second instance with accumulator
  i2 : entity fixitfetish.signed_mult4_accu
  generic map(
    NUM_SUMMAND        => NUM_SUMMAND,
    USE_CHAIN_INPUT    => true,
    NUM_INPUT_REG      => NUM_INPUT_REG+1, -- one more pipeline register because of chaining
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
