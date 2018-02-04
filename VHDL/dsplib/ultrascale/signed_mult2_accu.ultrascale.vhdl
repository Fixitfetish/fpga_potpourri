-------------------------------------------------------------------------------
--! @file       signed_mult2_accu.ultrascale.vhdl
--! @author     Fixitfetish
--! @date       03/Feb/2018
--! @version    0.40
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

--! @brief This is an implementation of the entity signed_mult2_accu
--! for Xilinx UltraScale.
--! Two signed multiplications are performed and both results are accumulated.
--!
--! This implementation uses two parallel instances of signed_mult1_accu.ultrascale
--! hence it requires two DSP48E2 Slices.
--! Refer to Xilinx UltraScale Architecture DSP48E2 Slice, UG579 (v1.5) October 18, 2017.
--!
--! * Input Data      : 2x2 signed values, x<=27 bits, y<=18 bits
--! * Input Register  : optional, at least one is strongly recommended
--! * Input Chain     : optional, 48 bits, requires injection after NUM_INPUT_REG cycles 
--!                     but only reasonable for HIGH_SPEED_MODE
--! * Accu Register   : 48 bits, always enabled
--! * Rounding        : optional half-up, within DSP cell
--! * Output Data     : 1x signed value, max 48 bits
--! * Output Register : optional, after shift-right and saturation
--! * Output Chain    : optional, 48 bits
--! * Pipeline stages : NUM_INPUT_REG + NUM_OUTPUT_REG (+1 for HIGH_SPEED_MODE)
--!
--! This implementation can be chained multiple times.
--! @image html signed_mult2_accu.ultrascale.svg "" width=1000px
--!
--! NOTE 1: It is recommended to use the HIGH_SPEED_MODE with NUM_INPUT_REG>=2 for best performance.
--!
--! NOTE 2: Disabling the HIGH_SPEED_MODE will disable the pipeline register P in DSP cell 1.
--! This might be useful to be conform to implementations of other FPGA Vendors.
--! Therefore, less input registers are required when this implementation is chained multiple times.
--! Drawback is a lower maximum frequency. If higher frequencies are required there are two options
--! * Set NUM_INPUT_REG >= 2 when multiple chaining is not needed. This enables the pipeline register M within the the DSP cell.
--! * use HIGH_SPEED_MODE to enable P register in DSP cell 1

architecture ultrascale of signed_mult2_accu is
  
  -- chain width in bits - implementation and device specific !
  signal chain : signed(chainout'length-1 downto 0);

  -- dummy and sink to avoid warnings
  signal dummy : signed(17 downto 0);
  procedure signed_sink(d:in signed) is
    variable b : boolean := false;
  begin b := (d(d'right)='1') or b; end procedure;

  function output_reg_dsp1(highspeed:boolean) return natural is
  begin
    if highspeed then return 1; else return 0; end if;
  end function;

  function input_reg_dsp0(highspeed:boolean) return natural is
  begin
    if highspeed then return NUM_INPUT_REG+1; else return NUM_INPUT_REG; end if;
  end function;

begin

  dsp0 : entity dsplib.signed_mult1_accu(ultrascale)
  generic map(
    NUM_SUMMAND        => NUM_SUMMAND,
    USE_CHAIN_INPUT    => true,
    NUM_INPUT_REG      => input_reg_dsp0(HIGH_SPEED_MODE),
    NUM_OUTPUT_REG     => NUM_OUTPUT_REG,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => OUTPUT_ROUND,
    OUTPUT_CLIP        => OUTPUT_CLIP,
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
  )
  port map(
    clk        => clk,
    rst        => rst,
    clr        => clr,
    vld        => vld,
    neg        => neg(0),
    x          => x0,
    y          => y0,
    result     => result,
    result_vld => result_vld,
    result_ovf => result_ovf,
    chainin    => chain,
    chainout   => chainout,
    PIPESTAGES => PIPESTAGES
  );

  dsp1 : entity dsplib.signed_mult1_accu(ultrascale)
  generic map(
    NUM_SUMMAND        => 1, -- irrelevant because chain output is used
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    NUM_INPUT_REG      => NUM_INPUT_REG,
    NUM_OUTPUT_REG     => output_reg_dsp1(HIGH_SPEED_MODE),
    OUTPUT_SHIFT_RIGHT => 0,     -- irrelevant because chain output is used
    OUTPUT_ROUND       => false, -- irrelevant because chain output is used
    OUTPUT_CLIP        => false, -- irrelevant because chain output is used
    OUTPUT_OVERFLOW    => false  -- irrelevant because chain output is used
  )
  port map(
    clk        => clk,
    rst        => rst,
    clr        => '1', -- disable accumulation
    vld        => vld,
    neg        => neg(1),
    x          => x1,
    y          => y1,
    result     => dummy, -- irrelevant because chain output is used
    result_vld => open,  -- irrelevant because chain output is used
    result_ovf => open,  -- irrelevant because chain output is used
    chainin    => chainin,
    chainout   => chain,
    PIPESTAGES => open
  );

  signed_sink(dummy);

end architecture;
