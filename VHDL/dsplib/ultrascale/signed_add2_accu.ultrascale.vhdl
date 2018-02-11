-------------------------------------------------------------------------------
--! @file       signed_add2_accu.ultrascale.vhdl
--! @author     Fixitfetish
--! @date       09/Feb/2018
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
  use baselib.ieee_extension.all;
library dsplib;
  use dsplib.dsp_pkg_ultrascale.all;

library unisim;
  use unisim.vcomponents.all;

--! @brief This is an implementation of the entity signed_add2_accu
--! for Xilinx UltraScale.
--! A two signed values are added with 48-bit full precision.
--! The results of this operation can be accumulated over several cycles.
--! The addition and accumulation of all inputs is LSB bound.
--!
--! This implementation requires a single DSP48E2 Slice.
--! Refer to Xilinx UltraScale Architecture DSP48E2 Slice, UG579 (v1.5) October 18, 2017.
--!
--! * Input Data A    : 1 signed value, <=48 bits
--! * Input Data Z    : 1 signed value, <=48 bits, only when chain input is disabled
--! * Input Register  : optional, at least one is strongly recommended
--! * Input Chain     : optional, 48 bits, requires injection after NUM_INPUT_REG cycles
--! * Accu Register   : 48 bits, first output register (mandatory)
--! * Rounding        : optional half-up, within DSP cell
--! * Output Data     : 1x signed value, max 48 bits
--! * Output Register : optional, after shift-right and saturation
--! * Output Chain    : optional, 48 bits
--! * Pipeline stages : NUM_INPUT_REG + NUM_OUTPUT_REG
--!
--! Note that with the generic USE_CHAIN_INPUT either the chain input or the Z input
--! can be selected to be added to A and to be accumulated.
--! If accumulation is not required but just summation consider using signed_add2_sum.ultrascale .
--!  
--! The output can be chained with other DSP implementations.
--! @image html signed_add2_accu.ultrascale.svg "" width=1000px

