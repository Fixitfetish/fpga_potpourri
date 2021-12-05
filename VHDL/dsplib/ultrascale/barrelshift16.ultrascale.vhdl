-------------------------------------------------------------------------------
--! @file       barrelshift16.ultrascale.vhdl
--! @author     Fixitfetish
--! @date       02/May/2021
--! @version    0.10
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension.all;
  use baselib.pipereg_pkg.all;
library unisim;
  use unisim.vcomponents.all;

--! @brief This is an implementation of the entity barrelshift16
--! for Xilinx UltraScale.
--! 
architecture ultrascale of barrelshift16 is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "barrelshift16(ultrascale)";

  -- shifter width according to input width
  constant WIDTH_DIN : positive := din'length;

  -- convert input to default range
  alias xdin : std_logic_vector(WIDTH_DIN-1 downto 0) is din;

  -- derived number of required DSP cells
  function NOF_DSP_CELLS return natural is
  begin
    if VARIANT="hybrid" then
      return WIDTH_DIN/16; -- floor(WIDTH_DIN/16)
    elsif VARIANT="dsp" then
      return (WIDTH_DIN+15)/16; -- ceil(WIDTH_DIN/16)
    else
      return 0;
    end if;
  end function;

  function WIDTH_SHIFTER return natural is
  begin
    if VARIANT="dsp" then
      -- padding in last DSP cell if needed
      return NOF_DSP_CELLS*16;
    else
      return WIDTH_DIN;
    end if;
  end function;

  -- derived width of logic based shifter
  constant WIDTH_SHIFTER_LOGIC : natural := WIDTH_SHIFTER - NOF_DSP_CELLS*16;

  signal din_i : std_logic_vector(WIDTH_SHIFTER+16-1 downto 0) := (others=>'0');
  signal dout_i : std_logic_vector(WIDTH_SHIFTER-1 downto 0) := (others=>'0');

  function ABREG return natural is
  begin if INPUT_REG then return 1; else return 0; end if; end function;

  function MREG return natural is
  begin if PIPE_REG then return 1; else return 0; end if; end function;

  function PREG return natural is
  begin if OUTPUT_REG then return 1; else return 0; end if; end function;

  constant PIPESTAGES : natural := ABREG + MREG + PREG;
  signal vld_q : std_logic_vector(0 to PIPESTAGES);

