-------------------------------------------------------------------------------
--! @file       complex_mult1add1.ultrascale.vhdl
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

--! @brief This is an implementation of the entity complex_mult1add1 for Xilinx UltraScale.
--! One complex multiplication is performed and results are accumulated.
--!
--! @image html complex_mult1add1.ultrascale.svg "" width=600px
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
architecture ultrascale of complex_mult1add1 is

begin

 --------------------------------------------------------------------------------------------------
 -- Operation with 4 DSP cells and chaining
 -- *  Re1 = ReChain + Xre*Yre + Zre
 -- *  Im1 = ImChain + Xre*Yim + Zim
 -- *  Re2 = Re1     - Xim*Yim
 -- *  Im2 = Im1     + Xim*Yre
 --
 -- Notes
 -- * Re1/Im1 can add Z input in addition to chain input
 -- * Re2/Im2 can add round bit and accumulate in addition to chain input
 --------------------------------------------------------------------------------------------------
 G1 : if OPTIMIZATION="MAXIMUM_PERFORMANCE" generate
  signal chainout_re1 : signed(79 downto 0);
  signal chainout_im1 : signed(79 downto 0);
  signal dummy_re, dummy_im : signed(ACCU_WIDTH-1 downto 0);
  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "complex_mult1add1(ultrascale) with optimization=MAXIMUM_PERFORMANCE";
 begin

  -- Operation:  Re1 = ReChain + Xre*Yre + Zre
  i_re1 : entity dsplib.signed_mult1add1(ultrascale)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND-1,
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    USE_Z_INPUT        => USE_Z_INPUT,
    USE_NEGATION       => true,
    NUM_INPUT_REG_XY   => NUM_INPUT_REG_XY,
    NUM_INPUT_REG_Z    => NUM_INPUT_REG_Z,
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
    z          => z_re,
    result     => dummy_re, -- unused
    result_vld => open, -- unused
    result_ovf => open, -- unused
    chainin    => chainin_re,
    chainout   => chainout_re1,
    PIPESTAGES => open  -- unused
  );

  -- operation:  Re2 = Re1 - Xim*Yim   (accumulation possible)
  i_re2 : entity dsplib.signed_mult1add1(ultrascale)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND, -- two multiplications per complex multiplication
    USE_CHAIN_INPUT    => true,
    USE_Z_INPUT        => false,
    USE_NEGATION       => true,
    NUM_INPUT_REG_XY   => NUM_INPUT_REG_XY+1, -- additional pipeline register(s) because of chaining
    NUM_INPUT_REG_Z    => 0,
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
    z          => "00",
    result     => result_re,
    result_vld => result_vld,
    result_ovf => result_ovf_re,
    chainin    => chainout_re1,
    chainout   => chainout_re,
    PIPESTAGES => PIPESTAGES
  );

  -- operation:  Im1 = ImChain + Xre*Yim + Zim 
  i_im1 : entity dsplib.signed_mult1add1(ultrascale)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND-1,
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    USE_Z_INPUT        => USE_Z_INPUT,
    USE_NEGATION       => true,
    NUM_INPUT_REG_XY   => NUM_INPUT_REG_XY,
    NUM_INPUT_REG_Z    => NUM_INPUT_REG_Z,
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
    z          => z_im,
    result     => dummy_im, -- unused
    result_vld => open, -- unused
    result_ovf => open, -- unused
    chainin    => chainin_im,
    chainout   => chainout_im1,
    PIPESTAGES => open  -- unused
  );

  -- operation:  Im2 = Im1 + Xim*Yre   (accumulation possible)
  i_im2 : entity dsplib.signed_mult1add1(ultrascale)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND, -- two multiplications per complex multiplication
    USE_CHAIN_INPUT    => true,
    USE_Z_INPUT        => false,
    USE_NEGATION       => true,
    NUM_INPUT_REG_XY   => NUM_INPUT_REG_XY+1, -- additional pipeline register(s) because of chaining
    NUM_INPUT_REG_Z    => 0,
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
    z          => "00",
    result     => result_im,
    result_vld => open, -- same as real component
    result_ovf => result_ovf_im,
    chainin    => chainout_im1,
    chainout   => chainout_im,
    PIPESTAGES => open  -- same as real component
  );

 end generate;


 --------------------------------------------------------------------------------------------------
 -- Operation with 3 DSP cells  (Z input not supported !)
 -- *  Temp =           ( Yre + Yim) * Xre 
 -- *  Re   = ReChain + (-Xre - Xim) * Yim + Temp
 -- *  Im   = ImChain + ( Xim - Xre) * Yre + Temp
 --
 -- USE_CHAIN_INPUT=true
 -- * accumulation not possible because P feedback must be disabled
 -- * The rounding (i.e. +0.5) not possible within DSP.
 --   But rounding bit can be injected at the first chain link where USE_CHAIN_INPUT=false
 --------------------------------------------------------------------------------------------------
 G2 : if OPTIMIZATION="MINIMUM_DSP_CELLS" generate
  constant TEMP_WIDTH : positive := x_re'length + y_re'length + 1;
  signal temp : signed(TEMP_WIDTH-1 downto 0);
  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "complex_mult1add1(ultrascale) with optimization=MINIMUM_DSP_CELLS";
  constant USE_NEGATION : boolean := true;

