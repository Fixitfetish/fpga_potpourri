-------------------------------------------------------------------------------
--! @file       complex_mult1_accu.ultrascale.vhdl
--! @author     Fixitfetish
--! @date       12/Dec/2021
--! @version    0.10
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Code comments are optimized for SIGASI and DOXYGEN.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;
library dsplib;
  use dsplib.dsp_pkg_ultrascale.all;

--! @brief This is an implementation of the entity complex_mult1_accu for Xilinx UltraScale.
--! One complex multiplication is performed and results are accumulated.
--!
--! @image html complex_mult1_accu.ultrascale.svg "" width=600px
--!
--! **MAXIMUM_PERFORMANCE**
--! * This implementation requires four instances of the entity signed_mult1_accu .
--! * Chaining is supported.
--! * The number of overall pipeline stages is typically NUM_INPUT_REG + 1 + NUM_OUTPUT_REG.
--! 
--! **MINIMUM_DSP_CELLS**
--! * This implementation requires three instances of the entity signed_preadd_mult1add1 .
--! * Chaining is supported.
--! * The number of overall pipeline stages is typically NUM_INPUT_REG + 2 + NUM_OUTPUT_REG.
--!
architecture ultrascale of complex_mult1_accu is

  signal r_ovf_re , r_ovf_im : std_logic;

