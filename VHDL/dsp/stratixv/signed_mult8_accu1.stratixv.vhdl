-------------------------------------------------------------------------------
--! @file       signed_mult8_accu1.stratixv.vhdl
--! @author     Fixitfetish
--! @date       15/Feb/2017
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

--! @brief This implementation uses a chain of the two instances signed_mult4_sum and
--! signed_mult4_accu1 and requires one pipeline register less than the chaining
--! of two signed_mult4_accu1 instances. But, the chain input is not supported
--! and the maximum possible frequency is lower.
--!
--! * Input Data      : 8x2 signed values
--! * Input Register  : optional, at least one is strongly recommended
--! * Accu Register   : width is implementation specific, enabled when NUM_OUTPUT_REG>0
--! * Rounding        : optional half-up
--! * Output Data     : 1x signed value, max width is implementation specific
--! * Output Register : optional, after rounding, shift-right and saturation
--! * Pipeline stages : NUM_INPUT_REG + 2 + NUM_OUTPUT_REG

architecture stratixv of signed_mult8_accu1 is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "signed_mult8_accu1(stratixv)";

  -- chain width in bits - implementation and device specific !
  signal chain : signed(chainout'length-1 downto 0);

  -- dummy sink to avoid warnings
  signal dummy : signed(17 downto 0);
  procedure signed_sink(d:in signed) is
    variable b : boolean := false;
  begin b := (d(d'right)='1') or b; end procedure;

begin

  assert USE_CHAIN_INPUT=false
    report "ERROR " & IMPLEMENTATION & ": Chain input is not supported. " &
           "Check if other architectures are available that support chain input."
    severity failure;

  -- unused chain input
  signed_sink(chainin);

  -- first instance performs just sum of four products without accumulation
  i1 : entity fixitfetish.signed_mult4_sum
  generic map(
    NUM_INPUT_REG      => NUM_INPUT_REG,
    NUM_OUTPUT_REG     => 1, -- Enable DSP cell internal output register which is used as pipeline register to drive the chain output
    OUTPUT_SHIFT_RIGHT => 0,     -- irrelevant because chain output is used
    OUTPUT_ROUND       => false, -- irrelevant because chain output is used
    OUTPUT_CLIP        => false, -- irrelevant because chain output is used
    OUTPUT_OVERFLOW    => false  -- irrelevant because chain output is used
  )
  port map (
   clk        => clk,
   rst        => rst,
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
   chainout   => chain,
   PIPESTAGES => open
  );

  signed_sink(dummy);

  -- second instance with accumulator
  i2 : entity fixitfetish.signed_mult4_accu1
  generic map(
    NUM_SUMMAND        => NUM_SUMMAND,
    USE_CHAIN_INPUT    => true,
    NUM_INPUT_REG      => NUM_INPUT_REG+1, -- one more pipeline register because of chaining
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
