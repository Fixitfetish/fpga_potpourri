-------------------------------------------------------------------------------
--! @file       signed_mult4_sum_stratixv.vhdl
--! @author     Fixitfetish
--! @date       24/Jan/2017
--! @version    0.30
--! @copyright  MIT License
--! @note       VHDL-1993
-------------------------------------------------------------------------------
-- Copyright (c) 2017 Fixitfetish
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library stratixv;
 use stratixv.stratixv_components.all;
library fixitfetish;
 use fixitfetish.ieee_extension.all;

--! @brief This is an implementation of the entity 
--! @link signed_mult4_sum signed_mult4_sum @endlink
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
--! * Output Register : optional, after shift-right and saturation
--! * Output Chain    : optional, 64 bits
--! * Pipeline stages : NUM_INPUT_REG + 1 + OUTPUT_REG
--!
--! The output can be chained with other DSP implementations.
--! @image html signed_mult4_sum_stratixv.svg "" width=800px
--!
--! NOTE 1: The product of the first input factor pair cannot be subtracted !
--!
--! NOTE 2: This implementation requires one pipeline register less than the
--! implementation 'signed_mutl4_accu'. Therefore, less registers in logic are required.
--! Drawback is a lower maximum frequency.
--!
--! NOTE 3: The 'chainin' input port is unused here because the chain input cannot
--! be enabled for mode_sub_location 0 in mode 'm18x18_sumof4'.

architecture stratixv of signed_mult4_sum is

  -- local auxiliary
  -- determine number of required additional guard bits (MSBs)
  function guard_bits(num_summand, dflt:natural) return integer is
    variable res : integer;
  begin
    if num_summand=0 then
      res := dflt; -- maximum possible (default)
    else
      res := LOG2CEIL(num_summand);
    end if;
    return res; 
  end function;

  function clock(n:natural) return string is
  begin
    -- if input registers enabled then use clock "0"
    if n>0 then return "0"; else return "none"; end if;
  end function;

  -- number of summands
  constant NUM_SUMMAND : positive := 4;

  -- accumulator width in bits
  constant ACCU_WIDTH : positive := 64;

  -- derived constants
  constant ROUND_ENABLE : boolean := OUTPUT_ROUND and (OUTPUT_SHIFT_RIGHT>0);
  constant PRODUCT_WIDTH : natural := x0'length + y0'length;
  constant MAX_GUARD_BITS : natural := ACCU_WIDTH - PRODUCT_WIDTH;
  constant GUARD_BITS_EVAL : natural := guard_bits(NUM_SUMMAND,MAX_GUARD_BITS);
  constant ACCU_USED_WIDTH : natural := PRODUCT_WIDTH + GUARD_BITS_EVAL;
  constant ACCU_USED_SHIFTED_WIDTH : natural := ACCU_USED_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result'length;

  -- input register pipeline
  type t_ireg is
  record
    rst, vld : std_logic;
    sub_a : std_logic; -- first DSP cell
    sub_b, negate_b : std_logic; -- second DSP cell
    x0, y0 : signed(17 downto 0);
    x1, y1 : signed(17 downto 0);
    x2, y2 : signed(17 downto 0);
    x3, y3 : signed(17 downto 0);
  end record;
  type array_ireg is array(integer range <>) of t_ireg;
  signal ireg : array_ireg(NUM_INPUT_REG downto 0);

  -- output register pipeline
  type r_oreg is
  record
    dat : signed(OUTPUT_WIDTH-1 downto 0);
    vld : std_logic;
    ovf : std_logic;
  end record;
  type array_oreg is array(integer range <>) of r_oreg;
  signal rslt : array_oreg(NUM_OUTPUT_REG downto 0);

  signal vld_q : std_logic;
  signal chain, chainout_i : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal accu : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal accu_used : signed(ACCU_USED_WIDTH-1 downto 0);
  signal accu_used_shifted : signed(ACCU_USED_SHIFTED_WIDTH-1 downto 0);