begin 

  -- check for correct variant generic
  assert (VARIANT="logic" or VARIANT="hybrid" or VARIANT="dsp")
    report "ERROR " & IMPLEMENTATION & ": " & "Selected variant '" & VARIANT & "' not supported."
    severity failure;

  g_in_lr : if LEFT_SHIFT generate
    g_cyclic: if CYCLIC generate
      din_i(WIDTH_DIN+16-1 downto 0) <= reverse(xdin(xdin'high downto xdin'high-15)) & reverse(xdin);
    else generate
      din_i(WIDTH_DIN+16-1 downto 0) <= reverse(ext) & reverse(xdin);
    end generate;
  else generate
    g_cyclic: if CYCLIC generate
      din_i(WIDTH_DIN+16-1 downto 0) <= xdin(15 downto 0) & xdin;
    else generate
      din_i(WIDTH_DIN+16-1 downto 0) <= ext & xdin;
    end generate;
  end generate;

  gdsp : if NOF_DSP_CELLS/=0 generate
    constant ALUMODE : std_logic_vector(3 downto 0) := "0000"; -- always P = Z + (W + X + Y + CIN)
    constant opmode_yx : std_logic_vector(3 downto 0) := "0101";
    constant opmode_z : std_logic_vector(6 downto 4) := "000";
    constant opmode_w : std_logic_vector(8 downto 7) := "00";
    signal inmode : std_logic_vector(4 downto 0);
    signal b : unsigned(17 downto 0) := (others=>'0');
  begin
    inmode(0) <= '1'; -- use A1 output
    inmode(1) <= shift(3); -- set A to 0 when D is used (A is used for shifts 0..7)
    inmode(2) <= shift(3); -- set D to 0 when A is used (D is used for shifts 8..15)
    inmode(3) <= '0'; -- do not negate A
    inmode(4) <= '1'; -- use B1 output

    b(17 downto 9) <= (others=>'0');
    b( 8 downto 0) <= ieee.numeric_std.SHIFT_RIGHT(to_unsigned(256,9), to_integer(shift(2 downto 0)));

    gn : for n in 0 to NOF_DSP_CELLS-1 generate
      signal a : std_logic_vector(29 downto 0) := (others=>'0');
      signal d : std_logic_vector(26 downto 0) := (others=>'0');
      signal p : std_logic_vector(47 downto 0);
    begin
      a(23 downto  0) <= din_i(16*n+23 downto 16*n+0);
      d(23 downto  0) <= din_i(16*n+31 downto 16*n+8);

      dsp : DSP48E2
      generic map(
        -- Feature Control Attributes: Data Path Selection
        AMULTSEL                  => "AD", -- use preadder for subtract feature
        A_INPUT                   => "DIRECT", -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
        BMULTSEL                  => "B", --Selects B input to multiplier (B,AD)
        B_INPUT                   => "DIRECT", -- Selects B input source,"DIRECT"(B port)or "CASCADE"(BCIN port)
        PREADDINSEL               => "A", -- Selects input to preadder (A, B)
        RND                       => open, -- Rounding Constant
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
        ACASCREG                  => 1,-- 0,1 or 2
        ADREG                     => 0,-- 0 or 1
        ALUMODEREG                => 1, -- 0 or 1
        AREG                      => ABREG,-- 0,1 or 2
        BCASCREG                  => 1,-- 0,1 or 2
        BREG                      => ABREG,-- 0,1 or 2
        CARRYINREG                => 1,
        CARRYINSELREG             => 1,
        CREG                      => 1,
        DREG                      => ABREG,-- 0 or 1
        INMODEREG                 => 1, -- 0 or 1
        MREG                      => MREG, -- 0 or 1
        OPMODEREG                 => 1, -- 0 or 1
        PREG                      => PREG -- 0 or 1
      ) 
      port map(
        -- Cascade: 30-bit (each) output: Cascade Ports
        ACOUT              => open,
        BCOUT              => open,
        CARRYCASCOUT       => open,
        MULTSIGNOUT        => open,
        PCOUT              => open,
        -- Control: 1-bit (each) output: Control Inputs/Status Bits
        OVERFLOW           => open,
        PATTERNBDETECT     => open,
        PATTERNDETECT      => open,
        UNDERFLOW          => open,
        -- Data: 4-bit (each) output: Data Ports
        CARRYOUT           => open,
        P                  => p,
        XOROUT             => open,
        -- Cascade: 30-bit (each) input: Cascade Ports
        ACIN               => (others=>'0'), -- unused
        BCIN               => (others=>'0'), -- unused
        CARRYCASCIN        => '0', -- unused
        MULTSIGNIN         => '0', -- unused
        PCIN               => (others=>'0'),
        -- Control: 4-bit (each) input: Control Inputs/Status Bits
        ALUMODE            => ALUMODE,
        CARRYINSEL         => "000", -- unused
        CLK                => clk,
        INMODE             => inmode,
        OPMODE(3 downto 0) => opmode_yx,
        OPMODE(6 downto 4) => opmode_z,
        OPMODE(8 downto 7) => opmode_w,
        -- Data: 30-bit (each) input: Data Ports
        A                  => a,
        B                  => std_logic_vector(b),
        C                  => (others=>'0'), -- unused
        CARRYIN            => '0', -- unused
        D                  => d,
        -- Clock Enable: 1-bit (each) input: Clock Enable Inputs
        CEA1               => ce,
        CEA2               => ce,
        CEAD               => ce,
        CEALUMODE          => ce,
        CEB1               => ce,
        CEB2               => ce,
        CEC                => '0', -- unused
        CECARRYIN          => '0', -- unused
        CECTRL             => ce, -- for opmode
        CED                => ce,
        CEINMODE           => ce,
        CEM                => ce, -- TODO : pipereg  CEM(clkena,NUM_INPUT_REG),
        CEP                => ce,
        -- Reset: 1-bit (each) input: Reset
        RSTA               => rst, -- TODO
        RSTALLCARRYIN      => '1', -- unused
        RSTALUMODE         => rst, -- TODO
        RSTB               => rst, -- TODO
        RSTC               => '1', -- unused
        RSTCTRL            => rst, -- TODO
        RSTD               => rst, -- TODO
        RSTINMODE          => rst, -- TODO
        RSTM               => rst, -- TODO
        RSTP               => rst  -- TODO
      );

      dout_i(16*n+15 downto 16*n) <= p(23 downto 8);

    end generate;
  end generate;

  glogic : if WIDTH_SHIFTER_LOGIC/=0 generate
    signal stage0, stage1_in : std_logic_vector(WIDTH_SHIFTER_LOGIC+16-1 downto 0);
    signal shift1 : unsigned(3 downto 0);
    signal stage1_out, stage2_in : std_logic_vector(WIDTH_SHIFTER_LOGIC+4-1 downto 0);
    signal stage1_shift, stage2_shift: integer range 0 to 3;
    signal stage2_out, stage2_out_q: std_logic_vector(WIDTH_SHIFTER_LOGIC-1 downto 0);
  begin

    stage0 <= din_i(din_i'high downto din_i'high-WIDTH_SHIFTER_LOGIC-15);

    gin : if INPUT_REG generate
      process(clk)
      begin
        if rising_edge(clk) then
          if rst='1' then
            shift1 <= (others=>'0');
            stage1_in <= (others=>'0');
          elsif ce='1' then
            shift1 <= shift;
            stage1_in <= stage0;
          end if;
        end if;
      end process;
    else generate
      shift1 <= shift;
      stage1_in <= stage0;
    end generate;

    -- 1. stage of shifter
    stage1_shift <= to_integer(shift1(3 downto 2));
    stage1_out <= stage1_in(WIDTH_SHIFTER_LOGIC+ 3+4*stage1_shift downto 4*stage1_shift);

    gpipe : if PIPE_REG generate
      process(clk)
      begin
        if rising_edge(clk) then
          if rst='1' then
            stage2_shift <= 0;
            stage2_in <= (others=>'0');
          elsif ce='1' then
            stage2_shift <= to_integer(shift1(1 downto 0));
            stage2_in <= stage1_out;
          end if;
        end if;
      end process;
    else generate
      stage2_shift <= to_integer(shift1(1 downto 0));
      stage2_in <= stage1_out;
    end generate;

    -- 2. stage of shifter
    stage2_out <= stage2_in(WIDTH_SHIFTER_LOGIC-1+stage2_shift downto stage2_shift);

    gout : if OUTPUT_REG generate
      process(clk)
      begin
        if rising_edge(clk) then
          if rst='1' then
            stage2_out_q <= (others=>'0');
          elsif ce='1' then
            stage2_out_q <= stage2_out;
          end if;
        end if;
      end process;
    else generate
      stage2_out_q <= stage2_out;
    end generate;

    dout_i(dout_i'high downto dout_i'high-WIDTH_SHIFTER_LOGIC+1) <= stage2_out_q;

  end generate;

  g_lr : if LEFT_SHIFT generate
    dout <= reverse(dout_i(WIDTH_DIN-1 downto 0));
  else generate
    dout <= dout_i(WIDTH_DIN-1 downto 0);
  end generate;

  -- VLD pipeline
  vld_q(0) <= din_vld;
  g_vld: if PIPESTAGES>=1 generate
    gn: for n in 1 to PIPESTAGES generate
      pipereg(vld_q(n), vld_q(n-1), clk, ce, rst);
    end generate;
  end generate;

  dout_vld <= vld_q(PIPESTAGES);

end architecture;
