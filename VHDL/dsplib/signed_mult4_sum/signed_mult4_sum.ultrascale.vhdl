-------------------------------------------------------------------------------
--! @file       signed_mult4_sum.ultrascale.vhdl
--! @author     Fixitfetish
--! @date       13/Sep/2017
--! @version    0.20
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension.all;
library dsplib;
  use dsplib.dsp_pkg_ultrascale.all;

library unisim;
  use unisim.vcomponents.all;

--! @brief This is an implementation of the entity signed_mult4_sum
--! for Xilinx UltraScale.
--! Four signed multiplications are performed and all results are summed.
--!
--! This implementation uses the architectures signed_mult2_accu.ultrascale and
--! signed_mult2_sum.ultrascale .  Hence, it requires four DSP48E2 Slices.
--!
--! * Input Data      : 4x2 signed values, x<=27 bits, y<=18 bits
--! * Input Register  : optional, at least one is strongly recommended
--! * Input Chain     : optional, 48 bits, requires injection after NUM_INPUT_REG cycles
--! * Rounding        : optional half-up, always in logic
--! * Output Data     : 1x signed value, max 48 bits
--! * Output Register : optional, at least one strongly recommended, another after shift-right, round and saturation
--! * Output Chain    : optional, 48 bits, after NUM_INPUT_REG+3 cycles (assuming NUM_OUTPUT_REG>=1)
--! * Pipeline stages : NUM_INPUT_REG + 2 + NUM_OUTPUT_REG
--!
--! The output can be chained with other DSP implementations.
--! @image html signed_mult4_sum.ultrascale.svg "" width=600px

architecture ultrascale of signed_mult4_sum is

  signal chainout_dsp1 : signed(79 downto 0);

  -- dummy and sink to avoid warnings
  signal dummy : signed(17 downto 0);
  procedure signed_sink(d:in signed) is
    variable b : boolean := false;
  begin b := (d(d'right)='1') or b; end procedure;

begin

  DSP0 : entity dsplib.signed_mult2_sum(ultrascale)
  generic map(
    NUM_SUMMAND        => NUM_SUMMAND, -- typically 4 + summands contributed through chain input 
    USE_CHAIN_INPUT    => true,
    NUM_INPUT_REG      => NUM_INPUT_REG,
    NUM_OUTPUT_REG     => NUM_OUTPUT_REG,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => OUTPUT_ROUND,
    OUTPUT_CLIP        => OUTPUT_CLIP,
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
  )
  port map (
    clk        => clk,
    rst        => rst,
    vld        => vld,
    neg        => neg(0 to 1),
    x0         => x0,
    y0         => y0,
    x1         => x1,
    y1         => y1,
    result     => result,
    result_vld => result_vld,
    result_ovf => result_ovf,
    chainin    => chainout_dsp1,
    chainout   => chainout, -- after NUM_INPUT_REG+3 cycles
    PIPESTAGES => PIPESTAGES
  );

  -- adds chain input and 2 of 4 multiplier results
  DSP1 : entity dsplib.signed_mult2_accu(ultrascale)
  generic map(
    NUM_SUMMAND        => NUM_SUMMAND-2, -- irrelevant because only chain output is used
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    NUM_INPUT_REG      => NUM_INPUT_REG,
    NUM_OUTPUT_REG     => 1,
    OUTPUT_SHIFT_RIGHT => 0,     -- irrelevant because chain output is used
    OUTPUT_ROUND       => false, -- irrelevant because chain output is used
    OUTPUT_CLIP        => false, -- irrelevant because chain output is used
    OUTPUT_OVERFLOW    => false  -- irrelevant because chain output is used
  )
  port map (
    clk        => clk,
    rst        => rst,
    clr        => '1', -- accumulator always disabled
    vld        => vld,
    neg        => neg(2 to 3),
    x0         => x2,
    y0         => y2,
    x1         => x3,
    y1         => y3,
    result     => dummy, -- irrelevant because chain output is used
    result_vld => open,  -- irrelevant because chain output is used
    result_ovf => open,  -- irrelevant because chain output is used
    chainin    => chainin, -- after NUM_INPUT_REG cycles
    chainout   => chainout_dsp1, -- after NUM_INPUT_REG+2 cycles
    PIPESTAGES => open
  );
  
  signed_sink(dummy);
  
end architecture;
  