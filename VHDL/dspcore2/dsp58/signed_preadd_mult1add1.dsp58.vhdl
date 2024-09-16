-------------------------------------------------------------------------------
-- @file       signed_preadd_mult1add1.dsp58.vhdl
-- @author     Fixitfetish
-- @date       15/Sep/2024
-- @note       VHDL-2008
-- @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--             <https://opensource.org/licenses/MIT>
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

-- Implementation of signed_preadd_mult1add1 for AMD/Xilinx DSP58.
--
-- Refer to Xilinx Versal ACAP DSP Engine, Architecture Manual, AM004 (v1.2.1) September 11, 2022
--
architecture dsp58 of signed_preadd_mult1add1 is

  constant DSPREG : t_dspreg := GET_NUM_DSP_REG(
    use_d => USE_XB_INPUT,
    use_a_neg => USE_XA_NEGATION,
    aregs => NUM_INPUT_REG_X,
    bregs => NUM_INPUT_REG_Y,
    cregs => NUM_INPUT_REG_Z,
    dregs => NUM_INPUT_REG_X
  );

  -- This function calculates the number registers that are required to correctly
  -- align data and control signals at the input of the DSP cell.
  -- DSP internal delays are intentionally not compensated here.
  function GET_NUM_LOGIC_REG return t_logicreg is
    variable reg : t_logicreg;
  begin
    reg.A := NUM_INPUT_REG_X - DSPREG.A - DSPREG.M - DSPREG.AD;
    reg.B := NUM_INPUT_REG_Y - DSPREG.B - DSPREG.M;
    reg.C := NUM_INPUT_REG_Z - DSPREG.C;
    if USE_XB_INPUT then
      reg.D := NUM_INPUT_REG_X - DSPREG.D - DSPREG.M - DSPREG.AD;
    else
      reg.D := 0;
    end if;
    -- Reset signal delay compensation
    if    RELATION_RST="X"  then reg.RST := reg.A;
    elsif RELATION_RST="Y"  then reg.RST := reg.B;
    elsif RELATION_RST="Z"  then reg.RST := reg.C;
    else  reg.RST := 0; end if;
    -- Accu clear control signal delay compensation
    if    RELATION_CLR="X"  then reg.CLR := reg.A;
    elsif RELATION_CLR="XB" then reg.CLR := reg.D; -- currently not supported
    elsif RELATION_CLR="Y"  then reg.CLR := reg.B;
    elsif RELATION_CLR="Z"  then reg.CLR := reg.C;
    else  reg.CLR := 0; end if;
    -- Product negation control signal delay compensation
    if    RELATION_NEG="X" then reg.NEG := reg.A;
    elsif RELATION_NEG="Y" then reg.NEG := reg.B; -- currently not supported
      report signed_preadd_mult1add1'instance_name &
             "Relating the product negation signal to port Y is not yet supported. Use port X instead."
      severity failure;
    else  reg.NEG := 0; end if;
    return reg;
  end function;
  constant LOGICREG : t_logicreg := GET_NUM_LOGIC_REG;

  function RELATION_CLR_ABCD return string is
  begin
    if    RELATION_CLR="X"  then return "A";
    elsif RELATION_CLR="XB" then return "D"; -- currently not supported
    elsif RELATION_CLR="Y"  then return "B";
    elsif RELATION_CLR="Z"  then return "C";
    else  return "INVALID";
    end if;
  end function;

  -- number of overall summands that contribute to the DSP internal accumulation register P
  function NUM_SUMMAND return natural is
  begin
    if USE_XB_INPUT then
      return (NUM_SUMMAND_CHAININ + NUM_SUMMAND_Z + 2) * NUM_ACCU_CYCLES;
    else
      return (NUM_SUMMAND_CHAININ + NUM_SUMMAND_Z + 1) * NUM_ACCU_CYCLES;
    end if;
  end function;

  -- derived constants
  constant ROUND_ENABLE : boolean := OUTPUT_ROUND and (OUTPUT_SHIFT_RIGHT/=0);
  constant PRODUCT_WIDTH : natural := MAXIMUM(xa'length,xb'length) + y'length;
  constant MAX_GUARD_BITS : natural := ACCU_WIDTH - PRODUCT_WIDTH;
  constant GUARD_BITS_EVAL : natural := accu_guard_bits(NUM_SUMMAND,MAX_GUARD_BITS,"signed_preadd_mult1add1");
  constant ACCU_USED_WIDTH : natural := PRODUCT_WIDTH + GUARD_BITS_EVAL;
  constant ACCU_USED_SHIFTED_WIDTH : natural := ACCU_USED_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result'length;

  -- **Preadder when input XB is disabled:**
  --
  -- * Port XA(=A) negation can be done with new DSP58 product negation feature.
  --   Hence, preadder based input XA negation is not required.
  -- * Preadder output register AD can be used as fourth input XA pipeline register.
  constant ENABLE_PREADDER : boolean := USE_XB_INPUT or (NUM_INPUT_REG_X>=4);

  function AMULTSEL return string is begin 
    if ENABLE_PREADDER then return "AD"; else return "A"; end if;
  end function;

  -- INMODE control signal
  signal inmode : std_logic_vector(4 downto 0) := (others=>'0');
  signal negate_preadd : std_logic;
  signal negate_product : std_logic;
  signal negate : std_logic_vector(2 downto 0) := (others=>'0');

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
  signal dsp_d_vld : std_logic;
  signal dsp_a_neg : std_logic;
  signal dsp_d_neg : std_logic;

  signal a_i   : signed(xa'length-1 downto 0);
  signal dsp_b : signed( y'length-1 downto 0);
  signal dsp_c : signed( z'length-1 downto 0);
  signal d_i   : signed(xb'length-1 downto 0);

  signal dsp_a : signed(MAX_WIDTH_AD-1 downto 0);
  signal dsp_d : signed(MAX_WIDTH_AD-1 downto 0);

  signal p_change, p_round, pcout_vld : std_logic;

  signal chainin_i, chainout_i : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal accu : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal accu_vld : std_logic := '0';
  signal accu_rnd : std_logic := '0';
  signal accu_rst : std_logic := '0';
  signal accu_used : signed(ACCU_USED_WIDTH-1 downto 0);

  signal clr_i : std_logic := '0';

begin

  assert (DSPREG.M=1)
    report signed_preadd_mult1add1'instance_name &
           "DSP internal pipeline register after multiplier is disabled. FIX: use at least two input registers at ports XA, XB and Y."
    severity warning;

  assert (xa'length<=MAX_WIDTH_AD)
    report signed_preadd_mult1add1'instance_name &
           "Preadder and Multiplier input XA width cannot exceed " & integer'image(MAX_WIDTH_AD)
    severity failure;

  assert (y'length<=MAX_WIDTH_B)
    report signed_preadd_mult1add1'instance_name &
           "Multiplier input Y width cannot exceed " & integer'image(MAX_WIDTH_B)
    severity failure;

  assert (z'length<=MAX_WIDTH_C)
    report signed_preadd_mult1add1'instance_name &
           "Summand input Z width cannot exceed " & integer'image(MAX_WIDTH_C)
    severity failure;

  assert (xb'length<=MAX_WIDTH_AD)
    report signed_preadd_mult1add1'instance_name &
           "Preadder and Multiplier input XB width cannot exceed " & integer'image(MAX_WIDTH_AD)
    severity failure;

  assert (NUM_INPUT_REG_X=NUM_INPUT_REG_Y)
    report signed_preadd_mult1add1'instance_name &
           "For now the number of input registers in X and Y path must be the same."
    severity failure;

  assert GUARD_BITS_EVAL<=MAX_GUARD_BITS
    report signed_preadd_mult1add1'instance_name &
           "Maximum number of accumulator bits is " & integer'image(ACCU_WIDTH) & " ." &
           "Input bit widths allow only maximum number of guard bits = " & integer'image(MAX_GUARD_BITS)
    severity failure;

  assert OUTPUT_WIDTH<ACCU_USED_SHIFTED_WIDTH or not(OUTPUT_CLIP or OUTPUT_OVERFLOW)
    report signed_preadd_mult1add1'instance_name &
           "More guard bits required for saturation/clipping and/or overflow detection." &
           "  OUTPUT_WIDTH="            & integer'image(OUTPUT_WIDTH) &
           ", ACCU_USED_SHIFTED_WIDTH=" & integer'image(ACCU_USED_SHIFTED_WIDTH) &
           ", OUTPUT_CLIP="             & boolean'image(OUTPUT_CLIP) &
           ", OUTPUT_OVERFLOW="         & boolean'image(OUTPUT_OVERFLOW)
    severity failure;

  clr_i <= clr when NUM_ACCU_CYCLES>1 else '0';

  i_feed : entity work.xilinx_input_pipe
  generic map(
    PIPEREGS_RST     => LOGICREG.RST,
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
    src_neg   => neg,
    src_a_vld => xa_vld,
    src_b_vld => y_vld,
    src_c_vld => z_vld,
    src_d_vld => xb_vld,
    src_a_neg => xa_neg,
    src_d_neg => xb_neg,
    src_a     => xa,
    src_b     => y,
    src_c     => z,
    src_d     => xb,
    dsp_rst   => dsp_rst,
    dsp_clr   => dsp_clr,
    dsp_neg   => dsp_neg,
    dsp_a_vld => dsp_a_vld,
    dsp_b_vld => dsp_b_vld,
    dsp_c_vld => dsp_c_vld,
    dsp_d_vld => dsp_d_vld,
    dsp_a_neg => dsp_a_neg,
    dsp_d_neg => dsp_d_neg,
    dsp_a     => a_i,
    dsp_b     => dsp_b,
    dsp_c     => dsp_c,
    dsp_d     => d_i
  );

  i_neg : entity work.xilinx_negation_logic(dsp58)
  generic map(
    USE_D_INPUT    => USE_XB_INPUT,
    USE_NEGATION   => USE_NEGATION,
    USE_A_NEGATION => USE_XA_NEGATION,
    USE_D_NEGATION => USE_XB_NEGATION
  )
  port map(
    neg          => dsp_neg,
    neg_a        => dsp_a_neg,
    neg_d        => dsp_d_neg,
    a            => a_i,
    d            => d_i,
    neg_preadd   => negate_preadd,
    neg_product  => negate_product,
    dsp_a        => dsp_a,
    dsp_d        => dsp_d
  );

  i_mode : entity work.xilinx_mode_logic
  generic map(
    USE_ACCU     => (NUM_ACCU_CYCLES>1),
    USE_PREADDER => ENABLE_PREADDER,
    ENABLE_ROUND => ROUND_ENABLE,
    NUM_AREG     => DSPREG.A,
    NUM_BREG     => DSPREG.B,
    NUM_CREG     => DSPREG.C,
    NUM_DREG     => DSPREG.D,
    NUM_ADREG    => DSPREG.AD,
    NUM_MREG     => DSPREG.M,
    RELATION_CLR => RELATION_CLR_ABCD
  )
  port map(
    clk       => clk,
    rst       => dsp_rst,
    clkena    => clkena,
    clr       => dsp_clr,
    neg       => negate_product,
    a_neg     => negate_preadd,
    a_vld     => dsp_a_vld,
    b_vld     => dsp_b_vld,
    c_vld     => dsp_c_vld,
    d_vld     => dsp_d_vld,
    pcin_vld  => chainin_vld,
    inmode    => inmode,
    negate    => negate,
    opmode    => opmode,
    alumode   => alumode,
    p_change  => p_change,
    p_round   => p_round,
    pcout_vld => pcout_vld
  );

  -- use only LSBs of chain input
  chainin_i <= std_logic_vector(chainin(ACCU_WIDTH-1 downto 0));

  i_dsp : unisim.VCOMPONENTS.DSP58
  generic map(
    -- Feature Control Attributes: Data Path Selection
    AMULTSEL                  => AMULTSEL, -- "A" or "AD"
    A_INPUT                   => "DIRECT", -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
    BMULTSEL                  => "B", --Selects B input to multiplier (B,AD)
    B_INPUT                   => "DIRECT", -- Selects B input source,"DIRECT"(B port)or "CASCADE"(BCIN port)
    PREADDINSEL               => "A", -- Selects input to preadder (A, B)
    RND                       => RND(ROUND_ENABLE,OUTPUT_SHIFT_RIGHT), -- Rounding Constant
    USE_MULT                  => "MULTIPLY", -- Select multiplier usage (MULTIPLY,DYNAMIC,NONE)
    USE_SIMD                  => "ONE58", -- SIMD selection(ONE58, FOUR12, TWO24)
    USE_WIDEXOR               => "FALSE", -- Use the Wide XOR function (FALSE, TRUE)
    XORSIMD                   => "XOR24_34_58_116", -- Mode of operation for the Wide XOR (XOR24_34_58_116, XOR12)
    RESET_MODE                => "SYNC",
    DSP_MODE                  => "INT24",
    -- Pattern Detector Attributes: Pattern Detection Configuration
    AUTORESET_PATDET          => "NO_RESET", -- NO_RESET, RESET_MATCH, RESET_NOT_MATCH
    AUTORESET_PRIORITY        => "RESET", -- Priority of AUTORESET vs.CEP (RESET, CEP).
    MASK                      => (others=>'1'), -- 58-bit mask value for pattern detect (1=ignore)
    PATTERN                   => (others=>'0'), -- 58-bit pattern match for pattern detect
    SEL_MASK                  => "MASK", -- MASK, C, ROUNDING_MODE1, ROUNDING_MODE2
    SEL_PATTERN               => "PATTERN", -- Select pattern value (PATTERN, C)
    USE_PATTERN_DETECT        => "NO_PATDET", -- Enable pattern detect (NO_PATDET, PATDET)
    -- Programmable Inversion Attributes: Specifies built-in programmable inversion on specific pins
    IS_ASYNC_RST_INVERTED     => '0',
    IS_NEGATE_INVERTED        => "000",
    IS_ALUMODE_INVERTED       => "0000",
    IS_CARRYIN_INVERTED       => '0',
    IS_CLK_INVERTED           => '0',
    IS_INMODE_INVERTED        => "00010", -- high-active A/B gate ! (like the D gate)
    IS_OPMODE_INVERTED        => "000000000",
    IS_RSTALLCARRYIN_INVERTED => '0',
    IS_RSTALUMODE_INVERTED    => '0',
    IS_RSTA_INVERTED          => '0',
    IS_RSTB_INVERTED          => '0',
    IS_RSTCTRL_INVERTED       => '0',
    IS_RSTC_INVERTED          => '0',
    IS_RSTD_INVERTED          => '0',
    IS_RSTINMODE_INVERTED     => '0',
    IS_RSTM_INVERTED          => '0',
    IS_RSTP_INVERTED          => '0',
    -- Register Control Attributes: Pipeline Register Configuration
    ACASCREG                  => open, -- unused
    ADREG                     => DSPREG.AD,-- 0 or 1
    ALUMODEREG                => DSPREG.ALUMODE, -- 0 or 1
    AREG                      => DSPREG.A,-- 0,1 or 2
    BCASCREG                  => open, -- unused
    BREG                      => DSPREG.B,-- 0,1 or 2
    CARRYINREG                => open, -- unused
    CARRYINSELREG             => open, -- unused
    CREG                      => DSPREG.C, -- 0 or 1
    DREG                      => DSPREG.D,-- 0 or 1
    INMODEREG                 => DSPREG.INMODE, -- 0 or 1
    MREG                      => DSPREG.M, -- 0 or 1
    OPMODEREG                 => DSPREG.OPMODE, -- 0 or 1
    PREG                      => 1 -- 0 or 1
  ) 
  port map(
    -- Cascade: 30-bit (each) output: Cascade Ports
    ACOUT              => open,
    BCOUT              => open,
    CARRYCASCOUT       => open,
    MULTSIGNOUT        => open,
    PCOUT              => chainout_i,
    -- Control: 1-bit (each) output: Control Inputs/Status Bits
    OVERFLOW           => open,
    PATTERNBDETECT     => open,
    PATTERNDETECT      => open,
    UNDERFLOW          => open,
    -- Data: 4-bit (each) output: Data Ports
    CARRYOUT           => open,
    P                  => accu,
    XOROUT             => open,
    -- Cascade: 30-bit (each) input: Cascade Ports
    ACIN               => (others=>'0'), -- unused
    BCIN               => (others=>'0'), -- unused
    CARRYCASCIN        => '0', -- unused
    MULTSIGNIN         => '0', -- unused
    PCIN               => chainin_i,
    -- Control: 4-bit (each) input: Control Inputs/Status Bits
    ALUMODE            => alumode,
    CARRYINSEL         => "000", -- unused
    CLK                => clk,
    INMODE             => inmode,
    OPMODE             => opmode,
    NEGATE             => negate,
    -- Data: 30-bit (each) input: Data Ports
    A                  => std_logic_vector(resize(dsp_a,MAX_WIDTH_A)),
    B                  => std_logic_vector(resize(dsp_b,MAX_WIDTH_B)),
    C                  => std_logic_vector(resize(dsp_c,MAX_WIDTH_C)),
    CARRYIN            => '0', -- unused
    D                  => std_logic_vector(resize(dsp_d,MAX_WIDTH_D)),
    -- Clock Enable: 1-bit (each) input: Clock Enable Inputs
    CEA1               => CE(clkena,DSPREG.A),
    CEA2               => CE(clkena,DSPREG.A),
    CEAD               => CE(clkena,DSPREG.AD),
    CEALUMODE          => CE(clkena,DSPREG.ALUMODE),
    CEB1               => CE(clkena,DSPREG.B),
    CEB2               => CE(clkena,DSPREG.B),
    CEC                => CE(clkena,DSPREG.C),
    CECARRYIN          => '0', -- unused
    CECTRL             => CE(clkena,DSPREG.OPMODE),
    CED                => CE(clkena,DSPREG.D),
    CEINMODE           => CE(clkena,DSPREG.INMODE),
    CEM                => CE(clkena,DSPREG.M),
    CEP                => CE(clkena and p_change,1), -- accumulate/output only valid values
    -- Reset: 1-bit (each) input: Reset
    ASYNC_RST          => '0',
    RSTA               => dsp_rst,
    RSTALLCARRYIN      => '1', -- unused
    RSTALUMODE         => dsp_rst,
    RSTB               => dsp_rst,
    RSTC               => dsp_rst,
    RSTCTRL            => dsp_rst,
    RSTD               => dsp_rst,
    RSTINMODE          => dsp_rst,
    RSTM               => dsp_rst,
    RSTP               => dsp_rst 
  );

  chainout<= resize(signed(chainout_i),chainout'length);
  chainout_vld <= pcout_vld;

  -- pipelined output valid signal
  p_clk : process(clk)
  begin
    if rising_edge(clk) then
      if dsp_rst/='0' then
        accu_vld <= '0';
        accu_rnd <= '0';
      elsif clkena='1' then
        accu_vld <= pcout_vld;
        accu_rnd <= p_round;
      end if; --reset
      accu_rst <= dsp_rst;
    end if; --clock
  end process;

  -- cut off unused sign extension bits
  -- (This reduces the logic consumption in the following steps when rounding,
  --  saturation and/or overflow detection is enabled.)
  accu_used <= signed(accu(ACCU_USED_WIDTH-1 downto 0));

  -- Right-shift and clipping
  -- Rounding is also done here when not possible within DSP cell.
  i_out : entity work.xilinx_output_logic
  generic map(
    PIPELINE_STAGES    => NUM_OUTPUT_REG-1,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_CLIP        => OUTPUT_CLIP,
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
  )
  port map (
    clk         => clk,
    rst         => accu_rst,
    clkena      => clkena,
    dsp_out     => accu_used,
    dsp_out_vld => accu_vld,
    dsp_out_rnd => accu_rnd,
    result      => result,
    result_vld  => result_vld,
    result_rst  => result_rst,
    result_ovf  => result_ovf
  );

  -- report constant number of pipeline register stages
  PIPESTAGES <= NUM_INPUT_REG_X + NUM_OUTPUT_REG;

end architecture;
