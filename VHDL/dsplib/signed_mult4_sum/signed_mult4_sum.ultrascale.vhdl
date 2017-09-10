-------------------------------------------------------------------------------
--! @file       signed_mult4_sum.ultrascale.vhdl
--! @author     Fixitfetish
--! @date       10/Sep/2017
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

--! @brief This is an implementation of the entity signed_mult4_sum
--! for Xilinx UltraScale.
--! Four signed multiplications are performed and all results are summed.
--!
--! This implementation uses the entities signed_mult1_accu , signed_mult2_accu
--! and signed_mult1add1_sum. Hence, it requires four DSP48E2 Slices.
--!
--! * Input Data      : 4x2 signed values, x<=27 bits, y<=18 bits
--! * Input Register  : optional, at least one is strongly recommended
--! * Input Chain     : not supported
--! * Accu Register   : 48 bits, always enabled
--! * Rounding        : optional half-up, always in logic
--! * Output Data     : 1x signed value, max 48 bits
--! * Output Register : optional, after shift-right, round and saturation
--! * Output Chain    : optional, 48 bits
--! * Pipeline stages : NUM_INPUT_REG + NUM_OUTPUT_REG + PIPELINE_REG
--!
--! The output can be chained with other DSP implementations.
--! @image html signed_mult4_sum.ultrascale.svg "" width=600px

architecture ultrascale of signed_mult4_sum is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "signed_mult4_sum(ultrascale)";

  signal result_dsp0 : signed(ACCU_WIDTH-1 downto 0);
  signal chainout_dsp2 : signed(ACCU_WIDTH-1 downto 0);

  -- dummy and sink to avoid warnings
  signal dummy : signed(17 downto 0);
  procedure signed_sink(d:in signed) is
    variable b : boolean := false;
  begin b := (d(d'right)='1') or b; end procedure;

begin

  DSP0 : entity dsplib.signed_mult1_accu(ultrascale)
  generic map(
    NUM_SUMMAND        => 1,
    USE_CHAIN_INPUT    => false,
    NUM_INPUT_REG      => NUM_INPUT_REG,
    NUM_OUTPUT_REG     => 1,     -- output connected to Z input of DSP1
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
    sub        => sub(0),
    x          => x0,
    y          => y0,
    result     => result_dsp0,
    result_vld => open, -- irrelevant because full output is used
    result_ovf => open, -- irrelevant because full output is used
    chainin    => open,
    chainout   => open,
    PIPESTAGES => open
  );

  DSP1 : entity dsplib.signed_mult1add1_sum(ultrascale)
  generic map(
    USE_CHAIN_INPUT    => true,
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
    sub        => sub(1),
    x          => x1,
    y          => y1,
    z          => result_dsp0,
    result     => result,
    result_vld => result_vld,
    result_ovf => result_ovf,
    chainin    => chainout_dsp2,
    chainout   => chainout,
    PIPESTAGES => PIPESTAGES
  );

  DSP2 : entity dsplib.signed_mult2_accu(ultrascale)
  generic map(
    NUM_SUMMAND        => 2,
    USE_CHAIN_INPUT    => false,
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
    sub        => sub(2 to 3),
    x0         => x2,
    y0         => y2,
    x1         => x3,
    y1         => y3,
    result     => dummy, -- irrelevant because chain output is used
    result_vld => open,  -- irrelevant because chain output is used
    result_ovf => open,  -- irrelevant because chain output is used
    chainin    => open,
    chainout   => chainout_dsp2,
    PIPESTAGES => open
  );
  
  signed_sink(dummy);
  
end architecture;
  