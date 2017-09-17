-------------------------------------------------------------------------------
--! @file       signed_mult4_sum.stratixv.vhdl
--! @author     Fixitfetish
--! @date       19/Mar/2017
--! @version    0.50
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
  use dsplib.dsp_pkg_stratixv.all;

library stratixv;
  use stratixv.stratixv_components.all;

--! @brief This is an implementation of the entity signed_mult4_sum
--! for Altera Stratix-V.
--! Four signed multiplications are performed and all results are summed.
--!
--! This implementation requires two Variable Precision DSP Blocks chained with
--! the mode 'm18x18_sumof4'.
--! For details please refer to the Altera Stratix V Device Handbook.
--!
--! * Input Data      : 4x2 signed values, each max 18 bits
--! * Input Register  : optional, at least one is strongly recommended
--! * Input Chain     : not supported
--! * Accu Register   : just pipeline register, accumulation not supported
--! * Rounding        : optional half-up, only possible in logic!
--! * Output Data     : 1x signed value, max 64 bits
--! * Output Register : optional, at least one strongly recommended, another after shift-right and saturation
--! * Output Chain    : optional, 64 bits
--! * Pipeline stages : NUM_INPUT_REG + NUM_OUTPUT_REG
--!
--! The output can be chained with other DSP implementations.
--! @image html signed_mult4_sum.stratixv.svg "" width=800px
--!
--! NOTE 1: The product of the first input factor pair cannot be subtracted !
--!
--! NOTE 2: This implementation requires one pipeline register less than the
--! implementation signed_mult4_accu.stratixv .
--! Therefore, less registers in logic are required. Drawback is a lower maximum frequency.
--!
--! NOTE 3: The 'chainin' input port cannot be unused here because the chain input
--! cannot be enabled for mode_sub_location 0 in mode 'm18x18_sumof4'.

