-------------------------------------------------------------------------------
--! @file       complex_mult1add1.dsp48e2.vhdl
--! @author     Fixitfetish
--! @date       15/Sep/2024
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Code comments are optimized for SIGASI.
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;

use work.xilinx_dsp_pkg_dsp48e2.all;

-- This is an implementation of the entity complex_mult1add1 for AMD/Xilinx DSP48e2.
--
-- **OPTIMIZATION="PERFORMANCE"**
-- * This implementation requires four instances of the entity signed_preadd_mult1add1 .
-- * This implementation requires four DSP48e2.
-- * X input width is limited to 27 bits and Y input to 18 bits.
-- * Chaining is supported.
-- * Additional Z summand input is supported.
-- * Accumulation is not supported when chain and Z input are used.
-- * The number of overall pipeline stages is typically NUM_INPUT_REG_XY + 1 + NUM_OUTPUT_REG.
--
-- **OPTIMIZATION="RESOURCES" with x and y input width <=18 bits**
-- * This implementation requires three instances of the entity signed_preadd_mult1add1 .
-- * This implementation requires three DSP48e2.
-- * X and Y input width is limited to 18 bits.
-- * Chaining is supported.
-- * Additional Z summand input is NOT supported.
-- * Accumulation is not supported when chain input is used.
-- * The number of overall pipeline stages is typically NUM_INPUT_REG_XY + 2 + NUM_OUTPUT_REG.
--
-- Refer to Xilinx UltraScale Architecture DSP48E2 Slice, UG579 (v1.11) August 30, 2021
--
architecture dsp48e2 of complex_mult1add1 is

  constant X_INPUT_WIDTH   : positive := maximum(x_re'length,x_im'length);
  constant Y_INPUT_WIDTH   : positive := maximum(y_re'length,y_im'length);
  constant MAX_INPUT_WIDTH : positive := maximum(X_INPUT_WIDTH,Y_INPUT_WIDTH);

  -- TODO: later independent X and Y input registers ?
  constant NUM_INPUT_REG_X : positive := NUM_INPUT_REG_XY;
  constant NUM_INPUT_REG_Y : positive := NUM_INPUT_REG_XY;

  signal neg_i, x_conj_i, y_conj_i : std_logic := '0';

