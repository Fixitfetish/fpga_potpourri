-------------------------------------------------------------------------------
--! @file       complex_mult1add1.dsp58.vhdl
--! @author     Fixitfetish
--! @date       29/Dec/2021
--! @version    0.00-draft
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

use work.xilinx_dsp_pkg_dsp58.all;

--! @brief This is an implementation of the entity complex_mult1add1 for Xilinx Versal.
--! One complex multiplication is performed and results and an additional summand can be accumulated.
--!
--! @image html complex_mult1add1.dsp58.svg "" width=600px
--!
--! **OPTIMIZATION="PERFORMANCE"**
--! * This implementation requires four instances of the entity signed_preadd_mult1add1 with disabled preadder.
--! * This implementation requires four DSP58s.
--! * X input width is limited to 27 bits and Y input to 24 bits.
--! * Chaining is supported.
--! * Additional Z summand input is supported.
--! * Accumulation is not supported when chain and Z input are used.
--! * The number of overall pipeline stages is typically NUM_INPUT_REG_XY + 1 + NUM_OUTPUT_REG.
--!
--! **OPTIMIZATION="RESOURCES" with x and y input width <=24 bits**
--! * This implementation requires three instances of the entity signed_preadd_mult1add1 .
--! * This implementation requires three DSP58s.
--! * X and Y input width is limited to 24 bits.
--! * Chaining is supported.
--! * Additional Z summand input is NOT supported.
--! * Accumulation is not supported when chain input is used.
--! * The number of overall pipeline stages is typically NUM_INPUT_REG_XY + 2 + NUM_OUTPUT_REG.
--!
--! **OPTIMIZATION="RESOURCES" with x and y input width <=18 bits**
--! * This implementation requires one instance of the entity xilinx_complex_macc .
--! * This implementation requires two back-to-back DSP58s.
--! * X and Y input width is limited to 18 bits.
--! * Chaining is supported.
--! * Additional Z summand input is supported.
--! * Accumulation is not supported when chain and Z input are used.
--! * The number of overall pipeline stages is typically NUM_INPUT_REG_XY + NUM_OUTPUT_REG.
--!
architecture dsp58 of complex_mult1add1 is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "complex_mult1add1(dsp58)";

  constant X_INPUT_WIDTH   : positive := maximum(x_re'length,x_im'length);
  constant Y_INPUT_WIDTH   : positive := maximum(y_re'length,y_im'length);
  constant MAX_INPUT_WIDTH : positive := maximum(X_INPUT_WIDTH,Y_INPUT_WIDTH);

  signal neg_i, conj_x_i, conj_y_i : std_logic := '0';

