-------------------------------------------------------------------------------
--! @file       xilinx_preadd_macc_standard.dsp48e2.vhdl
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

use work.xilinx_dsp_pkg_dsp48e2.all;

--! @brief Implementation of xilinx_preadd_macc_standard for Xilinx DSP48e2.
--!
--! Refer to Xilinx UltraScale Architecture DSP48E2 Slice, UG579 (v1.11) August 30, 2021
--!
architecture dsp48e2 of xilinx_preadd_macc_standard is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "xilinx_preadd_macc_standard(dsp48e2)";

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

  constant ENABLE_PREADDER : boolean := USE_D_INPUT or USE_NEGATION;

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

  -- Consider up to one INMODE input register stage
  constant NUM_INMODE_REG : natural := minimum(1,NUM_INPUT_REG_AD);
  -- OPMODE control signal
  signal inmode : std_logic_vector(4 downto 0);

  -- Consider up to one OPMODE input register stage
  constant NUM_OPMODE_REG : natural := minimum(1,NUM_INPUT_REG_CLR);
  -- OPMODE control signal
  signal opmode : std_logic_vector(8 downto 0);
  alias opmode_xy is opmode(3 downto 0);
  alias opmode_z  is opmode(6 downto 4);
  alias opmode_w  is opmode(8 downto 7);

  -- ALUMODE input register, here currently constant and disabled
  constant NUM_ALUMODE_REG : natural := 0;
  -- ALUMODE control signal
  constant alumode : std_logic_vector(3 downto 0) := "0000"; -- always P = Z + (W + X + Y + CIN)

  signal clr_i, clr_q : std_logic := '0';
  signal chainin_i, chainout_i : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal p_i : std_logic_vector(ACCU_WIDTH-1 downto 0);

begin

  assert (a'length<=MAX_WIDTH_D)
    report "ERROR " & IMPLEMENTATION & ": " & 
           "Preadder and Multiplier input A width cannot exceed " & integer'image(MAX_WIDTH_D)
    severity failure;

  assert (b'length<=MAX_WIDTH_B)
    report "ERROR " & IMPLEMENTATION & ": " & 
           "Multiplier input B width cannot exceed " & integer'image(MAX_WIDTH_B)
    severity failure;

  assert (c'length<=MAX_WIDTH_C)
    report "ERROR " & IMPLEMENTATION & ": " & 
           "Summand input C width cannot exceed " & integer'image(MAX_WIDTH_C)
    severity failure;

  assert (d'length<=MAX_WIDTH_D)
    report "ERROR " & IMPLEMENTATION & ": " & 
           "Preadder and Multiplier input D width cannot exceed " & integer'image(MAX_WIDTH_D)
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

  inmode(0) <= '0'; -- '0'= A2 Mux controlled AREG , '1'= A1
  inmode(1) <= '0'; -- do not gate A input
  inmode(2) <= '1' when USE_D_INPUT else '0'; -- D input gate
  inmode(3) <= neg when USE_NEGATION else '0';
  inmode(4) <= '0'; -- '0'= B2 Mux controlled BREG , '1'= B1

  -- hold clear until next valid
  p_clr : process(clk)
  begin
    if rising_edge(clk) then
      if rst/='0' then
        clr_q<='1';
      elsif clkena='1' then
        if pipe_clr(NUM_OPMODE_REG)='1' and pipe_vld(NUM_OPMODE_REG)='0' then
          clr_q<='1';
        elsif pipe_vld(NUM_OPMODE_REG)='1' then
          clr_q<='0';
        end if;
      end if;
    end if;
  end process;
  clr_i <= pipe_clr(NUM_OPMODE_REG) or clr_q;

  -- OPMODE control signal
  opmode_xy <= "0101"; -- constant, always multiplier result M
  opmode_z  <= "001" when USE_CHAIN_INPUT else -- PCIN
               "011" when USE_C_INPUT else -- Input C
               "000"; -- unused
  opmode_w  <= "11" when (USE_CHAIN_INPUT and USE_C_INPUT) else -- input C
               "10" when clr_i='1' else -- clear P and initialize P with rounding constant
               "00" when (NUM_OUTPUT_REG=0) else -- add zero when P register disabled
               "01"; -- feedback P accumulator register output

  -- use only LSBs of chain input
  chainin_i <= std_logic_vector(chainin(ACCU_WIDTH-1 downto 0));

  i_dsp : unisim.vcomponents.DSP48E2
  generic map(
    -- Feature Control Attributes: Data Path Selection
    AMULTSEL                  => AMULTSEL, -- "A" or "AD"
    A_INPUT                   => "DIRECT", -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
    BMULTSEL                  => "B", --Selects B input to multiplier (B,AD)
    B_INPUT                   => "DIRECT", -- Selects B input source,"DIRECT"(B port)or "CASCADE"(BCIN port)
    PREADDINSEL               => "A", -- Selects input to preadder (A, B)
    RND                       => gRND, -- Rounding Constant
    USE_MULT                  => "MULTIPLY", -- Select multiplier usage (MULTIPLY,DYNAMIC,NONE)
    USE_SIMD                  => "ONE48", -- SIMD selection(ONE48, FOUR12, TWO24)
    USE_WIDEXOR               => "FALSE", -- Use the Wide XOR function (FALSE, TRUE)
    XORSIMD                   => "XOR24_48_96", -- Mode of operation for the Wide XOR (XOR24_48_96, XOR12)
    -- Pattern Detector Attributes: Pattern Detection Configuration
    AUTORESET_PATDET          => "NO_RESET", -- NO_RESET, RESET_MATCH, RESET_NOT_MATCH
    AUTORESET_PRIORITY        => "RESET", -- Priority of AUTORESET vs.CEP (RESET, CEP).
    MASK                      => x"3FFFFFFFFFFF", -- 48-bit mask value for pattern detect (1=ignore)
    PATTERN                   => x"000000000000", -- 48-bit pattern match for pattern detect
    SEL_MASK                  => "MASK", -- MASK, C, ROUNDING_MODE1, ROUNDING_MODE2
    SEL_PATTERN               => "PATTERN", -- Select pattern value (PATTERN, C)
    USE_PATTERN_DETECT        => "NO_PATDET", -- Enable pattern detect (NO_PATDET, PATDET)
    -- Programmable Inversion Attributes: Specifies built-in programmable inversion on specific pins
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
    -- Data: 30-bit (each) input: Data Ports
    A                  => std_logic_vector(resize(a,MAX_WIDTH_A)),
    B                  => std_logic_vector(resize(b,MAX_WIDTH_B)),
    C                  => std_logic_vector(resize(c,MAX_WIDTH_C)),
    CARRYIN            => '0', -- unused
    D                  => std_logic_vector(resize(d,MAX_WIDTH_D)),
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
    CEP                => CE(clkena and pipe_vld(0),NUM_OUTPUT_REG), -- accumulate only valid values
    -- Reset: 1-bit (each) input: Reset
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
