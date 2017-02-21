-------------------------------------------------------------------------------
--! @file       signed_mult2_accu1.arria10.vhdl
--! @author     Fixitfetish
--! @date       16/Feb/2017
--! @version    0.85
--! @copyright  MIT License
--! @note       VHDL-1993
-------------------------------------------------------------------------------
-- Copyright (c) 2016-2017 Fixitfetish
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library fixitfetish;
 use fixitfetish.ieee_extension.all;

library twentynm;
 use twentynm.twentynm_components.all;

--! @brief This is an implementation of the entity 
--! @link signed_mult2_accu1 signed_mult2_accu1 @endlink
--! for Altera Arria 10.
--! Two signed multiplications are performed and both results are accumulated.
--!
--! This implementation requires a single Variable Precision DSP Block.
--! Please refer to Arria 10 Native Fixed Point DSP IP Core User Guide.
--! UG-01163,  2016.06.10 
--!
--! * Input Data      : 2x2 signed values, x<=18 bits, y<=19 bits
--! * Input Register  : optional, at least one is strongly recommended
--! * Input Chain     : optional, 64 bits
--! * Accu Register   : 64 bits, enabled when NUM_OUTPUT_REG>0
--! * Rounding        : optional half-up, within DSP cell
--! * Output Data     : 1x signed value, max 64 bits
--! * Output Register : optional, at least one strongly recommend, another after shift-right and saturation
--! * Output Chain    : optional, 64 bits
--! * Pipeline stages : NUM_INPUT_REG + NUM_OUTPUT_REG
--!
--! This implementation can be chained multiple times.
--! @image html signed_mult2_accu1.arria10.svg "" width=800px

architecture arria10 of signed_mult2_accu1 is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "signed_mult2_accu1(arria10)";

  -- local auxiliary
  -- determine number of required additional guard bits (MSBs)
  function guard_bits(num_summand, dflt:natural) return integer is
    variable res : integer;
  begin
    if num_summand=0 then
      res := dflt; -- maximum possible (default)
    else
      res := LOG2CEIL(num_summand);
      if res>dflt then 
        report "WARNING " & IMPLEMENTATION & ": Too many summands. " & 
           "Maximum number of " & integer'image(dflt) & " guard bits reached."
           severity warning;
        res:=dflt;
      end if;
    end if;
    return res; 
  end function;

  function use_chainadder(b:boolean) return string is
  begin
    if b then return "true"; else return "false"; end if;
  end function;

  function load_const_value(round: boolean; shifts:natural) return natural is
  begin
    -- if rounding is enabled then +0.5 in the beginning of accumulation
    if round and (shifts>0) then return (shifts-1); else return 0; end if;
  end function;

  -- clock select for input/output registers
  function clock(clksel:integer range 0 to 2; nreg:integer) return string is
  begin
    if    clksel=0 and nreg>0 then return "0";
    elsif clksel=1 and nreg>0 then return "1";
    elsif clksel=2 and nreg>0 then return "2";
    else return "none";
    end if;
  end function;

  constant MAX_WIDTH_X : positive := 18;
  constant MAX_WIDTH_Y : positive := 19;

  -- accumulator width in bits
  constant ACCU_WIDTH : positive := 64;

  -- derived constants
  constant ROUND_ENABLE : boolean := OUTPUT_ROUND and (OUTPUT_SHIFT_RIGHT/=0);
  constant PRODUCT_WIDTH : natural := x0'length + y0'length;
  constant MAX_GUARD_BITS : natural := ACCU_WIDTH - PRODUCT_WIDTH;
  constant GUARD_BITS_EVAL : natural := guard_bits(NUM_SUMMAND,MAX_GUARD_BITS);
  constant ACCU_USED_WIDTH : natural := PRODUCT_WIDTH + GUARD_BITS_EVAL;
  constant ACCU_USED_SHIFTED_WIDTH : natural := ACCU_USED_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result'length;

  -- input register pipeline
  type r_ireg is
  record
    rst, vld : std_logic;
    sub, negate : std_logic;
    accumulate, loadconst : std_logic;
    x0, x1 : signed(MAX_WIDTH_X-1 downto 0);
    y0, y1 : signed(MAX_WIDTH_Y-1 downto 0);
  end record;
  type array_ireg is array(integer range <>) of r_ireg;
  signal ireg : array_ireg(NUM_INPUT_REG downto 0);

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
  signal accu_used_shifted : signed(ACCU_USED_SHIFTED_WIDTH-1 downto 0);

