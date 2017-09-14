-------------------------------------------------------------------------------
--! @file       signed_mult2_sum.ultrascale.vhdl
--! @author     Fixitfetish
--! @date       13/Sep/2017
--! @version    0.10
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

--! @brief This implementation is a behavioral model of the entity signed_mult2_sum
--! for Xilinx UltraScale.
--! Two signed multiplications are performed and the results are summed.
--! 
--! This implementation uses the architectures signed_mult1_accu.ultrascale and
--! signed_mult1add1_sum.ultrascale . Hence, it requires two DSP48E2 Slices.
--!
--! * Input Data      : 2x2 signed values, x<=27 bits, y<=18 bits
--! * Input Register  : optional, at least one is strongly recommended
--! * Input Chain     : optional, 48 bits, requires injection after NUM_INPUT_REG+2 cycles
--! * Rounding        : optional half-up, always in logic
--! * Output Data     : 1x signed value, max 48 bits
--! * Output Register : optional, at least one strongly recommended, another after shift-right, round and saturation
--! * Output Chain    : optional, 48 bits, after NUM_INPUT_REG+3 cycles (assuming NUM_OUTPUT_REG>=1)
--! * Pipeline stages : NUM_INPUT_REG + 2 + NUM_OUTPUT_REG
--!
--! The output can be chained with other DSP implementations.
--! @image html signed_mult2_sum.ultrascale.svg "" width=600px

architecture ultrascale of signed_mult2_sum is

  signal result_dsp1 : signed(ACCU_WIDTH-1 downto 0);

begin

  DSP0 : entity dsplib.signed_mult1add1_sum(ultrascale)
  generic map(
    NUM_SUMMAND        => NUM_SUMMAND,
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    NUM_INPUT_REG_XY   => NUM_INPUT_REG+2,
    NUM_INPUT_REG_Z    => 1,
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
    sub        => sub(0),
    x          => x0,
    y          => y0,
    z          => result_dsp1,
    result     => result,
    result_vld => result_vld,
    result_ovf => result_ovf,
    chainin    => chainin,
    chainout   => chainout,
    PIPESTAGES => PIPESTAGES
  );

  DSP1 : entity dsplib.signed_mult1_accu(ultrascale)
  generic map(
    NUM_SUMMAND        => 1,
    USE_CHAIN_INPUT    => false,
    NUM_INPUT_REG      => NUM_INPUT_REG,
    NUM_OUTPUT_REG     => 1,     -- output connected to Z input of DSP0
    OUTPUT_SHIFT_RIGHT => 0,     -- irrelevant because full output is used
    OUTPUT_ROUND       => false, -- irrelevant because full output is used
    OUTPUT_CLIP        => false, -- irrelevant because full output is used
    OUTPUT_OVERFLOW    => false  -- irrelevant because full output is used
  )
  port map (
    clk        => clk,
    rst        => rst,
    clr        => '1', -- accumulator always disabled
    vld        => vld,
    sub        => sub(1),
    x          => x1,
    y          => y1,
    result     => result_dsp1,
    result_vld => open, -- irrelevant because full output is used
    result_ovf => open, -- irrelevant because full output is used
    chainin    => open,
    chainout   => open,
    PIPESTAGES => open
  );

end architecture;

