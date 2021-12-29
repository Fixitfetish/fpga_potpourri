-------------------------------------------------------------------------------
--! @file       signed_preadd_mult1add1.ultrascale.vhdl
--! @author     Fixitfetish
--! @date       12/Dec/2021
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
library dsplib;
  use dsplib.dsp_pkg_ultrascale.all;

library unisim;
  use unisim.vcomponents.all;

--! @brief This is an implementation of the entity signed_preadd_mult1add1
--! for Xilinx UltraScale.
--! Multiply a sum of two signed (+/-XA +/-XB) with a signed Y and accumulate results.
--!
--! This implementation requires a single DSP48E2 Slice.
--! Refer to Xilinx UltraScale Architecture DSP48E2 Slice, UG579 (v1.11) August 30, 2021
--!
--! * Input Data X    : 2 signed values, each max 26 bits
--! * Input Data Y    : 1 signed value, max 18 bits
--! * Input Register  : optional, at least one is strongly recommended
--! * Input Chain     : optional, 48 bits
--! * Accu Register   : 48 bits, first output register (strongly recommended in most cases)
--! * Rounding        : optional half-up, within DSP cell
--! * Output Data     : 1x signed value, max 48 bits
--! * Output Register : optional, after shift-right and saturation
--! * Output Chain    : optional, 48 bits
--! * Pipeline stages : NUM_INPUT_REG + NUM_OUTPUT_REG
--!
--! If NUM_OUTPUT_REG=0 then the accumulator register P is disabled.
--! This configuration is not recommended but might be useful when DSP cells are chained.
--!
--! Dependent on the preadder input mode the input data might need to be negated
--! using additional logic. Note that negation of the most negative value is
--! critical because an additional MSB is required.
--! In this implementation this is not an issue because the inputs xa and xb are
--! limited to 26 bits but the preadder input can be 27 bits wide.
--!
--! | PREADD XA | PREADD XB | Input D | Input A | Preadd +/- | Operation  | Comment
--! |:---------:|:---------:|:-------:|:-------:|:----------:|:----------:|:-------
--! | ADD       | ADD       |    XA   |   XB    |   '0' (+)  |    D  +  A | ---
--! | ADD       | SUBTRACT  |    XA   |   XB    |   '1' (-)  |    D  -  A | ---
--! | ADD       | DYNAMIC   |    XA   |   XB    |   sub_xb   |    D +/- A | ---
--! | SUBTRACT  | ADD       |    XB   |   XA    |   '1' (-)  |    D  -  A | ---
--! | SUBTRACT  | SUBTRACT  |   -XB   |   XA    |   '1' (-)  |   -D  -  A | additional logic required
--! | SUBTRACT  | DYNAMIC   |   -XA   |   XB    |   sub_xb   |   -D +/- A | additional logic required
--! | DYNAMIC   | ADD       |    XB   |   XA    |   sub_xa   |    D +/- A | ---
--! | DYNAMIC   | SUBTRACT  |   -XB   |   XA    |   sub_xa   |   -D +/- A | additional logic required
--! | DYNAMIC   | DYNAMIC   | +/-XA   |   XB    |   sub_xb   | +/-D +/- A | additional logic required
--!
--! This implementation can be chained multiple times.
--! If the chain input is used then the
--! * the accumulator feature is disabled, i.e. CLR input is ignored
--! * the DSP internal rounding is disabled, i.e. the rounding requires additional logic
--!
--! @image html signed_preadd_mult1add1.ultrascale.svg "" width=1000px
--!
architecture ultrascale of signed_preadd_mult1add1 is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "signed_preadd_mult1add1(ultrascale)";

  -- number input registers within DSP and in LOGIC
  constant NUM_IREG_DSP : natural := NUM_IREG(DSP,NUM_INPUT_REG_XY);
  constant NUM_IREG_LOGIC : natural := NUM_IREG(LOGIC,NUM_INPUT_REG_XY);

  constant NUM_IREG_C_LOGIC : natural := NUM_IREG_C(LOGIC,NUM_INPUT_REG_Z);

  alias NUM_INPUT_REG is NUM_INPUT_REG_XY;

  -- first data input register is supported, in the first stage only
  function AREG(n:natural) return natural is
  begin
    if n=0 then return 0; else return 1; end if;
  end function;

  -- second data input register is supported, in the third stage only
  function ADREG(n:natural) return natural is
  begin
    if n<=2 then return 0; else return 1; end if;
  end function;

  -- two data input registers are supported, the first and the third stage
  function BREG(n:natural) return natural is
  begin 
    if    n<=1 then return n;
    elsif n=2  then return 1; -- second input register uses MREG
    else            return 2;
    end if;
  end function;

  -- derived constants
  constant ROUND_ENABLE : boolean := OUTPUT_ROUND and (OUTPUT_SHIFT_RIGHT/=0);
  constant PRODUCT_WIDTH : natural := MAXIMUM(xa'length,xb'length) + 1 + y'length;
  constant MAX_GUARD_BITS : natural := ACCU_WIDTH - PRODUCT_WIDTH;
  constant GUARD_BITS_EVAL : natural := accu_guard_bits(NUM_SUMMAND,MAX_GUARD_BITS,IMPLEMENTATION);
  constant ACCU_USED_WIDTH : natural := PRODUCT_WIDTH + GUARD_BITS_EVAL;
  constant ACCU_USED_SHIFTED_WIDTH : natural := ACCU_USED_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result'length;

  constant clkena : std_logic := '1'; -- clock enable

  type r_pipe is
  record
    rst, clr, vld : std_logic;
    y  : signed(y'length-1 downto 0);
  end record;
  constant PIPE_DEFAULT : r_pipe := (
    rst => '1',
    clr => '1',
    vld => '0',
    y => (others=>'-')
  );
  type array_pipe is array(integer range <>) of r_pipe;
  signal pipe : array_pipe(NUM_IREG_LOGIC downto 0) := (others=>PIPE_DEFAULT);

  type array_c is array(integer range <>) of signed(z'length-1 downto 0);
  signal pipe_c : array_c(NUM_IREG_C_LOGIC downto 0) := (others=>(others=>'-'));

  type r_dsp_in is
  record
    rst, vld, clr : std_logic;
    inmode : std_logic_vector(4 downto 0);
    opmode : std_logic_vector(8 downto 0);
    a : signed(MAX_WIDTH_A-1 downto 0);
    b : signed(MAX_WIDTH_B-1 downto 0);
    c : signed(MAX_WIDTH_C-1 downto 0);
    d : signed(MAX_WIDTH_D-1 downto 0);
  end record;
  signal dsp_in : r_dsp_in;
  alias opmode_xy is dsp_in.opmode(3 downto 0);
  alias opmode_z  is dsp_in.opmode(6 downto 4);
  alias opmode_w  is dsp_in.opmode(8 downto 7);

  signal dsp_feed : r_dsp_in;

  signal clr_q, clr_i : std_logic;
  signal chainin_i, chainout_i : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal accu : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal accu_vld : std_logic := '0';
  signal accu_used : signed(ACCU_USED_WIDTH-1 downto 0);

begin

  -- check input/output length
  assert (y'length<=MAX_WIDTH_B)
    report "ERROR " & IMPLEMENTATION & ": " & 
           "Multiplier input Y width cannot exceed " & integer'image(MAX_WIDTH_B)
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

  -- Pipeline of factor Y and control signals
  pipe(NUM_IREG_LOGIC).rst <= rst;
  pipe(NUM_IREG_LOGIC).clr <= clr;
  pipe(NUM_IREG_LOGIC).vld <= vld;
  pipe(NUM_IREG_LOGIC).y <= y;
  g_pipe : if NUM_IREG_LOGIC>=1 generate
  begin
    process(clk)
    begin
      if rising_edge(clk) then
        if rst/='0' then
          pipe <= (others=>PIPE_DEFAULT);
        elsif clkena='1' then
          pipe(NUM_IREG_LOGIC-1 downto 0) <= pipe(NUM_IREG_LOGIC downto 1);
        end if;
      end if;
    end process;
  end generate;

  -- Pipeline of input Z
  pipe_c(NUM_IREG_C_LOGIC) <= z;
  g_pipe_c : if NUM_IREG_C_LOGIC>=1 generate
  begin
    process(clk)
    begin
      if rising_edge(clk) then
        if rst/='0' then
          pipe_c <= (others=>(others=>'-'));
        elsif clkena='1' then
          pipe_c(NUM_IREG_C_LOGIC-1 downto 0) <= pipe_c(NUM_IREG_C_LOGIC downto 1);
        end if;
      end if;
    end process;
  end generate;

  dsp_in.rst <= pipe(0).rst;
  dsp_in.clr <= pipe(0).clr;
  dsp_in.vld <= pipe(0).vld;
  dsp_in.b   <= resize(pipe(0).y, MAX_WIDTH_B);
  dsp_in.c   <= resize(pipe_c(0), MAX_WIDTH_C);

  -- Pipeline and control logic of inputs XA and XB
  i_preadd : entity work.preadd_input_logic_ultrascale
  generic map(
    PREADDER_INPUT_A  => PREADDER_INPUT_XA,
    PREADDER_INPUT_D  => PREADDER_INPUT_XB,
    NUM_INPUT_REG     => NUM_IREG_LOGIC
  )
  port map(
    clk        => clk,
    rst        => rst,
    clkena     => clkena,
    sub_a      => sub_xa,
    sub_d      => sub_xb,
    a          => xa,
    d          => xb,
    a_dsp      => dsp_in.a,
    d_dsp      => dsp_in.d,
    inmode     => dsp_in.inmode(3 downto 0),
    PIPESTAGES => open
  );


  -- support clr='1' when vld='0'
  -- TODO : clkena !
  p_clr : process(clk)
  begin
    if rising_edge(clk) then
      if rst/='0' then
        clr_q<='1';
      elsif dsp_in.clr='1' and dsp_in.vld='0' then
        clr_q<='1';
      elsif dsp_in.vld='1' then
        clr_q<='0';
      end if;
    end if;
  end process;
  clr_i <= dsp_in.clr or clr_q;

  -- control signal inputs
  dsp_in.inmode(4) <= '0'; -- BREG controlled input
  opmode_xy <= "0101"; -- constant, always multiplier result M
  opmode_z  <= "001" when USE_CHAIN_INPUT else -- PCIN
               "011"; -- Input C
  opmode_w  <= "11" when USE_CHAIN_INPUT else -- input C
               "10" when clr_i='1' else -- add rounding constant with clear signal
               "00" when NUM_OUTPUT_REG=0 else -- add zero when P register disabled
               "01"; -- feedback P accumulator register output


  i_dsp_in_logic : entity work.dsp_input_logic_ultrascale
  generic map(
    NUM_INPUT_REG => NUM_IREG_DSP
  )
  port map(
    clk         => clk,
    clkena      => clkena,
    src_rst     => dsp_in.rst,
    src_vld     => dsp_in.vld,
    src_inmode  => dsp_in.inmode,
    src_opmode  => dsp_in.opmode,
    src_a       => dsp_in.a,
    src_b       => dsp_in.b,
    src_c       => dsp_in.c,
    src_d       => dsp_in.d,
    dest_rst    => dsp_feed.rst,
    dest_vld    => dsp_feed.vld,
    dest_inmode => dsp_feed.inmode,
    dest_opmode => dsp_feed.opmode,
    dest_a      => dsp_feed.a,
    dest_b      => dsp_feed.b,
    dest_c      => dsp_feed.c,
    dest_d      => dsp_feed.d
  );
  dsp_feed.clr <= '-'; -- irrelevant

  -- use only LSBs of chain input
  chainin_i <= std_logic_vector(chainin(ACCU_WIDTH-1 downto 0));

  i_dsp : DSP48E2
  generic map(
    -- Feature Control Attributes: Data Path Selection
    AMULTSEL                  => "AD", -- use preadder for subtract feature
    A_INPUT                   => "DIRECT", -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
    BMULTSEL                  => "B", --Selects B input to multiplier (B,AD)
    B_INPUT                   => "DIRECT", -- Selects B input source,"DIRECT"(B port)or "CASCADE"(BCIN port)
    PREADDINSEL               => "A", -- Selects input to preadder (A, B)
    RND                       => RND(ROUND_ENABLE,OUTPUT_SHIFT_RIGHT), -- Rounding Constant
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
    ACASCREG                  => AREG(NUM_INPUT_REG),-- 0,1 or 2
    ADREG                     => ADREG(NUM_INPUT_REG),-- 0 or 1
    ALUMODEREG                => INMODEREG(NUM_INPUT_REG), -- 0 or 1
    AREG                      => AREG(NUM_INPUT_REG),-- 0,1 or 2
    BCASCREG                  => BREG(NUM_INPUT_REG),-- 0,1 or 2
    BREG                      => BREG(NUM_INPUT_REG),-- 0,1 or 2
    CARRYINREG                => 1,
    CARRYINSELREG             => 1,
    CREG                      => NUM_IREG_C(DSP,NUM_INPUT_REG_Z),
    DREG                      => AREG(NUM_INPUT_REG),-- 0 or 1
    INMODEREG                 => INMODEREG(NUM_INPUT_REG), -- 0 or 1
    MREG                      => MREG(NUM_INPUT_REG), -- 0 or 1
    OPMODEREG                 => INMODEREG(NUM_INPUT_REG), -- 0 or 1
    PREG                      => PREG(NUM_OUTPUT_REG) -- 0 or 1
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
    ALUMODE            => "0000", -- always P = Z + (W + X + Y + CIN)
    CARRYINSEL         => "000", -- unused
    CLK                => clk,
    INMODE             => dsp_feed.inmode,
    OPMODE             => dsp_feed.opmode,
    -- Data: 30-bit (each) input: Data Ports
    A                  => std_logic_vector(dsp_feed.a),
    B                  => std_logic_vector(dsp_feed.b),
    C                  => std_logic_vector(dsp_feed.c),
    CARRYIN            => '0', -- unused
    D                  => std_logic_vector(dsp_feed.d),
    -- Clock Enable: 1-bit (each) input: Clock Enable Inputs
    CEA1               => clkena,
    CEA2               => clkena,
    CEAD               => clkena,
    CEALUMODE          => clkena,
    CEB1               => clkena,
    CEB2               => clkena,
    CEC                => clkena,
    CECARRYIN          => '0', -- unused
    CECTRL             => clkena, -- for opmode
    CED                => clkena,
    CEINMODE           => clkena,
    CEM                => CEM(clkena,NUM_INPUT_REG),
    CEP                => dsp_feed.vld,
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

  chainout(ACCU_WIDTH-1 downto 0) <= signed(chainout_i);
  g_chainout : for n in ACCU_WIDTH to (chainout'length-1) generate
    -- sign extension (for simulation and to avoid warnings)
    chainout(n) <= chainout_i(ACCU_WIDTH-1);
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
  accu_used <= signed(accu(ACCU_USED_WIDTH-1 downto 0));

  -- right-shift and clipping
  i_out : entity dsplib.signed_output_logic
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
    dsp_out     => accu_used,
    dsp_out_vld => accu_vld,
    result      => result,
    result_vld  => result_vld,
    result_ovf  => result_ovf
  );

  -- report constant number of pipeline register stages
  PIPESTAGES <= NUM_INPUT_REG + NUM_OUTPUT_REG;

end architecture;
