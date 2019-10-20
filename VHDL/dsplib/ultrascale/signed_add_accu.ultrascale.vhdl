-------------------------------------------------------------------------------
--! @file       signed_add_accu.ultrascale.vhdl
--! @author     Fixitfetish
--! @date       19/Oct/2019
--! @version    0.10
--! @note       VHDL-2008
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
  use baselib.ieee_extension_types.all;
  use baselib.pipereg_pkg.all;
library dsplib;
  use dsplib.dsp_pkg_ultrascale.all;

library unisim;
  use unisim.vcomponents.all;

--! @brief This is an implementation of the entity signed_add_accu
--! for Xilinx UltraScale.
--! A two signed values are added and the resulting sums are accumulated over several cycles.
--!
--! The addition and accumulation of all inputs is LSB bound.
--! The maximum width of the input summands and the accumulator is 48 bits.
--! If the input and accumulator width is not larger than 24 then the operation can be done twice per DSP cell in SIMD mode.
--! If the input and accumulator width is not larger than 12 then the operation can be done four times per DSP cell in SIMD mode.
--!
--! This implementation requires DSP48E2 Slices.
--! Refer to Xilinx UltraScale Architecture DSP48E2 Slice, UG579 (v1.5) October 18, 2017.
--!
--! * Input Data A    : signed vector, max width of elements is 48 bits
--! * Input Data Z    : signed vector, max width of elements is 48 bits
--! * Input Register  : optional, at least one is strongly recommended
--! * Input Chain     : not supported
--! * Accu Register   : max 48 bits, first output register (mandatory)
--! * Rounding        : optional half-up, within DSP cell
--! * Output Data     : signed vector, max width of elements is 48 bits
--! * Output Register : optional, after shift-right and saturation
--! * Output Chain    : not supported
--! * Pipeline stages : NUM_INPUT_REG_A + NUM_OUTPUT_REG
--!
--! @image html signed_add_accu.ultrascale.svg "" width=1000px
--!
architecture ultrascale of signed_add_accu is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "signed_add_accu(ultrascale)";

  -- TODO : Chain input/output problems
  -- * dependent on number of DSP cell used multiple chain inputs required !?
  -- * how to handle SIMD mode in connection with chain input
  constant USE_CHAIN_INPUT : boolean := false;

  -- width of A inputs
  constant A_WIDTH : positive := a(a'low)'length;

  -- width of Z inputs
  constant Z_WIDTH : positive := z(z'low)'length;

  -- largest input width, i.e. maximum width of inputs A and Z
  constant MAX_INPUT_WIDTH : positive := MAXIMUM(A_WIDTH,Z_WIDTH);

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
  constant SIMD_USED_WIDTH : positive := MAX_INPUT_WIDTH + GUARD_BITS;
  constant SIMD : natural := SIMD_FACTOR(MAX_INPUT_WIDTH, SIMD_USED_WIDTH); -- 1, 2 or 4
  constant SIMD_WIDTH : positive := ACCU_WIDTH / SIMD; -- 48, 24 or 12
  constant SIMD_USED_SHIFTED_WIDTH : natural := SIMD_USED_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result(result'low)'length;

  constant NUM_DSP_CELLS : positive := (NUM_ACCU+SIMD-1) / SIMD; -- ceil(NUM_ACCU/SIMD)

  -- A logic input register pipeline
  type r_a_logic_ireg is
  record
    rst, vld, clr : std_logic;
    aux  : std_logic_vector(NUM_AUXILIARY_BITS-1 downto 0);
--    a    : a'subtype; -- VIVADO 2018.3 problem with signal declaration below : [Synth 8-318] illegal unconstrained array declaration 'a_logic_ireg'
    a    : signed_vector(0 to NUM_ACCU-1)(A_WIDTH-1 downto 0);
  end record;
  type array_a_logic_ireg is array(integer range <>) of r_a_logic_ireg;
  signal a_logic_ireg : array_a_logic_ireg(NUM_IREG_AB_LOGIC downto 0);
  signal ab : slv_array(0 to NUM_DSP_CELLS-1)(MAX_WIDTH_AB-1 downto 0) := (others=>(others=>'0'));

  -- Z logic input register pipeline
  type r_z_logic_ireg is
  record
    z : signed_vector(0 to NUM_ACCU-1)(Z_WIDTH-1 downto 0);
  end record;
  type array_z_logic_ireg is array(integer range <>) of r_z_logic_ireg;
  signal z_logic_ireg : array_z_logic_ireg(NUM_IREG_Z_LOGIC downto 0);
  signal c : slv_array(0 to NUM_DSP_CELLS-1)(MAX_WIDTH_C-1 downto 0) := (others=>(others=>'0'));

  -- DSP input register pipeline
  type r_dsp_ireg is
  record
    rst, vld  : std_logic;
    aux       : std_logic_vector(NUM_AUXILIARY_BITS-1 downto 0);
    alumode   : std_logic_vector(3 downto 0);
    opmode_w  : std_logic_vector(1 downto 0);
    opmode_xy : std_logic_vector(3 downto 0);
    opmode_z  : std_logic_vector(2 downto 0);
  end record;
  type array_dsp_ireg is array(integer range <>) of r_dsp_ireg;
  signal ireg : array_dsp_ireg(NUM_IREG_AB_DSP downto 0);

  constant reset : std_logic := '0';

  signal clr_q, clr_i : std_logic;
  signal p : slv_array(0 to NUM_DSP_CELLS-1)(ACCU_WIDTH-1 downto 0);
  signal accu : slv_array(0 to NUM_ACCU-1)(SIMD_WIDTH-1 downto 0);
  signal accu_vld : std_logic := '0';
  signal accu_aux : std_logic_vector(NUM_AUXILIARY_BITS-1 downto 0);
  signal accu_used : signed_vector(0 to NUM_ACCU-1)(SIMD_USED_WIDTH-1 downto 0);

  -- temporary internal signals
  signal result_i : signed_vector(0 to NUM_ACCU-1)(OUTPUT_WIDTH-1 downto 0);
  signal result_vld_i : std_logic_vector(0 to NUM_ACCU-1);
  signal result_aux_i : slv_array(0 to NUM_ACCU-1)(NUM_AUXILIARY_BITS-1 downto 0);

begin

  -- check input/output length
  assert (A_WIDTH<=MAX_WIDTH_AB)
    report "ERROR " & IMPLEMENTATION & ": Summand input A width cannot exceed " & integer'image(MAX_WIDTH_AB)
    severity failure;
  assert (Z_WIDTH<=MAX_WIDTH_C)
    report "ERROR " & IMPLEMENTATION & ": Summand input Z width cannot exceed " & integer'image(MAX_WIDTH_C)
    severity failure;

  assert OUTPUT_WIDTH<SIMD_USED_SHIFTED_WIDTH or not(OUTPUT_CLIP or OUTPUT_OVERFLOW)
    report "ERROR " & IMPLEMENTATION & ": " &
           "More guard bits required for saturation/clipping and/or overflow detection."
    severity failure;

  -- A input pipeline
  a_logic_ireg(NUM_IREG_AB_LOGIC).rst <= rst;
  a_logic_ireg(NUM_IREG_AB_LOGIC).clr <= clr;
  a_logic_ireg(NUM_IREG_AB_LOGIC).vld <= vld;
  a_logic_ireg(NUM_IREG_AB_LOGIC).aux <= aux;
  a_logic_ireg(NUM_IREG_AB_LOGIC).a <= a;
  g_a_ireg_logic : if NUM_IREG_AB_LOGIC>=1 generate
  begin
    p_ce : process(clk)
    begin
      if rising_edge(clk) then
        for n in 1 to NUM_IREG_AB_LOGIC loop
          if rst/='0' then
            a_logic_ireg(n-1).vld <= '0';
            a_logic_ireg(n-1).clr <= '1';
            a_logic_ireg(n-1).aux <= (others=>'0');
          elsif clkena='1' then
            a_logic_ireg(n-1) <= a_logic_ireg(n);
          end if;
        end loop;
      end if;
    end process;
  end generate;

  -- Z input pipeline
  z_logic_ireg(NUM_IREG_Z_LOGIC).z <= z;
  g_z_ireg_logic : if NUM_IREG_Z_LOGIC>=1 generate
  begin
    p_ce : process(clk)
    begin
      if rising_edge(clk) then
        for n in 1 to NUM_IREG_Z_LOGIC loop
          if clkena='1' then
            z_logic_ireg(n-1) <= z_logic_ireg(n);
          end if;
        end loop;
      end if;
    end process;
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
  ireg(NUM_IREG_AB_DSP).aux <= a_logic_ireg(0).aux;

  g_accu_in : for n in 0 to NUM_ACCU-1 generate
    constant d : natural := n/SIMD; -- DSP cell index
    constant s : natural := n - d*SIMD; -- SIMD index
  begin
    -- LSB bound data input
    ab(d)((s+1)*SIMD_WIDTH-1 downto s*SIMD_WIDTH) <= std_logic_vector(resize(a_logic_ireg(0).a(n),SIMD_WIDTH));
     c(d)((s+1)*SIMD_WIDTH-1 downto s*SIMD_WIDTH) <= std_logic_vector(resize(z_logic_ireg(0).z(n),SIMD_WIDTH));
  end generate;

  -- DSP multiplexer control
  ireg(NUM_IREG_AB_DSP).alumode   <= "0000"; -- always P = Z + (W + X + Y + CIN)
  ireg(NUM_IREG_AB_DSP).opmode_w  <= "10" when clr_i='1' else -- add rounding constant with clear signal
                                     "01"; -- feedback P accumulator register output
  ireg(NUM_IREG_AB_DSP).opmode_xy <= "1111"; -- x = A:B 48-bit wide , y = C
  ireg(NUM_IREG_AB_DSP).opmode_z  <= "001" when USE_CHAIN_INPUT else "000"; -- either chain input or ZEROS

  -- second input register stage
  g_ab_dsp_ireg2 : if NUM_IREG_AB_DSP>=2 generate
  begin
    pipereg(xout=>ireg(1).rst, xin=>ireg(2).rst, clk=>clk, ce=>clkena, rst=>rst, rstval=>'1');
    pipereg(xout=>ireg(1).vld, xin=>ireg(2).vld, clk=>clk, ce=>clkena, rst=>rst);
    pipereg(xout=>ireg(1).aux, xin=>ireg(2).aux, clk=>clk, ce=>clkena);
    pipereg(xout=>ireg(1).alumode, xin=>ireg(2).alumode, clk=>clk, ce=>clkena);
    pipereg(xout=>ireg(1).opmode_w, xin=>ireg(2).opmode_w, clk=>clk, ce=>clkena);
    pipereg(xout=>ireg(1).opmode_xy, xin=>ireg(2).opmode_xy, clk=>clk, ce=>clkena);
    pipereg(xout=>ireg(1).opmode_z, xin=>ireg(2).opmode_z, clk=>clk, ce=>clkena);
  end generate;

  -- first input register stage
  g_ab_dsp_ireg1 : if NUM_IREG_AB_DSP>=1 generate
  begin
    pipereg(xout=>ireg(0).rst, xin=>ireg(1).rst, clk=>clk, ce=>clkena, rst=>rst, rstval=>'1');
    pipereg(xout=>ireg(0).vld, xin=>ireg(1).vld, clk=>clk, ce=>clkena, rst=>rst);
    pipereg(xout=>ireg(0).aux, xin=>ireg(1).aux, clk=>clk, ce=>clkena, rst=>rst);
    -- the following register are located within the DSP cell
    ireg(0).alumode   <= ireg(1).alumode; 
    ireg(0).opmode_w  <= ireg(1).opmode_w; 
    ireg(0).opmode_xy <= ireg(1).opmode_xy; 
    ireg(0).opmode_z  <= ireg(1).opmode_z; 
  end generate;

  g_dsp : for n in 0 to NUM_DSP_CELLS-1 generate
  dsp : DSP48E2
  generic map(
    -- Feature Control Attributes: Data Path Selection
    AMULTSEL                  => "A", -- don't use preadder feature
    A_INPUT                   => "DIRECT", -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
    BMULTSEL                  => "B", --Selects B input to multiplier (B,AD)
    B_INPUT                   => "DIRECT", -- Selects B input source,"DIRECT"(B port)or "CASCADE"(BCIN port)
    PREADDINSEL               => "A", -- Selects input to preadder (A, B)
    RND                       => RND(ROUND_ENABLE,OUTPUT_SHIFT_RIGHT,SIMD), -- Rounding Constant
    USE_MULT                  => "NONE", -- Select multiplier usage (MULTIPLY,DYNAMIC,NONE)
    USE_SIMD                  => USE_SIMD(SIMD), -- SIMD selection(ONE48, FOUR12, TWO24)
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
    ALUMODEREG                => NUM_IREG_OPMODE_DSP, -- 0 or 1
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
    PCOUT              => open, --chainout_i, TODO
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
    ALUMODE            => ireg(0).alumode,
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
    A                  => ab(n)(MAX_WIDTH_AB-1 downto MAX_WIDTH_B), -- MSBs
    RSTA               => reset, -- TODO
    CEA1               => clkena,
    CEA2               => clkena,
    -- input B
    B                  => ab(n)(MAX_WIDTH_B-1 downto 0), -- LSBs
    RSTB               => reset, -- TODO
    CEB1               => clkena,
    CEB2               => clkena,
    -- input C
    C                  => c(n),
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
    P                  => p(n),
    RSTP               => reset,  -- TODO
    CEP                => (clkena and ireg(0).vld),
    -- Data: 4-bit (each) output: Data Ports
    CARRYOUT           => open,
    XOROUT             => open,
    -- Cascade: 30-bit (each) input: Cascade Ports
    ACIN               => (others=>'0'), -- unused
    BCIN               => (others=>'0'), -- unused
    CARRYCASCIN        => '0', -- unused
    MULTSIGNIN         => '0', -- unused
    PCIN               => (others=>'0')
  );
  end generate;

  -- pipelined valid signal
  g_dspreg_on : if NUM_OUTPUT_REG>=1 generate
  begin
    p_clk : process(clk)
    begin
      if rising_edge(clk) then
        if rst/='0' then
          accu_vld <= '0';
          accu_aux <= (others=>'0');
        elsif clkena='1' then
          accu_vld <= ireg(0).vld;
          accu_aux <= ireg(0).aux;
        end if; --reset
      end if; --clock
    end process;
  end generate;

  g_dspreg_off : if NUM_OUTPUT_REG<=0 generate
    accu_vld <= ireg(0).vld;
    accu_aux <= ireg(0).aux;
  end generate;

  g_accu_out : for n in 0 to NUM_ACCU-1 generate
    constant d : natural := n/SIMD; -- DSP cell index
    constant s : natural := n - d*SIMD; -- SIMD index
  begin
    -- split DSP cell output into SIMD slices
    accu(n) <= p(d)((s+1)*SIMD_WIDTH-1 downto s*SIMD_WIDTH);

    -- cut off unused sign extension bits
    -- (This reduces the logic consumption in the following steps when rounding,
    --  saturation and/or overflow detection is enabled.)
    accu_used(n) <= signed(accu(n)(SIMD_USED_WIDTH-1 downto 0));

    -- right-shift and clipping
    i_out : entity dsplib.signed_output_logic
    generic map(
      PIPELINE_STAGES    => NUM_OUTPUT_REG-1, -- consider DSP cell output register
      OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
      OUTPUT_ROUND       => false, -- rounding already done within DSP cell!
      OUTPUT_CLIP        => OUTPUT_CLIP,
      OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW,
      NUM_AUXILIARY_BITS => NUM_AUXILIARY_BITS
    )
    port map (
      clk         => clk,
      rst         => rst,
      clkena      => clkena,
      dsp_out     => accu_used(n),
      dsp_out_vld => accu_vld,
      dsp_out_aux => accu_aux,
      result      => result_i(n),
      result_vld  => result_vld_i(n),
      result_ovf  => result_ovf(n),
      result_aux  => result_aux_i(n)
    );

  end generate;

  result <= result_i;
  result_vld <= result_vld_i(0); -- same for all
  result_aux <= result_aux_i(0); -- same for all

  -- report constant number of pipeline register stages
  PIPESTAGES <= NUM_INPUT_REG_A + NUM_OUTPUT_REG;

end architecture;
