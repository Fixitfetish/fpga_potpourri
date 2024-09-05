-------------------------------------------------------------------------------
--! @file       complex_mult1add1.dsp58.vhdl
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
  use baselib.ieee_extension.all;
library unisim;

use work.xilinx_dsp_pkg_dsp58.all;

-- Implementation of complex_mult1add1 for AMD/Xilinx DSP58.
--
-- Notes and Limitations
-- * Maximum A and B factor input width is 2x18 bits.
-- * DSP internal accumulation not supported when both summand inputs, chain and C, are enabled.
-- * DSP internal rounding bit addition not possible when both summand inputs, chain and C, are enabled.
-- * Product negation requires additional DSP external logic which is implemented at the input.
-- * Additional negation logic includes clipping of 18-bit input to most positive value when most negative value is negated.
--
-- Refer to Xilinx Versal ACAP DSP Engine, Architecture Manual, AM004 (v1.2.1) September 11, 2022
--
architecture dsp58 of complex_mult1add1 is

  constant INSTANCE_NAME : string := complex_mult1add1'INSTANCE_NAME;

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "complex_mult1add1(dsp58)";

  -- Max input width
  constant INPUT_WIDTH : positive := 18;

  -- TODO: later independent X and Y input registers ?
  constant NUM_INPUT_REG_X : positive := NUM_INPUT_REG_XY;
  constant NUM_INPUT_REG_Y : positive := NUM_INPUT_REG_XY;

  constant DSPREG : t_dspreg := GET_NUM_DSPCPLX_REG(
    aregs => NUM_INPUT_REG_X,
    bregs => NUM_INPUT_REG_Y,
    cregs => NUM_INPUT_REG_Z
  );

  -- number of additional pipeline register in logic in-front of DSP input.
  type t_logicreg is
  record
    A   : natural;
    B   : natural;
    C   : natural;
    D   : natural;
    CLR : natural;
    NEG : natural;
  end record;

  -- This function calculates the number registers that are required to correctly
  -- align data and control signals at the input of the DSP cell.
  -- DSP internal delays are intentionally not compensated here.
  function GET_NUM_LOGIC_REG return t_logicreg is
    variable reg : t_logicreg;
  begin
    reg.A := NUM_INPUT_REG_X - DSPREG.A - DSPREG.M;
    reg.B := NUM_INPUT_REG_Y - DSPREG.B - DSPREG.M;
    reg.C := NUM_INPUT_REG_Z - DSPREG.C;
    reg.D := 0; -- unused
    if    RELATION_CLR="X"  then reg.CLR := reg.A;
    elsif RELATION_CLR="Y"  then reg.CLR := reg.B;
    elsif RELATION_CLR="Z"  then reg.CLR := reg.C;
    else  reg.CLR := 0; end if;
    if    RELATION_NEG="X" then reg.NEG := reg.A;
    elsif RELATION_NEG="Y" then reg.NEG := reg.B;
    else  reg.NEG := 0; end if;
    return reg;
  end function;
  constant LOGICREG : t_logicreg := GET_NUM_LOGIC_REG;

  function RELATION_CLR_ABC return string is
  begin
    if    RELATION_CLR="X"  then return "A";
    elsif RELATION_CLR="Y"  then return "B";
    elsif RELATION_CLR="Z"  then return "C";
    else  return "INVALID";
    end if;
  end function;

  -- derived constants
  constant ROUND_ENABLE : boolean := OUTPUT_ROUND and (OUTPUT_SHIFT_RIGHT/=0);
  constant PRODUCT_WIDTH : natural := x_re'length + y_re'length + 1;
  constant MAX_GUARD_BITS : natural := ACCU_WIDTH - PRODUCT_WIDTH;
  constant GUARD_BITS_EVAL : natural := accu_guard_bits(NUM_SUMMAND,MAX_GUARD_BITS,IMPLEMENTATION);
  constant ACCU_USED_WIDTH : natural := PRODUCT_WIDTH + GUARD_BITS_EVAL;
  constant ACCU_USED_SHIFTED_WIDTH : natural := ACCU_USED_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result_re'length;


  -- OPMODE control signal
  signal opmode : std_logic_vector(8 downto 0);

  -- ALUMODE control signal
  signal alumode : std_logic_vector(3 downto 0);

  signal dsp_rst   : std_logic;
  signal dsp_clr   : std_logic;
  signal dsp_neg   : std_logic;
  signal dsp_a_vld : std_logic;
  signal dsp_b_vld : std_logic;
  signal dsp_c_vld : std_logic;
  signal dsp_a_conj : std_logic;
  signal dsp_b_conj : std_logic;
  signal a_conj : std_logic;
  signal b_conj : std_logic;

  signal a_re : signed(x_re'length-1 downto 0);
  signal b_re : signed(y_re'length-1 downto 0);
  signal dsp_a_re : signed(INPUT_WIDTH-1 downto 0);
  signal dsp_b_re : signed(INPUT_WIDTH-1 downto 0);
  signal dsp_c_re : signed(z_re'length-1 downto 0);
  signal dsp_a_im : signed(x_im'length-1 downto 0);
  signal dsp_b_im : signed(y_im'length-1 downto 0);
  signal dsp_c_im : signed(z_im'length-1 downto 0);

  signal dsp_d_re : signed(1 downto 0); -- dummy
  signal dsp_d_im : signed(1 downto 0); -- dummy

  signal p_change, p_round, pcout_vld : std_logic;

  signal chainin_re_i, chainout_re_i : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal chainin_im_i, chainout_im_i : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal dsp_ofl_re, dsp_ofl_im : std_logic;
  signal dsp_ufl_re, dsp_ufl_im : std_logic;

  signal accu_re, accu_im : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal accu_vld : std_logic := '0';
  signal accu_rnd : std_logic := '0';
  signal accu_used_re, accu_used_im : signed(ACCU_USED_WIDTH-1 downto 0);

  signal clr_i, neg_i, x_conj_i, y_conj_i : std_logic := '0';

begin

  clr_i    <= clr    when USE_ACCU        else '0';
  neg_i    <= neg    when USE_NEGATION    else '0';
  x_conj_i <= x_conj when USE_CONJUGATE_X else '0';
  y_conj_i <= y_conj when USE_CONJUGATE_Y else '0';


  assert (x_re'length<=INPUT_WIDTH and x_im'length<=INPUT_WIDTH)
    report IMPLEMENTATION & ": " & "Multiplier input X width cannot exceed " & integer'image(INPUT_WIDTH)
    severity failure;

  assert (y_re'length<=INPUT_WIDTH and y_im'length<=INPUT_WIDTH)
    report IMPLEMENTATION & ": " & "Multiplier input Y width cannot exceed " & integer'image(INPUT_WIDTH)
    severity failure;

  assert (z_re'length<=MAX_WIDTH_C and z_im'length<=MAX_WIDTH_C)
    report IMPLEMENTATION & ": " & "Summand input Z width cannot exceed " & integer'image(MAX_WIDTH_C)
    severity failure;

  assert (NUM_INPUT_REG_X=NUM_INPUT_REG_Y)
    report IMPLEMENTATION & ": " & 
           "For now the number of input registers in X and Y path must be the same."
    severity failure;

  assert GUARD_BITS_EVAL<=MAX_GUARD_BITS
    report IMPLEMENTATION & ": " &
           "Maximum number of accumulator bits is " & integer'image(ACCU_WIDTH) & " ." &
           "Input bit widths allow only maximum number of guard bits = " & integer'image(MAX_GUARD_BITS)
    severity failure;

  assert OUTPUT_WIDTH<ACCU_USED_SHIFTED_WIDTH or not(OUTPUT_CLIP or OUTPUT_OVERFLOW)
    report IMPLEMENTATION & ": " &
           "More guard bits required for saturation/clipping and/or overflow detection." &
           "  OUTPUT_WIDTH="            & integer'image(OUTPUT_WIDTH) &
           ", ACCU_USED_SHIFTED_WIDTH=" & integer'image(ACCU_USED_SHIFTED_WIDTH) &
           ", OUTPUT_CLIP="             & boolean'image(OUTPUT_CLIP) &
           ", OUTPUT_OVERFLOW="         & boolean'image(OUTPUT_OVERFLOW)
    severity failure;

  assert (DSPREG.M=1)
    report INSTANCE_NAME & ": DSP internal pipeline register after multiplier is disabled. FIX: use at least two input registers at ports X and Y."
    severity warning;

  i_feed_re : entity work.xilinx_input_pipe
  generic map(
    PIPEREGS_RST     => LOGICREG.A, -- TODO
    PIPEREGS_CLR     => LOGICREG.CLR,
    PIPEREGS_NEG     => LOGICREG.NEG,
    PIPEREGS_A       => LOGICREG.A,
    PIPEREGS_B       => LOGICREG.B,
    PIPEREGS_C       => LOGICREG.C,
    PIPEREGS_D       => LOGICREG.D
  )
  port map(
    clk       => clk,
    srst      => open, -- unused
    clkena    => clkena,
    src_rst   => rst,
    src_clr   => clr_i,
    src_neg   => neg_i,
    src_a_vld => x_vld,
    src_b_vld => y_vld,
    src_c_vld => z_vld,
    src_d_vld => open,
    src_a_neg => x_conj_i,
    src_d_neg => open,
    src_a     => x_re,
    src_b     => y_re,
    src_c     => z_re,
    src_d     => "00", -- unused
    dsp_rst   => dsp_rst,
    dsp_clr   => dsp_clr,
    dsp_neg   => dsp_neg,
    dsp_a_vld => dsp_a_vld,
    dsp_b_vld => dsp_b_vld,
    dsp_c_vld => dsp_c_vld,
    dsp_d_vld => open, -- unused
    dsp_a_neg => a_conj,
    dsp_d_neg => open,
    dsp_a     => a_re,
    dsp_b     => b_re,
    dsp_c     => dsp_c_re,
    dsp_d     => dsp_d_re
  );

  i_feed_im : entity work.xilinx_input_pipe
  generic map(
    PIPEREGS_RST     => LOGICREG.A, -- TODO
    PIPEREGS_CLR     => LOGICREG.CLR,
    PIPEREGS_NEG     => LOGICREG.NEG,
    PIPEREGS_A       => LOGICREG.A,
    PIPEREGS_B       => LOGICREG.B,
    PIPEREGS_C       => LOGICREG.C,
    PIPEREGS_D       => LOGICREG.D
  )
  port map(
    clk       => clk,
    srst      => open, -- unused
    clkena    => clkena,
    src_rst   => rst,
    src_clr   => clr_i,
    src_neg   => neg_i, -- TODO: better y_conj_i here? with separate delay!
    src_a_vld => x_vld,
    src_b_vld => y_vld,
    src_c_vld => z_vld,
    src_d_vld => open,
    src_a_neg => y_conj_i,
    src_d_neg => open,
    src_a     => x_im,
    src_b     => y_im,
    src_c     => z_im,
    src_d     => "00", -- unused
    dsp_rst   => open,
    dsp_clr   => open,
    dsp_neg   => open,
    dsp_a_vld => open,
    dsp_b_vld => open,
    dsp_c_vld => open,
    dsp_d_vld => open,
    dsp_a_neg => b_conj,
    dsp_d_neg => open,
    dsp_a     => dsp_a_im,
    dsp_b     => dsp_b_im,
    dsp_c     => dsp_c_im,
    dsp_d     => dsp_d_im
  );


  -- Negate port A because NEG and A_RE are synchronous.
  g_neg_a : if RELATION_NEG="X" generate
    constant re_max : signed(INPUT_WIDTH-1 downto 0) := to_signed(2**(INPUT_WIDTH-1)-1,INPUT_WIDTH);
    constant re_min : signed(INPUT_WIDTH-1 downto 0) := not re_max;
    signal re : signed(INPUT_WIDTH-1 downto 0);
  begin
    -- Includes clipping to most positive value when most negative value is negated.
    re <= resize(a_re,INPUT_WIDTH);
    dsp_a_re <= re_max when (a_re'length=INPUT_WIDTH and dsp_neg='1' and re=re_min) else -re when dsp_neg='1' else re;
    dsp_a_conj <= dsp_neg xor a_conj;
    -- pass through port B
    dsp_b_re <= resize(b_re,dsp_b_re'length);
    dsp_b_conj <= b_conj;
  end generate;

  -- Negate port B because NEG and B_RE are synchronous.
  g_neg_b : if RELATION_NEG="Y" generate
    constant re_max : signed(INPUT_WIDTH-1 downto 0) := to_signed(2**(INPUT_WIDTH-1)-1,INPUT_WIDTH);
    constant re_min : signed(INPUT_WIDTH-1 downto 0) := not re_max;
    signal re : signed(INPUT_WIDTH-1 downto 0);
  begin
    -- Includes clipping to most positive value when most negative value is negated.
    re <= resize(b_re,INPUT_WIDTH);
    dsp_b_re <= re_max when (b_re'length=INPUT_WIDTH and dsp_neg='1' and re=re_min) else -re when dsp_neg='1' else re;
    dsp_b_conj <= dsp_neg xor b_conj;
    -- pass through port A
    dsp_a_re <= resize(a_re,dsp_a_re'length);
    dsp_a_conj <= a_conj;
  end generate;

  i_mode : entity work.xilinx_mode_logic -- TODO : special for CPLX ?
  generic map(
    USE_ACCU     => USE_ACCU,
    USE_PREADDER => open, -- unused
    ENABLE_ROUND => ROUND_ENABLE,
    NUM_AREG     => DSPREG.A,
    NUM_BREG     => DSPREG.B,
    NUM_CREG     => DSPREG.C,
    NUM_DREG     => DSPREG.D, -- irrelevant
    NUM_ADREG    => 0, -- AD register does not contribute to input delay! (see AM004 v1.2.1, Table 22)
    NUM_MREG     => DSPREG.M,
    RELATION_CLR => RELATION_CLR_ABC
  )
  port map(
    clk       => clk,
    rst       => rst,
    clkena    => clkena,
    clr       => dsp_clr,
    neg       => open, -- unused
    a_neg     => open, -- unused
    a_vld     => dsp_a_vld,
    b_vld     => dsp_b_vld,
    c_vld     => dsp_c_vld,
    d_vld     => open, -- unused
    pcin_vld  => chainin_vld,
    negate    => open, -- unused
    inmode    => open, -- unused
    opmode    => opmode,
    alumode   => alumode,
    p_change  => p_change,
    p_round   => p_round,
    pcout_vld => pcout_vld
  );

  -- use only LSBs of chain input
  chainin_re_i <= std_logic_vector(chainin_re(ACCU_WIDTH-1 downto 0));
  chainin_im_i <= std_logic_vector(chainin_im(ACCU_WIDTH-1 downto 0));

  i_dspcplx : unisim.VCOMPONENTS.DSPCPLX
  generic map(
     ACASCREG_IM                  => 1, -- integer := 1;
     ACASCREG_RE                  => 1, -- integer := 1;
     ADREG                        => DSPREG.AD,
     ALUMODEREG_IM                => DSPREG.ALUMODE,
     ALUMODEREG_RE                => DSPREG.ALUMODE,
     AREG_IM                      => DSPREG.A, -- integer := 2;
     AREG_RE                      => DSPREG.A, -- integer := 2;
     AUTORESET_PATDET_IM          => "NO_RESET", -- string := "NO_RESET";
     AUTORESET_PATDET_RE          => "NO_RESET", -- string := "NO_RESET";
     AUTORESET_PRIORITY_IM        => "RESET", -- string := "RESET";
     AUTORESET_PRIORITY_RE        => "RESET", -- string := "RESET";
     A_INPUT_IM                   => "DIRECT", -- string := "DIRECT";
     A_INPUT_RE                   => "DIRECT", -- string := "DIRECT";
     BCASCREG_IM                  => 1, -- integer := 1;
     BCASCREG_RE                  => 1, -- integer := 1;
     BREG_IM                      => DSPREG.B, -- integer := 2;
     BREG_RE                      => DSPREG.B, -- integer := 2;
     B_INPUT_IM                   => "DIRECT", -- string := "DIRECT";
     B_INPUT_RE                   => "DIRECT", -- string := "DIRECT";
     CARRYINREG_IM                => 1, -- integer := 1;
     CARRYINREG_RE                => 1, -- integer := 1;
     CARRYINSELREG_IM             => 1, -- integer := 1;
     CARRYINSELREG_RE             => 1, -- integer := 1;
     CONJUGATEREG_A               => DSPREG.INMODE,
     CONJUGATEREG_B               => DSPREG.INMODE,
     CREG_IM                      => DSPREG.C, -- integer := 1;
     CREG_RE                      => DSPREG.C, -- integer := 1;
     IS_ALUMODE_IM_INVERTED       => (others=>'0'), -- std_logic_vector(3 downto 0) := "0000";
     IS_ALUMODE_RE_INVERTED       => (others=>'0'), -- std_logic_vector(3 downto 0) := "0000";
     IS_ASYNC_RST_INVERTED        => '0', -- bit := '0';
     IS_CARRYIN_IM_INVERTED       => '0', -- bit := '0';
     IS_CARRYIN_RE_INVERTED       => '0', -- bit := '0';
     IS_CLK_INVERTED              => '0', -- bit := '0';
     IS_CONJUGATE_A_INVERTED      => '0', -- bit := '0';
     IS_CONJUGATE_B_INVERTED      => '0', -- bit := '0';
     IS_OPMODE_IM_INVERTED        => (others=>'0'), -- std_logic_vector(8 downto 0) := "000000000";
     IS_OPMODE_RE_INVERTED        => (others=>'0'), -- std_logic_vector(8 downto 0) := "000000000";
     IS_RSTAD_INVERTED            => '0', -- bit := '0';
     IS_RSTALLCARRYIN_IM_INVERTED => '0', -- bit := '0';
     IS_RSTALLCARRYIN_RE_INVERTED => '0', -- bit := '0';
     IS_RSTALUMODE_IM_INVERTED    => '0', -- bit := '0';
     IS_RSTALUMODE_RE_INVERTED    => '0', -- bit := '0';
     IS_RSTA_IM_INVERTED          => '0', -- bit := '0';
     IS_RSTA_RE_INVERTED          => '0', -- bit := '0';
     IS_RSTB_IM_INVERTED          => '0', -- bit := '0';
     IS_RSTB_RE_INVERTED          => '0', -- bit := '0';
     IS_RSTCONJUGATE_A_INVERTED   => '0', -- bit := '0';
     IS_RSTCONJUGATE_B_INVERTED   => '0', -- bit := '0';
     IS_RSTCTRL_IM_INVERTED       => '0', -- bit := '0';
     IS_RSTCTRL_RE_INVERTED       => '0', -- bit := '0';
     IS_RSTC_IM_INVERTED          => '0', -- bit := '0';
     IS_RSTC_RE_INVERTED          => '0', -- bit := '0';
     IS_RSTM_IM_INVERTED          => '0', -- bit := '0';
     IS_RSTM_RE_INVERTED          => '0', -- bit := '0';
     IS_RSTP_IM_INVERTED          => '0', -- bit := '0';
     IS_RSTP_RE_INVERTED          => '0', -- bit := '0';
     MASK_IM                      => (others=>'0'), -- std_logic_vector(57 downto 0) := "00" & X"FFFFFFFFFFFFFF";
     MASK_RE                      => (others=>'0'), -- std_logic_vector(57 downto 0) := "00" & X"FFFFFFFFFFFFFF";
     MREG_IM                      => DSPREG.M,
     MREG_RE                      => DSPREG.M,
     OPMODEREG_IM                 => DSPREG.OPMODE,
     OPMODEREG_RE                 => DSPREG.OPMODE,
     PATTERN_IM                   => (others=>'0'), -- std_logic_vector(57 downto 0) := "00" & X"00000000000000";
     PATTERN_RE                   => (others=>'0'), -- std_logic_vector(57 downto 0) := "00" & X"00000000000000";
     PREG_IM                      => 1, -- always used
     PREG_RE                      => 1, -- always used
     RESET_MODE                   => "SYNC", -- string := "SYNC";
     RND_IM                       => RND(ROUND_ENABLE,OUTPUT_SHIFT_RIGHT), -- Rounding Constant
     RND_RE                       => RND(ROUND_ENABLE,OUTPUT_SHIFT_RIGHT), -- Rounding Constant
     SEL_MASK_IM                  => "MASK", -- string := "MASK";
     SEL_MASK_RE                  => "MASK", -- string := "MASK";
     SEL_PATTERN_IM               => "PATTERN", -- string := "PATTERN";
     SEL_PATTERN_RE               => "PATTERN", -- string := "PATTERN";
     USE_PATTERN_DETECT_IM        => "NO_PATDET", -- string := "NO_PATDET";
     USE_PATTERN_DETECT_RE        => "NO_PATDET"  -- string := "NO_PATDET"
  )
  port map(
     ACOUT_IM          => open, -- out std_logic_vector(17 downto 0);
     ACOUT_RE          => open, -- out std_logic_vector(17 downto 0);
     BCOUT_IM          => open, -- out std_logic_vector(17 downto 0);
     BCOUT_RE          => open, -- out std_logic_vector(17 downto 0);
     CARRYCASCOUT_IM   => open, -- out std_ulogic;
     CARRYCASCOUT_RE   => open, -- out std_ulogic;
     CARRYOUT_IM       => open, -- out std_ulogic;
     CARRYOUT_RE       => open, -- out std_ulogic;
     MULTSIGNOUT_IM    => open, -- out std_ulogic;
     MULTSIGNOUT_RE    => open, -- out std_ulogic;
     OVERFLOW_IM       => dsp_ofl_im, -- out std_ulogic;
     OVERFLOW_RE       => dsp_ofl_re, -- out std_ulogic;
     PATTERNBDETECT_IM => open, -- out std_ulogic;
     PATTERNBDETECT_RE => open, -- out std_ulogic;
     PATTERNDETECT_IM  => open, -- out std_ulogic;
     PATTERNDETECT_RE  => open, -- out std_ulogic;
     PCOUT_IM          => chainout_im_i, -- out std_logic_vector(57 downto 0);
     PCOUT_RE          => chainout_re_i, -- out std_logic_vector(57 downto 0);
     P_IM              => accu_im, -- out std_logic_vector(57 downto 0);
     P_RE              => accu_re, -- out std_logic_vector(57 downto 0);
     UNDERFLOW_IM      => dsp_ufl_im, -- out std_ulogic;
     UNDERFLOW_RE      => dsp_ufl_re, -- out std_ulogic;
     ACIN_IM           => (others=>'0'), -- unused;
     ACIN_RE           => (others=>'0'), -- unused;
     ALUMODE_IM        => alumode, -- in std_logic_vector(3 downto 0);
     ALUMODE_RE        => alumode, -- in std_logic_vector(3 downto 0);
     ASYNC_RST         => '0', -- unused
     A_IM              => std_logic_vector(resize(dsp_a_im,INPUT_WIDTH)),
     A_RE              => std_logic_vector(resize(dsp_a_re,INPUT_WIDTH)),
     BCIN_IM           => (others=>'0'), -- unused
     BCIN_RE           => (others=>'0'), -- unused
     B_IM              => std_logic_vector(resize(dsp_b_im,INPUT_WIDTH)),
     B_RE              => std_logic_vector(resize(dsp_b_re,INPUT_WIDTH)),
     CARRYCASCIN_IM    => '0', -- unused
     CARRYCASCIN_RE    => '0', -- unused
     CARRYINSEL_IM     => (others=>'0'), -- unused
     CARRYINSEL_RE     => (others=>'0'), -- unused
     CARRYIN_IM        => '0', -- unused
     CARRYIN_RE        => '0', -- unused
     CEA1_IM           => CE(clkena,DSPREG.A),
     CEA1_RE           => CE(clkena,DSPREG.A),
     CEA2_IM           => CE(clkena,DSPREG.A),
     CEA2_RE           => CE(clkena,DSPREG.A),
     CEAD              => CE(clkena,DSPREG.AD),
     CEALUMODE_IM      => CE(clkena,DSPREG.ALUMODE),
     CEALUMODE_RE      => CE(clkena,DSPREG.ALUMODE),
     CEB1_IM           => CE(clkena,DSPREG.B),
     CEB1_RE           => CE(clkena,DSPREG.B),
     CEB2_IM           => CE(clkena,DSPREG.B),
     CEB2_RE           => CE(clkena,DSPREG.B),
     CECARRYIN_IM      => '0', -- unused
     CECARRYIN_RE      => '0', -- unused
     CECONJUGATE_A     => CE(clkena,DSPREG.INMODE),
     CECONJUGATE_B     => CE(clkena,DSPREG.INMODE),
     CECTRL_IM         => CE(clkena,DSPREG.OPMODE),
     CECTRL_RE         => CE(clkena,DSPREG.OPMODE),
     CEC_IM            => CE(clkena,DSPREG.C),
     CEC_RE            => CE(clkena,DSPREG.C),
     CEM_IM            => CE(clkena,DSPREG.M),
     CEM_RE            => CE(clkena,DSPREG.M),
     CEP_IM            => CE(clkena and p_change,1), -- accumulate/output only valid values
     CEP_RE            => CE(clkena and p_change,1), -- accumulate/output only valid values
     CLK               => clk,
     CONJUGATE_A       => dsp_a_conj,
     CONJUGATE_B       => dsp_b_conj,
     C_IM              => std_logic_vector(resize(dsp_c_im,MAX_WIDTH_C)),
     C_RE              => std_logic_vector(resize(dsp_c_re,MAX_WIDTH_C)),
     MULTSIGNIN_IM     => '0', -- unused
     MULTSIGNIN_RE     => '0', -- unused
     OPMODE_IM         => opmode,
     OPMODE_RE         => opmode,
     PCIN_IM           => chainin_im_i, -- in std_logic_vector(57 downto 0);
     PCIN_RE           => chainin_re_i, -- in std_logic_vector(57 downto 0);
     RSTAD             => rst,
     RSTALLCARRYIN_IM  => '1', -- unused
     RSTALLCARRYIN_RE  => '1', -- unused
     RSTALUMODE_IM     => rst,
     RSTALUMODE_RE     => rst,
     RSTA_IM           => rst,
     RSTA_RE           => rst,
     RSTB_IM           => rst,
     RSTB_RE           => rst,
     RSTCONJUGATE_A    => rst,
     RSTCONJUGATE_B    => rst,
     RSTCTRL_IM        => rst,
     RSTCTRL_RE        => rst,
     RSTC_IM           => rst,
     RSTC_RE           => rst,
     RSTM_IM           => rst,
     RSTM_RE           => rst,
     RSTP_IM           => rst,
     RSTP_RE           => rst 
  );

  chainout_re<= resize(signed(chainout_re_i),chainout_re'length);
  chainout_im<= resize(signed(chainout_im_i),chainout_im'length);
  chainout_vld <= pcout_vld;

  -- pipelined output valid signal
  p_clk : process(clk)
  begin
    if rising_edge(clk) then
      if rst/='0' then
        accu_vld <= '0';
        accu_rnd <= '0';
      elsif clkena='1' then
        accu_vld <= pcout_vld;
        accu_rnd <= p_round;
      end if; --reset
    end if; --clock
  end process;

  -- cut off unused sign extension bits
  -- (This reduces the logic consumption in the following steps when rounding,
  --  saturation and/or overflow detection is enabled.)
  accu_used_re <= signed(accu_re(ACCU_USED_WIDTH-1 downto 0));
  accu_used_im <= signed(accu_im(ACCU_USED_WIDTH-1 downto 0));

  -- Right-shift and clipping
  -- Rounding is also done here when not possible within DSP cell.
  i_out_re : entity work.xilinx_output_logic
  generic map(
    PIPELINE_STAGES    => NUM_OUTPUT_REG-1,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_CLIP        => OUTPUT_CLIP,
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
  )
  port map (
    clk         => clk,
    rst         => rst,
    clkena      => clkena,
    dsp_out     => accu_used_re,
    dsp_out_vld => accu_vld,
    dsp_out_ovf => (dsp_ufl_re or dsp_ofl_re),
    dsp_out_rnd => accu_rnd,
    result      => result_re,
    result_vld  => result_vld,
    result_ovf  => result_ovf_re
  );

  -- Right-shift and clipping
  -- Rounding is also done here when not possible within DSP cell.
  i_out_im : entity work.xilinx_output_logic
  generic map(
    PIPELINE_STAGES    => NUM_OUTPUT_REG-1,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_CLIP        => OUTPUT_CLIP,
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
  )
  port map (
    clk         => clk,
    rst         => rst,
    clkena      => clkena,
    dsp_out     => accu_used_im,
    dsp_out_vld => accu_vld,
    dsp_out_ovf => (dsp_ufl_im or dsp_ofl_im),
    dsp_out_rnd => accu_rnd,
    result      => result_im,
    result_vld  => open, -- same as real
    result_ovf  => result_ovf_im
  );

  -- report constant number of pipeline register stages
  PIPESTAGES <= NUM_INPUT_REG_X + NUM_OUTPUT_REG; -- TODO ?

end architecture;
