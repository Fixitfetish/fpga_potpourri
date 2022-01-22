-------------------------------------------------------------------------------
--! @file       xilinx_preadd_macc.dsp58.vhdl
--! @author     Fixitfetish
--! @date       01/Jan/2022
--! @version    0.10
--! @note       VHDL-1993
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
library unisim;

use work.xilinx_dsp_pkg_dsp58.all;

--! @brief Implementation of xilinx_preadd_macc for Xilinx DSP58.
--!
--! Refer to Xilinx Versal ACAP DSP Engine, Architecture Manual, AM004 (v1.1.2) July 15, 2021
--!
architecture dsp58 of xilinx_preadd_macc is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "xilinx_preadd_macc(dsp58)";

  --! rounding bit generation (+0.5)
  function gRND return std_logic_vector is
    variable res : std_logic_vector(ACCU_WIDTH-1 downto 0) := (others=>'0');
  begin 
    if ROUND_ENABLE then res(ROUND_BIT):='1'; end if;
    return res;
  end function;

  function nof_regs_clr return natural is
  begin 
    if    RELATION_CLR="AD" then return NUM_INPUT_REG_AD;
    elsif RELATION_CLR="B"  then return NUM_INPUT_REG_B;
    elsif RELATION_CLR="C"  then return NUM_INPUT_REG_C;
    else
      report "ERROR: CLR input port must be related to AD, B or C."
        severity failure;
      return integer'high;
    end if;
  end function;
  constant NUM_INPUT_REG_CLR : natural := nof_regs_clr;

  constant NUM_INPUT_REG_VLD : natural := NUM_INPUT_REG_AD;

  -- Consider up to one MREG register as second input register stage
  constant NUM_MREG : natural := minimum(1,maximum(0,NUM_INPUT_REG_AD-1));

  -- Preadder only needed when D input enabled - otherwise product negation can be used instead.
  constant ENABLE_PREADDER : boolean := USE_D_INPUT;

  function AMULTSEL return string is begin 
    if ENABLE_PREADDER then return "AD"; else return "A"; end if;
  end function;

  -- Consider up to two AREG register stages
  function GET_AREG return natural is begin 
    if ENABLE_PREADDER then
      return minimum(1,NUM_INPUT_REG_AD); -- consider MREG and ADREG because AMULTSEL="AD"
    else
      return NUM_INPUT_REG_AD - NUM_MREG; -- A1/A2 with AMULTSEL="A"
    end if;
  end function;
  constant NUM_AREG : natural := GET_AREG;

  -- Consider up to one ADREG register stage (requires AMULTSEL="AD")
  function GET_ADREG return natural is begin 
    if ENABLE_PREADDER then
      return maximum(0,NUM_INPUT_REG_AD-2); -- consider AREG and MREG
    else
      return 0; -- ADREG unused because AMULTSEL="A"
    end if;
  end function;
  constant NUM_ADREG : natural := GET_ADREG;

  -- Consider up to one DREG register stage (requires AMULTSEL="AD")
  function GET_DREG return natural is begin 
    if USE_D_INPUT and ENABLE_PREADDER then
      return minimum(1,NUM_INPUT_REG_AD); -- consider MREG and ADREG because AMULTSEL="AD"
    else
      return 0; -- D input is unused or AMULTSEL="A"
    end if;
  end function;
  constant NUM_DREG : natural := GET_DREG;

  -- Consider up to two BREG register stages
  constant NUM_BREG : natural := NUM_INPUT_REG_B - NUM_MREG;

  -- Consider up to one CREG register stage
  constant NUM_CREG : natural := NUM_INPUT_REG_C;

  signal pipe_clr : std_logic_vector(NUM_INPUT_REG_CLR downto 0);
  signal pipe_vld : std_logic_vector(NUM_INPUT_REG_VLD downto 0);

  -- Consider up to one INMODE input register stage (also used for NEGATE)
  constant NUM_INMODE_REG : natural := minimum(1,NUM_INPUT_REG_AD);
  -- OPMODE control signal
  signal inmode : std_logic_vector(4 downto 0) := (others=>'0');
  alias negate_preadd : std_logic is inmode(3);
  signal negate : std_logic_vector(2 downto 0) := (others=>'0');
  alias negate_product : std_logic is negate(0);

  -- Consider up to one OPMODE input register stage
  constant NUM_OPMODE_REG : natural := minimum(1,NUM_INPUT_REG_CLR);
  -- OPMODE control signal
  signal opmode : std_logic_vector(8 downto 0);

  -- ALUMODE input register, here currently constant and disabled
  constant NUM_ALUMODE_REG : natural := 0;
  -- ALUMODE control signal
  constant alumode : std_logic_vector(3 downto 0) := "0000"; -- always P = Z + (W + X + Y + CIN)

  signal chainin_i, chainout_i : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal p_i : std_logic_vector(ACCU_WIDTH-1 downto 0);

  signal dsp_a : signed(MAX_WIDTH_AD-1 downto 0);
  signal dsp_d : signed(MAX_WIDTH_AD-1 downto 0);