architecture ultrascale of signed_add2_accu is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "signed_add2_accu(ultrascale)";

  -- number of additional A input registers in logic (not within DSP cell)
  constant NUM_IREG_AB_LOGIC : natural := NUM_IREG_AB(LOGIC,NUM_INPUT_REG_A);

  -- number of DSP internal A1/A2 and B1/B2 register stages
  constant NUM_IREG_AB_DSP : natural := NUM_IREG_AB(DSP,NUM_INPUT_REG_A);

  -- DSP internal OPMODE input register - 0 or 1
  constant NUM_IREG_OPMODE_DSP : natural := MINIMUM(NUM_IREG_AB_DSP,1);

  -- number of additional Z input registers in logic (not within DSP cell)
  constant NUM_IREG_Z_LOGIC : natural := NUM_IREG_C(LOGIC,NUM_INPUT_REG_Z);

  -- number of DSP internal C register stages
  constant NUM_IREG_Z_DSP : natural := NUM_IREG_C(DSP,NUM_INPUT_REG_Z);

  -- derived constants
  constant ROUND_ENABLE : boolean := OUTPUT_ROUND and (OUTPUT_SHIFT_RIGHT/=0);
  constant INPUT_WIDTH : natural := a'length;
  constant MAX_GUARD_BITS : natural := ACCU_WIDTH - INPUT_WIDTH;
  constant GUARD_BITS_EVAL : natural := accu_guard_bits(NUM_SUMMAND,MAX_GUARD_BITS,IMPLEMENTATION);
  constant ACCU_USED_WIDTH : natural := INPUT_WIDTH + GUARD_BITS_EVAL;
  constant ACCU_USED_SHIFTED_WIDTH : natural := ACCU_USED_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result'length;

  -- A logic input register pipeline
  type r_a_logic_ireg is
  record
    rst, vld, clr : std_logic;
    a : signed(a'length-1 downto 0);
  end record;
  type array_a_logic_ireg is array(integer range <>) of r_a_logic_ireg;
  signal a_logic_ireg : array_logic_ireg(NUM_IREG_AB_LOGIC downto 0);
  signal ab : signed(MAX_WIDTH_AB-1 downto 0) := (others=>'0');

  -- Z logic input register pipeline
  type array_z_logic_ireg is array(integer range <>) of signed(z'length-1 downto 0);
  signal z_logic_ireg : array_z_logic_ireg(NUM_IREG_Z_LOGIC downto 0);
  signal c : signed(MAX_WIDTH_C-1 downto 0) := (others=>'0');

  -- DSP input register pipeline
  type r_dsp_ireg is
  record
    rst, vld  : std_logic;
    ab        : signed(MAX_WIDTH_AB-1 downto 0);
    opmode_w  : std_logic_vector(1 downto 0);
    opmode_xy : std_logic_vector(3 downto 0);
    opmode_z  : std_logic_vector(2 downto 0);
  end record;
  type array_dsp_ireg is array(integer range <>) of r_dsp_ireg;
  signal ireg : array_dsp_ireg(NUM_IREG_AB_DSP downto 0);

  constant clkena : std_logic := '1'; -- clock enable +++ TODO
  constant reset : std_logic := '0';

  signal clr_q, clr_i : std_logic;
  signal chainin_i, chainout_i : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal accu : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal accu_vld : std_logic := '0';
  signal accu_used : signed(ACCU_USED_WIDTH-1 downto 0);

begin

  -- check input/output length
  assert (a'length<=MAX_WIDTH_AB)
    report "ERROR " & IMPLEMENTATION & ": Summand input A width cannot exceed " & integer'image(MAX_WIDTH_AB)
    severity failure;
  assert (z'length<=MAX_WIDTH_C)
    report "ERROR " & IMPLEMENTATION & ": Summand input Z width cannot exceed " & integer'image(MAX_WIDTH_C)
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

  -- A input pipeline
  a_logic_ireg(NUM_IREG_AB_LOGIC).rst <= rst;
  a_logic_ireg(NUM_IREG_AB_LOGIC).vld <= vld;
  a_logic_ireg(NUM_IREG_AB_LOGIC).clr <= clr;
  a_logic_ireg(NUM_IREG_AB_LOGIC) <= a;
  g_ab : if NUM_IREG_AB_LOGIC>=1 generate
  begin
    gn : for n in 1 to NUM_IREG_AB_LOGIC generate
    begin
      a_logic_ireg(n-1) <= a_logic_ireg(n) when (rising_edge(clk) and clkena='1');
    end generate;
  end generate;

  -- Z input pipeline
  z_logic_ireg(NUM_IREG_Z_LOGIC).z <= z;
  g_z : if NUM_IREG_Z_LOGIC>=1 generate
  begin
    gn : for n in 1 to NUM_IREG_Z_LOGIC generate
    begin
      z_logic_ireg(n-1) <= z_logic_ireg(n) when (rising_edge(clk) and clkena='1');
    end generate;
  end generate;

  -- support clr='1' when vld='0'
  p_clr : process(clk)
  begin
    if rising_edge(clk) then
      if a_logic_ireg(0).clr='1' and a_logic_ireg(0).vld='0' then
        clr_q<='1';
      elsif a_logic_ireg(0).vld='1' then
        clr_q<='0';
      end if;
    end if;
  end process;
  clr_i <= a_logic_ireg(0).clr or clr_q;

  -- control signal inputs
  ireg(NUM_IREG_AB_DSP).rst <= a_logic_ireg(0).rst;
  ireg(NUM_IREG_AB_DSP).vld <= a_logic_ireg(0).vld;
  ireg(NUM_IREG_AB_DSP).ab  <= resize(a_logic_ireg(0),MAX_WIDTH_AB); -- LSB bound data input

  -- DSP multiplexer control
  ireg(NUM_IREG_AB_DSP).opmode_w  <= "10" when clr_i='1' else -- add rounding constant with clear signal
                                     "00" when NUM_OUTPUT_REG=0 else -- add zero when P register disabled
                                     "01"; -- feedback P accumulator register output
  ireg(NUM_IREG_AB_DSP).opmode_xy <= "0011"; -- constant, always A:B, 48-bit wide
  ireg(NUM_IREG_AB_DSP).opmode_z  <= "001" when USE_CHAIN_INPUT else "011"; -- either chain input or C

  -- second input register stage
  g_dsp2in : if NUM_IREG_AB_DSP>=2 generate
  begin
    ireg(1).rst <= ireg(2).rst when rising_edge(clk);
    ireg(1).vld <= ireg(2).vld when rising_edge(clk);
    ireg(1).opmode_w  <= ireg(2).opmode_w  when rising_edge(clk); 
    ireg(1).opmode_xy <= ireg(2).opmode_xy when rising_edge(clk); 
    ireg(1).opmode_z  <= ireg(2).opmode_z  when rising_edge(clk); 
    -- the following register are located within the DSP cell
    ireg(1).ab <= ireg(2).ab; 
  end generate;

  -- first input register stage
  g_dsp1in : if NUM_IREG_AB_DSP>=1 generate
  begin
    ireg(0).rst <= ireg(1).rst when rising_edge(clk);
    ireg(0).vld <= ireg(1).vld when rising_edge(clk);
    -- the following register are located within the DSP cell
    ireg(0).opmode_w  <= ireg(1).opmode_w; 
    ireg(0).opmode_xy <= ireg(1).opmode_xy; 
    ireg(0).opmode_z  <= ireg(1).opmode_z; 
    ireg(0).ab <= ireg(1).ab; 
  end generate;

  g_chainin : if USE_CHAIN_INPUT generate
  begin
    -- use only LSBs of chain input
    chainin_i <= std_logic_vector(chainin(ACCU_WIDTH-1 downto 0));
    c <= (others=>'0');
  end generate;

  g_bin : if not USE_CHAIN_INPUT generate
  begin
    chainin_i <= (others=>'0');
    -- Resize Z to DSP input C 
    c <= resize(z_logic_ireg(0),MAX_WIDTH_C);
  end generate;

  dsp : DSP48E2
  generic map(
    -- Feature Control Attributes: Data Path Selection
    AMULTSEL                  => "A", -- don't use preadder feature
    A_INPUT                   => "DIRECT", -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
    BMULTSEL                  => "B", --Selects B input to multiplier (B,AD)
    B_INPUT                   => "DIRECT", -- Selects B input source,"DIRECT"(B port)or "CASCADE"(BCIN port)
    PREADDINSEL               => "A", -- Selects input to preadder (A, B)
    RND                       => RND(ROUND_ENABLE,OUTPUT_SHIFT_RIGHT), -- Rounding Constant
    USE_MULT                  => "NONE", -- Select multiplier usage (MULTIPLY,DYNAMIC,NONE)
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
    ACASCREG                  => NUM_IREG_AB_DSP,-- 0,1 or 2
    ADREG                     => 0,-- 0 or 1
    ALUMODEREG                => 0, -- 0 or 1
    AREG                      => NUM_IREG_AB_DSP,-- 0,1 or 2
    BCASCREG                  => NUM_IREG_AB_DSP,-- 0,1 or 2
    BREG                      => NUM_IREG_AB_DSP,-- 0,1 or 2
    CARRYINREG                => 1,
    CARRYINSELREG             => 1,
    CREG                      => NUM_IREG_Z_DSP, -- 0 or 1
    DREG                      => 0,-- 0 or 1
    INMODEREG                 => 0, -- 0 or 1
    MREG                      => 0, -- 0 or 1
    OPMODEREG                 => NUM_IREG_OPMODE_DSP, -- 0 or 1
    PREG                      => PREG(NUM_OUTPUT_REG) -- 0 or 1
  ) 
  port map(
    CLK                => clk,
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
    -- Control: 4-bit (each) input: Control Inputs/Status Bits
    CARRYINSEL         => "000", -- unused
    CARRYIN            => '0', -- unused
    CECARRYIN          => '0', -- unused
    RSTALLCARRYIN      => '1', -- unused
    -- control input
    ALUMODE            => "0000", -- always P = Z + (W + X + Y + CIN)
    INMODE             => (others=>'0'), -- irrelevant
    OPMODE(3 downto 0) => ireg(0).opmode_xy, -- XY = A:B, 48-bit wide
    OPMODE(6 downto 4) => ireg(0).opmode_z, -- either chainin or C
    OPMODE(8 downto 7) => ireg(0).opmode_w, -- either RND or P
    RSTALUMODE         => reset, -- TODO
    RSTCTRL            => reset, -- TODO
    RSTINMODE          => reset, -- TODO
    CEALUMODE          => clkena,
    CECTRL             => clkena, -- for opmode
    CEINMODE           => clkena,
    -- input A
    A                  => std_logic_vector(ireg(0).ab(MAX_WIDTH_AB-1 downto MAX_WIDTH_B)), -- MSBs
    RSTA               => reset, -- TODO
    CEA1               => clkena,
    CEA2               => clkena,
    -- input B
    B                  => std_logic_vector(ireg(0).ab(MAX_WIDTH_B-1 downto 0)), -- LSBs
    RSTB               => reset, -- TODO
    CEB1               => clkena,
    CEB2               => clkena,
    -- input C
    C                  => std_logic_vector(c),
    RSTC               => reset, -- TODO
    CEC                => clkena,
    -- input D/AD
    D                  => (others=>'0'), -- unused,
    RSTD               => '1', -- unused
    CED                => '0', -- unused
    CEAD               => '0', -- unused
    -- pipeline M
    RSTM               => '1', -- unused
    CEM                => '0', -- unused
    -- output P
    P                  => accu,
    RSTP               => reset,  -- TODO
    CEP                => ireg(0).vld,
    -- Data: 4-bit (each) output: Data Ports
    CARRYOUT           => open,
    XOROUT             => open,
    -- Cascade: 30-bit (each) input: Cascade Ports
    ACIN               => (others=>'0'), -- unused
    BCIN               => (others=>'0'), -- unused
    CARRYCASCIN        => '0', -- unused
    MULTSIGNIN         => '0', -- unused
    PCIN               => chainin_i
  );

  chainout(ACCU_WIDTH-1 downto 0) <= signed(chainout_i);
  g_chainout : for n in ACCU_WIDTH to (chainout'length-1) generate
    -- sign extension (for simulation and to avoid warnings)
    chainout(n) <= chainout_i(ACCU_WIDTH-1);
  end generate;

  -- pipelined valid signal
  g_dspreg_on : if NUM_OUTPUT_REG>=1 generate
    accu_vld <= ireg(0).vld when rising_edge(clk);
  end generate;
  g_dspreg_off : if NUM_OUTPUT_REG<=0 generate
    accu_vld <= ireg(0).vld;
  end generate;

  -- cut off unused sign extension bits
  -- (This reduces the logic consumption in the following steps when rounding,
  --  saturation and/or overflow detection is enabled.)
  accu_used <= signed(accu(ACCU_USED_WIDTH-1 downto 0));

  -- right-shift and clipping
  i_out : entity dsplib.signed_output_logic
  generic map(
    PIPELINE_STAGES    => NUM_OUTPUT_REG-1, -- consider DSP cell output register
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => false, -- rounding already done within DSP cell!
    OUTPUT_CLIP        => OUTPUT_CLIP,
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
  )
  port map (
    clk         => clk,
    rst         => rst,
    dsp_out     => accu_used,
    dsp_out_vld => accu_vld,
    result      => result,
    result_vld  => result_vld,
    result_ovf  => result_ovf
  );

  -- report constant number of pipeline register stages
  PIPESTAGES <= NUM_INPUT_REG_A + NUM_OUTPUT_REG;

end architecture;