begin

  -- check input/output length
  assert (     x0'length<=18 and y0'length<=18 and x1'length<=18 and y1'length<=18
           and x2'length<=18 and y2'length<=18 and x3'length<=18 and y3'length<=18 )
    report "ERROR signed_mult4_sum(stratixv): Multiplier input width cannot exceed 18 bits."
    severity failure;

  assert sub(0)='0'
    report "ERROR signed_mult4_sum(stratixv) : " & 
           "Subtraction of first product 0 is not supported - only subtraction of products 1, 2 and 3 allowed."
    severity failure;

  assert GUARD_BITS_EVAL<=MAX_GUARD_BITS
    report "ERROR signed_mult4_sum(stratixv) : " & 
           "Maximum number of output bits is " & integer'image(ACCU_WIDTH) & " ." &
           "Input bit widths allow only maximum number of guard bits = " & integer'image(MAX_GUARD_BITS)
    severity failure;

  assert OUTPUT_WIDTH<ACCU_USED_SHIFTED_WIDTH or not(OUTPUT_CLIP or OUTPUT_OVERFLOW)
    report "ERROR signed_mult4_sum(stratixv) : " & 
           "More guard bits required for saturation/clipping and/or overflow detection."
    severity failure;

  -- pipeline inputs
  ireg(NUM_INPUT_REG).rst <= rst;
  ireg(NUM_INPUT_REG).vld <= vld;
  ireg(NUM_INPUT_REG).sub_a <= sub(1);
  ireg(NUM_INPUT_REG).negate_b <= sub(3);
  ireg(NUM_INPUT_REG).sub_b <= sub(2) xor sub(3);

  -- LSB bound data inputs
  ireg(NUM_INPUT_REG).x0 <= resize(x0,18);
  ireg(NUM_INPUT_REG).y0 <= resize(y0,18);
  ireg(NUM_INPUT_REG).x1 <= resize(x1,18);
  ireg(NUM_INPUT_REG).y1 <= resize(y1,18);
  ireg(NUM_INPUT_REG).x2 <= resize(x2,18);
  ireg(NUM_INPUT_REG).y2 <= resize(y2,18);
  ireg(NUM_INPUT_REG).x3 <= resize(x3,18);
  ireg(NUM_INPUT_REG).y3 <= resize(y3,18);

  g_reg : if NUM_INPUT_REG>=2 generate
  begin
    g1 : for n in 2 to NUM_INPUT_REG generate
    begin
      ireg(n-1) <= ireg(n) when rising_edge(clk);
    end generate;
  end generate;

  g_in : if NUM_INPUT_REG>=1 generate
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
    ax_clock                  => clock(NUM_INPUT_REG),
    ax_width                  => 18,
    ay_scan_in_clock          => clock(NUM_INPUT_REG),
    ay_scan_in_width          => 18,
    ay_use_scan_in            => "false",
    az_clock                  => "none", -- unused
    az_width                  => 1, -- unused
    bx_clock                  => clock(NUM_INPUT_REG),
    bx_width                  => 18,
    by_clock                  => clock(NUM_INPUT_REG),
    by_use_scan_in            => "false",
    by_width                  => 18,
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
    sub_clock                 => clock(NUM_INPUT_REG),
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
    accumulate_clock          => clock(NUM_INPUT_REG),
    ax_clock                  => clock(NUM_INPUT_REG),
    ax_width                  => 18,
    ay_scan_in_clock          => clock(NUM_INPUT_REG),
    ay_scan_in_width          => 18,
    ay_use_scan_in            => "false",
    az_clock                  => "none", -- unused
    az_width                  => 1, -- unused
    bx_clock                  => clock(NUM_INPUT_REG),
    bx_width                  => 18,
    by_clock                  => clock(NUM_INPUT_REG),
    by_use_scan_in            => "false",
    by_width                  => 18,
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
    load_const_clock          => clock(NUM_INPUT_REG),
    load_const_value          => 0,
    lpm_type                  => "stratixv_mac",
    mode_sub_location         => 1,
    negate_clock              => clock(NUM_INPUT_REG),
    operand_source_max        => "input",
    operand_source_may        => "input",
    operand_source_mbx        => "input",
    operand_source_mby        => "input",
    operation_mode            => "m18x18_sumof4",
    output_clock              => "1",
    preadder_subtract_a       => "false",
    preadder_subtract_b       => "false",
    result_a_width            => ACCU_WIDTH,
    result_b_width            => 1,
    scan_out_width            => 1,
    signed_max                => "true",
    signed_may                => "true",
    signed_mbx                => "true",
    signed_mby                => "true",
    sub_clock                 => clock(NUM_INPUT_REG),
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

  -- accumulator delay compensation
  vld_q <= ireg(0).vld when rising_edge(clk);

  -- cut off unused sign extension bits
  -- (This reduces the logic consumption in the following steps when rounding,
  --  saturation and/or overflow detection is enabled.)
  accu_used <= signed(accu(ACCU_USED_WIDTH-1 downto 0));

  -- shift right and round 
  g_rnd_off : if (not ROUND_ENABLE) generate
    accu_used_shifted <= RESIZE(SHIFT_RIGHT_ROUND(accu_used, OUTPUT_SHIFT_RIGHT),ACCU_USED_SHIFTED_WIDTH);
  end generate;
  g_rnd_on : if (ROUND_ENABLE) generate
    accu_used_shifted <= RESIZE(SHIFT_RIGHT_ROUND(accu_used, OUTPUT_SHIFT_RIGHT, nearest),ACCU_USED_SHIFTED_WIDTH);
  end generate;

  p_out : process(accu_used_shifted, vld_q)
    variable v_dat : signed(OUTPUT_WIDTH-1 downto 0);
    variable v_ovf : std_logic;
  begin
    RESIZE_CLIP(din=>accu_used_shifted, dout=>v_dat, ovfl=>v_ovf, clip=>OUTPUT_CLIP);
    rslt(0).vld <= vld_q; 
    rslt(0).dat <= v_dat; 
    if OUTPUT_OVERFLOW then rslt(0).ovf<=v_ovf; else rslt(0).ovf<='0'; end if;
  end process;

  g_out_reg : if NUM_OUTPUT_REG>=1 generate
    g_loop : for n in 1 to NUM_OUTPUT_REG generate
      rslt(n) <= rslt(n-1) when rising_edge(clk);
    end generate;
  end generate;

  -- map result to output port
  result     <= rslt(NUM_OUTPUT_REG).dat;
  result_vld <= rslt(NUM_OUTPUT_REG).vld;
  result_ovf <= rslt(NUM_OUTPUT_REG).ovf;

  -- report constant number of pipeline register stages
  PIPESTAGES <= NUM_INPUT_REG + 1 + NUM_OUTPUT_REG;

end architecture;
