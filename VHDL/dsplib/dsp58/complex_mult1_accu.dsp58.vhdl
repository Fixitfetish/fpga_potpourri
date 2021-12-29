-------------------------------------------------------------------------------
--! @file       complex_mult1_accu.dsp58.vhdl
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
  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;
library dsplib;
  use dsplib.dsp_pkg_dsp58.all;

library unisim;
  use unisim.vcomponents.all;

--! @brief This is an implementation of the entity complex_mult1_accu for Xilinx Versal.
--! One complex multiplication is performed and results are accumulated.
--!
--! Refer to Xilinx Versal ACAP DSP Engine, Architecture Manual, AM004 (v1.1.2) July 15, 2021
--!
--! @image html complex_mult1_accu.dsp58.svg "" width=600px
--!
--! **MAXIMUM_PERFORMANCE**
--! * This implementation requires two back-to-back DSP58s.
--! * Chaining is supported.
--! * The number of overall pipeline stages is typically NUM_INPUT_REG + 1 + NUM_OUTPUT_REG.
--! 
architecture dsp58 of complex_mult1_accu is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "complex_mult1_accu(dsp58)";

  -- derived constants
  constant ROUND_ENABLE : boolean := OUTPUT_ROUND and (OUTPUT_SHIFT_RIGHT/=0);
  constant PRODUCT_WIDTH : natural := x_re'length + 1 + y_re'length;
  constant MAX_GUARD_BITS : natural := ACCU_WIDTH - PRODUCT_WIDTH;
  constant GUARD_BITS_EVAL : natural := accu_guard_bits(NUM_SUMMAND,MAX_GUARD_BITS,IMPLEMENTATION);
  constant ACCU_USED_WIDTH : natural := PRODUCT_WIDTH + GUARD_BITS_EVAL;
  constant ACCU_USED_SHIFTED_WIDTH : natural := ACCU_USED_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result_re'length;

  type r_dsp_in is
  record
    rst, vld, clr : std_logic;
    inmode : std_logic_vector(4 downto 0);
    opmode : std_logic_vector(8 downto 0);
    a_re : signed(17 downto 0);
    a_im : signed(17 downto 0);
    b_re : signed(17 downto 0);
    b_im : signed(17 downto 0);
    c_re : signed(MAX_WIDTH_C-1 downto 0);
    c_im : signed(MAX_WIDTH_C-1 downto 0);
  end record;
  signal dsp_in : r_dsp_in;
  signal dsp_feed : r_dsp_in;

  signal chainin_re_i, chainout_re_i : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal chainin_im_i, chainout_im_i : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal accu_re, accu_im : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal accu_vld : std_logic := '0';
  signal accu_used_re, accu_used_im : signed(ACCU_USED_WIDTH-1 downto 0);

  signal reset : std_logic := '0';
  signal ofl_re , ofl_im : std_logic;
  signal ufl_re , ufl_im : std_logic;
  signal result_ovf_re , result_ovf_im : std_logic;