begin

  assert (a'length<=MAX_WIDTH_AD)
    report "ERROR " & IMPLEMENTATION & ": " & 
           "Preadder and Multiplier input A width cannot exceed " & integer'image(MAX_WIDTH_AD)
    severity failure;

  assert (b'length<=MAX_WIDTH_B)
    report "ERROR " & IMPLEMENTATION & ": " & 
           "Multiplier input B width cannot exceed " & integer'image(MAX_WIDTH_B)
    severity failure;

  assert (c'length<=MAX_WIDTH_C)
    report "ERROR " & IMPLEMENTATION & ": " & 
           "Summand input C width cannot exceed " & integer'image(MAX_WIDTH_C)
    severity failure;

  assert (d'length<=MAX_WIDTH_AD)
    report "ERROR " & IMPLEMENTATION & ": " & 
           "Preadder and Multiplier input D width cannot exceed " & integer'image(MAX_WIDTH_AD)
    severity failure;

  assert (NUM_INPUT_REG_AD=NUM_INPUT_REG_B)
    report "ERROR " & IMPLEMENTATION & ": " & 
           "For now the number of input registers in AD and B path must be the same."
    severity failure;

  assert not(ROUND_ENABLE and USE_C_INPUT and USE_CHAIN_INPUT)
    report "ERROR " & IMPLEMENTATION & ": " & 
           "DSP internal rounding bit addition not possible when C and CHAIN inputs are enabled."
    severity failure;

  pipe_clr(NUM_INPUT_REG_CLR) <= clr;
  g_clr : if NUM_INPUT_REG_CLR>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if rst/='0' then
          pipe_clr(NUM_INPUT_REG_CLR-1 downto 0) <= (others=>'1');
        elsif clkena='1' then
          pipe_clr(NUM_INPUT_REG_CLR-1 downto 0) <= pipe_clr(NUM_INPUT_REG_CLR downto 1);
        end if;
      end if;
    end process;
  end generate;

  pipe_vld(NUM_INPUT_REG_VLD) <= vld;
  g_vld : if NUM_INPUT_REG_VLD>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if rst/='0' then
          pipe_vld(NUM_INPUT_REG_VLD-1 downto 0) <= (others=>'0');
        elsif clkena='1' then
          pipe_vld(NUM_INPUT_REG_VLD-1 downto 0) <= pipe_vld(NUM_INPUT_REG_VLD downto 1);
        end if;
      end if;
    end process;
  end generate;

  i_neg : entity work.xilinx_negation_logic(dsp58)
  generic map(
    USE_D_INPUT    => USE_D_INPUT,
    USE_NEGATION   => USE_NEGATION,
    USE_A_NEGATION => USE_A_NEGATION,
    USE_D_NEGATION => USE_D_NEGATION
  )
  port map(
    neg          => neg,
    neg_a        => neg_a,
    neg_d        => neg_d,
    a            => a,
    d            => d,
    neg_preadd   => negate_preadd,
    neg_product  => negate_product,
    dsp_a        => dsp_a,
    dsp_d        => dsp_d
  );

  inmode(0) <= '0'; -- '0'= A2 Mux controlled AREG , '1'= A1
  inmode(1) <= '0'; -- do not gate A input
  inmode(2) <= '1' when USE_D_INPUT else '0'; -- pass D through input gate
  inmode(4) <= '0'; -- '0'= B2 Mux controlled BREG , '1'= B1

  i_opmode : entity work.xilinx_opmode_logic
  generic map(
    USE_PCIN_INPUT => USE_CHAIN_INPUT,
    USE_C_INPUT    => USE_C_INPUT,
    ENABLE_P_REG   => (NUM_OUTPUT_REG>=1)
  )
  port map(
    clk    => clk,
    rst    => rst,
    clkena => clkena,
    clr    => pipe_clr(NUM_OPMODE_REG),
    vld    => pipe_vld(NUM_OPMODE_REG),
    opmode => opmode
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
    RND                       => gRND, -- Rounding Constant
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
    IS_INMODE_INVERTED        => "00000",
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
    ADREG                     => NUM_ADREG,-- 0 or 1
    ALUMODEREG                => NUM_ALUMODE_REG, -- 0 or 1
    AREG                      => NUM_AREG,-- 0,1 or 2
    BCASCREG                  => open, -- unused
    BREG                      => NUM_BREG,-- 0,1 or 2
    CARRYINREG                => open, -- unused
    CARRYINSELREG             => open, -- unused
    CREG                      => NUM_CREG, -- 0 or 1
    DREG                      => NUM_DREG,-- 0 or 1
    INMODEREG                 => NUM_INMODE_REG, -- 0 or 1
    MREG                      => NUM_MREG, -- 0 or 1
    OPMODEREG                 => NUM_OPMODE_REG, -- 0 or 1
    PREG                      => NUM_OUTPUT_REG -- 0 or 1
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
    P                  => p_i,
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
    B                  => std_logic_vector(resize(b,MAX_WIDTH_B)),
    C                  => std_logic_vector(resize(c,MAX_WIDTH_C)),
    CARRYIN            => '0', -- unused
    D                  => std_logic_vector(resize(dsp_d,MAX_WIDTH_D)),
    -- Clock Enable: 1-bit (each) input: Clock Enable Inputs
    CEA1               => CE(clkena,NUM_AREG),
    CEA2               => CE(clkena,NUM_AREG),
    CEAD               => CE(clkena,NUM_ADREG),
    CEALUMODE          => CE(clkena,NUM_ALUMODE_REG),
    CEB1               => CE(clkena,NUM_BREG),
    CEB2               => CE(clkena,NUM_BREG),
    CEC                => CE(clkena,NUM_CREG),
    CECARRYIN          => '0', -- unused
    CECTRL             => CE(clkena,NUM_OPMODE_REG),
    CED                => CE(clkena,NUM_DREG),
    CEINMODE           => CE(clkena,NUM_INMODE_REG),
    CEM                => CE(clkena,NUM_MREG),
    CEP                => CE(clkena and pipe_vld(0),NUM_OUTPUT_REG), -- accumulate/output only valid values
    -- Reset: 1-bit (each) input: Reset
    ASYNC_RST          => '0',
    RSTA               => rst,
    RSTALLCARRYIN      => '1', -- unused
    RSTALUMODE         => rst,
    RSTB               => rst,
    RSTC               => rst,
    RSTCTRL            => rst,
    RSTD               => rst,
    RSTINMODE          => rst,
    RSTM               => rst,
    RSTP               => rst 
  );

  chainout<= resize(signed(chainout_i),chainout'length);

  -- pipelined output valid signal
  g_dspreg_on : if NUM_OUTPUT_REG=1 generate
  begin
    process(clk)
    begin
      if rising_edge(clk) then
        if rst/='0' then
          p_vld <= '0';
        elsif clkena='1' then
          p_vld <= pipe_vld(0);
        end if;
      end if;
    end process;
  end generate;
  g_dspreg_off : if NUM_OUTPUT_REG=0 generate
    p_vld <= pipe_vld(0);
  end generate;

  p <= signed(p_i);

  PIPESTAGES <= NUM_INPUT_REG_AD + NUM_OUTPUT_REG;

end architecture;