begin

  -- check chain in/out length
  assert (chainin'length>=ACCU_WIDTH or (not USE_CHAIN_INPUT))
    report "ERROR " & IMPLEMENTATION & ": " &
           "Chain input width must be " & integer'image(ACCU_WIDTH) & " bits."
    severity failure;

  -- check input/output length
  assert (x0'length<=MAX_WIDTH_X and x1'length<=MAX_WIDTH_X)
    report "ERROR " & IMPLEMENTATION & ": Multiplier input X width cannot exceed " & integer'image(MAX_WIDTH_X)
    severity failure;
  assert (y0'length<=MAX_WIDTH_Y and y1'length<=MAX_WIDTH_Y)
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

  p_clr : process(clk)
  begin
    if rising_edge(clk) then
      if clr='1' and vld='0' then
        clr_q<='1';
      elsif vld='1' then
        clr_q<='0';
      end if;
    end if;
  end process;
  clr_i <= clr or clr_q;

  -- control signal inputs
  ireg(NUM_INPUT_REG).rst <= rst;
  ireg(NUM_INPUT_REG).vld <= vld;
  ireg(NUM_INPUT_REG).negate <= sub(1);
  ireg(NUM_INPUT_REG).sub <= sub(0) xor sub(1);
  ireg(NUM_INPUT_REG).accumulate <= vld and (not clr_i); -- TODO - valid required ? or is accu clkena sufficient ?
  ireg(NUM_INPUT_REG).loadconst <= clr_i and to_01(ROUND_ENABLE);

  -- LSB bound data inputs
  ireg(NUM_INPUT_REG).x0 <= resize(x0,MAX_WIDTH_X);
  ireg(NUM_INPUT_REG).y0 <= resize(y0,MAX_WIDTH_Y);
  ireg(NUM_INPUT_REG).x1 <= resize(x1,MAX_WIDTH_X);
  ireg(NUM_INPUT_REG).y1 <= resize(y1,MAX_WIDTH_Y);

  g_reg : if NUM_INPUT_REG>=3 generate
  begin
    g_1 : for n in 3 to NUM_INPUT_REG generate
    begin
      ireg(n-1) <= ireg(n) when rising_edge(clk);
    end generate;
  end generate;

  g_in2 : if NUM_INPUT_REG>=2 generate
  begin
    ireg(1).rst <= ireg(2).rst when rising_edge(clk);
    ireg(1).vld <= ireg(2).vld when rising_edge(clk);
    -- DSP cell registers are used for first input register stage
    ireg(1).sub <= ireg(2).sub;
    ireg(1).negate <= ireg(2).negate;
    ireg(1).accumulate <= ireg(2).accumulate;
    ireg(1).loadconst <= ireg(2).loadconst;
    ireg(1).x0 <= ireg(2).x0;
    ireg(1).y0 <= ireg(2).y0;
    ireg(1).x1 <= ireg(2).x1;
    ireg(1).y1 <= ireg(2).y1;
  end generate;

  g_in1 : if NUM_INPUT_REG>=1 generate
  begin
    ireg(0).rst <= ireg(1).rst when rising_edge(clk);
    ireg(0).vld <= ireg(1).vld when rising_edge(clk);
    -- DSP cell registers are used for first input register stage
    ireg(0).sub <= ireg(1).sub;
    ireg(0).negate <= ireg(1).negate;
    ireg(0).accumulate <= ireg(1).accumulate;
    ireg(0).loadconst <= ireg(1).loadconst;
    ireg(0).x0 <= ireg(1).x0;
    ireg(0).y0 <= ireg(1).y0;
    ireg(0).x1 <= ireg(1).x1;
    ireg(0).y1 <= ireg(1).y1;
  end generate;

  -- use only LSBs of chain input
  chainin_i <= std_logic_vector(chainin(ACCU_WIDTH-1 downto 0));

  dsp : twentynm_mac
  generic map (
    accum_pipeline_clock      => clock(0,NUM_INPUT_REG),
    accumulate_clock          => clock(0,NUM_INPUT_REG-1),
    ax_clock                  => clock(0,NUM_INPUT_REG-1),
    ax_width                  => MAX_WIDTH_X,
    ay_scan_in_clock          => clock(0,NUM_INPUT_REG),
    ay_scan_in_width          => MAX_WIDTH_Y,
    ay_use_scan_in            => "false",
    az_clock                  => "none", -- unused here
    az_width                  => 1, -- unused here
    bx_clock                  => clock(0,NUM_INPUT_REG-1),
    bx_width                  => MAX_WIDTH_X,
    by_clock                  => clock(0,NUM_INPUT_REG-1),
    by_use_scan_in            => "false",
    by_width                  => MAX_WIDTH_Y,
    bz_clock                  => clock(0,NUM_INPUT_REG-1),
    bz_width                  => 18,
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
    delay_scan_out_ay         => "false",
    delay_scan_out_by         => "false",
    enable_double_accum       => "false",
    input_pipeline_clock      => clock(0,NUM_INPUT_REG),
    load_const_clock          => clock(0,NUM_INPUT_REG-1),
    load_const_pipeline_clock => clock(0,NUM_INPUT_REG),
    load_const_value          => load_const_value(OUTPUT_ROUND, OUTPUT_SHIFT_RIGHT),
    lpm_type                  => "twentynm_mac",
    mode_sub_location         => 0,
    negate_clock              => clock(0,NUM_INPUT_REG-1),
    negate_pipeline_clock     => clock(0,NUM_INPUT_REG),
    operand_source_max        => "input",
    operand_source_may        => "input",
    operand_source_mbx        => "input",
    operand_source_mby        => "input",
    operation_mode            => "m18x18_sumof2",
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
    sub_clock                 => clock(0,NUM_INPUT_REG-1),
    sub_pipeline_clock        => clock(0,NUM_INPUT_REG),
    use_chainadder            => use_chainadder(USE_CHAIN_INPUT)
  )
  port map (
    accumulate => ireg(0).accumulate,
    aclr(0)    => '0', -- clear input registers
    aclr(1)    => ireg(0).rst, -- clear output registers
    ax         => std_logic_vector(ireg(0).x0),
    ay         => std_logic_vector(ireg(0).y0),
    az         => (others=>'0'),
    bx         => std_logic_vector(ireg(0).x1),
    by         => std_logic_vector(ireg(0).y1),
    bz         => (others=>'0'),
    chainin    => chainin_i,
    chainout   => chainout_i,
    clk(0)     => clk, -- input clock
    clk(1)     => clk, -- output clock
    clk(2)     => clk, -- unused
    coefsela   => open,
    coefselb   => open,
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

  -- a.) just shift right without rounding because rounding bit is has been added 
  --     within the DSP cell already.
  -- b.) cut off unused sign extension bits
  --    (This reduces the logic consumption in the following steps when rounding,
  --     saturation and/or overflow detection is enabled.)
  accu_used_shifted <= signed(accu(ACCU_USED_WIDTH-1 downto OUTPUT_SHIFT_RIGHT));

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
  PIPESTAGES <= NUM_INPUT_REG + NUM_OUTPUT_REG;

end architecture;