begin

 -- Operation with 4 DSP cells and chaining
 -- *  re1 = x_re*y_re
 -- *  im1 = x_re*y_im
 -- *  re  = re1 - x_im*y_im
 -- *  im  = im1 + x_im*y_re
 G1 : if OPTIMIZATION="MAXIMUM_PERFORMANCE" generate
  signal chainout_re1 : signed(79 downto 0);
  signal chainout_im1 : signed(79 downto 0);
  signal dummy_re, dummy_im : signed(ACCU_WIDTH-1 downto 0);
 begin

  -- operation: re1 = x_re*y_re
  i_re1 : entity dsplib.signed_mult1_accu(ultrascale)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND-1,
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    NUM_INPUT_REG      => NUM_INPUT_REG,
    NUM_OUTPUT_REG     => 1,
    OUTPUT_SHIFT_RIGHT => 0,
    OUTPUT_ROUND       => false,
    OUTPUT_CLIP        => false,
    OUTPUT_OVERFLOW    => false
  )
  port map (
    clk        => clk,
    rst        => rst,
    clkena     => clkena,
    clr        => '1',
    vld        => vld,
    neg        => neg,
    x          => x_re,
    y          => y_re,
    result     => dummy_re, -- unused
    result_vld => open, -- unused
    result_ovf => open, -- unused
    chainin    => chainin_re,
    chainout   => chainout_re1,
    PIPESTAGES => open  -- unused
  );

  -- operation: re = re1 - x_im*y_im
  i_re2 : entity dsplib.signed_mult1_accu(ultrascale)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND, -- two multiplications per complex multiplication
    USE_CHAIN_INPUT    => true,
    NUM_INPUT_REG      => NUM_INPUT_REG+1, -- additional pipeline register(s) because of chaining
    NUM_OUTPUT_REG     => NUM_OUTPUT_REG,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => OUTPUT_ROUND,
    OUTPUT_CLIP        => OUTPUT_CLIP,
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
  )
  port map (
    clk        => clk,
    rst        => rst,
    clkena     => clkena,
    clr        => clr, -- accumulator enabled in last instance only!
    vld        => vld,
    neg        => not neg,
    x          => x_im,
    y          => y_im,
    result     => result_re,
    result_vld => result_vld,
    result_ovf => r_ovf_re,
    chainin    => chainout_re1,
    chainout   => chainout_re,
    PIPESTAGES => PIPESTAGES
  );

  -- operation: im1 = x_re*y_im
  i_im1 : entity dsplib.signed_mult1_accu(ultrascale)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND-1,
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    NUM_INPUT_REG      => NUM_INPUT_REG,
    NUM_OUTPUT_REG     => 1,
    OUTPUT_SHIFT_RIGHT => 0,
    OUTPUT_ROUND       => false,
    OUTPUT_CLIP        => false,
    OUTPUT_OVERFLOW    => false
  )
  port map (
    clk        => clk,
    rst        => rst,
    clkena     => clkena,
    clr        => '1',
    vld        => vld,
    neg        => neg,
    x          => x_re,
    y          => y_im,
    result     => dummy_im, -- unused
    result_vld => open, -- unused
    result_ovf => open, -- unused
    chainin    => chainin_im,
    chainout   => chainout_im1,
    PIPESTAGES => open  -- unused
  );

  -- operation: im = im1 + x_im*y_re
  i_im2 : entity dsplib.signed_mult1_accu(ultrascale)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND, -- two multiplications per complex multiplication
    USE_CHAIN_INPUT    => true,
    NUM_INPUT_REG      => NUM_INPUT_REG+1, -- additional pipeline register(s) because of chaining
    NUM_OUTPUT_REG     => NUM_OUTPUT_REG,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => OUTPUT_ROUND,
    OUTPUT_CLIP        => OUTPUT_CLIP,
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
  )
  port map (
    clk        => clk,
    rst        => rst,
    clkena     => clkena,
    clr        => clr, -- accumulator enabled in last instance only!
    vld        => vld,
    neg        => neg,
    x          => x_im,
    y          => y_re,
    result     => result_im,
    result_vld => open, -- same as real component
    result_ovf => r_ovf_im,
    chainin    => chainout_im1,
    chainout   => chainout_im,
    PIPESTAGES => open  -- same as real component
  );

 end generate;


 -- Operation with 3 DSP cells
 -- *  temp = ( y_re + y_im) * x_re 
 -- *  re   = (-x_re - x_im) * y_im + temp
 -- *  im   = ( x_im - x_re) * y_re + temp
 G2 : if OPTIMIZATION="MINIMUM_DSP_CELLS" generate
  constant TEMP_WIDTH : positive := x_re'length + y_re'length + 1;
  signal temp : signed(TEMP_WIDTH-1 downto 0);
 begin

  -- operation: temp = (y_re + y_im) * x_re  ... raw with full resolution
  i_temp : entity dsplib.signed_preadd_mult1add1(ultrascale)
  generic map(
    NUM_SUMMAND        => 2,
    USE_CHAIN_INPUT    => false,
    PREADDER_INPUT_XA  => "ADD",
    PREADDER_INPUT_XB  => "ADD",
    NUM_INPUT_REG_XY   => NUM_INPUT_REG,
    NUM_INPUT_REG_Z    => open, -- unused
    NUM_OUTPUT_REG     => 1,
    OUTPUT_SHIFT_RIGHT => 0,
    OUTPUT_ROUND       => false,
    OUTPUT_CLIP        => false,
    OUTPUT_OVERFLOW    => false
  )
  port map(
    clk        => clk, -- clock
    rst        => rst, -- reset
    clr        => open,
    vld        => vld, -- valid
    sub_xa     => open, -- unused
    sub_xb     => open, -- unused
    xa         => y_re, -- first factor
    xb         => y_im, -- first factor
    y          => x_re, -- second factor
    z          => "00", -- unused
    result     => temp, -- temporary result
    result_vld => open, -- not needed
    result_ovf => open, -- not needed
    chainin    => open, -- unused
    chainout   => open, -- unused
    PIPESTAGES => open
  );

  -- operation: re = (-x_re - x_im) * y_im + temp
  i_re : entity dsplib.signed_preadd_mult1add1(ultrascale)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND,
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    PREADDER_INPUT_XA  => "SUBTRACT",
    PREADDER_INPUT_XB  => "SUBTRACT",
    NUM_INPUT_REG_XY   => NUM_INPUT_REG+2, -- 2 more pipeline stages to compensate Z input
    NUM_INPUT_REG_Z    => 1,
    NUM_OUTPUT_REG     => NUM_OUTPUT_REG,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => OUTPUT_ROUND,
    OUTPUT_CLIP        => OUTPUT_CLIP,
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
  )
  port map(
    clk        => clk, -- clock
    rst        => rst, -- reset
    clr        => clr, -- clear
    vld        => vld, -- valid
    sub_xa     => open, -- unused
    sub_xb     => open, -- unused
    xa         => x_re,
    xb         => x_im,
    y          => y_im,
    z          => temp,
    result     => result_re,
    result_vld => result_vld,
    result_ovf => r_ovf_re,
    chainin    => chainin_re,
    chainout   => chainout_re,
    PIPESTAGES => PIPESTAGES
  );

  -- operation: im = (x_im - x_re) * y_re + temp
  i_im : entity dsplib.signed_preadd_mult1add1(ultrascale)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND,
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    PREADDER_INPUT_XA  => "ADD",
    PREADDER_INPUT_XB  => "SUBTRACT",
    NUM_INPUT_REG_XY   => NUM_INPUT_REG+2, -- 2 more pipeline stages to compensate Z input
    NUM_INPUT_REG_Z    => 1,
    NUM_OUTPUT_REG     => NUM_OUTPUT_REG,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => OUTPUT_ROUND,
    OUTPUT_CLIP        => OUTPUT_CLIP,
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
  )
  port map(
    clk        => clk, -- clock
    rst        => rst, -- reset
    clr        => clr, -- clear
    vld        => vld, -- valid
    sub_xa     => open, -- unused
    sub_xb     => open, -- unused
    xa         => x_im,
    xb         => x_re,
    y          => y_re,
    z          => temp,
    result     => result_im,
    result_vld => open, -- same as real component
    result_ovf => r_ovf_im,
    chainin    => chainin_im,
    chainout   => chainout_im,
    PIPESTAGES => open -- same as real component
  );

 end generate;

 result_ovf <= r_ovf_re or r_ovf_im;

end architecture;