architecture stratixv of signed_mult4_sum is

  -- identifier for reports of warnings and errors
  -- (Note: Quartus 14.1 does not support attribute entity'instance_name within architecture)
  constant IMPLEMENTATION : string := "signed_mult4_sum(stratixv)";

  -- number input registers within DSP and in LOGIC
  constant NUM_IREG_DSP : natural := NUM_IREG(DSP,NUM_INPUT_REG);
  constant NUM_IREG_LOGIC : natural := NUM_IREG(LOGIC,NUM_INPUT_REG);

  constant MAX_WIDTH_X : positive := 18;
  constant MAX_WIDTH_Y : positive := 18;

  -- derived constants
  constant PRODUCT_WIDTH : natural := x0'length + y0'length;
  constant MAX_GUARD_BITS : natural := ACCU_WIDTH - PRODUCT_WIDTH;
  constant GUARD_BITS_EVAL : natural := accu_guard_bits(NUM_SUMMAND,MAX_GUARD_BITS,IMPLEMENTATION);
  constant ACCU_USED_WIDTH : natural := PRODUCT_WIDTH + GUARD_BITS_EVAL;
  constant ACCU_USED_SHIFTED_WIDTH : natural := ACCU_USED_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result'length;

  -- logic input register pipeline
  type r_logic_ireg is
  record
    rst, clr, vld : std_logic;
    sub : std_logic_vector(neg'range);
    x0 : signed(x0'length-1 downto 0);
    y0 : signed(y0'length-1 downto 0);
    x1 : signed(x1'length-1 downto 0);
    y1 : signed(y1'length-1 downto 0);
    x2 : signed(x2'length-1 downto 0);
    y2 : signed(y2'length-1 downto 0);
    x3 : signed(x3'length-1 downto 0);
    y3 : signed(y3'length-1 downto 0);
  end record;
  type array_logic_ireg is array(integer range <>) of r_logic_ireg;
  signal logic_ireg : array_logic_ireg(NUM_IREG_LOGIC downto 0);

  -- input register pipeline
  type r_dsp_ireg is
  record
    rst, vld : std_logic;
    sub_a : std_logic; -- first DSP cell
    sub_b, negate_b : std_logic; -- second DSP cell
    x0, x1, x2, x3 : signed(MAX_WIDTH_X-1 downto 0);
    y0, y1, y2, y3 : signed(MAX_WIDTH_Y-1 downto 0);
  end record;
  type array_dsp_ireg is array(integer range <>) of r_dsp_ireg;
  signal ireg : array_dsp_ireg(NUM_IREG_DSP downto 0);

  signal chain, chainout_i : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal accu : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal accu_vld : std_logic := '0';
  signal accu_used : signed(ACCU_USED_WIDTH-1 downto 0);

  -- dummy and sink to avoid warnings
  procedure signed_sink(d:in signed) is
    variable b : boolean := false;
  begin b := (d(d'right)='1') or b; end procedure;

begin

  signed_sink(chainin); -- chain input is unused

  assert not USE_CHAIN_INPUT
    report "ERROR " & IMPLEMENTATION & ": " &
           "Chain input not supported."
    severity failure;

  assert neg(0)='0'
    report "ERROR " & IMPLEMENTATION & ": " &
           "Negation of first product 0 is not supported - only negation of products 1, 2 and 3 allowed."
    severity failure;

  -- check input/output length
  assert (x0'length<=MAX_WIDTH_X and x1'length<=MAX_WIDTH_X and x2'length<=MAX_WIDTH_X and x3'length<=MAX_WIDTH_X)
    report "ERROR " & IMPLEMENTATION & ": Multiplier input X width cannot exceed " & integer'image(MAX_WIDTH_X)
    severity failure;
  assert (y0'length<=MAX_WIDTH_Y and y1'length<=MAX_WIDTH_Y and y2'length<=MAX_WIDTH_Y and y3'length<=MAX_WIDTH_Y)
    report "ERROR " & IMPLEMENTATION & ": Multiplier input Y width cannot exceed " & integer'image(MAX_WIDTH_Y)
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

  logic_ireg(NUM_IREG_LOGIC).rst <= rst;
  logic_ireg(NUM_IREG_LOGIC).vld <= vld;
  logic_ireg(NUM_IREG_LOGIC).sub <= neg;
  logic_ireg(NUM_IREG_LOGIC).x0 <= x0;
  logic_ireg(NUM_IREG_LOGIC).y0 <= y0;
  logic_ireg(NUM_IREG_LOGIC).x1 <= x1;
  logic_ireg(NUM_IREG_LOGIC).y1 <= y1;
  logic_ireg(NUM_IREG_LOGIC).x2 <= x2;
  logic_ireg(NUM_IREG_LOGIC).y2 <= y2;
  logic_ireg(NUM_IREG_LOGIC).x3 <= x3;
  logic_ireg(NUM_IREG_LOGIC).y3 <= y3;

  g_ireg_logic : if NUM_IREG_LOGIC>=1 generate
  begin
    g_1 : for n in 1 to NUM_IREG_LOGIC generate
    begin
      logic_ireg(n-1) <= logic_ireg(n) when rising_edge(clk);
    end generate;
  end generate;

  -- control signal inputs
  ireg(NUM_IREG_DSP).rst <= logic_ireg(0).rst;
  ireg(NUM_IREG_DSP).vld <= logic_ireg(0).vld;
  ireg(NUM_IREG_DSP).sub_a <= logic_ireg(0).sub(1);
  ireg(NUM_IREG_DSP).negate_b <= logic_ireg(0).sub(3);
  ireg(NUM_IREG_DSP).sub_b <= logic_ireg(0).sub(2) xor logic_ireg(0).sub(3);

  -- LSB bound data inputs
  ireg(NUM_IREG_DSP).x0 <= resize(logic_ireg(0).x0,MAX_WIDTH_X);
  ireg(NUM_IREG_DSP).y0 <= resize(logic_ireg(0).y0,MAX_WIDTH_Y);
  ireg(NUM_IREG_DSP).x1 <= resize(logic_ireg(0).x1,MAX_WIDTH_X);
  ireg(NUM_IREG_DSP).y1 <= resize(logic_ireg(0).y1,MAX_WIDTH_Y);
  ireg(NUM_IREG_DSP).x2 <= resize(logic_ireg(0).x2,MAX_WIDTH_X);
  ireg(NUM_IREG_DSP).y2 <= resize(logic_ireg(0).y2,MAX_WIDTH_Y);
  ireg(NUM_IREG_DSP).x3 <= resize(logic_ireg(0).x3,MAX_WIDTH_X);
  ireg(NUM_IREG_DSP).y3 <= resize(logic_ireg(0).y3,MAX_WIDTH_Y);

  g_dsp_ireg1 : if NUM_IREG_DSP>=1 generate
  begin
    ireg(0).rst <= ireg(1).rst when rising_edge(clk);
    ireg(0).vld <= ireg(1).vld when rising_edge(clk);
    -- DSP cell registers are used for first input register stage
    ireg(0).sub_a <= ireg(1).sub_a;
    ireg(0).sub_b <= ireg(1).sub_b;
    ireg(0).negate_b <= ireg(1).negate_b;
    ireg(0).x0 <= ireg(1).x0;
    ireg(0).y0 <= ireg(1).y0;
    ireg(0).x1 <= ireg(1).x1;
    ireg(0).y1 <= ireg(1).y1;
    ireg(0).x2 <= ireg(1).x2;
    ireg(0).y2 <= ireg(1).y2;
    ireg(0).x3 <= ireg(1).x3;
    ireg(0).y3 <= ireg(1).y3;
  end generate;

  dsp_a : stratixv_mac
  generic map (
    accumulate_clock          => "none",
    ax_clock                  => clock(0,NUM_INPUT_REG),
    ax_width                  => MAX_WIDTH_X,
    ay_scan_in_clock          => clock(0,NUM_INPUT_REG),
    ay_scan_in_width          => MAX_WIDTH_Y,
    ay_use_scan_in            => "false",
    az_clock                  => "none", -- unused
    az_width                  => 1, -- unused
    bx_clock                  => clock(0,NUM_INPUT_REG),
    bx_width                  => MAX_WIDTH_X,
    by_clock                  => clock(0,NUM_INPUT_REG),
    by_use_scan_in            => "false",
    by_width                  => MAX_WIDTH_Y,
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
    load_const_clock          => "none",
    load_const_value          => 0, -- unused
    lpm_type                  => "stratixv_mac",
    mode_sub_location         => 0,
    negate_clock              => "none",
    operand_source_max        => "input",
    operand_source_may        => "input",
    operand_source_mbx        => "input",
    operand_source_mby        => "input",
    operation_mode            => "m18x18_sumof4",
    output_clock              => "none",
    preadder_subtract_a       => "false",
    preadder_subtract_b       => "false",
    result_a_width            => ACCU_WIDTH,
    result_b_width            => 1,
    scan_out_width            => 1,
    signed_max                => "true",
    signed_may                => "true",
    signed_mbx                => "true",
    signed_mby                => "true",
    sub_clock                 => clock(0,NUM_INPUT_REG),
    use_chainadder            => "false"
  )
  port map (
    accumulate => '0',
    aclr(0)    => '0', -- clear input registers
    aclr(1)    => '0', -- clear output registers
    ax         => std_logic_vector(ireg(0).x1),
    ay         => std_logic_vector(ireg(0).y1),
    az         => open,
    bx         => std_logic_vector(ireg(0).x0),
    by         => std_logic_vector(ireg(0).y0),
    chainin    => open,
    chainout   => chain,
    cin        => '0',
    clk(0)     => clk, -- input clock
    clk(1)     => clk, -- output clock
    clk(2)     => clk, -- unused
    coefsela   => open,
    coefselb   => open,
    complex    => open,
    cout       => open,
    dftout     => open,
    ena(0)     => '1', -- clk(0) enable
    ena(1)     => '0', -- clk(1) enable - unused
    ena(2)     => '0', -- clk(2) enable - unused
    loadconst  => '0',
    negate     => '0',
    resulta    => open,
    resultb    => open,
    scanin     => open,
    scanout    => open,
    sub        => ireg(0).sub_a
  );

  dsp_b : stratixv_mac
  generic map (
    accumulate_clock          => clock(0,NUM_INPUT_REG),
    ax_clock                  => clock(0,NUM_INPUT_REG),
    ax_width                  => MAX_WIDTH_X,
    ay_scan_in_clock          => clock(0,NUM_INPUT_REG),
    ay_scan_in_width          => MAX_WIDTH_Y,
    ay_use_scan_in            => "false",
    az_clock                  => "none", -- unused here
    az_width                  => 1, -- unused here
    bx_clock                  => clock(0,NUM_INPUT_REG),
    bx_width                  => MAX_WIDTH_X,
    by_clock                  => clock(0,NUM_INPUT_REG),
    by_use_scan_in            => "false",
    by_width                  => MAX_WIDTH_Y,
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
    load_const_clock          => clock(0,NUM_INPUT_REG),
    load_const_value          => 0,
    lpm_type                  => "stratixv_mac",
    mode_sub_location         => 1,
    negate_clock              => clock(0,NUM_INPUT_REG),
    operand_source_max        => "input",
    operand_source_may        => "input",
    operand_source_mbx        => "input",
    operand_source_mby        => "input",
    operation_mode            => "m18x18_sumof4",
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
    sub_clock                 => clock(0,NUM_INPUT_REG),
    use_chainadder            => "false"
  )
  port map (
    accumulate => '0',
    aclr(0)    => '0', -- clear input registers
    aclr(1)    => ireg(0).rst, -- clear output registers
    ax         => std_logic_vector(ireg(0).x2),
    ay         => std_logic_vector(ireg(0).y2),
    az         => open,
    bx         => std_logic_vector(ireg(0).x3),
    by         => std_logic_vector(ireg(0).y3),
    chainin    => chain,
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
    loadconst  => '0',
    negate     => ireg(0).negate_b,
    resulta    => accu,
    resultb    => open,
    scanin     => open,
    scanout    => open,
    sub        => ireg(0).sub_b
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
  i_out : entity dsplib.dsp_output_logic
  generic map(
    PIPELINE_STAGES    => NUM_OUTPUT_REG-1,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => OUTPUT_ROUND,
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
  PIPESTAGES <= NUM_INPUT_REG + NUM_OUTPUT_REG;

end architecture;

