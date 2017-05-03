-------------------------------------------------------------------------------
--! @file       signed_mult1add1_accu.stratixv.vhdl
--! @author     Fixitfetish
--! @date       19/Mar/2017
--! @version    0.20
--! @copyright  MIT License
--! @note       VHDL-1993
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension.all;
library dsplib;
  use dsplib.dsp_pkg_stratixv.all;

library stratixv;
  use stratixv.stratixv_components.all;

--! @brief This is an implementation of the entity 
--! @link signed_mult1add1_accu signed_mult1add1_accu @endlink
--! for Altera Stratix-V.
--! A product of two signed values is added or subtracted to/from a third signed value.
--! The results of this operation can be accumulated over several cycles.
--!
--! This implementation requires a single Variable Precision DSP Block of mode 'm18x18_plus36'.
--! For details please refer to the Altera Stratix V Device Handbook.
--!
--! * Input Data X,Y  : 2 signed values, x<=18 bits, y<=18 bits
--! * Input Data Z    : 1 signed value, z<=36 bits
--! * Input Register  : optional, at least one is strongly recommended
--! * Input Chain     : optional, 64 bits
--! * Accu Register   : 64 bits, enabled when NUM_OUTPUT_REG>0
--! * Rounding        : optional half-up, within DSP cell
--! * Output Data     : 1x signed value, max 64 bits
--! * Output Register : optional, at least one strongly recommend, another after shift-right and saturation
--! * Output Chain    : optional, 64 bits
--! * Pipeline stages : NUM_INPUT_REG_XY + NUM_OUTPUT_REG (main data path through multiplier)
--!
--! This implementation can be chained multiple times.
--! @image html signed_mult1add1_accu.stratixv.svg "" width=800px

