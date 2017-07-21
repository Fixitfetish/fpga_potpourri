-------------------------------------------------------------------------------
--! @file       signed_mult3.stratixv.vhdl
--! @author     Fixitfetish
--! @date       19/Mar/2017
--! @version    0.20
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

--! @brief This is an implementation of the entity 
--! @link signed_mult3 signed_mult3 @endlink
--! for Altera Stratix-V.
--! Three parallel and synchronous signed multiplications are performed.
--!
--! This implementation requires two chained Variable Precision DSP Blocks of mode 'm18x18_compact'.
--! For details please refer to the Altera Stratix V Device Handbook.
--!
--! * Input Data      : 3x2 signed values, each max 18 bits
--! * Input Register  : optional, at least one is strongly recommended
--! * Result Register : 3x36 bits
--! * Rounding        : optional half-up, only possible in logic
--! * Output Data     : 2x signed values, max 36 bits each
--! * Output Register : optional, at least one strongly recommend, another after rounding, shift-right and saturation
--! * Pipeline stages : NUM_INPUT_REG + NUM_OUTPUT_REG
--!
--! Note that negation of the product results within the DSP cell is not supported.
--! Hence, for each product one of the two input factors is negated using additional logic.
--! WARNING: If both input factors have the maximum size of 18 bits and the
--! input that is going to be negated is the most negative number then an overflow occurs.
--! @image html signed_mult3.stratixv.svg "" width=800px
--! This implementation does not support chaining.

