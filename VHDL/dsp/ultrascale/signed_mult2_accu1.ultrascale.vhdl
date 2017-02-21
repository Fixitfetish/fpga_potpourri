-------------------------------------------------------------------------------
--! @file       signed_mult2_accu1.ultrascale.vhdl
--! @author     Fixitfetish
--! @date       14/Feb/2017
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

--! @brief This is an implementation of the entity 
--! @link signed_mult2_accu1 signed_mult2_accu1 @endlink
--! for Xilinx UltraScale.
--! Two signed multiplications are performed and both results are accumulated.
--!
--! This implementation uses two parallel instances of
--! @link signed_mult_accu signed_mult_accu @endlink , hence it requires two DSP48E2 Slices.
--! Refer to Xilinx UltraScale Architecture DSP48E2 Slice, UG579 (v1.3) November 24, 2015.
--!
--! * Input Data      : 2x2 signed values, x<=27 bits, y<=18 bits
--! * Input Register  : optional, at least one is strongly recommended
--! * Input Chain     : optional, 48 bits
--! * Accu Register   : 48 bits, always enabled
--! * Rounding        : optional half-up, within DSP cell
--! * Output Data     : 1x signed value, max 48 bits
--! * Output Register : optional, after shift-right and saturation
--! * Output Chain    : optional, 48 bits
--! * Pipeline stages : NUM_INPUT_REG + NUM_OUTPUT_REG
--!
--! This implementation can be chained multiple times.
--! @image html signed_mult2_accu1.ultrascale.svg "" width=800px
--!
--! NOTE: This implementation does not make use of the pipeline register P in DSP cell 0.
--! This might be useful to be conform to implementations of other FPGA Vendors.
--! Therefore, less input registers are required when this implementation is chained multiple times.
--! Drawback is a lower maximum frequency. If higher frequencies are required there are two options
--! * Set NUM_INPUT_REG >= 2 when multiple chaining is not needed. This enables the pipeline register M within the the DSP cell.
--! * Use the implementation @link signed_mult2_accu1 signed_mult2_accu1(chain) @endlink with enabled pipeline register P.

architecture ultrascale of signed_mult2_accu1 is
  
  -- chain width in bits - implementation and device specific !
  signal chain : signed(chainout'length-1 downto 0);

  -- dummy and sink to avoid warnings
  signal dummy : signed(17 downto 0);
  procedure signed_sink(d:in signed) is
    variable b : boolean := false;
  begin b := (d(d'right)='1') or b; end procedure;

begin

  dsp0 : entity fixitfetish.signed_mult1_accu1(ultrascale)
  generic map(
    NUM_SUMMAND        => 1, -- irrelevant because chain output is used
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    NUM_INPUT_REG      => NUM_INPUT_REG,
    NUM_OUTPUT_REG     => 0,     -- must be 0 to disable ACCU register P !
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
    sub        => sub(0),
    x          => x0,
    y          => y0,
    result     => dummy, -- irrelevant because chain output is used
    result_vld => open,  -- irrelevant because chain output is used
    result_ovf => open,  -- irrelevant because chain output is used
    chainin    => chainin,
    chainout   => chain,
    PIPESTAGES => open
  );

  signed_sink(dummy);

  dsp1 : entity fixitfetish.signed_mult1_accu1(ultrascale)
  generic map(
    NUM_SUMMAND        => NUM_SUMMAND,
    USE_CHAIN_INPUT    => true,
    NUM_INPUT_REG      => NUM_INPUT_REG,
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
    sub        => sub(1),
    x          => x1,
    y          => y1,
    result     => result,
    result_vld => result_vld,
    result_ovf => result_ovf,
    chainin    => chain,
    chainout   => chainout,
    PIPESTAGES => PIPESTAGES
  );

end architecture;