--  constant TEMP_PREADDER_XA : string := "ADD";
--  constant TEMP_PREADDER_XB : string := "ADD";
--  constant RE_PREADDER_XA   : string := "SUBTRACT";
--  constant RE_PREADDER_XB   : string := "SUBTRACT";
--  constant IM_PREADDER_XA   : string := "ADD";
--  constant IM_PREADDER_XB   : string := "SUBTRACT";

--  constant TEMP_PREADDER_XA : string := "DYNAMIC";
--  constant TEMP_PREADDER_XB : string := "DYNAMIC";
--  constant RE_PREADDER_XA   : string := "DYNAMIC";
--  constant RE_PREADDER_XB   : string := "DYNAMIC";
--  constant IM_PREADDER_XA   : string := "DYNAMIC";
--  constant IM_PREADDER_XB   : string := "DYNAMIC";

  function TEMP_PREADDER_XA return string is begin
    if USE_NEGATION then return "DYNAMIC"; else return "ADD"; end if;
  end function;
  function TEMP_PREADDER_XB return string is begin
    if USE_NEGATION then return "DYNAMIC"; else return "ADD"; end if;
  end function;

  function RE_PREADDER_XA return string is begin
    if USE_NEGATION then return "DYNAMIC"; else return "SUBTRACT"; end if;
  end function;
  function RE_PREADDER_XB return string is begin
    if USE_NEGATION then return "DYNAMIC"; else return "SUBTRACT"; end if;
  end function;

  function IM_PREADDER_XA return string is begin
    if USE_NEGATION then return "DYNAMIC"; else return "ADD"; end if;
  end function;
  function IM_PREADDER_XB return string is begin
    if USE_NEGATION then return "DYNAMIC"; else return "SUBTRACT"; end if;
  end function;

 begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (not USE_Z_INPUT)
    report "ERROR " & IMPLEMENTATION & " :" &
           " Z input not supported with selected optimization."
    severity failure;
  assert (not USE_CHAIN_INPUT)
    report "NOTE " & IMPLEMENTATION & " :" &
           " Selected optimization does not allow accumulation when chain input is used. Ignoring CLR input port."
    severity note;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)


  -- Operation:
  -- Temp = ( Yre + Yim) * Xre  ... raw with full resolution
  i_temp : entity dsplib.signed_preadd_mult1add1(ultrascale)
  generic map(
    NUM_SUMMAND        => 2,
    USE_CHAIN_INPUT    => false,
    USE_Z_INPUT        => false,
    PREADDER_INPUT_XA  => TEMP_PREADDER_XA,
    PREADDER_INPUT_XB  => TEMP_PREADDER_XB,
    NUM_INPUT_REG_XY   => NUM_INPUT_REG_XY,
    NUM_INPUT_REG_Z    => open, -- unused
    NUM_OUTPUT_REG     => 1,
    OUTPUT_SHIFT_RIGHT => 0, -- raw temporary result for following RE and IM stage
    OUTPUT_ROUND       => false,
    OUTPUT_CLIP        => false,
    OUTPUT_OVERFLOW    => false
  )
  port map(
    clk        => clk, -- clock
    rst        => rst, -- reset
    clr        => open,
    vld        => vld, -- valid
    sub_xa     => neg, -- add (subtract)
    sub_xb     => neg, -- add (subtract)
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

  -- Operation:
  -- Re = ReChain + (-Xre - Xim) * Yim + Temp   (accumulation only when chain input unused)
  i_re : entity dsplib.signed_preadd_mult1add1(ultrascale)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND,
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    USE_Z_INPUT        => true,
    PREADDER_INPUT_XA  => RE_PREADDER_XA,
    PREADDER_INPUT_XB  => RE_PREADDER_XB,
    NUM_INPUT_REG_XY   => NUM_INPUT_REG_XY+2, -- 2 more pipeline stages to compensate Z input
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
    sub_xa     => not neg, -- subtract (add)
    sub_xb     => not neg, -- subtract (add)
    xa         => x_re,
    xb         => x_im,
    y          => y_im,
    z          => temp,
    result     => result_re,
    result_vld => result_vld,
    result_ovf => result_ovf_re,
    chainin    => chainin_re,
    chainout   => chainout_re,
    PIPESTAGES => PIPESTAGES
  );

  -- Operation:
  -- Im = ImChain + ( Xim - Xre) * Yre + Temp   (accumulation only when chain input unused)
  i_im : entity dsplib.signed_preadd_mult1add1(ultrascale)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND,
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    USE_Z_INPUT        => true,
    PREADDER_INPUT_XA  => IM_PREADDER_XA,
    PREADDER_INPUT_XB  => IM_PREADDER_XB,
    NUM_INPUT_REG_XY   => NUM_INPUT_REG_XY+2, -- 2 more pipeline stages to compensate Z input
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
    sub_xa     => neg,     -- add (subtract)
    sub_xb     => not neg, -- subtract (add)
    xa         => x_im,
    xb         => x_re,
    y          => y_re,
    z          => temp,
    result     => result_im,
    result_vld => open, -- same as real component
    result_ovf => result_ovf_im,
    chainin    => chainin_im,
    chainout   => chainout_im,
    PIPESTAGES => open -- same as real component
  );

 end generate;

end architecture;
