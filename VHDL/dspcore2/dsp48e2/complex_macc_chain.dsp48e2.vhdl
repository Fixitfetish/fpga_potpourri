-------------------------------------------------------------------------------
--! @file       complex_macc_chain.dsp48e2.vhdl
--! @author     Fixitfetish
--! @date       29/Jan/2022
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
  use baselib.ieee_extension_types.all;

use work.xilinx_dsp_pkg_dsp48e2.all;

--! @brief N complex multiplications and sum of all product results.
--!
architecture dsp48e2 of complex_macc_chain is

--  function CHAIN_LINKS_PER_MACC return natural is begin
--    if OPTIMIZATION="PERFORMANCE" then return 2; else return 1; end if;
--  end function;
--
--  function OUTREGS(i:natural) return natural is begin
--    if i<(NUM_MULT-1) then return 1; else return NUM_OUTPUT_REG; end if;
--  end function;
--
--  signal result_re_i : signed_vector(0 to NUM_MULT-1)(result_re'length-1 downto 0);
--  signal result_im_i : signed_vector(0 to NUM_MULT-1)(result_im'length-1 downto 0);
--  signal result_vld_i : std_logic_vector(0 to NUM_MULT-1);
--  signal result_ovf_re_i : std_logic_vector(0 to NUM_MULT-1);
--  signal result_ovf_im_i : std_logic_vector(0 to NUM_MULT-1);
--  signal pipestages_i : integer_vector(0 to NUM_MULT-1);
--
--  signal chainin_re  : signed_vector(0 to NUM_MULT)(79 downto 0);
--  signal chainin_im  : signed_vector(0 to NUM_MULT)(79 downto 0);
--  signal chainin_vld : std_logic_vector(0 to NUM_MULT);
--
-- begin
--
--  -- dummy chain input
--  chainin_re(0) <= (others=>'0');
--  chainin_im(0) <= (others=>'0');
--  chainin_vld(0) <= '0';
--
--  -- Only the last DSP chain link requires ACCU, output registers, rounding, clipping and overflow detection.
--  -- All other DSP chain links do not output anything.
--  gn : for n in 0 to NUM_MULT-1 generate
--    signal clr_i : std_logic;
--  begin
--
--    clr_i <= clr when (USE_ACCU and (n=(NUM_MULT-1))) else '0';
--
--    i_cmacc : entity work.complex_macc(dsp48e2)
--    generic map(
--      OPTIMIZATION       => OPTIMIZATION,
--      USE_ACCU           => (USE_ACCU and (n=(NUM_MULT-1))),
--      NUM_SUMMAND        => NUM_MULT,
--      USE_NEGATION       => USE_NEGATION,
--      USE_CONJUGATE_X    => USE_CONJUGATE_X,
--      USE_CONJUGATE_Y    => USE_CONJUGATE_Y,
--      NUM_INPUT_REG_XY   => NUM_INPUT_REG_XY + n*CHAIN_LINKS_PER_MACC,
--      NUM_INPUT_REG_Z    => NUM_INPUT_REG_Z + n*CHAIN_LINKS_PER_MACC,
--      NUM_OUTPUT_REG     => OUTREGS(n),
--      OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
--      OUTPUT_ROUND       => (OUTPUT_ROUND and (n=(NUM_MULT-1))),
--      OUTPUT_CLIP        => (OUTPUT_CLIP and (n=(NUM_MULT-1))),
--      OUTPUT_OVERFLOW    => (OUTPUT_OVERFLOW and (n=(NUM_MULT-1)))
--    )
--    port map(
--      clk           => clk,
--      rst           => rst,
--      clkena        => clkena,
--      clr           => clr_i,
--      vld           => vld,
--      neg           => neg(n),
--      x_re          => x_re(n),
--      x_im          => x_im(n),
--      x_conj        => x_conj(n),
--      y_re          => y_re(n),
--      y_im          => y_im(n),
--      y_conj        => y_conj(n),
--      z_re          => z_re(n),
--      z_im          => z_im(n),
--      z_vld         => z_vld(n),
--      result_re     => result_re_i(n),
--      result_im     => result_im_i(n),
--      result_vld    => result_vld_i(n),
--      result_ovf_re => result_ovf_re_i(n),
--      result_ovf_im => result_ovf_im_i(n),
--      chainin_re    => chainin_re(n),
--      chainin_im    => chainin_im(n),
--      chainin_vld   => chainin_vld(n),
--      chainout_re   => chainin_re(n+1),
--      chainout_im   => chainin_im(n+1),
--      chainout_vld  => chainin_vld(n+1),
--      PIPESTAGES    => pipestages_i(n)
--    );
--  end generate;
--
--  result_re <= result_re_i(NUM_MULT-1);
--  result_im <= result_im_i(NUM_MULT-1);
--  result_vld <= result_vld_i(NUM_MULT-1);
--  result_ovf <= result_ovf_re_i(NUM_MULT-1) or result_ovf_im_i(NUM_MULT-1);
--  PIPESTAGES <= pipestages_i(NUM_MULT-1);
--
--end architecture;
--
-----------------------------------------------------------------------------------------------------
--library ieee;
--  use ieee.std_logic_1164.all;
--  use ieee.numeric_std.all;
--library baselib;
--  use baselib.ieee_extension_types.all;
--
--use work.xilinx_dsp_pkg_dsp48e2.all;
--
--
--architecture test of complex_macc_chain is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "complex_macc_chain(dsp48e2)";

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
  signal x_vld, y_vld : std_logic := '0';

  signal chainin_re  : signed_vector(0 to NUM_MULT)(79 downto 0);
  signal chainin_im  : signed_vector(0 to NUM_MULT)(79 downto 0);
  signal chainin_re_vld : std_logic_vector(0 to NUM_MULT);
  signal chainin_im_vld : std_logic_vector(0 to NUM_MULT);

 begin

  -- For now it's assumed that Y is always valid when X is valid.
  -- TODO : Further interface flexibility reasonable and possible here ?
  x_vld <= vld;
  y_vld <= vld;

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
  constant CHOICE : string := IMPLEMENTATION & " with optimization=PERFORMANCE";

  begin

  assert (X_INPUT_WIDTH<=MAX_WIDTH_AD)
    report "ERROR " & CHOICE & ": " & "Multiplier input X width cannot exceed " & integer'image(MAX_WIDTH_AD)
    severity failure;

  assert (Y_INPUT_WIDTH<=MAX_WIDTH_B)
    report "ERROR " & CHOICE & ": " & "Multiplier input Y width cannot exceed " & integer'image(MAX_WIDTH_B) & ". Maybe swap X and Y inputs ?"
    severity failure;

  CHAIN : for n in 0 to NUM_MULT-1 generate
  signal chain_re , chain_im: signed(79 downto 0);
  signal chain_re_vld, chain_im_vld : std_logic;
  signal dummy_re, dummy_im : signed(ACCU_WIDTH-1 downto 0);
  signal clr_i : std_logic;
  begin

  clr_i <= clr when (USE_ACCU and (n=(NUM_MULT-1))) else '0';

  -- Operation:  Re1 = ReChain + Xre*Yre + Zre
  i_re1 : entity work.signed_preadd_mult1add1(dsp48e2)
  generic map(
    USE_ACCU           => false,
    NUM_SUMMAND        => 2*NUM_MULT-1,
    USE_XB_INPUT       => false, -- unused
    USE_NEGATION       => USE_NEGATION,
    USE_XA_NEGATION    => open, -- unused
    USE_XB_NEGATION    => open, -- unused
    NUM_INPUT_REG_X    => NUM_INPUT_REG_X + 2*n,
    NUM_INPUT_REG_Y    => NUM_INPUT_REG_Y + 2*n,
    NUM_INPUT_REG_Z    => NUM_INPUT_REG_Z + 2*n,
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
    neg          => neg_i(n),
    xa           => x_re(n),
    xa_vld       => vld,
    xa_neg       => open, -- unused
    xb           => "00", -- unused
    xb_vld       => open, -- unused
    xb_neg       => open, -- unused
    y            => y_re(n),
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
  i_re2 : entity work.signed_preadd_mult1add1(dsp48e2)
  generic map(
    USE_ACCU           => (USE_ACCU and (n=(NUM_MULT-1))),
    NUM_SUMMAND        => 2*NUM_MULT, -- two multiplications per complex multiplication
    USE_XB_INPUT       => false, -- unused
    USE_NEGATION       => true,
    USE_XA_NEGATION    => USE_CONJUGATE_X,
    USE_XB_NEGATION    => open, -- unused
    NUM_INPUT_REG_X    => NUM_INPUT_REG_X + 2*n + 1, -- additional pipeline register(s) because of chaining
    NUM_INPUT_REG_Y    => NUM_INPUT_REG_Y + 2*n + 1, -- additional pipeline register(s) because of chaining
    NUM_INPUT_REG_Z    => open, -- unused
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
    clr          => clr_i, -- accumulator enabled in last instance only!
    neg          => (not neg_i(n)) xor y_conj_i(n),
    xa           => x_im(n),
    xa_vld       => vld,
    xa_neg       => x_conj_i(n),
    xb           => "00", -- unused
    xb_vld       => open, -- unused
    xb_neg       => open, -- unused
    y            => y_im(n),
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
  i_im1 : entity work.signed_preadd_mult1add1(dsp48e2)
  generic map(
    USE_ACCU           => false,
    NUM_SUMMAND        => 2*NUM_MULT-1,
    USE_XB_INPUT       => false, -- unused
    USE_NEGATION       => USE_CONJUGATE_Y,
    USE_XA_NEGATION    => USE_NEGATION,
    USE_XB_NEGATION    => open, -- unused
    NUM_INPUT_REG_X    => NUM_INPUT_REG_X + 2*n,
    NUM_INPUT_REG_Y    => NUM_INPUT_REG_Y + 2*n,
    NUM_INPUT_REG_Z    => NUM_INPUT_REG_Z + 2*n,
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
    xa_vld       => vld,
    xa_neg       => neg_i(n),
    xb           => "00", -- unused
    xb_vld       => open, -- unused
    xb_neg       => open, -- unused
    y            => y_im(n),
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
  i_im2 : entity work.signed_preadd_mult1add1(dsp48e2)
  generic map(
    USE_ACCU           => (USE_ACCU and (n=(NUM_MULT-1))),
    NUM_SUMMAND        => 2*NUM_MULT, -- two multiplications per complex multiplication
    USE_XB_INPUT       => false, -- unused
    USE_NEGATION       => USE_NEGATION,
    USE_XA_NEGATION    => USE_CONJUGATE_X,
    USE_XB_NEGATION    => open, -- unused
    NUM_INPUT_REG_X    => NUM_INPUT_REG_X + 2*n + 1, -- additional pipeline register(s) because of chaining
    NUM_INPUT_REG_Y    => NUM_INPUT_REG_Y + 2*n + 1, -- additional pipeline register(s) because of chaining
    NUM_INPUT_REG_Z    => open, -- unused
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
    clr          => clr_i, -- accumulator enabled in last instance only!
    neg          => neg_i(n),
    xa           => x_im(n),
    xa_vld       => vld,
    xa_neg       => x_conj_i(n),
    xb           => "00", -- unused
    xb_vld       => open, -- unused
    xb_neg       => open, -- unused
    y            => y_re(n),
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
 -- *  Re   = ReChain + (-Xre - Xim) * Yim + Temp
 -- *  Im   = ImChain + ( Xim - Xre) * Yre + Temp
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
  constant CHOICE : string := IMPLEMENTATION & " with optimization=RESOURCES (3 DSP cells)";

 begin

  assert (MAX_INPUT_WIDTH<=MAX_WIDTH_B)
    report "ERROR " & CHOICE & ": " & "Multiplier input X and Y width cannot exceed " & integer'image(MAX_WIDTH_B)
    severity failure;

  assert (z_vld=(0 to NUM_MULT-1=>'0'))
    report "ERROR " & CHOICE & " :" &
           " Z input not supported with selected optimization."
    severity failure;

  assert (NUM_MULT=1 or not USE_ACCU)
    report "NOTE " & CHOICE & " :" &
           " Selected optimization with NUM_MULT>=2 does not allow accumulation. Ignoring CLR input port."
    severity WARNING;

  CHAIN : for n in 0 to NUM_MULT-1 generate
    constant TEMP_WIDTH : positive := x_re(0)'length + y_re(0)'length + 1;
    signal temp : signed(TEMP_WIDTH-1 downto 0);
    signal temp_vld : std_logic;
    signal clr_i : std_logic;
  begin

  clr_i <= clr when (USE_ACCU and NUM_MULT=1) else '0';

  -- Operation:
  -- Temp = ( Yre + Yim) * Xre  ... raw with full resolution
  i_temp : entity work.signed_preadd_mult1add1(dsp48e2)
  generic map(
    USE_ACCU           => false,
    NUM_SUMMAND        => 2,
    USE_XB_INPUT       => true,
    USE_NEGATION       => USE_NEGATION,
    USE_XA_NEGATION    => USE_CONJUGATE_Y,
    USE_XB_NEGATION    => false, -- unused
    NUM_INPUT_REG_X    => NUM_INPUT_REG_X,
    NUM_INPUT_REG_Y    => NUM_INPUT_REG_Y,
    NUM_INPUT_REG_Z    => open, -- unused
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
    clr          => '0',
    neg          => neg_i(n),
    xa           => y_im(n), -- first factor
    xa_vld       => y_vld,
    xa_neg       => y_conj_i(n),
    xb           => y_re(n), -- first factor
    xb_vld       => y_vld,
    xb_neg       => open, -- unused
    y            => x_re(n), -- second factor
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
  i_re : entity work.signed_preadd_mult1add1(dsp48e2)
  generic map(
    USE_ACCU           => (USE_ACCU and (n=(NUM_MULT-1))),
    NUM_SUMMAND        => 2*NUM_MULT,
    USE_XB_INPUT       => true,
    USE_NEGATION       => true,
    USE_XA_NEGATION    => USE_CONJUGATE_X,
    USE_XB_NEGATION    => false, -- unused
    NUM_INPUT_REG_X    => NUM_INPUT_REG_X + n + 2, -- 2 more pipeline stages to compensate Z input
    NUM_INPUT_REG_Y    => NUM_INPUT_REG_Y + n + 2, -- 2 more pipeline stages to compensate Z input
    NUM_INPUT_REG_Z    => n + 1,
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
    clr          => clr_i,
    neg          => (not neg_i(n)) xor y_conj_i(n),
    xa           => x_im(n),
    xa_vld       => x_vld,
    xa_neg       => x_conj_i(n),
    xb           => x_re(n),
    xb_vld       => x_vld,
    xb_neg       => open, -- unused
    y            => y_im(n),
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
  i_im : entity work.signed_preadd_mult1add1(dsp48e2)
  generic map(
    USE_ACCU           => (USE_ACCU and (n=(NUM_MULT-1))),
    NUM_SUMMAND        => 2*NUM_MULT,
    USE_XB_INPUT       => true,
    USE_NEGATION       => USE_NEGATION,
    USE_XA_NEGATION    => true,
    USE_XB_NEGATION    => USE_CONJUGATE_X,
    NUM_INPUT_REG_X    => NUM_INPUT_REG_X + n + 2, -- 2 more pipeline stages to compensate Z input
    NUM_INPUT_REG_Y    => NUM_INPUT_REG_Y + n + 2, -- 2 more pipeline stages to compensate Z input
    NUM_INPUT_REG_Z    => n + 1,
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
    clr          => clr_i,
    neg          => neg_i(n),
    xa           => x_re(n),
    xa_vld       => x_vld,
    xa_neg       => '1',
    xb           => x_im(n),
    xb_vld       => x_vld,
    xb_neg       => x_conj_i(n),
    y            => y_re(n),
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

  result_re <= result_re_i(NUM_MULT-1);
  result_im <= result_im_i(NUM_MULT-1);
  result_vld <= result_vld_i(NUM_MULT-1);
  result_ovf <= result_ovf_re_i(NUM_MULT-1) or result_ovf_im_i(NUM_MULT-1);
  PIPESTAGES <= pipestages_i(NUM_MULT-1);

end architecture;

---------------------------------------------------------------------------------------------------

--architecture test_old of complex_macc_chain is
--
--  type r_din is
--  record
--    neg : std_logic_vector(0 to 2*NUM_MULT-1);
--    xa_vld : std_logic_vector(0 to 2*NUM_MULT-1);
--    xa_neg : std_logic_vector(0 to 2*NUM_MULT-1);
--    xb_vld : std_logic_vector(0 to 2*NUM_MULT-1);
--    xb_neg : std_logic_vector(0 to 2*NUM_MULT-1);
--    z_vld  : std_logic_vector(0 to 2*NUM_MULT-1);
--    xa : signed_vector(0 to 2*NUM_MULT-1)(x_re(0)'range);
--    xb : signed_vector(0 to 2*NUM_MULT-1)(x_re(0)'range);
--    y  : signed_vector(0 to 2*NUM_MULT-1)(y_re(0)'range);
--    z  : signed_vector(0 to 2*NUM_MULT-1)(z_re(0)'range);
--  end record;
--  signal re_din, im_din : r_din;
--
--begin
--
-- G4DSP : if OPTIMIZATION="PERFORMANCE" generate
--
--  g : for n in 0 to NUM_MULT-1 generate
--    -- even                                                   -- odd
--    re_din.neg(2*n)      <= neg(n);                           re_din.neg(2*n+1)    <= not neg(n); -- TODO conj                     
--    re_din.xa_vld(2*n)   <= vld;                              re_din.xa_vld(2*n+1) <= vld; -- TODO                                 
--    re_din.xa_neg(2*n)   <= '0';                              re_din.xa_neg(2*n+1) <= '0'; -- TODD conj                           
--    re_din.xb_vld(2*n)   <= '0';                              re_din.xb_vld(2*n+1) <= '0';  -- TODO xb                              
--    re_din.xb_neg(2*n)   <= '0';                              re_din.xb_neg(2*n+1) <= '0';  -- TODO xb                             
--    re_din.z_vld(2*n)    <= z_vld(n);                         re_din.z_vld(2*n+1)  <= '0'; -- unused                               
--    re_din.xa(2*n)       <= x_re(n);                          re_din.xa(2*n+1)     <= x_im(n);                                     
--    re_din.xb(2*n)       <= to_signed(0,x_re(0)'length);      re_din.xb(2*n+1)     <= to_signed(0,x_re(0)'length); -- TODO xb      
--    re_din.y(2*n)        <= y_re(n);                          re_din.y(2*n+1)      <= y_im(n);                                     
--    re_din.z(2*n)        <= z_re(n);                          re_din.z(2*n+1)      <= to_signed(0,re_din.z(0)'length); -- unused;  
--
--    im_din.neg(2*n)      <= neg(n);                           im_din.neg(2*n+1)    <= neg(n);
--    im_din.xa_vld(2*n)   <= vld;                              im_din.xa_vld(2*n+1) <= vld; -- TODO                                 
--    im_din.xa_neg(2*n)   <= '0';                              im_din.xa_neg(2*n+1) <= '0'; -- TODD conj                           
--    im_din.xb_vld(2*n)   <= '0';                              im_din.xb_vld(2*n+1) <= '0';  -- TODO xb                              
--    im_din.xb_neg(2*n)   <= '0';                              im_din.xb_neg(2*n+1) <= '0';  -- TODO xb                             
--    im_din.z_vld(2*n)    <= z_vld(n);                         im_din.z_vld(2*n+1)  <= '0'; -- unused                               
--    im_din.xa(2*n)       <= x_re(n);                          im_din.xa(2*n+1)     <= x_im(n);                                     
--    im_din.xb(2*n)       <= to_signed(0,x_re(0)'length);      im_din.xb(2*n+1)     <= to_signed(0,x_re(0)'length); -- TODO xb      
--    im_din.y(2*n)        <= y_im(n);                          im_din.y(2*n+1)      <= y_re(n);                                     
--    im_din.z(2*n)        <= z_im(n);                          im_din.z(2*n+1)      <= to_signed(0,re_din.z(0)'length); -- unused;  
--  end generate;
--
--  i_re : entity work.signed_preadd_multadd_chain
--  generic map(
--    USE_ACCU           => USE_ACCU,
--    NUM_MULT           => 2*NUM_MULT,
--    NUM_SUMMAND        => 2*NUM_MULT-1,
--    USE_XB_INPUT       => false, -- unused
--    USE_NEGATION       => USE_NEGATION,
--    USE_XA_NEGATION    => open, -- unused
--    USE_XB_NEGATION    => open, -- unused
--    NUM_INPUT_REG_X    => NUM_INPUT_REG_XY,
--    NUM_INPUT_REG_Y    => NUM_INPUT_REG_XY,
--    NUM_INPUT_REG_Z    => NUM_INPUT_REG_Z,
--    NUM_OUTPUT_REG     => NUM_OUTPUT_REG,
--    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
--    OUTPUT_ROUND       => OUTPUT_ROUND,
--    OUTPUT_CLIP        => OUTPUT_CLIP,
--    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
--  )
--  port map (
--    clk          => clk,
--    rst          => rst,
--    clkena       => clkena,
--    clr          => open,
--    neg          => re_din.neg,
--    xa           => re_din.xa,
--    xa_vld       => re_din.xa_vld,
--    xa_neg       => re_din.xa_neg,
--    xb           => re_din.xb,
--    xb_vld       => re_din.xb_vld,
--    xb_neg       => re_din.xb_neg,
--    y            => re_din.y,
--    z            => re_din.z,
--    z_vld        => re_din.z_vld,
--    result       => result_re,
--    result_vld   => open,
--    result_ovf   => open,
--    chainout     => open,
--    chainout_vld => open,
--    PIPESTAGES   => PIPESTAGES
--  );
--
--  i_im : entity work.signed_preadd_multadd_chain
--  generic map(
--    USE_ACCU           => USE_ACCU,
--    NUM_MULT           => 2*NUM_MULT,
--    NUM_SUMMAND        => 2*NUM_MULT-1,
--    USE_XB_INPUT       => false, -- unused
--    USE_NEGATION       => USE_NEGATION,
--    USE_XA_NEGATION    => open, -- unused
--    USE_XB_NEGATION    => open, -- unused
--    NUM_INPUT_REG_X    => NUM_INPUT_REG_XY,
--    NUM_INPUT_REG_Y    => NUM_INPUT_REG_XY,
--    NUM_INPUT_REG_Z    => NUM_INPUT_REG_Z,
--    NUM_OUTPUT_REG     => NUM_OUTPUT_REG,
--    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
--    OUTPUT_ROUND       => OUTPUT_ROUND,
--    OUTPUT_CLIP        => OUTPUT_CLIP,
--    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
--  )
--  port map (
--    clk          => clk,
--    rst          => rst,
--    clkena       => clkena,
--    clr          => open,
--    neg          => im_din.neg,
--    xa           => im_din.xa,
--    xa_vld       => im_din.xa_vld,
--    xa_neg       => im_din.xa_neg,
--    xb           => im_din.xb,
--    xb_vld       => im_din.xb_vld,
--    xb_neg       => im_din.xb_neg,
--    y            => im_din.y,
--    z            => im_din.z,
--    z_vld        => im_din.z_vld,
--    result       => result_im,
--    result_vld   => open,
--    result_ovf   => open,
--    chainout     => open,
--    chainout_vld => open,
--    PIPESTAGES   => open  -- unused, same as real component
--  );
--
-- end generate G4DSP;
--
--end architecture;