begin

  assert (OPTIMIZATION="PERFORMANCE" or OPTIMIZATION="RESOURCES" or OPTIMIZATION="DSP3")
    report "ERROR " & IMPLEMENTATION & " :" &
           " Supported optimizations are : PERFORMANCE or RESOURCES"
    severity failure;

  neg_i    <= neg    when USE_NEGATION    else '0';
  conj_x_i <= conj_x when USE_CONJUGATE_X else '0';
  conj_y_i <= conj_y when USE_CONJUGATE_Y else '0';


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
  i_re1 : entity work.signed_preadd_mult1add1(dsp58)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND-1,
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    USE_Z_INPUT        => USE_Z_INPUT,
    USE_XB_INPUT       => false, -- unused
    USE_NEGATION       => USE_NEGATION,
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
  i_re2 : entity work.signed_preadd_mult1add1(dsp58)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND, -- two multiplications per complex multiplication
    USE_CHAIN_INPUT    => true,
    USE_Z_INPUT        => false, -- unused
    USE_XB_INPUT       => false, -- unused
    USE_NEGATION       => true,
    USE_XA_NEGATION    => USE_CONJUGATE_X,
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
  i_im1 : entity work.signed_preadd_mult1add1(dsp58)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND-1,
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    USE_Z_INPUT        => USE_Z_INPUT,
    USE_XB_INPUT       => false, -- unused
    USE_NEGATION       => USE_CONJUGATE_Y,
    USE_XA_NEGATION    => USE_NEGATION,
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
  i_im2 : entity work.signed_preadd_mult1add1(dsp58)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND, -- two multiplications per complex multiplication
    USE_CHAIN_INPUT    => true,
    USE_Z_INPUT        => false, -- unused
    USE_XB_INPUT       => false, -- unused
    USE_NEGATION       => USE_NEGATION,
    USE_XA_NEGATION    => USE_CONJUGATE_X,
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
 -- * factor inputs X and Y are limited to 2x24 bits
 --
 -- USE_CHAIN_INPUT=true
 -- * accumulation not possible because P feedback must be disabled
 -- * The rounding (i.e. +0.5) not possible within DSP.
 --   But rounding bit can be injected at the first chain link where USE_CHAIN_INPUT=false
 --------------------------------------------------------------------------------------------------
 G3DSP : if (OPTIMIZATION="RESOURCES" and MAX_INPUT_WIDTH>18) or OPTIMIZATION="DSP3" generate
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
  i_temp : entity work.signed_preadd_mult1add1(dsp58)
  generic map(
    NUM_SUMMAND        => 2,
    USE_CHAIN_INPUT    => false,
    USE_Z_INPUT        => false,
    USE_XB_INPUT       => true,
    USE_NEGATION       => USE_NEGATION,
    USE_XA_NEGATION    => USE_CONJUGATE_Y,
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
  i_re : entity work.signed_preadd_mult1add1(dsp58)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND,
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    USE_Z_INPUT        => true,
    USE_XB_INPUT       => true,
    USE_NEGATION       => true,
    USE_XA_NEGATION    => USE_CONJUGATE_X,
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
  i_im : entity work.signed_preadd_mult1add1(dsp58)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND,
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    USE_Z_INPUT        => true,
    USE_XB_INPUT       => true,
    USE_NEGATION       => USE_NEGATION,
    USE_XA_NEGATION    => true,
    USE_XB_NEGATION    => USE_CONJUGATE_X,
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


 --------------------------------------------------------------------------------------------------
 -- Special Operation with 2 back-to-back DSP cells plus chain and Z input.
 --
 -- Notes
 -- * factor inputs X and Y are limited to 2x18 bits
 --------------------------------------------------------------------------------------------------
 G2DSP : if (OPTIMIZATION="RESOURCES" and MAX_INPUT_WIDTH<=18) generate
  -- identifier for reports of warnings and errors
  constant CHOICE : string := IMPLEMENTATION & " with optimization=RESOURCES (2 DSP cells)";
  -- number main path input registers within DSP
  constant NUM_IREG_DSP : natural := NUM_IREG(DSP,NUM_INPUT_REG_XY);
  -- number main path input registers in LOGIC
  constant NUM_IREG_LOGIC : natural := NUM_IREG(LOGIC,NUM_INPUT_REG_XY);
  -- derived constants
  constant ROUND_ENABLE : boolean := OUTPUT_ROUND and (OUTPUT_SHIFT_RIGHT/=0);
  constant PRODUCT_WIDTH : natural := x_re'length + y_re'length + 1;
  constant MAX_GUARD_BITS : natural := ACCU_WIDTH - PRODUCT_WIDTH;
  constant GUARD_BITS_EVAL : natural := accu_guard_bits(NUM_SUMMAND,MAX_GUARD_BITS,CHOICE);
  constant ACCU_USED_WIDTH : natural := PRODUCT_WIDTH + GUARD_BITS_EVAL;
  constant ACCU_USED_SHIFTED_WIDTH : natural := ACCU_USED_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result_re'length;
  signal dsp_rst : std_logic;
  signal dsp_clr : std_logic;
  signal dsp_vld : std_logic;
  signal dsp_neg : std_logic;
  signal dsp_a_conj : std_logic;
  signal dsp_b_conj : std_logic;
  signal dsp_a_re : signed(x_re'length-1 downto 0);
  signal dsp_b_re : signed(y_re'length-1 downto 0);
  signal dsp_c_re : signed(z_re'length-1 downto 0);
  signal dsp_d_re : signed(1 downto 0); -- dummy
  signal dsp_a_im : signed(x_im'length-1 downto 0);
  signal dsp_b_im : signed(y_im'length-1 downto 0);
  signal dsp_c_im : signed(z_im'length-1 downto 0);
  signal dsp_d_im : signed(1 downto 0); -- dummy
  signal accu_re, accu_im : signed(ACCU_WIDTH-1 downto 0);
  signal accu_vld : std_logic := '0';
  signal accu_used_re, accu_used_im : signed(ACCU_USED_WIDTH-1 downto 0);
 begin

  assert GUARD_BITS_EVAL<=MAX_GUARD_BITS
    report "ERROR " & CHOICE & ": " &
           "Maximum number of accumulator bits is " & integer'image(ACCU_WIDTH) & " ." &
           "Input bit widths allow only maximum number of guard bits = " & integer'image(MAX_GUARD_BITS)
    severity failure;

  assert OUTPUT_WIDTH<ACCU_USED_SHIFTED_WIDTH or not(OUTPUT_CLIP or OUTPUT_OVERFLOW)
    report "ERROR " & CHOICE & ": " &
           "More guard bits required for saturation/clipping and/or overflow detection."
    severity failure;

  i_feed_re : entity work.xilinx_dsp_input_pipe
  generic map(
    PIPEREGS_RST     => NUM_IREG_LOGIC,
    PIPEREGS_CLR     => NUM_IREG_LOGIC,
    PIPEREGS_VLD     => NUM_IREG_LOGIC,
    PIPEREGS_NEG     => open,
    PIPEREGS_NEG_A   => NUM_IREG_LOGIC,
    PIPEREGS_NEG_D   => NUM_IREG_LOGIC,
    PIPEREGS_A       => NUM_IREG_LOGIC,
    PIPEREGS_B       => NUM_IREG_LOGIC,
    PIPEREGS_C       => NUM_IREG_C(LOGIC,NUM_INPUT_REG_Z),
    PIPEREGS_D       => 0  -- unused
  )
  port map(
    clk      => clk,
    srst     => open, -- unused
    clkena   => clkena,
    src_rst  => rst,
    src_clr  => clr,
    src_vld  => vld,
    src_neg  => open,
    src_neg_a=> conj_x_i,
    src_neg_d=> conj_y_i,
    src_a    => x_re,
    src_b    => y_re,
    src_c    => z_re,
    src_d    => "00",
    dsp_rst  => dsp_rst,
    dsp_clr  => dsp_clr,
    dsp_vld  => dsp_vld,
    dsp_neg  => open,
    dsp_neg_a=> dsp_a_conj,
    dsp_neg_d=> dsp_b_conj,
    dsp_a    => dsp_a_re,
    dsp_b    => dsp_b_re,
    dsp_c    => dsp_c_re,
    dsp_d    => dsp_d_re
  );

  i_feed_im : entity work.xilinx_dsp_input_pipe
  generic map(
    PIPEREGS_RST     => NUM_IREG_LOGIC,
    PIPEREGS_CLR     => NUM_IREG_LOGIC,
    PIPEREGS_VLD     => NUM_IREG_LOGIC,
    PIPEREGS_NEG     => NUM_IREG_LOGIC,
    PIPEREGS_NEG_A   => open,
    PIPEREGS_NEG_D   => open,
    PIPEREGS_A       => NUM_IREG_LOGIC,
    PIPEREGS_B       => NUM_IREG_LOGIC,
    PIPEREGS_C       => NUM_IREG_C(LOGIC,NUM_INPUT_REG_Z),
    PIPEREGS_D       => 0  -- unused
  )
  port map(
    clk      => clk,
    srst     => open, -- unused
    clkena   => clkena,
    src_rst  => rst,
    src_clr  => clr,
    src_vld  => vld,
    src_neg  => neg,
    src_neg_a=> open,
    src_neg_d=> open,
    src_a    => x_im,
    src_b    => y_im,
    src_c    => z_im,
    src_d    => "00",
    dsp_rst  => dsp_rst,
    dsp_clr  => dsp_clr,
    dsp_vld  => dsp_vld,
    dsp_neg  => dsp_neg,
    dsp_neg_a=> open,
    dsp_neg_d=> open,
    dsp_a    => dsp_a_im,
    dsp_b    => dsp_b_im,
    dsp_c    => dsp_c_im,
    dsp_d    => dsp_d_im
  );

  i_dsp : entity work.xilinx_complex_macc(dsp58)
  generic map(
    USE_CHAIN_INPUT  => USE_CHAIN_INPUT,
    USE_C_INPUT      => USE_Z_INPUT,
    NUM_INPUT_REG_A  => NUM_IREG_DSP,
    NUM_INPUT_REG_B  => NUM_IREG_DSP,
    NUM_INPUT_REG_C  => NUM_IREG_C(DSP,NUM_INPUT_REG_Z),
    RELATION_CLR     => "A",
    RELATION_VLD     => "A",
    RELATION_NEG     => "A",
    NUM_OUTPUT_REG   => 1,
    ROUND_ENABLE     => ROUND_ENABLE and not (USE_CHAIN_INPUT and USE_Z_INPUT),
    ROUND_BIT        => maximum(0,OUTPUT_SHIFT_RIGHT-1)
  )
  port map(
    clk         => clk,
    rst         => rst,
    clkena      => clkena,
    clr         => dsp_clr,
    vld         => dsp_vld,
    neg         => dsp_neg,
    a_conj      => dsp_a_conj,
    b_conj      => dsp_b_conj,
    a_re        => dsp_a_re,
    a_im        => dsp_a_im,
    b_re        => dsp_b_re,
    b_im        => dsp_b_im,
    c_re        => dsp_c_re,
    c_im        => dsp_c_im,
    p_re        => accu_re,
    p_im        => accu_im,
    p_vld       => accu_vld,
    p_ovf_re    => open, -- TODO
    p_ovf_im    => open, -- TODO
    chainin_re  => chainin_re,
    chainin_im  => chainin_im,
    chainout_re => chainout_re,
    chainout_im => chainout_im,
    PIPESTAGES  => open
);

  -- cut off unused sign extension bits
  -- (This reduces the logic consumption in the following steps when rounding,
  --  saturation and/or overflow detection is enabled.)
  accu_used_re <= signed(accu_re(ACCU_USED_WIDTH-1 downto 0));
  accu_used_im <= signed(accu_im(ACCU_USED_WIDTH-1 downto 0));

  -- Right-shift and clipping
  -- Enable rounding here when not possible within DSP cell.
  i_out_re : entity work.signed_output_logic
  generic map(
    PIPELINE_STAGES    => NUM_OUTPUT_REG-1,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => (ROUND_ENABLE and USE_CHAIN_INPUT and USE_Z_INPUT),
    OUTPUT_CLIP        => OUTPUT_CLIP,
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
  )
  port map (
    clk         => clk,
    rst         => rst,
    clkena      => clkena,
    dsp_out     => accu_used_re,
    dsp_out_vld => accu_vld,
    result      => result_re,
    result_vld  => result_vld,
    result_ovf  => result_ovf_re
  );

  i_out_im : entity work.signed_output_logic
  generic map(
    PIPELINE_STAGES    => NUM_OUTPUT_REG-1,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => (ROUND_ENABLE and USE_CHAIN_INPUT and USE_Z_INPUT),
    OUTPUT_CLIP        => OUTPUT_CLIP,
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
  )
  port map (
    clk         => clk,
    rst         => rst,
    clkena      => clkena,
    dsp_out     => accu_used_im,
    dsp_out_vld => accu_vld,
    result      => result_im,
    result_vld  => open, -- same as real
    result_ovf  => result_ovf_im
  );

  -- report constant number of pipeline register stages
  PIPESTAGES <= NUM_INPUT_REG_XY + NUM_OUTPUT_REG;
 end generate;

end architecture;