begin

  -- check input/output length
  assert (x_re'length<=18 and x_im'length<=18 and y_re'length<=18 and y_im'length<=18)
    report "ERROR " & IMPLEMENTATION & ": " & 
           "Complex multiplier input width is limited to 18."
    severity failure;

  assert GUARD_BITS_EVAL<=MAX_GUARD_BITS
    report "ERROR " & IMPLEMENTATION & ": " &
           "Maximum number of accumulator bits is " & integer'image(ACCU_WIDTH) & " ." &
           "Input bit widths allow only maximum number of guard bits = " & integer'image(MAX_GUARD_BITS)
    severity failure;

  assert OUTPUT_WIDTH<ACCU_USED_SHIFTED_WIDTH or not(OUTPUT_CLIP or OUTPUT_OVERFLOW)
    report "ERROR " & IMPLEMENTATION & ": " &
           "More guard bits required for saturation/clipping and/or overflow detection."
    severity failure;


  -- use only LSBs of chain input
  chainin_re_i <= std_logic_vector(chainin_re(ACCU_WIDTH-1 downto 0));
  chainin_im_i <= std_logic_vector(chainin_im(ACCU_WIDTH-1 downto 0));

  i_dspcplx : DSPCPLX
  generic map(
     ACASCREG_IM                  => 1, -- integer := 1;
     ACASCREG_RE                  => 1, -- integer := 1;
     ADREG                        => 1, -- integer := 1;
     ALUMODEREG_IM                => 1, -- integer := 1;
     ALUMODEREG_RE                => 1, -- integer := 1;
     AREG_IM                      => 2, -- integer := 2;
     AREG_RE                      => 2, -- integer := 2;
     AUTORESET_PATDET_IM          => "NO_RESET", -- string := "NO_RESET";
     AUTORESET_PATDET_RE          => "NO_RESET", -- string := "NO_RESET";
     AUTORESET_PRIORITY_IM        => "RESET", -- string := "RESET";
     AUTORESET_PRIORITY_RE        => "RESET", -- string := "RESET";
     A_INPUT_IM                   => "DIRECT", -- string := "DIRECT";
     A_INPUT_RE                   => "DIRECT", -- string := "DIRECT";
     BCASCREG_IM                  => 1, -- integer := 1;
     BCASCREG_RE                  => 1, -- integer := 1;
     BREG_IM                      => 2, -- integer := 2;
     BREG_RE                      => 2, -- integer := 2;
     B_INPUT_IM                   => "DIRECT", -- string := "DIRECT";
     B_INPUT_RE                   => "DIRECT", -- string := "DIRECT";
     CARRYINREG_IM                => 1, -- integer := 1;
     CARRYINREG_RE                => 1, -- integer := 1;
     CARRYINSELREG_IM             => 1, -- integer := 1;
     CARRYINSELREG_RE             => 1, -- integer := 1;
     CONJUGATEREG_A               => 1, -- integer := 1;
     CONJUGATEREG_B               => 1, -- integer := 1;
     CREG_IM                      => 1, -- integer := 1;
     CREG_RE                      => 1, -- integer := 1;
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
     MREG_IM                      => 1, -- integer := 1;
     MREG_RE                      => 1, -- integer := 1;
     OPMODEREG_IM                 => 1, -- integer := 1;
     OPMODEREG_RE                 => 1, -- integer := 1;
     PATTERN_IM                   => (others=>'0'), -- std_logic_vector(57 downto 0) := "00" & X"00000000000000";
     PATTERN_RE                   => (others=>'0'), -- std_logic_vector(57 downto 0) := "00" & X"00000000000000";
     PREG_IM                      => 1, -- integer := 1;
     PREG_RE                      => 1, -- integer := 1;
     RESET_MODE                   => "SYNC", -- string := "SYNC";
     RND_IM                       => (others=>'0'), -- std_logic_vector(57 downto 0) := "00" & X"00000000000000";
     RND_RE                       => (others=>'0'), -- std_logic_vector(57 downto 0) := "00" & X"00000000000000";
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
     P_IM              => accu_im, -- out std_logic_vector(57 downto 0);
     P_RE              => accu_re, -- out std_logic_vector(57 downto 0);
     UNDERFLOW_IM      => ufl_im, -- out std_ulogic;
     UNDERFLOW_RE      => ufl_re, -- out std_ulogic;
     ACIN_IM           => open, -- in std_logic_vector(17 downto 0);
     ACIN_RE           => open, -- in std_logic_vector(17 downto 0);
     ALUMODE_IM        => "0000", -- in std_logic_vector(3 downto 0);
     ALUMODE_RE        => "0000", -- in std_logic_vector(3 downto 0);
     ASYNC_RST         => open, -- in std_ulogic;
     A_IM              => std_logic_vector(dsp_feed.a_im),
     A_RE              => std_logic_vector(dsp_feed.a_re),
     BCIN_IM           => open, -- in std_logic_vector(17 downto 0);
     BCIN_RE           => open, -- in std_logic_vector(17 downto 0);
     B_IM              => std_logic_vector(dsp_feed.b_im),
     B_RE              => std_logic_vector(dsp_feed.b_re),
     CARRYCASCIN_IM    => open, -- in std_ulogic;
     CARRYCASCIN_RE    => open, -- in std_ulogic;
     CARRYINSEL_IM     => open, -- in std_logic_vector(2 downto 0);
     CARRYINSEL_RE     => open, -- in std_logic_vector(2 downto 0);
     CARRYIN_IM        => open, -- in std_ulogic;
     CARRYIN_RE        => open, -- in std_ulogic;
     CEA1_IM           => clkena, -- in std_ulogic;
     CEA1_RE           => clkena, -- in std_ulogic;
     CEA2_IM           => clkena, -- in std_ulogic;
     CEA2_RE           => clkena, -- in std_ulogic;
     CEAD              => clkena, -- in std_ulogic;
     CEALUMODE_IM      => clkena, -- in std_ulogic;
     CEALUMODE_RE      => clkena, -- in std_ulogic;
     CEB1_IM           => clkena, -- in std_ulogic;
     CEB1_RE           => clkena, -- in std_ulogic;
     CEB2_IM           => clkena, -- in std_ulogic;
     CEB2_RE           => clkena, -- in std_ulogic;
     CECARRYIN_IM      => open, -- in std_ulogic;
     CECARRYIN_RE      => open, -- in std_ulogic;
     CECONJUGATE_A     => open, -- in std_ulogic;
     CECONJUGATE_B     => open, -- in std_ulogic;
     CECTRL_IM         => clkena, -- in std_ulogic;
     CECTRL_RE         => clkena, -- in std_ulogic;
     CEC_IM            => clkena, -- in std_ulogic;
     CEC_RE            => clkena, -- in std_ulogic;
     CEM_IM            => clkena, -- in std_ulogic;
     CEM_RE            => clkena, -- in std_ulogic;
     CEP_IM            => clkena, -- in std_ulogic;
     CEP_RE            => clkena, -- in std_ulogic;
     CLK               => clk, -- in std_ulogic;
     CONJUGATE_A       => '0', -- in std_ulogic;
     CONJUGATE_B       => '0', -- in std_ulogic;
     C_IM              => std_logic_vector(dsp_feed.c_im),
     C_RE              => std_logic_vector(dsp_feed.c_re),
     MULTSIGNIN_IM     => open, -- in std_ulogic;
     MULTSIGNIN_RE     => open, -- in std_ulogic;
     OPMODE_IM         => dsp_feed.opmode,
     OPMODE_RE         => dsp_feed.opmode,
     PCIN_IM           => chainin_im_i, -- in std_logic_vector(57 downto 0);
     PCIN_RE           => chainin_re_i, -- in std_logic_vector(57 downto 0);
     RSTAD             => reset, -- in std_ulogic;
     RSTALLCARRYIN_IM  => reset, -- in std_ulogic;
     RSTALLCARRYIN_RE  => reset, -- in std_ulogic;
     RSTALUMODE_IM     => reset, -- in std_ulogic;
     RSTALUMODE_RE     => reset, -- in std_ulogic;
     RSTA_IM           => reset, -- in std_ulogic;
     RSTA_RE           => reset, -- in std_ulogic;
     RSTB_IM           => reset, -- in std_ulogic;
     RSTB_RE           => reset, -- in std_ulogic;
     RSTCONJUGATE_A    => reset, -- in std_ulogic;
     RSTCONJUGATE_B    => reset, -- in std_ulogic;
     RSTCTRL_IM        => reset, -- in std_ulogic;
     RSTCTRL_RE        => reset, -- in std_ulogic;
     RSTC_IM           => reset, -- in std_ulogic;
     RSTC_RE           => reset, -- in std_ulogic;
     RSTM_IM           => reset, -- in std_ulogic;
     RSTM_RE           => reset, -- in std_ulogic;
     RSTP_IM           => reset, -- in std_ulogic;
     RSTP_RE           => reset  -- in std_ulogic
  );

  chainout_re(ACCU_WIDTH-1 downto 0) <= signed(chainout_re_i);
  chainout_im(ACCU_WIDTH-1 downto 0) <= signed(chainout_im_i);
  g_chainout : for n in ACCU_WIDTH to (chainout_re'length-1) generate
    -- sign extension (for simulation and to avoid warnings)
    chainout_re(n) <= chainout_re_i(ACCU_WIDTH-1);
    chainout_im(n) <= chainout_im_i(ACCU_WIDTH-1);
  end generate;

  -- pipelined valid signal
  g_dspreg_on : if NUM_OUTPUT_REG>=1 generate
  begin
    process(clk)
    begin
      if rising_edge(clk) then
        if rst/='0' then
          accu_vld <= '0';
        elsif clkena='1' then
          accu_vld <= dsp_feed.vld;
        end if;
      end if;
    end process;
  end generate;
  g_dspreg_off : if NUM_OUTPUT_REG<=0 generate
    accu_vld <= dsp_feed.vld;
  end generate;

  -- cut off unused sign extension bits
  -- (This reduces the logic consumption in the following steps when rounding,
  --  saturation and/or overflow detection is enabled.)
  accu_used_re <= signed(accu_re(ACCU_USED_WIDTH-1 downto 0));
  accu_used_im <= signed(accu_im(ACCU_USED_WIDTH-1 downto 0));

  -- right-shift and clipping
  i_out_re : entity dsplib.signed_output_logic
  generic map(
    PIPELINE_STAGES    => NUM_OUTPUT_REG-1,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => OUTPUT_ROUND and USE_CHAIN_INPUT,
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

  i_out_im : entity dsplib.signed_output_logic
  generic map(
    PIPELINE_STAGES    => NUM_OUTPUT_REG-1,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => OUTPUT_ROUND and USE_CHAIN_INPUT,
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

  -- TODO
  result_ovf <= result_ovf_re or result_ovf_im or ofl_re or ofl_im or ufl_re or ufl_im;

end architecture;
