-------------------------------------------------------------------------------
--! @file       signed_mult2.stratixv.vhdl
--! @author     Fixitfetish
--! @date       19/Mar/2017
--! @version    0.40
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

--! @brief This is an implementation of the entity signed_mult2 for Altera Stratix-V.
--! Two parallel and synchronous signed multiplications are performed with limited result width.
--!
--! This implementation requires a single Variable Precision DSP Block of mode 'm18x18_partial'.
--! Note that the sum of input widths x'length + y'length cannot exceed 32.
--! For details please refer to the Altera Stratix V Device Handbook.
--!
--! * Input Data      : 2x2 signed values, each max 18 bits
--! * Input Register  : optional, at least one is strongly recommended
--! * Result Register : 2x32 bits, max width of each product result is 32
--! * Rounding        : optional half-up, only possible in logic
--! * Output Data     : 2x signed values, max 32 bits each
--! * Output Register : optional, at least one strongly recommend, another after rounding, shift-right and saturation
--! * Pipeline stages : NUM_INPUT_REG + NUM_OUTPUT_REG
--!
--! Note that negation of the product results within the DSP cell is not supported.
--! Hence, for each product one of the two input factors is negated using additional logic.
--! @image html signed_mult2.stratixv.svg "" width=800px
--! This implementation does not support chaining.

architecture stratixv of signed_mult2 is

  -- identifier for reports of warnings and errors
  -- (Note: Quartus 14.1 does not support attribute entity'instance_name within architecture)
  constant IMPLEMENTATION : string := "signed_mult2(stratixv)";

  -- number input registers within DSP and in LOGIC
  constant NUM_IREG_DSP : natural := NUM_IREG(DSP,NUM_INPUT_REG);
  constant NUM_IREG_LOGIC : natural := NUM_IREG(LOGIC,NUM_INPUT_REG);

  constant MAX_WIDTH_X : positive := 18;
  constant MAX_WIDTH_Y : positive := 18;
  constant MAX_PRODUCT_WIDTH : positive := 32;

  -- derived constants
  constant PRODUCT_WIDTH : natural := x0'length + y0'length;

  -- logic input register pipeline
  type r_logic_ireg is
  record
    rst, vld : std_logic;
    neg : std_logic_vector(neg'range);
    x0 : signed(x0'length-1 downto 0);
    y0 : signed(y0'length-1 downto 0);
    x1 : signed(x1'length-1 downto 0);
    y1 : signed(y1'length-1 downto 0);
  end record;
  type array_logic_ireg is array(integer range <>) of r_logic_ireg;
  signal logic_ireg : array_logic_ireg(NUM_IREG_LOGIC downto 0);

  -- input register pipeline
  type r_dsp_ireg is
  record
    rst, vld : std_logic;
    x0, x1 : signed(MAX_WIDTH_X-1 downto 0);
    y0, y1 : signed(MAX_WIDTH_Y-1 downto 0);
  end record;
  type array_dsp_ireg is array(integer range <>) of r_dsp_ireg;
  signal ireg : array_dsp_ireg(NUM_IREG_DSP downto 0);

  type t_prod is array(integer range <>) of std_logic_vector(MAX_PRODUCT_WIDTH-1 downto 0);
  signal prod : t_prod(0 to 1) := (others=>(others=>'0'));
  signal prod_vld : std_logic := '0';


begin

  -- check input/output length
  assert (x0'length<=MAX_WIDTH_X and x1'length<=MAX_WIDTH_X)
    report "ERROR " & IMPLEMENTATION & ": Multiplier input X width cannot exceed " & integer'image(MAX_WIDTH_X)
    severity failure;
  assert (y0'length<=MAX_WIDTH_Y and y1'length<=MAX_WIDTH_Y)
    report "ERROR " & IMPLEMENTATION & ": Multiplier input Y width cannot exceed " & integer'image(MAX_WIDTH_Y)
    severity failure;
  assert (x0'length+y0'length<=MAX_PRODUCT_WIDTH and x1'length+y1'length<=MAX_PRODUCT_WIDTH)
    report "ERROR " & IMPLEMENTATION & ": Resulting product length x'length + y'length exceeds " & integer'image(MAX_PRODUCT_WIDTH)
    severity failure;
  assert (x0'length+y0'length)=(x1'length+y1'length)
    report "ERROR " & IMPLEMENTATION & ": Both products must result in same length."
    severity failure;

  logic_ireg(NUM_IREG_LOGIC).rst <= rst;
  logic_ireg(NUM_IREG_LOGIC).vld <= vld;
  logic_ireg(NUM_IREG_LOGIC).neg <= neg;
  logic_ireg(NUM_IREG_LOGIC).x0 <= x0;
  logic_ireg(NUM_IREG_LOGIC).y0 <= y0;
  logic_ireg(NUM_IREG_LOGIC).x1 <= x1;
  logic_ireg(NUM_IREG_LOGIC).y1 <= y1;

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

  g_dsp_ireg1 : if NUM_IREG_DSP>=1 generate
  begin
    ireg(0).rst <= ireg(1).rst when rising_edge(clk);
    ireg(0).vld <= ireg(1).vld when rising_edge(clk);
    -- DSP cell registers are used for first input register stage
    ireg(0).x0 <= ireg(1).x0;
    ireg(0).y0 <= ireg(1).y0;
    ireg(0).x1 <= ireg(1).x1;
    ireg(0).y1 <= ireg(1).y1;
  end generate;

  dsp : stratixv_mac
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
    operation_mode            => "m18x18_partial",
    output_clock              => clock(1,NUM_OUTPUT_REG),
    preadder_subtract_a       => "false",
    preadder_subtract_b       => "false",
    result_a_width            => MAX_PRODUCT_WIDTH,
    result_b_width            => MAX_PRODUCT_WIDTH,
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
    cout       => open,
    dftout     => open,
    ena(0)     => '1', -- clk(0) enable
    ena(1)     => ireg(0).vld, -- clk(1) enable
    ena(2)     => '0', -- clk(2) enable - unused
    loadconst  => '0',
    negate     => '0',
    resulta    => prod(0),
    resultb    => prod(1),
    scanin     => open,
    scanout    => open,
    sub        => '0'
  );

  -- pipelined valid signal
  g_dspreg_on : if NUM_OUTPUT_REG>=1 generate
    prod_vld <= ireg(0).vld when rising_edge(clk);
  end generate;
  g_dspreg_off : if NUM_OUTPUT_REG<=0 generate
    prod_vld <= ireg(0).vld;
  end generate;

  -- right-shift, rounding and clipping
  i_out0 : entity dsplib.signed_output_logic
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
    -- cut off unused sign extension bits
    -- (This reduces the logic consumption when rounding,
    -- saturation and/or overflow detection is enabled.)
    dsp_out     => signed(prod(0)(PRODUCT_WIDTH-1 downto 0)),
    dsp_out_vld => prod_vld,
    result      => result0,
    result_vld  => result_vld(0),
    result_ovf  => result_ovf(0)
  );

  i_out1 : entity dsplib.signed_output_logic
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
    -- cut off unused sign extension bits
    -- (This reduces the logic consumption when rounding,
    -- saturation and/or overflow detection is enabled.)
    dsp_out     => signed(prod(1)(PRODUCT_WIDTH-1 downto 0)),
    dsp_out_vld => prod_vld,
    result      => result1,
    result_vld  => result_vld(1),
    result_ovf  => result_ovf(1)
  );

  -- report constant number of pipeline register stages
  PIPESTAGES <= NUM_INPUT_REG + NUM_OUTPUT_REG;

end architecture;

