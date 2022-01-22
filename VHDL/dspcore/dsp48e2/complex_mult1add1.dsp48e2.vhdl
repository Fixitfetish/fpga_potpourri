-------------------------------------------------------------------------------
--! @file       complex_mult1add1.dsp48e2.vhdl
--! @author     Fixitfetish
--! @date       01/Jan/2022
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
  use baselib.ieee_extension.all;

use work.xilinx_dsp_pkg_dsp48e2.all;

--! @brief This is an implementation of the entity complex_mult1add1 for Xilinx UltraScale.
--! One complex multiplication is performed and results and an additional summand can be accumulated.
--!
--! @image html complex_mult1add1.dsp48e2.svg "" width=600px
--!
--! **OPTIMIZATION="PERFORMANCE"**
--! * This implementation requires four instances of the entity signed_preadd_mult1add1 .
--! * This implementation requires four DSP48e2.
--! * X input width is limited to 27 bits and Y input to 18 bits.
--! * Chaining is supported.
--! * Additional Z summand input is supported.
--! * Accumulation is not supported when chain and Z input are used.
--! * The number of overall pipeline stages is typically NUM_INPUT_REG_XY + 1 + NUM_OUTPUT_REG.
--!
--! **OPTIMIZATION="RESOURCES" with x and y input width <=18 bits**
--! * This implementation requires three instances of the entity signed_preadd_mult1add1 .
--! * This implementation requires three DSP48e2.
--! * X and Y input width is limited to 18 bits.
--! * Chaining is supported.
--! * Additional Z summand input is NOT supported.
--! * Accumulation is not supported when chain input is used.
--! * The number of overall pipeline stages is typically NUM_INPUT_REG_XY + 2 + NUM_OUTPUT_REG.
--!
architecture dsp48e2 of complex_mult1add1 is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "complex_mult1add1(dsp48e2)";

  constant X_INPUT_WIDTH   : positive := maximum(x_re'length,x_im'length);
  constant Y_INPUT_WIDTH   : positive := maximum(y_re'length,y_im'length);
  constant MAX_INPUT_WIDTH : positive := maximum(X_INPUT_WIDTH,Y_INPUT_WIDTH);

  signal neg_i, conj_x_i, conj_y_i : std_logic := '0';

