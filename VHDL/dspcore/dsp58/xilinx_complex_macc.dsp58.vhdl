-------------------------------------------------------------------------------
--! @file       xilinx_complex_macc.dsp58.vhdl
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

--! @brief Implementation of xilinx_complex_macc for Xilinx DSP58.
--!
--! Refer to Xilinx Versal ACAP DSP Engine, Architecture Manual, AM004 (v1.1.2) July 15, 2021
--!
architecture dsp58 of xilinx_complex_macc is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "xilinx_complex_macc(dsp58)";

  -- Max input width
  constant INPUT_WIDTH : positive := 18;

  --! rounding bit generation (+0.5)
  function gRND return std_logic_vector is
    variable res : std_logic_vector(ACCU_WIDTH-1 downto 0) := (others=>'0');
  begin 
    if ROUND_ENABLE then res(ROUND_BIT):='1'; end if;
    return res;
  end function;

  function nof_regs_clr return natural is
  begin 
    if    RELATION_CLR="A" then return NUM_INPUT_REG_A;
    elsif RELATION_CLR="B" then return NUM_INPUT_REG_B;
    elsif RELATION_CLR="C" then return NUM_INPUT_REG_C;
    else
      report "ERROR: CLR input port must be related to A, B or C."
        severity failure;
      return integer'high;
    end if;
  end function;
  constant NUM_INPUT_REG_CLR : natural := nof_regs_clr;

  function nof_regs_vld return natural is
  begin 
    if    RELATION_VLD="A" then return NUM_INPUT_REG_A;
    elsif RELATION_VLD="B" then return NUM_INPUT_REG_B;
    elsif RELATION_VLD="C" then return NUM_INPUT_REG_C;
    else
      report "ERROR: VLD input port must be related to A, B or C."
        severity failure;
      return integer'high;
    end if;
  end function;
  constant NUM_INPUT_REG_VLD : natural := nof_regs_vld;

  -- Consider up to one MREG register as second input register stage
  constant NUM_MREG : natural := minimum(1,maximum(0,NUM_INPUT_REG_A-1)); -- TODO

  -- Consider up to two AREG register stages
  constant NUM_AREG : natural := NUM_INPUT_REG_A - NUM_MREG;

  -- Consider up to two BREG register stages
  constant NUM_BREG : natural := NUM_INPUT_REG_B - NUM_MREG;

  -- Consider up to one Conjugate A register as second input register stage
  constant NUM_CONJ_AREG : natural := minimum(1,NUM_INPUT_REG_A);

  -- Consider up to one Conjugate B register as second input register stage
  constant NUM_CONJ_BREG : natural := minimum(1,NUM_INPUT_REG_B);

  -- Consider up to one ADREG register stage
  constant NUM_ADREG : natural := minimum(1,maximum(0,NUM_INPUT_REG_A-2)); -- TODO  ???

  -- Consider up to one CREG register stage
  constant NUM_CREG : natural := NUM_INPUT_REG_C;

  signal pipe_clr : std_logic_vector(NUM_INPUT_REG_CLR downto 0);
  signal pipe_vld : std_logic_vector(NUM_INPUT_REG_VLD downto 0);

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
  signal chainin_re_i, chainout_re_i : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal chainin_im_i, chainout_im_i : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal p_re_i, p_im_i : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal ofl_re , ofl_im : std_logic;
  signal ufl_re , ufl_im : std_logic;