begin

  neg_i    <= neg    when USE_NEGATION    else '0';
  x_conj_i <= x_conj when USE_CONJUGATE_X else '0';
  y_conj_i <= y_conj when USE_CONJUGATE_Y else '0';

 --------------------------------------------------------------------------------------------------
 -- Operation with 4 DSP cells and chaining
 -- *  Re1 = ReChain + Xre*Yre + Zre
 -- *  Im1 = ImChain + Xre*Yim + Zim
 -- *  Re2 = Re1     - Xim*Yim + ReAccu
 -- *  Im2 = Im1     + Xim*Yre + ImAccu
 --
 -- Notes
 -- * Re1/Im1 can add Z input in addition to chain input
 -- * Re2/Im2 can add round bit and accumulate in addition to chain input
 -- * TODO : also allows complex preadder => different entity complex_preadd_macc !?
 --------------------------------------------------------------------------------------------------
 G4DSP : if OPTIMIZATION="PERFORMANCE" or OPTIMIZATION="G4DSP" generate
  -- identifier for reports of warnings and errors
  constant CHOICE : string := "(optimization=PERFORMANCE, 4 DSPs):: ";
  signal chain_re , chain_im: signed(79 downto 0);
  signal chain_re_vld, chain_im_vld : std_logic;
  signal dummy_re, dummy_im : signed(ACCU_WIDTH-1 downto 0);
 begin

  assert (NUM_INPUT_REG_X>=2 and NUM_INPUT_REG_Y>=2)
    report complex_mult1add1'INSTANCE_NAME & CHOICE &
           "For high-speed the X and Y paths should have at least two input registers."
    severity warning;

  assert (X_INPUT_WIDTH<=MAX_WIDTH_AD)
    report complex_mult1add1'INSTANCE_NAME & CHOICE &
           "Multiplier input X width cannot exceed " & integer'image(MAX_WIDTH_AD)
    severity failure;

  assert (Y_INPUT_WIDTH<=MAX_WIDTH_B)
    report complex_mult1add1'INSTANCE_NAME & CHOICE &
           "Multiplier input Y width cannot exceed " & integer'image(MAX_WIDTH_B) & ". Maybe swap X and Y inputs ?"
    severity failure;

  -- Operation:  Re1 = ReChain + Xre*Yre + Zre
  i_re1 : entity work.signed_preadd_mult1add1(dsp48e2)
  generic map(
    NUM_ACCU_CYCLES     => open, -- accumulator disabled
    NUM_SUMMAND_CHAININ => 2*NUM_SUMMAND_CHAININ, -- two single summands per complex chain input
    NUM_SUMMAND_Z       => 2*NUM_SUMMAND_Z, -- two single summands per complex Z input
    USE_XB_INPUT        => false, -- unused
    USE_NEGATION        => USE_NEGATION,
    USE_XA_NEGATION     => open, -- unused
    USE_XB_NEGATION     => open, -- unused
    NUM_INPUT_REG_X     => NUM_INPUT_REG_X,
    NUM_INPUT_REG_Y     => NUM_INPUT_REG_Y,
    NUM_INPUT_REG_Z     => NUM_INPUT_REG_Z,
    RELATION_RST        => RELATION_RST,
    RELATION_CLR        => open, -- unused
    RELATION_NEG        => RELATION_NEG,
    NUM_OUTPUT_REG      => 1,
    OUTPUT_SHIFT_RIGHT  => 0,     -- result output unused
    OUTPUT_ROUND        => false, -- result output unused
    OUTPUT_CLIP         => false, -- result output unused
    OUTPUT_OVERFLOW     => false  -- result output unused
  )
  port map (
    clk          => clk,
    rst          => rst,
    clkena       => clkena,
    clr          => open, -- unused
    neg          => neg_i,
    xa           => x_re,
    xa_vld       => x_vld,
    xa_neg       => open, -- unused
    xb           => "00", -- unused
    xb_vld       => open, -- unused
    xb_neg       => open, -- unused
    y            => y_re,
    y_vld        => y_vld,
    z            => z_re,
    z_vld        => z_vld,
    result       => dummy_re, -- unused
    result_vld   => open, -- unused
    result_ovf   => open, -- unused
    result_rst   => open, -- unused
    chainin      => chainin_re,
    chainin_vld  => chainin_re_vld,
    chainout     => chain_re,
    chainout_vld => chain_re_vld,
    PIPESTAGES   => open  -- unused
  );

  -- operation:  Re2 = Re1 - Xim*Yim   (accumulation possible)
  i_re2 : entity work.signed_preadd_mult1add1(dsp48e2)
  generic map(
    NUM_ACCU_CYCLES     => NUM_ACCU_CYCLES, -- accumulator enabled in last chain link only!
    NUM_SUMMAND_CHAININ => 2*NUM_SUMMAND_CHAININ + 2*NUM_SUMMAND_Z + 1,
    NUM_SUMMAND_Z       => 0, -- unused
    USE_XB_INPUT        => false, -- unused
    USE_NEGATION        => true,
    USE_XA_NEGATION     => USE_CONJUGATE_X,
    USE_XB_NEGATION     => open, -- unused
    NUM_INPUT_REG_X     => NUM_INPUT_REG_X + 1,
    NUM_INPUT_REG_Y     => NUM_INPUT_REG_Y + 1,
    NUM_INPUT_REG_Z     => open, -- unused
    RELATION_RST        => RELATION_RST,
    RELATION_CLR        => RELATION_CLR,
    RELATION_NEG        => RELATION_NEG, -- TODO : neg and y_conj must have same relation. force "Y" ?
    NUM_OUTPUT_REG      => NUM_OUTPUT_REG,
    OUTPUT_SHIFT_RIGHT  => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND        => OUTPUT_ROUND,
    OUTPUT_CLIP         => OUTPUT_CLIP,
    OUTPUT_OVERFLOW     => OUTPUT_OVERFLOW
  )
  port map (
    clk          => clk,
    rst          => rst,
    clkena       => clkena,
    clr          => clr, -- accumulator enabled in last chain link only!
    neg          => (not neg_i) xor y_conj_i,
    xa           => x_im,
    xa_vld       => x_vld,
    xa_neg       => x_conj_i,
    xb           => "00", -- unused
    xb_vld       => open, -- unused
    xb_neg       => open, -- unused
    y            => y_im,
    y_vld        => y_vld,
    z            => "00", -- unused
    z_vld        => open, -- unused
    result       => result_re,
    result_vld   => result_vld,
    result_ovf   => result_ovf_re,
    result_rst   => result_rst,
    chainin      => chain_re,
    chainin_vld  => chain_re_vld,
    chainout     => chainout_re,
    chainout_vld => chainout_re_vld,
    PIPESTAGES   => PIPESTAGES
  );

  -- operation:  Im1 = ImChain + Xre*Yim + Zim 
  i_im1 : entity work.signed_preadd_mult1add1(dsp48e2)
  generic map(
    NUM_ACCU_CYCLES     => open, -- accumulator disabled
    NUM_SUMMAND_CHAININ => 2*NUM_SUMMAND_CHAININ, -- two single summands per complex chain input
    NUM_SUMMAND_Z       => 2*NUM_SUMMAND_Z, -- two single summands per complex Z input
    USE_XB_INPUT        => false, -- unused
    USE_NEGATION        => USE_CONJUGATE_Y,
    USE_XA_NEGATION     => USE_NEGATION,
    USE_XB_NEGATION     => open, -- unused
    NUM_INPUT_REG_X     => NUM_INPUT_REG_X,
    NUM_INPUT_REG_Y     => NUM_INPUT_REG_Y,
    NUM_INPUT_REG_Z     => NUM_INPUT_REG_Z,
    RELATION_RST        => RELATION_RST,
    RELATION_CLR        => open, -- unused
    RELATION_NEG        => RELATION_NEG, -- TODO : fixed to "Y" ?
    NUM_OUTPUT_REG      => 1,
    OUTPUT_SHIFT_RIGHT  => 0,     -- result output unused
    OUTPUT_ROUND        => false, -- result output unused
    OUTPUT_CLIP         => false, -- result output unused
    OUTPUT_OVERFLOW     => false  -- result output unused
  )
  port map (
    clk          => clk,
    rst          => rst,
    clkena       => clkena,
    clr          => open,
    neg          => y_conj_i,
    xa           => x_re,
    xa_vld       => x_vld,
    xa_neg       => neg_i,
    xb           => "00", -- unused
    xb_vld       => open, -- unused
    xb_neg       => open, -- unused
    y            => y_im,
    y_vld        => y_vld,
    z            => z_im,
    z_vld        => z_vld,
    result       => dummy_im, -- unused
    result_vld   => open, -- unused
    result_ovf   => open, -- unused
    result_rst   => open, -- unused
    chainin      => chainin_im,
    chainin_vld  => chainin_im_vld,
    chainout     => chain_im,
    chainout_vld => chain_im_vld,
    PIPESTAGES   => open  -- unused
  );

  -- operation:  Im2 = Im1 + Xim*Yre   (accumulation possible)
  i_im2 : entity work.signed_preadd_mult1add1(dsp48e2)
  generic map(
    NUM_ACCU_CYCLES     => NUM_ACCU_CYCLES, -- accumulator enabled in last chain link only!
    NUM_SUMMAND_CHAININ => 2*NUM_SUMMAND_CHAININ + 2*NUM_SUMMAND_Z + 1,
    NUM_SUMMAND_Z       => 0, -- unused
    USE_XB_INPUT        => false, -- unused
    USE_NEGATION        => USE_NEGATION,
    USE_XA_NEGATION     => USE_CONJUGATE_X,
    USE_XB_NEGATION     => open, -- unused
    NUM_INPUT_REG_X     => NUM_INPUT_REG_X + 1,
    NUM_INPUT_REG_Y     => NUM_INPUT_REG_Y + 1,
    NUM_INPUT_REG_Z     => open, -- unused
    RELATION_RST        => RELATION_RST,
    RELATION_CLR        => RELATION_CLR,
    RELATION_NEG        => RELATION_NEG,
    NUM_OUTPUT_REG      => NUM_OUTPUT_REG,
    OUTPUT_SHIFT_RIGHT  => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND        => OUTPUT_ROUND,
    OUTPUT_CLIP         => OUTPUT_CLIP,
    OUTPUT_OVERFLOW     => OUTPUT_OVERFLOW
  )
  port map (
    clk          => clk,
    rst          => rst,
    clkena       => clkena,
    clr          => clr, -- accumulator enabled in last chain link only!
    neg          => neg_i,
    xa           => x_im,
    xa_vld       => x_vld,
    xa_neg       => x_conj_i,
    xb           => "00", -- unused
    xb_vld       => open, -- unused
    xb_neg       => open, -- unused
    y            => y_re,
    y_vld        => y_vld,
    z            => "00", -- unused
    z_vld        => open, -- unused
    result       => result_im,
    result_vld   => open, -- same as real component
    result_ovf   => result_ovf_im,
    result_rst   => open, -- same as real component
    chainin      => chain_im,
    chainin_vld  => chain_im_vld,
    chainout     => chainout_im,
    chainout_vld => chainout_im_vld,
    PIPESTAGES   => open  -- same as real component
  );

 end generate G4DSP;


 --------------------------------------------------------------------------------------------------
 -- Operation with 3 DSP cells
 -- *  Temp =           ( Yre - Yim) * Xim 
 -- *  Re   = ReChain + ( Xre - Xim) * Yre + Temp  = ReChain + (Xre * Yre) - (Xim * Yim)
 -- *  Im   = ImChain + ( Xre + Xim) * Yim + Temp  = ImChain + (Xre * Yim) + (Xim * Yre)
 --
 -- Notes
 -- * Z input not supported !
 -- * factor inputs X and Y are limited to 2x18 bits
 --
 -- If the chain input is used, i.e. when the chainin_vld is connected and not static, then
 -- * accumulation not possible because P feedback must be disabled
 -- * The rounding (i.e. +0.5) not possible within DSP.
 --   But rounding bit can be injected at the first chain link where the chain input is unused.
 --------------------------------------------------------------------------------------------------
 G3DSP : if OPTIMIZATION="RESOURCES" or OPTIMIZATION="G3DSP" generate
  -- identifier for reports of warnings and errors
  constant CHOICE : string := "(optimization=RESOURCES, 3 DSPs):: ";
  constant TEMP_WIDTH : positive := x_re'length + y_re'length + 1;
  signal temp : signed(TEMP_WIDTH-1 downto 0);
  signal temp_vld : std_logic;
 begin

  assert (NUM_INPUT_REG_X>=2 and NUM_INPUT_REG_Y>=2)
    report complex_mult1add1'INSTANCE_NAME & CHOICE &
           "For high-speed the X and Y paths should have at least two input registers."
    severity warning;

  assert (chainin_re_vld/='1' and chainin_im_vld/='1') or (NUM_ACCU_CYCLES=1)
    report complex_mult1add1'INSTANCE_NAME & CHOICE &
           "Selected optimization does not allow simultaneous chain input and accumulation."
    severity warning;

  assert (MAX_INPUT_WIDTH<=MAX_WIDTH_B)
    report complex_mult1add1'INSTANCE_NAME & CHOICE &
           "Multiplier input X and Y width cannot exceed " & integer'image(MAX_WIDTH_B)
    severity failure;

  assert (z_vld/='1')
    report complex_mult1add1'INSTANCE_NAME & CHOICE &
           "Z input not supported with selected optimization."
    severity failure;

  -- Operation:
  -- Temp = ( Yre - Yim) * Xim  ... raw with full resolution
  i_temp : entity work.signed_preadd_mult1add1(dsp48e2)
  generic map(
    NUM_ACCU_CYCLES     => open, -- accumulator disabled
    NUM_SUMMAND_CHAININ => 0, -- unused
    NUM_SUMMAND_Z       => 0, -- unused
    USE_XB_INPUT        => true,
    USE_NEGATION        => USE_NEGATION or USE_CONJUGATE_X,
    USE_XA_NEGATION     => true,
    USE_XB_NEGATION     => false, -- unused
    NUM_INPUT_REG_X     => NUM_INPUT_REG_Y, -- X/Y swapped because Y requires preadder
    NUM_INPUT_REG_Y     => NUM_INPUT_REG_X, -- X/Y swapped because Y requires preadder
    NUM_INPUT_REG_Z     => open, -- unused
    RELATION_RST        => RELATION_RST,
    RELATION_CLR        => open, -- unused
    RELATION_NEG        => RELATION_NEG,
    NUM_OUTPUT_REG      => 1,
    OUTPUT_SHIFT_RIGHT  => 0, -- raw temporary result for following RE and IM stage
    OUTPUT_ROUND        => false,
    OUTPUT_CLIP         => false,
    OUTPUT_OVERFLOW     => false
  )
  port map(
    clk          => clk, -- clock
    rst          => rst, -- reset
    clkena       => clkena,
    clr          => open, -- unused
    neg          => neg_i xor x_conj_i,
    xa           => y_im, -- first factor
    xa_vld       => y_vld,
    xa_neg       => not y_conj_i,
    xb           => y_re, -- first factor
    xb_vld       => y_vld,
    xb_neg       => open, -- unused
    y            => x_im, -- second factor
    y_vld        => x_vld,
    z            => "00", -- unused
    z_vld        => open, -- unused
    result       => temp, -- temporary result
    result_vld   => temp_vld,
    result_ovf   => open, -- not needed
    result_rst   => open, -- unused
    chainin      => open, -- unused
    chainin_vld  => open, -- unused
    chainout     => open, -- unused
    chainout_vld => open, -- unused
    PIPESTAGES   => open  -- unused
  );

  -- Operation:
  -- Re = ReChain + (Xre - Xim) * Yre + Temp   (accumulation only when chain input unused)
  i_re : entity work.signed_preadd_mult1add1(dsp48e2)
  generic map(
    NUM_ACCU_CYCLES     => NUM_ACCU_CYCLES, -- accumulator enabled in last chain link only!
    NUM_SUMMAND_CHAININ => 2*NUM_SUMMAND_CHAININ, -- two single summands per complex chain input
    NUM_SUMMAND_Z       => 1, -- temp contributes with two summands because of preadder but one of those is subtracted here again
    USE_XB_INPUT        => true,
    USE_NEGATION        => USE_NEGATION,
    USE_XA_NEGATION     => true,
    USE_XB_NEGATION     => false, -- unused
    NUM_INPUT_REG_X     => NUM_INPUT_REG_X + NUM_INPUT_REG_Z + 1,
    NUM_INPUT_REG_Y     => NUM_INPUT_REG_Y + NUM_INPUT_REG_Z + 1,
    NUM_INPUT_REG_Z     => NUM_INPUT_REG_Z,
    RELATION_RST        => RELATION_RST,
    RELATION_CLR        => RELATION_CLR,
    RELATION_NEG        => RELATION_NEG,
    NUM_OUTPUT_REG      => NUM_OUTPUT_REG,
    OUTPUT_SHIFT_RIGHT  => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND        => OUTPUT_ROUND,
    OUTPUT_CLIP         => OUTPUT_CLIP,
    OUTPUT_OVERFLOW     => OUTPUT_OVERFLOW
  )
  port map(
    clk          => clk,
    rst          => rst,
    clkena       => clkena,
    clr          => clr, -- only relevant when accumulator is enabled
    neg          => neg_i,
    xa           => x_im,
    xa_vld       => x_vld,
    xa_neg       => not x_conj_i,
    xb           => x_re,
    xb_vld       => x_vld,
    xb_neg       => open, -- unused
    y            => y_re,
    y_vld        => y_vld,
    z            => temp,
    z_vld        => temp_vld,
    result       => result_re,
    result_vld   => result_vld,
    result_ovf   => result_ovf_re,
    result_rst   => result_rst,
    chainin      => chainin_re,
    chainin_vld  => chainin_re_vld,
    chainout     => chainout_re,
    chainout_vld => chainout_re_vld,
    PIPESTAGES   => PIPESTAGES
  );

  -- Operation:
  -- Im = ImChain + ( Xre + Xim) * Yim + Temp   (accumulation only when chain input unused)
  i_im : entity work.signed_preadd_mult1add1(dsp48e2)
  generic map(
    NUM_ACCU_CYCLES     => NUM_ACCU_CYCLES, -- accumulator enabled in last chain link only!
    NUM_SUMMAND_CHAININ => 2*NUM_SUMMAND_CHAININ, -- two single summands per complex chain input
    NUM_SUMMAND_Z       => 1, -- temp contributes with two summands because of preadder but one of those is subtracted here again
    USE_XB_INPUT        => true,
    USE_NEGATION        => USE_NEGATION or USE_CONJUGATE_Y,
    USE_XA_NEGATION     => USE_CONJUGATE_X,
    USE_XB_NEGATION     => false, -- unused
    NUM_INPUT_REG_X     => NUM_INPUT_REG_X + NUM_INPUT_REG_Z + 1,
    NUM_INPUT_REG_Y     => NUM_INPUT_REG_Y + NUM_INPUT_REG_Z + 1,
    NUM_INPUT_REG_Z     => NUM_INPUT_REG_Z,
    RELATION_RST        => RELATION_RST,
    RELATION_CLR        => RELATION_CLR,
    RELATION_NEG        => RELATION_NEG,
    NUM_OUTPUT_REG      => NUM_OUTPUT_REG,
    OUTPUT_SHIFT_RIGHT  => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND        => OUTPUT_ROUND,
    OUTPUT_CLIP         => OUTPUT_CLIP,
    OUTPUT_OVERFLOW     => OUTPUT_OVERFLOW
  )
  port map(
    clk          => clk,
    rst          => rst,
    clkena       => clkena,
    clr          => clr, -- only relevant when accumulator is enabled
    neg          => neg_i xor y_conj_i,
    xa           => x_im,
    xa_vld       => x_vld,
    xa_neg       => x_conj_i,
    xb           => x_re,
    xb_vld       => x_vld,
    xb_neg       => open, -- unused
    y            => y_im,
    y_vld        => y_vld,
    z            => temp,
    z_vld        => temp_vld,
    result       => result_im,
    result_vld   => open, -- same as real component
    result_ovf   => result_ovf_im,
    result_rst   => open, -- same as real component
    chainin      => chainin_im,
    chainin_vld  => chainin_im_vld,
    chainout     => chainout_im,
    chainout_vld => chainout_im_vld,
    PIPESTAGES   => open  -- same as real component
  );

 end generate G3DSP;

end architecture;