architecture stratixv of signed_mult3 is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := signed_mult3'INSTANCE_NAME;

  -- number input registers within DSP and in LOGIC
  constant NUM_IREG_DSP : natural := NUM_IREG(DSP,NUM_INPUT_REG);
  constant NUM_IREG_LOGIC : natural := NUM_IREG(LOGIC,NUM_INPUT_REG);

  constant MAX_WIDTH_X : positive := 18;
  constant MAX_WIDTH_Y : positive := 18;
  constant MAX_PRODUCT_WIDTH : positive := MAX_WIDTH_X+MAX_WIDTH_Y;

  -- derived constants
  constant ROUND_ENABLE : boolean := OUTPUT_ROUND and (OUTPUT_SHIFT_RIGHT/=0);
  constant PRODUCT_WIDTH : natural := x0'length + y0'length;
  constant PRODUCT_SHIFTED_WIDTH : natural := PRODUCT_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result0'length;

  -- logic input register pipeline
  type r_logic_ireg is
  record
    rst, vld : std_logic;
    neg : std_logic_vector(neg'range);
    x0 : signed(x0'length-1 downto 0);
    y0 : signed(y0'length-1 downto 0);
    x1 : signed(x1'length-1 downto 0);
    y1 : signed(y1'length-1 downto 0);
    x2 : signed(x2'length-1 downto 0);
    y2 : signed(y2'length-1 downto 0);
  end record;
  type array_logic_ireg is array(integer range <>) of r_logic_ireg;
  signal logic_ireg : array_logic_ireg(NUM_IREG_LOGIC downto 0);

  -- input register pipeline
  type r_dsp_ireg is
  record
    rst, vld : std_logic;
    x0, x1, x2 : signed(MAX_WIDTH_X-1 downto 0);
    y0, y1, y2 : signed(MAX_WIDTH_Y-1 downto 0);
  end record;
  type array_dsp_ireg is array(integer range <>) of r_dsp_ireg;
  signal ireg : array_dsp_ireg(NUM_IREG_DSP downto 0);

  -- output register pipeline
  type r_oreg is
  record
    dat0, dat1, dat2 : signed(OUTPUT_WIDTH-1 downto 0);
    vld : std_logic;
    ovf : std_logic_vector(result_ovf'range);
  end record;
  type array_oreg is array(integer range <>) of r_oreg;
  signal rslt : array_oreg(0 to NUM_OUTPUT_REG);

  signal cout : std_logic;
  signal prod0, prod1,prod2 : std_logic_vector(MAX_PRODUCT_WIDTH-1 downto 0);
  signal prod0_used, prod1_used, prod2_used : signed(PRODUCT_WIDTH-1 downto 0);
  signal prod0_used_shifted, prod1_used_shifted, prod2_used_shifted : signed(PRODUCT_SHIFTED_WIDTH-1 downto 0);

begin

  -- check input/output length
  assert (x0'length<=MAX_WIDTH_X and x1'length<=MAX_WIDTH_X and x2'length<=MAX_WIDTH_X)
    report "ERROR " & IMPLEMENTATION & ": Multiplier input X width cannot exceed " & integer'image(MAX_WIDTH_X)
    severity failure;
  assert (y0'length<=MAX_WIDTH_Y and y1'length<=MAX_WIDTH_Y and y2'length<=MAX_WIDTH_Y)
    report "ERROR " & IMPLEMENTATION & ": Multiplier input Y width cannot exceed " & integer'image(MAX_WIDTH_Y)
    severity failure;
  assert     (x0'length+y0'length)=(x1'length+y1'length)
         and (x0'length+y0'length)=(x2'length+y2'length)
    report "ERROR " & IMPLEMENTATION & ": All products must result in same length."
    severity failure;

  logic_ireg(NUM_IREG_LOGIC).rst <= rst;
  logic_ireg(NUM_IREG_LOGIC).vld <= vld;
  logic_ireg(NUM_IREG_LOGIC).neg <= neg;
  logic_ireg(NUM_IREG_LOGIC).x0 <= x0;
  logic_ireg(NUM_IREG_LOGIC).y0 <= y0;
  logic_ireg(NUM_IREG_LOGIC).x1 <= x1;
  logic_ireg(NUM_IREG_LOGIC).y1 <= y1;
  logic_ireg(NUM_IREG_LOGIC).x2 <= x2;
  logic_ireg(NUM_IREG_LOGIC).y2 <= y2;

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

  -- LSB bound data inputs
  -- Always negate the shorter input factor which does not have maximum width.
  -- This also avoids overflows when input is most negative number.
  g_neg_x0 : if x0'length<y0'length generate
    ireg(NUM_IREG_DSP).x0 <= resize(logic_ireg(0).x0,MAX_WIDTH_X) when logic_ireg(0).neg(0)='0' else
                            -resize(logic_ireg(0).x0,MAX_WIDTH_X);
    ireg(NUM_IREG_DSP).y0 <= resize(logic_ireg(0).y0,MAX_WIDTH_Y);
  end generate;
  g_neg_y0 : if x0'length>=y0'length generate
    ireg(NUM_IREG_DSP).x0 <= resize(logic_ireg(0).x0,MAX_WIDTH_X);
    ireg(NUM_IREG_DSP).y0 <= resize(logic_ireg(0).y0,MAX_WIDTH_Y) when logic_ireg(0).neg(0)='0' else
                            -resize(logic_ireg(0).y0,MAX_WIDTH_Y);
  end generate;
  g_neg_x1 : if x1'length<y1'length generate
    ireg(NUM_IREG_DSP).x1 <= resize(logic_ireg(0).x1,MAX_WIDTH_X) when logic_ireg(0).neg(1)='0' else
                            -resize(logic_ireg(0).x1,MAX_WIDTH_X);
    ireg(NUM_IREG_DSP).y1 <= resize(logic_ireg(0).y1,MAX_WIDTH_Y);
  end generate;
  g_neg_y1 : if x1'length>=y1'length generate
    ireg(NUM_IREG_DSP).x1 <= resize(logic_ireg(0).x1,MAX_WIDTH_X);
    ireg(NUM_IREG_DSP).y1 <= resize(logic_ireg(0).y1,MAX_WIDTH_Y) when logic_ireg(0).neg(1)='0' else
                            -resize(logic_ireg(0).y1,MAX_WIDTH_Y);
  end generate;
  g_neg_x2 : if x2'length<y2'length generate
    ireg(NUM_IREG_DSP).x2 <= resize(logic_ireg(0).x2,MAX_WIDTH_X) when logic_ireg(0).neg(2)='0' else
                            -resize(logic_ireg(0).x2,MAX_WIDTH_X);
    ireg(NUM_IREG_DSP).y2 <= resize(logic_ireg(0).y2,MAX_WIDTH_Y);
  end generate;
  g_neg_y2 : if x2'length>=y2'length generate
    ireg(NUM_IREG_DSP).x2 <= resize(logic_ireg(0).x2,MAX_WIDTH_X);
    ireg(NUM_IREG_DSP).y2 <= resize(logic_ireg(0).y2,MAX_WIDTH_Y) when logic_ireg(0).neg(2)='0' else
                            -resize(logic_ireg(0).y2,MAX_WIDTH_Y);
  end generate;

  g_dsp_ireg1 : if NUM_IREG_DSP>=1 generate
  begin
    ireg(0).rst <= ireg(1).rst when rising_edge(clk);
    ireg(0).vld <= ireg(1).vld when rising_edge(clk);
    -- DSP cell registers are used for first input register stage
    ireg(0).x0 <= ireg(1).x0;
    ireg(0).y0 <= ireg(1).y0;
    ireg(0).x1 <= ireg(1).x1;
    ireg(0).y1 <= ireg(1).y1;
    ireg(0).x2 <= ireg(1).x2;
    ireg(0).y2 <= ireg(1).y2;
  end generate;

  dsp0 : stratixv_mac
  generic map (
    accumulate_clock          => "none", --irrelevant
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
    load_const_clock          => "none", -- irrelevant
    load_const_value          => 0, -- irrelevant
    lpm_type                  => "stratixv_mac",
    mode_sub_location         => 0,
    negate_clock              => "none", -- irrelevant
    operand_source_max        => "input",
    operand_source_may        => "input",
    operand_source_mbx        => "input",
    operand_source_mby        => "input",
    operation_mode            => "m18x18_compact",
    output_clock              => clock(1,NUM_OUTPUT_REG),
    preadder_subtract_a       => "false",
    preadder_subtract_b       => "false",
    result_a_width            => MAX_PRODUCT_WIDTH, -- product 0
    result_b_width            => MAX_PRODUCT_WIDTH/2, -- product 1, LSBs
    scan_out_width            => 1,
    signed_max                => "true",
    signed_may                => "true",
    signed_mbx                => "true",
    signed_mby                => "true",
    sub_clock                 => "none",
    use_chainadder            => "false"
  )
  port map (
    accumulate => '0',
    aclr(0)    => '0', -- clear input registers
    aclr(1)    => ireg(0).rst, -- clear output registers
    ax         => std_logic_vector(ireg(0).x0),
    ay         => std_logic_vector(ireg(0).y0),
    az         => open,
    bx         => std_logic_vector(ireg(0).x1),
    by         => std_logic_vector(ireg(0).y1),
    chainin    => open,
    chainout   => open,
    cin        => open,
    clk(0)     => clk, -- input clock
    clk(1)     => clk, -- output clock
    clk(2)     => clk, -- unused
    coefsela   => open,
    coefselb   => open,
    complex    => open,
    cout       => cout,
    dftout     => open,
    ena(0)     => '1', -- clk(0) enable
    ena(1)     => ireg(0).vld, -- clk(1) enable
    ena(2)     => '0', -- clk(2) enable - unused
    loadconst  => '0',
    negate     => '0',
    resulta    => prod0,
    resultb    => prod1(MAX_PRODUCT_WIDTH/2-1 downto 0),
    scanin     => open,
    scanout    => open,
    sub        => '0'
  );

  dsp1 : stratixv_mac
  generic map (
    accumulate_clock          => "none", --irrelevant
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
    load_const_clock          => "none", -- irrelevant
    load_const_value          => 0, -- irrelevant
    lpm_type                  => "stratixv_mac",
    mode_sub_location         => 1,
    negate_clock              => "none", -- irrelevant
    operand_source_max        => "input",
    operand_source_may        => "input",
    operand_source_mbx        => "input",
    operand_source_mby        => "input",
    operation_mode            => "m18x18_compact",
    output_clock              => clock(1,NUM_OUTPUT_REG),
    preadder_subtract_a       => "false",
    preadder_subtract_b       => "false",
    result_a_width            => MAX_PRODUCT_WIDTH/2, -- product 1, MSBs
    result_b_width            => MAX_PRODUCT_WIDTH, -- product 2
    scan_out_width            => 1,
    signed_max                => "true",
    signed_may                => "true",
    signed_mbx                => "true",
    signed_mby                => "true",
    sub_clock                 => "none",
    use_chainadder            => "false"
  )
  port map (
    accumulate => '0',
    aclr(0)    => '0', -- clear input registers
    aclr(1)    => ireg(0).rst, -- clear output registers
    ax         => std_logic_vector(ireg(0).x1),
    ay         => std_logic_vector(ireg(0).y1),
    az         => open,
    bx         => std_logic_vector(ireg(0).x2),
    by         => std_logic_vector(ireg(0).y2),
    chainin    => open,
    chainout   => open,
    cin        => cout,
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
    negate     => '0',
    resulta    => prod1(MAX_PRODUCT_WIDTH-1 downto MAX_PRODUCT_WIDTH/2),
    resultb    => prod2,
    scanin     => open,
    scanout    => open,
    sub        => '0'
  );

  -- cut off unused sign extension bits
  -- (This reduces the logic consumption in the following steps when rounding,
  -- saturation and/or overflow detection is enabled.)
  prod0_used <= signed(prod0(PRODUCT_WIDTH-1 downto 0));
  prod1_used <= signed(prod1(PRODUCT_WIDTH-1 downto 0));
  prod2_used <= signed(prod2(PRODUCT_WIDTH-1 downto 0));

  -- shift right and round 
  g_rnd_off : if (not ROUND_ENABLE) generate
    prod0_used_shifted <= RESIZE(SHIFT_RIGHT_ROUND(prod0_used, OUTPUT_SHIFT_RIGHT),PRODUCT_SHIFTED_WIDTH);
    prod1_used_shifted <= RESIZE(SHIFT_RIGHT_ROUND(prod1_used, OUTPUT_SHIFT_RIGHT),PRODUCT_SHIFTED_WIDTH);
    prod2_used_shifted <= RESIZE(SHIFT_RIGHT_ROUND(prod2_used, OUTPUT_SHIFT_RIGHT),PRODUCT_SHIFTED_WIDTH);
  end generate;
  g_rnd_on : if (ROUND_ENABLE) generate
    prod0_used_shifted <= RESIZE(SHIFT_RIGHT_ROUND(prod0_used, OUTPUT_SHIFT_RIGHT, nearest),PRODUCT_SHIFTED_WIDTH);
    prod1_used_shifted <= RESIZE(SHIFT_RIGHT_ROUND(prod1_used, OUTPUT_SHIFT_RIGHT, nearest),PRODUCT_SHIFTED_WIDTH);
    prod2_used_shifted <= RESIZE(SHIFT_RIGHT_ROUND(prod2_used, OUTPUT_SHIFT_RIGHT, nearest),PRODUCT_SHIFTED_WIDTH);
  end generate;

  p_out : process(prod0_used_shifted, prod1_used_shifted, prod2_used_shifted, ireg(0).vld)
    variable v_dat0, v_dat1, v_dat2 : signed(OUTPUT_WIDTH-1 downto 0);
    variable v_ovf : std_logic_vector(result_ovf'range);
  begin
    RESIZE_CLIP(din=>prod0_used_shifted, dout=>v_dat0, ovfl=>v_ovf(0), clip=>OUTPUT_CLIP);
    RESIZE_CLIP(din=>prod1_used_shifted, dout=>v_dat1, ovfl=>v_ovf(1), clip=>OUTPUT_CLIP);
    RESIZE_CLIP(din=>prod2_used_shifted, dout=>v_dat2, ovfl=>v_ovf(2), clip=>OUTPUT_CLIP);
    rslt(0).vld <= ireg(0).vld;
    rslt(0).dat0 <= v_dat0;
    rslt(0).dat1 <= v_dat1;
    rslt(0).dat2 <= v_dat2;
    if OUTPUT_OVERFLOW then rslt(0).ovf<=v_ovf; else rslt(0).ovf<=(others=>'0'); end if;
  end process;

  g_oreg1 : if NUM_OUTPUT_REG>=1 generate
  begin
    rslt(1).vld <= rslt(0).vld when rising_edge(clk); -- VLD bypass
    -- DSP cell result/accumulator register is always used as first output register stage
    rslt(1).dat0 <= rslt(0).dat0;
    rslt(1).dat1 <= rslt(0).dat1;
    rslt(1).dat2 <= rslt(0).dat2;
    rslt(1).ovf <= rslt(0).ovf;
  end generate;

  -- additional output registers always in logic
  g_oreg2 : if NUM_OUTPUT_REG>=2 generate
    g_loop : for n in 2 to NUM_OUTPUT_REG generate
      rslt(n) <= rslt(n-1) when rising_edge(clk);
    end generate;
  end generate;

  -- map result to output port
  result0 <= rslt(NUM_OUTPUT_REG).dat0;
  result1 <= rslt(NUM_OUTPUT_REG).dat1;
  result2 <= rslt(NUM_OUTPUT_REG).dat2;
  result_vld(0) <= rslt(NUM_OUTPUT_REG).vld;
  result_vld(1) <= rslt(NUM_OUTPUT_REG).vld;
  result_vld(2) <= rslt(NUM_OUTPUT_REG).vld;
  result_ovf <= rslt(NUM_OUTPUT_REG).ovf;

  -- report constant number of pipeline register stages
  PIPESTAGES <= NUM_INPUT_REG + NUM_OUTPUT_REG;

end architecture;

