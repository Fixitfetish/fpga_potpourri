-------------------------------------------------------------------------------
--! @file       complex_macc_chain.dsp58.vhdl
--! @author     Fixitfetish
--! @date       05/Sep/2024
--! @version    0.21
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Code comments are optimized for SIGASI.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;

use work.xilinx_dsp_pkg_dsp58.all;

-- N complex multiplications and sum of all product results.
--
architecture dsp58 of complex_macc_chain is

  -- identifier for reports of warnings and errors
  constant INSTANCE_NAME : string := complex_macc_chain'instance_name;

  constant X_INPUT_WIDTH   : positive := maximum(x_re(0)'length,x_im(0)'length);
  constant Y_INPUT_WIDTH   : positive := maximum(y_re(0)'length,y_im(0)'length);
  constant MAX_INPUT_WIDTH : positive := maximum(X_INPUT_WIDTH,Y_INPUT_WIDTH);

  constant NUM_INPUT_REG_X : natural := NUM_INPUT_REG_XY;
  constant NUM_INPUT_REG_Y : natural := NUM_INPUT_REG_XY;

  function OUTREGS(i:natural) return natural is begin
    if i<(NUM_MULT-1) then return 1; else return NUM_OUTPUT_REG; end if;
  end function;

  signal result_re_i : signed_vector(0 to NUM_MULT-1)(result_re'length-1 downto 0);
  signal result_im_i : signed_vector(0 to NUM_MULT-1)(result_im'length-1 downto 0);
  signal result_vld_i : std_logic_vector(0 to NUM_MULT-1);
  signal result_ovf_re_i : std_logic_vector(0 to NUM_MULT-1);
  signal result_ovf_im_i : std_logic_vector(0 to NUM_MULT-1);
  signal pipestages_i : integer_vector(0 to NUM_MULT-1);

  signal neg_i, x_conj_i, y_conj_i : std_logic_vector(0 to NUM_MULT-1) := (others=>'0');

  signal chainin_re  : signed_vector(0 to NUM_MULT)(79 downto 0);
  signal chainin_im  : signed_vector(0 to NUM_MULT)(79 downto 0);
  signal chainin_re_vld : std_logic_vector(0 to NUM_MULT);
  signal chainin_im_vld : std_logic_vector(0 to NUM_MULT);

 begin

  neg_i    <= neg    when USE_NEGATION    else (others=>'0');
  x_conj_i <= x_conj when USE_CONJUGATE_X else (others=>'0');
  y_conj_i <= y_conj when USE_CONJUGATE_Y else (others=>'0');

  -- dummy chain input
  chainin_re(0) <= (others=>'0');
  chainin_im(0) <= (others=>'0');
  chainin_re_vld(0) <= '0';
  chainin_im_vld(0) <= '0';


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
  constant CHOICE : string := INSTANCE_NAME & " (optimization=PERFORMANCE, 4N*DSP):: ";
 begin

  assert (NUM_INPUT_REG_X>=1 and NUM_INPUT_REG_Y>=1)
    report CHOICE & "For high-speed the X and Y paths should have at least one additional input register."
    severity warning;

  assert (X_INPUT_WIDTH<=MAX_WIDTH_AD)
    report CHOICE & "Multiplier input X width cannot exceed " & integer'image(MAX_WIDTH_AD)
    severity failure;

  assert (Y_INPUT_WIDTH<=MAX_WIDTH_B)
    report CHOICE & "Multiplier input Y width cannot exceed " & integer'image(MAX_WIDTH_B) & ". Maybe swap X and Y inputs ?"
    severity failure;

  CHAIN : for n in 0 to NUM_MULT-1 generate
    -- Always at least one X input pipeline register is required
    constant STAGE1_INPUT_REG_X : positive := 1 + NUM_INPUT_REG_X + 2*n;
    -- Stage 2 with one additional X input pipeline register to compensate chaining
    constant STAGE2_INPUT_REG_X : positive := STAGE1_INPUT_REG_X + 1;
    -- Always at least one Y input pipeline register is required
    constant STAGE1_INPUT_REG_Y : positive := 1 + NUM_INPUT_REG_Y + 2*n;
    -- Stage 2 with one additional Y input pipeline register to compensate chaining
    constant STAGE2_INPUT_REG_Y : positive := STAGE1_INPUT_REG_Y + 1;
    -- Always at least one Z input pipeline register is required
    constant STAGE1_INPUT_REG_Z : positive := 1 + NUM_INPUT_REG_Z + 2*n;
    signal chain_re , chain_im: signed(79 downto 0);
    signal chain_re_vld, chain_im_vld : std_logic;
    signal dummy_re, dummy_im : signed(ACCU_WIDTH-1 downto 0);
  begin

  -- Operation:  Re1 = ReChain + Xre*Yre + Zre
  i_re1 : entity work.signed_preadd_mult1add1(dsp58)
  generic map(
    USE_ACCU           => false,
    NUM_SUMMAND        => 2*NUM_MULT-1,
    USE_XB_INPUT       => false, -- unused
    USE_NEGATION       => USE_NEGATION,
    USE_XA_NEGATION    => open, -- unused
    USE_XB_NEGATION    => open, -- unused
    NUM_INPUT_REG_X    => STAGE1_INPUT_REG_X,
    NUM_INPUT_REG_Y    => STAGE1_INPUT_REG_Y,
    NUM_INPUT_REG_Z    => STAGE1_INPUT_REG_Z,
    RELATION_CLR       => open, -- TODO
    RELATION_NEG       => open, -- TODO
    NUM_OUTPUT_REG     => 1,
    OUTPUT_SHIFT_RIGHT => 0,
    OUTPUT_ROUND       => false,
    OUTPUT_CLIP        => false,
    OUTPUT_OVERFLOW    => false
  )
  port map (
    clk          => clk,
    rst          => rst,
    clkena       => clkena,
    clr          => open, -- unused
    neg          => neg_i(n),
    xa           => x_re(n),
    xa_vld       => x_vld(n),
    xa_neg       => open, -- unused
    xb           => "00", -- unused
    xb_vld       => open, -- unused
    xb_neg       => open, -- unused
    y            => y_re(n),
    y_vld        => y_vld(n),
    z            => z_re(n),
    z_vld        => z_vld(n),
    result       => dummy_re, -- unused
    result_vld   => open, -- unused
    result_ovf   => open, -- unused
    chainin      => chainin_re(n),
    chainin_vld  => chainin_re_vld(n),
    chainout     => chain_re,
    chainout_vld => chain_re_vld,
    PIPESTAGES   => open  -- unused
  );

  -- operation:  Re2 = Re1 - Xim*Yim   (accumulation possible)
  i_re2 : entity work.signed_preadd_mult1add1(dsp58)
  generic map(
    USE_ACCU           => (USE_ACCU and (n=(NUM_MULT-1))), -- accumulator enabled in last chain link only!
    NUM_SUMMAND        => 2*NUM_MULT, -- two multiplications per complex multiplication
    USE_XB_INPUT       => false, -- unused
    USE_NEGATION       => true,
    USE_XA_NEGATION    => USE_CONJUGATE_X,
    USE_XB_NEGATION    => open, -- unused
    NUM_INPUT_REG_X    => STAGE2_INPUT_REG_X,
    NUM_INPUT_REG_Y    => STAGE2_INPUT_REG_Y,
    NUM_INPUT_REG_Z    => open, -- unused
    RELATION_CLR       => open, -- TODO
    RELATION_NEG       => open, -- TODO
    NUM_OUTPUT_REG     => OUTREGS(n),
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => (OUTPUT_ROUND and (n=(NUM_MULT-1))),
    OUTPUT_CLIP        => (OUTPUT_CLIP and (n=(NUM_MULT-1))),
    OUTPUT_OVERFLOW    => (OUTPUT_OVERFLOW and (n=(NUM_MULT-1)))
  )
  port map (
    clk          => clk,
    rst          => rst,
    clkena       => clkena,
    clr          => clr, -- accumulator enabled in last chain link only!
    neg          => (not neg_i(n)) xor y_conj_i(n),
    xa           => x_im(n),
    xa_vld       => x_vld(n),
    xa_neg       => x_conj_i(n),
    xb           => "00", -- unused
    xb_vld       => open, -- unused
    xb_neg       => open, -- unused
    y            => y_im(n),
    y_vld        => y_vld(n),
    z            => "00", -- unused
    z_vld        => open, -- unused
    result       => result_re_i(n),
    result_vld   => result_vld_i(n),
    result_ovf   => result_ovf_re_i(n),
    chainin      => chain_re,
    chainin_vld  => chain_re_vld,
    chainout     => chainin_re(n+1),
    chainout_vld => chainin_re_vld(n+1),
    PIPESTAGES   => pipestages_i(n)
  );

  -- operation:  Im1 = ImChain + Xre*Yim + Zim 
  i_im1 : entity work.signed_preadd_mult1add1(dsp58)
  generic map(
    USE_ACCU           => false,
    NUM_SUMMAND        => 2*NUM_MULT-1,
    USE_XB_INPUT       => false, -- unused
    USE_NEGATION       => USE_CONJUGATE_Y,
    USE_XA_NEGATION    => USE_NEGATION,
    USE_XB_NEGATION    => open, -- unused
    NUM_INPUT_REG_X    => STAGE1_INPUT_REG_X,
    NUM_INPUT_REG_Y    => STAGE1_INPUT_REG_Y,
    NUM_INPUT_REG_Z    => STAGE1_INPUT_REG_Z,
    RELATION_CLR       => open, -- TODO
    RELATION_NEG       => open, -- TODO
    NUM_OUTPUT_REG     => 1,
    OUTPUT_SHIFT_RIGHT => 0,
    OUTPUT_ROUND       => false,
    OUTPUT_CLIP        => false,
    OUTPUT_OVERFLOW    => false
  )
  port map (
    clk          => clk,
    rst          => rst,
    clkena       => clkena,
    clr          => open,
    neg          => y_conj_i(n),
    xa           => x_re(n),
    xa_vld       => x_vld(n),
    xa_neg       => neg_i(n),
    xb           => "00", -- unused
    xb_vld       => open, -- unused
    xb_neg       => open, -- unused
    y            => y_im(n),
    y_vld        => y_vld(n),
    z            => z_im(n),
    z_vld        => z_vld(n),
    result       => dummy_im, -- unused
    result_vld   => open, -- unused
    result_ovf   => open, -- unused
    chainin      => chainin_im(n),
    chainin_vld  => chainin_im_vld(n),
    chainout     => chain_im,
    chainout_vld => chain_im_vld,
    PIPESTAGES   => open  -- unused
  );

  -- operation:  Im2 = Im1 + Xim*Yre   (accumulation possible)
  i_im2 : entity work.signed_preadd_mult1add1(dsp58)
  generic map(
    USE_ACCU           => (USE_ACCU and (n=(NUM_MULT-1))), -- accumulator enabled in last chain link only!
    NUM_SUMMAND        => 2*NUM_MULT, -- two multiplications per complex multiplication
    USE_XB_INPUT       => false, -- unused
    USE_NEGATION       => USE_NEGATION,
    USE_XA_NEGATION    => USE_CONJUGATE_X,
    USE_XB_NEGATION    => open, -- unused
    NUM_INPUT_REG_X    => STAGE2_INPUT_REG_X,
    NUM_INPUT_REG_Y    => STAGE2_INPUT_REG_Y,
    NUM_INPUT_REG_Z    => open, -- unused
    RELATION_CLR       => open, -- TODO
    RELATION_NEG       => open, -- TODO
    NUM_OUTPUT_REG     => OUTREGS(n),
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => (OUTPUT_ROUND and (n=(NUM_MULT-1))),
    OUTPUT_CLIP        => (OUTPUT_CLIP and (n=(NUM_MULT-1))),
    OUTPUT_OVERFLOW    => (OUTPUT_OVERFLOW and (n=(NUM_MULT-1)))
  )
  port map (
    clk          => clk,
    rst          => rst,
    clkena       => clkena,
    clr          => clr, -- accumulator enabled in last chain link only!
    neg          => neg_i(n),
    xa           => x_im(n),
    xa_vld       => x_vld(n),
    xa_neg       => x_conj_i(n),
    xb           => "00", -- unused
    xb_vld       => open, -- unused
    xb_neg       => open, -- unused
    y            => y_re(n),
    y_vld        => y_vld(n),
    z            => "00", -- unused
    z_vld        => open, -- unused
    result       => result_im_i(n),
    result_vld   => open, -- same as real component
    result_ovf   => result_ovf_im_i(n),
    chainin      => chain_im,
    chainin_vld  => chain_im_vld,
    chainout     => chainin_im(n+1),
    chainout_vld => chainin_im_vld(n+1),
    PIPESTAGES   => open  -- same as real component
  );

  end generate CHAIN;
 end generate G4DSP;

 --------------------------------------------------------------------------------------------------
 -- Operation with 3 DSP cells
 -- *  Temp =           ( Yre + Yim) * Xre 
 -- *  Re   = ReChain + (-Xre - Xim) * Yim + Temp  = ReChain + (Xre * Yre) - (Xim * Yim)
 -- *  Im   = ImChain + ( Xim - Xre) * Yre + Temp  = ImChain + (Xre * Yim) + (Xim * Yre)
 --
 -- Notes
 -- * Z input not supported !
 -- * factor inputs X and Y are limited to 2x24 bits
 --
 -- If the chain input is used, i.e. when the chainin_vld is connected and not static, then
 -- * accumulation not possible because P feedback must be disabled
 -- * The rounding (i.e. +0.5) not possible within DSP.
 --   But rounding bit can be injected at the first chain link where the chain input is unused.
 --------------------------------------------------------------------------------------------------
 G3DSP : if (OPTIMIZATION="RESOURCES" and MAX_INPUT_WIDTH>18) or OPTIMIZATION="G3DSP" generate
  -- identifier for reports of warnings and errors
  constant CHOICE : string := INSTANCE_NAME & " (optimization=RESOURCES, 3N*DSP):: ";
 begin

  assert (MAX_INPUT_WIDTH<=MAX_WIDTH_B)
    report CHOICE & "Multiplier input X and Y width cannot exceed " & integer'image(MAX_WIDTH_B)
    severity failure;

  assert (z_vld=(0 to NUM_MULT-1=>'0'))
    report CHOICE & "Z input not supported with selected optimization."
    severity failure;

  assert (NUM_MULT=1 or not USE_ACCU)
    report CHOICE & "Selected optimization with NUM_MULT>=2 does not allow accumulation. Ignoring CLR input port."
    severity WARNING;

  CHAIN : for n in 0 to NUM_MULT-1 generate
    -- Always at least one X input pipeline register is required
    constant STAGE1_INPUT_REG_X : positive := 1 + NUM_INPUT_REG_X;
    -- Always at least one Y input pipeline register is required
    constant STAGE1_INPUT_REG_Y : positive := 1 + NUM_INPUT_REG_Y;
    -- Stage 2 with one additional X input pipeline register to compensate Z input
    constant STAGE2_INPUT_REG_X : positive := STAGE1_INPUT_REG_X + n + 2;
    -- Stage 2 with one additional Y input pipeline register to compensate Z input
    constant STAGE2_INPUT_REG_Y : positive := STAGE1_INPUT_REG_Y + n + 2;
    constant TEMP_WIDTH : positive := x_re(0)'length + y_re(0)'length + 1;
    signal temp : signed(TEMP_WIDTH-1 downto 0);
    signal temp_vld : std_logic;
  begin

  -- Operation:
  -- Temp = ( Yre + Yim) * Xre  ... raw with full resolution
  i_temp : entity work.signed_preadd_mult1add1(dsp58)
  generic map(
    USE_ACCU           => false,
    NUM_SUMMAND        => 2,
    USE_XB_INPUT       => true,
    USE_NEGATION       => USE_NEGATION,
    USE_XA_NEGATION    => USE_CONJUGATE_Y,
    USE_XB_NEGATION    => false, -- unused
    NUM_INPUT_REG_X    => STAGE1_INPUT_REG_Y, -- X/Y swapped because Y requires preadder
    NUM_INPUT_REG_Y    => STAGE1_INPUT_REG_X, -- X/Y swapped because Y requires preadder
    NUM_INPUT_REG_Z    => open, -- unused
    RELATION_CLR       => open, -- TODO
    RELATION_NEG       => open, -- TODO
    NUM_OUTPUT_REG     => 1,
    OUTPUT_SHIFT_RIGHT => 0, -- raw temporary result for following RE and IM stage
    OUTPUT_ROUND       => false,
    OUTPUT_CLIP        => false,
    OUTPUT_OVERFLOW    => false
  )
  port map(
    clk          => clk, -- clock
    rst          => rst, -- reset
    clkena       => clkena,
    clr          => open, -- unused
    neg          => neg_i(n),
    xa           => y_im(n), -- first factor
    xa_vld       => y_vld(n),
    xa_neg       => y_conj_i(n),
    xb           => y_re(n), -- first factor
    xb_vld       => y_vld(n),
    xb_neg       => open, -- unused
    y            => x_re(n), -- second factor
    y_vld        => x_vld(n),
    z            => "00", -- unused
    z_vld        => open, -- unused
    result       => temp, -- temporary result
    result_vld   => temp_vld,
    result_ovf   => open, -- not needed
    chainin      => open, -- unused
    chainin_vld  => open, -- unused
    chainout     => open, -- unused
    chainout_vld => open, -- unused
    PIPESTAGES   => open  -- unused
  );

  -- Operation:
  -- Re = ReChain + (-Xre - Xim) * Yim + Temp   (accumulation only when chain input unused)
  i_re : entity work.signed_preadd_mult1add1(dsp58)
  generic map(
    USE_ACCU           => (USE_ACCU and (n=(NUM_MULT-1))), -- accumulator enabled in last chain link only!
    NUM_SUMMAND        => 2*NUM_MULT,
    USE_XB_INPUT       => true,
    USE_NEGATION       => true,
    USE_XA_NEGATION    => USE_CONJUGATE_X,
    USE_XB_NEGATION    => false, -- unused
    NUM_INPUT_REG_X    => STAGE2_INPUT_REG_X,
    NUM_INPUT_REG_Y    => STAGE2_INPUT_REG_Y,
    NUM_INPUT_REG_Z    => n + 1,
    RELATION_CLR       => open, -- TODO
    RELATION_NEG       => open, -- TODO
    NUM_OUTPUT_REG     => OUTREGS(n),
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => (OUTPUT_ROUND and (n=(NUM_MULT-1))),
    OUTPUT_CLIP        => (OUTPUT_CLIP and (n=(NUM_MULT-1))),
    OUTPUT_OVERFLOW    => (OUTPUT_OVERFLOW and (n=(NUM_MULT-1)))
  )
  port map(
    clk          => clk,
    rst          => rst,
    clkena       => clkena,
    clr          => clr, -- accumulator enabled in last chain link only!
    neg          => (not neg_i(n)) xor y_conj_i(n),
    xa           => x_im(n),
    xa_vld       => x_vld(n),
    xa_neg       => x_conj_i(n),
    xb           => x_re(n),
    xb_vld       => x_vld(n),
    xb_neg       => open, -- unused
    y            => y_im(n),
    y_vld        => y_vld(n),
    z            => temp,
    z_vld        => temp_vld,
    result       => result_re_i(n),
    result_vld   => result_vld_i(n),
    result_ovf   => result_ovf_re_i(n),
    chainin      => chainin_re(n),
    chainin_vld  => chainin_re_vld(n),
    chainout     => chainin_re(n+1),
    chainout_vld => chainin_re_vld(n+1),
    PIPESTAGES   => pipestages_i(n)
  );

  -- Operation:
  -- Im = ImChain + ( Xim - Xre) * Yre + Temp   (accumulation only when chain input unused)
  i_im : entity work.signed_preadd_mult1add1(dsp58)
  generic map(
    USE_ACCU           => (USE_ACCU and (n=(NUM_MULT-1))), -- accumulator enabled in last chain link only!
    NUM_SUMMAND        => 2*NUM_MULT,
    USE_XB_INPUT       => true,
    USE_NEGATION       => USE_NEGATION,
    USE_XA_NEGATION    => true,
    USE_XB_NEGATION    => USE_CONJUGATE_X,
    NUM_INPUT_REG_X    => STAGE2_INPUT_REG_X,
    NUM_INPUT_REG_Y    => STAGE2_INPUT_REG_Y,
    NUM_INPUT_REG_Z    => n + 1,
    RELATION_CLR       => open, -- TODO
    RELATION_NEG       => open, -- TODO
    NUM_OUTPUT_REG     => OUTREGS(n),
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => (OUTPUT_ROUND and (n=(NUM_MULT-1))),
    OUTPUT_CLIP        => (OUTPUT_CLIP and (n=(NUM_MULT-1))),
    OUTPUT_OVERFLOW    => (OUTPUT_OVERFLOW and (n=(NUM_MULT-1)))
  )
  port map(
    clk          => clk,
    rst          => rst,
    clkena       => clkena,
    clr          => clr, -- accumulator enabled in last chain link only!
    neg          => neg_i(n),
    xa           => x_re(n),
    xa_vld       => x_vld(n),
    xa_neg       => '1',
    xb           => x_im(n),
    xb_vld       => x_vld(n),
    xb_neg       => x_conj_i(n),
    y            => y_re(n),
    y_vld        => y_vld(n),
    z            => temp,
    z_vld        => temp_vld,
    result       => result_im_i(n),
    result_vld   => open, -- same as real component
    result_ovf   => result_ovf_im_i(n),
    chainin      => chainin_im(n),
    chainin_vld  => chainin_im_vld(n),
    chainout     => chainin_im(n+1),
    chainout_vld => chainin_im_vld(n+1),
    PIPESTAGES   => open  -- same as real component
  );

  end generate CHAIN;
 end generate G3DSP;


 --------------------------------------------------------------------------------------------------
 -- Special Operation with 2 back-to-back DSP cells plus chain and Z input.
 --
 -- Notes
-- * last Z input in chain not supported, when accumulation is required !
-- * factor inputs X and Y are limited to 2x18 bits
 --------------------------------------------------------------------------------------------------
 G2DSP : if (OPTIMIZATION="RESOURCES" and MAX_INPUT_WIDTH<=18) or OPTIMIZATION="G2DSP" generate
  -- identifier for reports of warnings and errors
  constant CHOICE : string := INSTANCE_NAME & " (optimization=RESOURCES, 2N*DSP):: ";
 begin

  assert (NUM_INPUT_REG_X>=1 and NUM_INPUT_REG_Y>=1)
    report CHOICE & "For high-speed the X and Y paths should have at least one additional input register."
    severity warning;

  assert (MAX_INPUT_WIDTH<=18)
    report CHOICE & "Multiplier input X and Y width cannot exceed 18 bits."
    severity failure;

  CHAIN : for n in 0 to NUM_MULT-1 generate

  i_cmacc : entity work.complex_mult1add1(dsp58)
  generic map(
    USE_ACCU           => (USE_ACCU and (n=(NUM_MULT-1))),
    NUM_SUMMAND        => 2*NUM_MULT,
    USE_NEGATION       => USE_NEGATION,
    USE_CONJUGATE_X    => USE_CONJUGATE_X,
    USE_CONJUGATE_Y    => USE_CONJUGATE_Y,
    NUM_INPUT_REG_XY   => 1 + NUM_INPUT_REG_XY + n, -- minimum one input register
    NUM_INPUT_REG_Z    => 1 + NUM_INPUT_REG_Z  + n, -- minimum one input register
    RELATION_CLR       => open, -- TODO
    RELATION_NEG       => open, -- TODO
    NUM_OUTPUT_REG     => OUTREGS(n),
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => (OUTPUT_ROUND and (n=(NUM_MULT-1))),
    OUTPUT_CLIP        => (OUTPUT_CLIP and (n=(NUM_MULT-1))),
    OUTPUT_OVERFLOW    => (OUTPUT_OVERFLOW and (n=(NUM_MULT-1)))
  )
  port map(
    clk          => clk,
    rst          => rst,
    clkena       => clkena,
    clr          => clr,
    neg          => neg_i(n),
    x_re         => x_re(n),
    x_im         => x_im(n),
    x_vld        => x_vld(n),
    x_conj       => x_conj_i(n),
    y_re         => y_re(n),
    y_im         => y_im(n),
    y_vld        => y_vld(n),
    y_conj       => y_conj_i(n),
    z_re         => z_re(n),
    z_im         => z_im(n),
    z_vld        => z_vld(n),
    result_re    => result_re_i(n),
    result_im    => result_im_i(n),
    result_vld   => result_vld_i(n),
    result_ovf_re=> result_ovf_re_i(n),
    result_ovf_im=> result_ovf_im_i(n),
    chainin_re   => chainin_re(n),
    chainin_im   => chainin_im(n),
    chainin_vld  => chainin_re_vld(n),
    chainout_re  => chainin_re(n+1),
    chainout_im  => chainin_im(n+1),
    chainout_vld => chainin_re_vld(n+1),
    PIPESTAGES   => pipestages_i(n)
  );

  end generate CHAIN;
 end generate G2DSP;


  result_re <= result_re_i(NUM_MULT-1);
  result_im <= result_im_i(NUM_MULT-1);
  result_vld <= result_vld_i(NUM_MULT-1);
  result_ovf <= result_ovf_re_i(NUM_MULT-1) or result_ovf_im_i(NUM_MULT-1);
  PIPESTAGES <= pipestages_i(NUM_MULT-1);

end architecture;