begin

  assert (OPTIMIZATION="PERFORMANCE" or OPTIMIZATION="RESOURCES")
    report "ERROR " & IMPLEMENTATION & " :" &
           " Supported optimizations are : PERFORMANCE or RESOURCES"
    severity failure;

  neg_i <= neg when NEGATION="DYNAMIC" else '1' when NEGATION="ON" else '0';
  conj_x_i <= conj_x when CONJUGATE_X="DYNAMIC" else '1' when CONJUGATE_X="ON" else '0';
  conj_y_i <= conj_y when CONJUGATE_Y="DYNAMIC" else '1' when CONJUGATE_Y="ON" else '0';


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
 G4DSP : if OPTIMIZATION="PERFORMANCE" generate
  -- identifier for reports of warnings and errors
  constant CHOICE : string := IMPLEMENTATION & " with optimization=PERFORMANCE";
  signal chainout_re1 : signed(79 downto 0);
  signal chainout_im1 : signed(79 downto 0);
  signal dummy_re, dummy_im : signed(ACCU_WIDTH-1 downto 0);
 begin

  assert (X_INPUT_WIDTH<=MAX_WIDTH_AD)
    report "ERROR " & CHOICE & ": " & "Multiplier input X width cannot exceed " & integer'image(MAX_WIDTH_AD)
    severity failure;

  assert (Y_INPUT_WIDTH<=MAX_WIDTH_B)
    report "ERROR " & CHOICE & ": " & "Multiplier input Y width cannot exceed " & integer'image(MAX_WIDTH_B) & ". Maybe swap X and Y inputs ?"
    severity failure;

  -- Operation:  Re1 = ReChain + Xre*Yre + Zre
  i_re1 : entity work.signed_preadd_mult1add1(dsp48e2)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND-1,
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    USE_Z_INPUT        => USE_Z_INPUT,
    USE_XB_INPUT       => false, -- unused
    USE_NEGATION       => (NEGATION/="OFF"), -- TODO
    USE_XA_NEGATION    => open, -- unused
    USE_XB_NEGATION    => open, -- unused
    NUM_INPUT_REG_X    => NUM_INPUT_REG_XY,
    NUM_INPUT_REG_Y    => NUM_INPUT_REG_XY,
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
    neg        => neg_i,
    neg_xa     => open, -- unused
    neg_xb     => open, -- unused
    xa         => x_re,
    xb         => "00", -- unused
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
  i_re2 : entity work.signed_preadd_mult1add1(dsp48e2)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND, -- two multiplications per complex multiplication
    USE_CHAIN_INPUT    => true,
    USE_Z_INPUT        => false, -- unused
    USE_XB_INPUT       => false, -- unused
    USE_NEGATION       => true,
    USE_XA_NEGATION    => (CONJUGATE_X/="OFF"),
    USE_XB_NEGATION    => open, -- unused
    NUM_INPUT_REG_X    => NUM_INPUT_REG_XY+1, -- additional pipeline register(s) because of chaining
    NUM_INPUT_REG_Y    => NUM_INPUT_REG_XY+1, -- additional pipeline register(s) because of chaining
    NUM_INPUT_REG_Z    => 0, -- unused
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
    neg        => (not neg_i) xor conj_y_i,
    neg_xa     => conj_x_i,
    neg_xb     => open, -- unused
    xa         => x_im,
    xb         => "00", -- unused
    y          => y_im,
    z          => "00", -- unused
    result     => result_re,
    result_vld => result_vld,
    result_ovf => result_ovf_re,
    chainin    => chainout_re1,
    chainout   => chainout_re,
    PIPESTAGES => PIPESTAGES
  );

  -- operation:  Im1 = ImChain + Xre*Yim + Zim 
  i_im1 : entity work.signed_preadd_mult1add1(dsp48e2)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND-1,
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    USE_Z_INPUT        => USE_Z_INPUT,
    USE_XB_INPUT       => false, -- unused
    USE_NEGATION       => (CONJUGATE_Y/="OFF"), -- TODO
    USE_XA_NEGATION    => (NEGATION/="OFF"), -- TODO
    USE_XB_NEGATION    => open, -- unused
    NUM_INPUT_REG_X    => NUM_INPUT_REG_XY,
    NUM_INPUT_REG_Y    => NUM_INPUT_REG_XY,
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
    neg        => conj_y_i,
    neg_xa     => neg_i,
    neg_xb     => open, -- unused
    xa         => x_re,
    xb         => "00", -- unused
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
  i_im2 : entity work.signed_preadd_mult1add1(dsp48e2)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND, -- two multiplications per complex multiplication
    USE_CHAIN_INPUT    => true,
    USE_Z_INPUT        => false, -- unused
    USE_XB_INPUT       => false, -- unused
    USE_NEGATION       => (NEGATION/="OFF"), -- TODO
    USE_XA_NEGATION    => (CONJUGATE_X/="OFF"), -- TODO
    USE_XB_NEGATION    => open, -- unused
    NUM_INPUT_REG_X    => NUM_INPUT_REG_XY+1, -- additional pipeline register(s) because of chaining
    NUM_INPUT_REG_Y    => NUM_INPUT_REG_XY+1, -- additional pipeline register(s) because of chaining
    NUM_INPUT_REG_Z    => 0, -- unused
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
    neg        => neg_i,
    neg_xa     => conj_x_i,
    neg_xb     => open, -- unused
    xa         => x_im,
    xb         => "00", -- unused
    y          => y_re,
    z          => "00", -- unused
    result     => result_im,
    result_vld => open, -- same as real component
    result_ovf => result_ovf_im,
    chainin    => chainout_im1,
    chainout   => chainout_im,
    PIPESTAGES => open  -- same as real component
  );

 end generate;


 --------------------------------------------------------------------------------------------------
 -- Operation with 3 DSP cells
 -- *  Temp =           ( Yre + Yim) * Xre 
 -- *  Re   = ReChain + (-Xre - Xim) * Yim + Temp
 -- *  Im   = ImChain + ( Xim - Xre) * Yre + Temp
 --
 -- Notes
 -- * Z input not supported !
 -- * factor inputs X and Y are limited to 2x18 bits
 --
 -- USE_CHAIN_INPUT=true
 -- * accumulation not possible because P feedback must be disabled
 -- * The rounding (i.e. +0.5) not possible within DSP.
 --   But rounding bit can be injected at the first chain link where USE_CHAIN_INPUT=false
 --------------------------------------------------------------------------------------------------
 G3DSP : if OPTIMIZATION="RESOURCES" generate
  -- identifier for reports of warnings and errors
  constant CHOICE : string := IMPLEMENTATION & " with optimization=RESOURCES (3 DSP cells)";

  constant TEMP_WIDTH : positive := x_re'length + y_re'length + 1;
  signal temp : signed(TEMP_WIDTH-1 downto 0);

 begin

  assert (MAX_INPUT_WIDTH<=MAX_WIDTH_B)
    report "ERROR " & CHOICE & ": " & "Multiplier input X and Y width cannot exceed " & integer'image(MAX_WIDTH_B)
    severity failure;

  assert (not USE_Z_INPUT)
    report "ERROR " & CHOICE & " :" &
           " Z input not supported with selected optimization."
    severity failure;

  assert (not USE_CHAIN_INPUT)
    report "NOTE " & CHOICE & " :" &
           " Selected optimization does not allow accumulation when chain input is used. Ignoring CLR input port."
    severity note;

  -- Operation:
  -- Temp = ( Yre + Yim) * Xre  ... raw with full resolution
  i_temp : entity work.signed_preadd_mult1add1(dsp48e2)
  generic map(
    NUM_SUMMAND        => 2,
    USE_CHAIN_INPUT    => false,
    USE_Z_INPUT        => false,
    USE_XB_INPUT       => true,
    USE_NEGATION       => (NEGATION/="OFF"), -- TODO
    USE_XA_NEGATION    => (CONJUGATE_Y/="OFF"), -- TODO
    USE_XB_NEGATION    => false, -- unused
    NUM_INPUT_REG_X    => NUM_INPUT_REG_XY,
    NUM_INPUT_REG_Y    => NUM_INPUT_REG_XY,
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
    clkena     => clkena,
    clr        => open,
    vld        => vld, -- valid
    neg        => neg_i,
    neg_xa     => conj_y_i,
    neg_xb     => open, -- unused
    xa         => y_im, -- first factor
    xb         => y_re, -- first factor
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
  i_re : entity work.signed_preadd_mult1add1(dsp48e2)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND,
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    USE_Z_INPUT        => true,
    USE_XB_INPUT       => true,
    USE_NEGATION       => true,
    USE_XA_NEGATION    => (CONJUGATE_X/="OFF"), -- TODO
    USE_XB_NEGATION    => false, -- unused
    NUM_INPUT_REG_X    => NUM_INPUT_REG_XY+2, -- 2 more pipeline stages to compensate Z input
    NUM_INPUT_REG_Y    => NUM_INPUT_REG_XY+2, -- 2 more pipeline stages to compensate Z input
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
    clkena     => clkena,
    clr        => clr, -- clear
    vld        => vld, -- valid
    neg        => (not neg_i) xor conj_y_i,
    neg_xa     => conj_x_i,
    neg_xb     => open, -- unused
    xa         => x_im,
    xb         => x_re,
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
  i_im : entity work.signed_preadd_mult1add1(dsp48e2)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND,
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    USE_Z_INPUT        => true,
    USE_XB_INPUT       => true,
    USE_NEGATION       => (NEGATION/="OFF"), -- TODO
    USE_XA_NEGATION    => true,
    USE_XB_NEGATION    => (CONJUGATE_X/="OFF"), -- TODO,
    NUM_INPUT_REG_X    => NUM_INPUT_REG_XY+2, -- 2 more pipeline stages to compensate Z input
    NUM_INPUT_REG_Y    => NUM_INPUT_REG_XY+2, -- 2 more pipeline stages to compensate Z input
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
    clkena     => clkena,
    clr        => clr, -- clear
    vld        => vld, -- valid
    neg        => neg_i,
    neg_xa     => '1',
    neg_xb     => conj_x_i,
    xa         => x_re,
    xb         => x_im,
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