begin

  assert (a_re'length<=INPUT_WIDTH and a_im'length<=INPUT_WIDTH)
    report "ERROR " & IMPLEMENTATION & ": " & "Multiplier input A width cannot exceed " & integer'image(INPUT_WIDTH)
    severity failure;

  assert (b_re'length<=INPUT_WIDTH and b_im'length<=INPUT_WIDTH)
    report "ERROR " & IMPLEMENTATION & ": " & "Multiplier input B width cannot exceed " & integer'image(INPUT_WIDTH)
    severity failure;

  assert (c_re'length<=MAX_WIDTH_C and c_im'length<=MAX_WIDTH_C)
    report "ERROR " & IMPLEMENTATION & ": " & "Summand input C width cannot exceed " & integer'image(MAX_WIDTH_C)
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
  chainin_re_i <= std_logic_vector(chainin_re(ACCU_WIDTH-1 downto 0));
  chainin_im_i <= std_logic_vector(chainin_im(ACCU_WIDTH-1 downto 0));

  i_dspcplx : unisim.vcomponents.DSPCPLX
  generic map(
     ACASCREG_IM                  => 1, -- integer := 1;
     ACASCREG_RE                  => 1, -- integer := 1;
     ADREG                        => NUM_ADREG,
     ALUMODEREG_IM                => NUM_ALUMODE_REG,
     ALUMODEREG_RE                => NUM_ALUMODE_REG,
     AREG_IM                      => NUM_AREG, -- integer := 2;
     AREG_RE                      => NUM_AREG, -- integer := 2;
     AUTORESET_PATDET_IM          => "NO_RESET", -- string := "NO_RESET";
     AUTORESET_PATDET_RE          => "NO_RESET", -- string := "NO_RESET";
     AUTORESET_PRIORITY_IM        => "RESET", -- string := "RESET";
     AUTORESET_PRIORITY_RE        => "RESET", -- string := "RESET";
     A_INPUT_IM                   => "DIRECT", -- string := "DIRECT";
     A_INPUT_RE                   => "DIRECT", -- string := "DIRECT";
     BCASCREG_IM                  => 1, -- integer := 1;
     BCASCREG_RE                  => 1, -- integer := 1;
     BREG_IM                      => NUM_BREG, -- integer := 2;
     BREG_RE                      => NUM_BREG, -- integer := 2;
     B_INPUT_IM                   => "DIRECT", -- string := "DIRECT";
     B_INPUT_RE                   => "DIRECT", -- string := "DIRECT";
     CARRYINREG_IM                => 1, -- integer := 1;
     CARRYINREG_RE                => 1, -- integer := 1;
     CARRYINSELREG_IM             => 1, -- integer := 1;
     CARRYINSELREG_RE             => 1, -- integer := 1;
     CONJUGATEREG_A               => NUM_CONJ_AREG,
     CONJUGATEREG_B               => NUM_CONJ_BREG,
     CREG_IM                      => NUM_CREG, -- integer := 1;
     CREG_RE                      => NUM_CREG, -- integer := 1;
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
     MREG_IM                      => NUM_MREG,
     MREG_RE                      => NUM_MREG,
     OPMODEREG_IM                 => NUM_OPMODE_REG,
     OPMODEREG_RE                 => NUM_OPMODE_REG,
     PATTERN_IM                   => (others=>'0'), -- std_logic_vector(57 downto 0) := "00" & X"00000000000000";
     PATTERN_RE                   => (others=>'0'), -- std_logic_vector(57 downto 0) := "00" & X"00000000000000";
     PREG_IM                      => NUM_OUTPUT_REG,
     PREG_RE                      => NUM_OUTPUT_REG,
     RESET_MODE                   => "SYNC", -- string := "SYNC";
     RND_IM                       => gRND, -- Rounding Constant
     RND_RE                       => gRND, -- Rounding Constant
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
     OVERFLOW_IM       => ofl_im, -- out std_ulogic;
     OVERFLOW_RE       => ofl_re, -- out std_ulogic;
     PATTERNBDETECT_IM => open, -- out std_ulogic;
     PATTERNBDETECT_RE => open, -- out std_ulogic;
     PATTERNDETECT_IM  => open, -- out std_ulogic;
     PATTERNDETECT_RE  => open, -- out std_ulogic;
     PCOUT_IM          => chainout_im_i, -- out std_logic_vector(57 downto 0);
     PCOUT_RE          => chainout_re_i, -- out std_logic_vector(57 downto 0);
     P_IM              => p_im_i, -- out std_logic_vector(57 downto 0);
     P_RE              => p_re_i, -- out std_logic_vector(57 downto 0);
     UNDERFLOW_IM      => ufl_im, -- out std_ulogic;
     UNDERFLOW_RE      => ufl_re, -- out std_ulogic;
     ACIN_IM           => (others=>'0'), -- unused;
     ACIN_RE           => (others=>'0'), -- unused;
     ALUMODE_IM        => alumode, -- in std_logic_vector(3 downto 0);
     ALUMODE_RE        => alumode, -- in std_logic_vector(3 downto 0);
     ASYNC_RST         => '0', -- unused
     A_IM              => std_logic_vector(resize(a_im,INPUT_WIDTH)),
     A_RE              => std_logic_vector(resize(a_re,INPUT_WIDTH)),
     BCIN_IM           => (others=>'0'), -- unused
     BCIN_RE           => (others=>'0'), -- unused
     B_IM              => std_logic_vector(resize(b_im,INPUT_WIDTH)),
     B_RE              => std_logic_vector(resize(b_re,INPUT_WIDTH)),
     CARRYCASCIN_IM    => '0', -- unused
     CARRYCASCIN_RE    => '0', -- unused
     CARRYINSEL_IM     => (others=>'0'), -- unused
     CARRYINSEL_RE     => (others=>'0'), -- unused
     CARRYIN_IM        => '0', -- unused
     CARRYIN_RE        => '0', -- unused
     CEA1_IM           => CE(clkena,NUM_AREG),
     CEA1_RE           => CE(clkena,NUM_AREG),
     CEA2_IM           => CE(clkena,NUM_AREG),
     CEA2_RE           => CE(clkena,NUM_AREG),
     CEAD              => CE(clkena,NUM_ADREG),
     CEALUMODE_IM      => CE(clkena,NUM_ALUMODE_REG),
     CEALUMODE_RE      => CE(clkena,NUM_ALUMODE_REG),
     CEB1_IM           => CE(clkena,NUM_BREG),
     CEB1_RE           => CE(clkena,NUM_BREG),
     CEB2_IM           => CE(clkena,NUM_BREG),
     CEB2_RE           => CE(clkena,NUM_BREG),
     CECARRYIN_IM      => '0', -- unused
     CECARRYIN_RE      => '0', -- unused
     CECONJUGATE_A     => CE(clkena,NUM_CONJ_AREG),
     CECONJUGATE_B     => CE(clkena,NUM_CONJ_BREG),
     CECTRL_IM         => CE(clkena,NUM_OPMODE_REG),
     CECTRL_RE         => CE(clkena,NUM_OPMODE_REG),
     CEC_IM            => CE(clkena,NUM_CREG),
     CEC_RE            => CE(clkena,NUM_CREG),
     CEM_IM            => CE(clkena,NUM_MREG),
     CEM_RE            => CE(clkena,NUM_MREG),
     CEP_IM            => CE(clkena and pipe_vld(0),NUM_OUTPUT_REG), -- accumulate only valid values
     CEP_RE            => CE(clkena and pipe_vld(0),NUM_OUTPUT_REG), -- accumulate only valid values
     CLK               => clk, -- in std_ulogic;
     CONJUGATE_A       => a_conj, -- in std_ulogic;
     CONJUGATE_B       => b_conj, -- in std_ulogic;
     C_IM              => std_logic_vector(resize(c_im,MAX_WIDTH_C)),
     C_RE              => std_logic_vector(resize(c_re,MAX_WIDTH_C)),
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

  p_re <= signed(p_re_i);
  p_im <= signed(p_im_i);

  p_ovf_re <= ofl_re or ufl_re;
  p_ovf_im <= ofl_im or ufl_im;

  PIPESTAGES <= NUM_INPUT_REG_A + NUM_OUTPUT_REG; -- TODO A?

end architecture;