architecture stratixv of signed_mult1add1_accu is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "signed_mult1add1_accu(stratixv)";

  -- number input registers within DSP and in LOGIC
  constant NUM_IREG_DSP : natural := NUM_IREG("DSP",NUM_INPUT_REG_XY);
  constant NUM_IREG_LOGIC : natural := NUM_IREG("LOGIC",NUM_INPUT_REG_XY);

  -- number of additional Z input registers in logic (not within DSP cell)
  constant NUM_IREG_Z_LOGIC : natural := NUM_IREG("LOGIC",NUM_INPUT_REG_Z);

  constant MAX_WIDTH_X : positive := 18;
  constant MAX_WIDTH_Y : positive := 18;
  constant MAX_WIDTH_Z : positive := 36;

  -- derived constants
  constant ROUND_ENABLE : boolean := OUTPUT_ROUND and (OUTPUT_SHIFT_RIGHT/=0);
  constant PRODUCT_WIDTH : natural := x'length + y'length;
  constant MAX_GUARD_BITS : natural := ACCU_WIDTH - PRODUCT_WIDTH;
  constant GUARD_BITS_EVAL : natural := accu_guard_bits(NUM_SUMMAND,MAX_GUARD_BITS,IMPLEMENTATION);
  constant ACCU_USED_WIDTH : natural := PRODUCT_WIDTH + GUARD_BITS_EVAL;
  constant ACCU_USED_SHIFTED_WIDTH : natural := ACCU_USED_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result'length;

  type array_zreg is array(integer range <>) of signed(z'length-1 downto 0);
  signal zreg : array_zreg(NUM_IREG_Z_LOGIC downto 0);
  signal b : signed(MAX_WIDTH_Z-1 downto 0);

  -- logic input register pipeline
  type r_logic_ireg is
  record
    rst, clr, vld : std_logic;
    sub : std_logic;
    x : signed(x'length-1 downto 0);
    y : signed(y'length-1 downto 0);
  end record;
  type array_logic_ireg is array(integer range <>) of r_logic_ireg;
  signal logic_ireg : array_logic_ireg(NUM_IREG_LOGIC downto 0);

  -- input register pipeline
  type r_dsp_ireg is
  record
    rst, vld : std_logic;
    negate, sub : std_logic;
    accumulate, loadconst : std_logic;
    x : signed(MAX_WIDTH_X-1 downto 0);
    y : signed(MAX_WIDTH_Y-1 downto 0);
  end record;
  type array_dsp_ireg is array(integer range <>) of r_dsp_ireg;
  signal ireg : array_dsp_ireg(NUM_IREG_DSP downto 0);

  -- output register pipeline
  type r_oreg is
  record
    dat : signed(OUTPUT_WIDTH-1 downto 0);
    vld : std_logic;
    ovf : std_logic;
  end record;
  type array_oreg is array(integer range <>) of r_oreg;
  signal rslt : array_oreg(0 to NUM_OUTPUT_REG);

  signal clr_q, clr_i : std_logic;
  signal chainin_i, chainout_i : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal accu : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal accu_used : signed(ACCU_USED_WIDTH-1 downto 0);
  signal accu_used_shifted : signed(ACCU_USED_SHIFTED_WIDTH-1 downto 0);

begin

  -- check chain in/out length
  assert (chainin'length>=ACCU_WIDTH or (not USE_CHAIN_INPUT))
    report "ERROR " & IMPLEMENTATION & ": " &
           "Chain input width must be " & integer'image(ACCU_WIDTH) & " bits."
    severity failure;

  -- check input/output length
  assert (x'length<=MAX_WIDTH_X)
    report "ERROR " & IMPLEMENTATION & ": Multiplier input X width cannot exceed " & integer'image(MAX_WIDTH_X)
    severity failure;
  assert (y'length<=MAX_WIDTH_Y)
    report "ERROR " & IMPLEMENTATION & ": Multiplier input Y width cannot exceed " & integer'image(MAX_WIDTH_Y)
    severity failure;
  assert (z'length<=MAX_WIDTH_Z)
    report "ERROR " & IMPLEMENTATION & ": Multiplier input Y width cannot exceed " & integer'image(MAX_WIDTH_Z)
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

  zreg(NUM_IREG_Z_LOGIC) <= z;
  g_zreg : if NUM_IREG_Z_LOGIC>=1 generate
  begin
    g_1 : for n in 1 to NUM_IREG_Z_LOGIC generate
    begin
      zreg(n-1) <= zreg(n) when rising_edge(clk);
    end generate;
  end generate;
  b <= resize(zreg(0),MAX_WIDTH_Z);
  
  logic_ireg(NUM_IREG_LOGIC).rst <= rst;
  logic_ireg(NUM_IREG_LOGIC).clr <= clr;
  logic_ireg(NUM_IREG_LOGIC).vld <= vld;
  logic_ireg(NUM_IREG_LOGIC).sub <= sub;
  logic_ireg(NUM_IREG_LOGIC).x <= x;
  logic_ireg(NUM_IREG_LOGIC).y <= y;

  g_ireg_logic : if NUM_IREG_LOGIC>=1 generate
  begin
    g_1 : for n in 1 to NUM_IREG_LOGIC generate
    begin
      logic_ireg(n-1) <= logic_ireg(n) when rising_edge(clk);
    end generate;
  end generate;

  -- support clr='1' when vld='0'
  p_clr : process(clk)
  begin
    if rising_edge(clk) then
      if logic_ireg(0).clr='1' and logic_ireg(0).vld='0' then
        clr_q<='1';
      elsif logic_ireg(0).vld='1' then
        clr_q<='0';
      end if;
    end if;
  end process;
  clr_i <= logic_ireg(0).clr or clr_q;

  -- control signal inputs
  ireg(NUM_IREG_DSP).rst <= logic_ireg(0).rst;
  ireg(NUM_IREG_DSP).vld <= logic_ireg(0).vld;
  ireg(NUM_IREG_DSP).sub <= logic_ireg(0).sub; -- +/- X*Y
  ireg(NUM_IREG_DSP).negate <= '0'; -- always +Z (for now!)
  ireg(NUM_IREG_DSP).accumulate <= logic_ireg(0).vld and (not clr_i); -- TODO - valid required ? or is accu clkena sufficient ?
  ireg(NUM_IREG_DSP).loadconst <= clr_i and to_01(ROUND_ENABLE);

  -- LSB bound data inputs
  ireg(NUM_IREG_DSP).x <= resize(logic_ireg(0).x,MAX_WIDTH_X);
  ireg(NUM_IREG_DSP).y <= resize(logic_ireg(0).y,MAX_WIDTH_Y);

  g_dsp_ireg1 : if NUM_IREG_DSP>=1 generate
  begin
    ireg(0).rst <= ireg(1).rst when rising_edge(clk);
    ireg(0).vld <= ireg(1).vld when rising_edge(clk);
    -- DSP cell registers are used for first input register stage
    ireg(0).sub <= ireg(1).sub;
    ireg(0).negate <= ireg(1).negate;
    ireg(0).accumulate <= ireg(1).accumulate;
    ireg(0).loadconst <= ireg(1).loadconst;
    ireg(0).x <= ireg(1).x;
    ireg(0).y <= ireg(1).y;
  end generate;

  -- use only LSBs of chain input
  chainin_i <= std_logic_vector(chainin(ACCU_WIDTH-1 downto 0));

  dsp : stratixv_mac
  generic map (
    accumulate_clock          => clock(0,NUM_INPUT_REG_XY),
    ax_clock                  => clock(0,NUM_INPUT_REG_XY),
    ax_width                  => MAX_WIDTH_X,
    ay_scan_in_clock          => clock(0,NUM_INPUT_REG_XY),
    ay_scan_in_width          => MAX_WIDTH_Y,
    ay_use_scan_in            => "false",
    az_clock                  => "none", -- unused here
    az_width                  => 1, -- unused here
    bx_clock                  => clock(0,NUM_INPUT_REG_Z),
    bx_width                  => MAX_WIDTH_Z/2,
    by_clock                  => clock(0,NUM_INPUT_REG_Z),
    by_use_scan_in            => "false",
    by_width                  => MAX_WIDTH_Z/2,
    coef_a_0                  => 0,
    coef_a_1                  => 0,
    coef_a_2                  => 0,
    coef_a_3                  => 0,
    coef_a_4                  => 0,
    coef_a_5                  => 0,
    coef_a_6                  => 0,
    coef_a_7                  => 0,
    coef_b_0                  => 0,
    coef_b_1                  => 0,
    coef_b_2                  => 0,
    coef_b_3                  => 0,
    coef_b_4                  => 0,
    coef_b_5                  => 0,
    coef_b_6                  => 0,
    coef_b_7                  => 0,
    coef_sel_a_clock          => "none",
    coef_sel_b_clock          => "none",
    complex_clock             => "none",
    delay_scan_out_ay         => "false",
    delay_scan_out_by         => "false",
    load_const_clock          => clock(0,NUM_INPUT_REG_XY),
    load_const_value          => load_const_value(OUTPUT_ROUND, OUTPUT_SHIFT_RIGHT),
    lpm_type                  => "stratixv_mac",
    mode_sub_location         => 0,
    negate_clock              => clock(0,NUM_INPUT_REG_XY),
    operand_source_max        => "input",
    operand_source_may        => "input",
    operand_source_mbx        => "input",
    operand_source_mby        => "input",
    operation_mode            => "m18x18_plus36",
    output_clock              => clock(1,NUM_OUTPUT_REG),
    preadder_subtract_a       => "false",
    preadder_subtract_b       => "false",
    result_a_width            => ACCU_WIDTH,
    result_b_width            => 1,
    scan_out_width            => 1,
    signed_max                => "true",
    signed_may                => "true",
    signed_mbx                => "true",
    signed_mby                => "true",
    sub_clock                 => clock(0,NUM_INPUT_REG_XY),
    use_chainadder            => use_chainadder(USE_CHAIN_INPUT)
  )
  port map (
    accumulate => ireg(0).accumulate,
    aclr(0)    => '0', -- clear input registers
    aclr(1)    => ireg(0).rst, -- clear output registers
    ax         => std_logic_vector(ireg(0).x),
    ay         => std_logic_vector(ireg(0).y),
    az         => open,
    bx         => std_logic_vector(b(MAX_WIDTH_Z-1 downto MAX_WIDTH_Z/2)),
    by         => std_logic_vector(b(MAX_WIDTH_Z/2-1 downto 0)),
    chainin    => chainin_i,
    chainout   => chainout_i,
    cin        => open,
    clk(0)     => clk, -- input clock
    clk(1)     => clk, -- output clock
    clk(2)     => clk, -- unused
    coefsela   => open,
    coefselb   => open,
    complex    => open,
    cout       => open,
    dftout     => open,
    ena(0)     => '1', -- clk(0) enable
    ena(1)     => ireg(0).vld, -- clk(1) enable
    ena(2)     => '0', -- clk(2) enable - unused
    loadconst  => ireg(0).loadconst,
    negate     => ireg(0).negate,
    resulta    => accu,
    resultb    => open,
    scanin     => open,
    scanout    => open,
    sub        => ireg(0).sub
  );

  chainout(ACCU_WIDTH-1 downto 0) <= signed(chainout_i);
  g_chainout : for n in ACCU_WIDTH to (chainout'length-1) generate
    -- sign extension (for simulation and to avoid warnings)
    chainout(n) <= chainout_i(ACCU_WIDTH-1);
  end generate;

  -- cut off unused sign extension bits
  -- (This reduces the logic consumption in the following steps when rounding,
  --  saturation and/or overflow detection is enabled.)
  accu_used <= signed(accu(ACCU_USED_WIDTH-1 downto 0));

  -- just shift right without rounding because rounding bit has been added
  -- within the DSP cell already.
  accu_used_shifted <= accu_used(ACCU_USED_WIDTH-1 downto OUTPUT_SHIFT_RIGHT);

--  -- shift right and round
--  g_rnd_off : if (not ROUND_ENABLE) generate
--    accu_used_shifted <= RESIZE(SHIFT_RIGHT_ROUND(accu_used, OUTPUT_SHIFT_RIGHT),ACCU_USED_SHIFTED_WIDTH);
--  end generate;
--  g_rnd_on : if (ROUND_ENABLE) generate
--    accu_used_shifted <= RESIZE(SHIFT_RIGHT_ROUND(accu_used, OUTPUT_SHIFT_RIGHT, nearest),ACCU_USED_SHIFTED_WIDTH);
--  end generate;

  p_out : process(accu_used_shifted, ireg(0).vld)
    variable v_dat : signed(OUTPUT_WIDTH-1 downto 0);
    variable v_ovf : std_logic;
  begin
    RESIZE_CLIP(din=>accu_used_shifted, dout=>v_dat, ovfl=>v_ovf, clip=>OUTPUT_CLIP);
    rslt(0).vld <= ireg(0).vld;
    rslt(0).dat <= v_dat;
    if OUTPUT_OVERFLOW then rslt(0).ovf<=v_ovf; else rslt(0).ovf<='0'; end if;
  end process;

  g_oreg1 : if NUM_OUTPUT_REG>=1 generate
  begin
    rslt(1).vld <= rslt(0).vld when rising_edge(clk); -- VLD bypass
    -- DSP cell result/accumulator register is always used as first output register stage
    rslt(1).dat <= rslt(0).dat;
    rslt(1).ovf <= rslt(0).ovf;
  end generate;

  -- additional output registers always in logic
  g_oreg2 : if NUM_OUTPUT_REG>=2 generate
    g_loop : for n in 2 to NUM_OUTPUT_REG generate
      rslt(n) <= rslt(n-1) when rising_edge(clk);
    end generate;
  end generate;

  -- map result to output port
  result <= rslt(NUM_OUTPUT_REG).dat;
  result_vld <= rslt(NUM_OUTPUT_REG).vld;
  result_ovf <= rslt(NUM_OUTPUT_REG).ovf;

  -- report constant number of pipeline register stages
  PIPESTAGES <= NUM_INPUT_REG_XY + NUM_OUTPUT_REG;

end architecture;

