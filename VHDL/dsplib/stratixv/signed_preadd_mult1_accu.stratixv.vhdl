-------------------------------------------------------------------------------
--! @file       signed_preadd_mult1_accu.stratixv.vhdl
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

--! @brief This is an implementation of the entity 
--! @link signed_preadd_mult1_accu signed_preadd_mult1_accu @endlink
--! for Altera Stratix-V.
--! Multiply a sum of two signed (+/-AX +/-BX) with a signed Y and accumulate results.
--!
--! This implementation requires a single Variable Precision DSP Block of mode 'm27x27'.
--! For details please refer to the Altera Stratix V Device Handbook.
--!
--! * Input Data X    : 2 signed values, each max 25 bits
--! * Input Data Y    : 1 signed value, max 22 bits
--! * Input Register  : optional, at least one is strongly recommended
--! * Input Chain     : optional, 64 bits
--! * Accu Register   : 64 bits, enabled when NUM_OUTPUT_REG>0
--! * Rounding        : optional half-up, within DSP cell
--! * Output Data     : 1x signed value, max 64 bits
--! * Output Register : optional, at least one strongly recommend, another after shift-right and saturation
--! * Output Chain    : optional, 64 bits
--! * Pipeline stages : NUM_INPUT_REG + NUM_OUTPUT_REG
--!
--! If NUM_OUTPUT_REG=0 then the accumulator register is disabled. 
--!
--! | PREADD AX | PREADD BX |  X   |    Y  | Preadd |   Neg  | Comment
--! |:---------:|:---------:|:----:|:-----:|:------:|:------:|:--------------------------
--! | ADD       | ADD       |  AX  |    BX |  X+Y   |    0   | ---
--! | ADD       | SUBTRACT  |  AX  |    BX |  X-Y   |    0   | ---
--! | ADD       | DYNAMIC   |  AX  | +/-BX |  X+Y   |    0   | additional logic required
--! | SUBTRACT  | ADD       |  AX  |    BX |  X-Y   |    1   | ---
--! | SUBTRACT  | SUBTRACT  |  AX  |    BX |  X+Y   |    1   | ---
--! | SUBTRACT  | DYNAMIC   |  AX  | -/+BX |  X+Y   |    1   | additional logic required
--! | DYNAMIC   | ADD       |  AX  | +/-BX |  X+Y   | sub_ax | additional logic required
--! | DYNAMIC   | SUBTRACT  |  AX  | -/+BX |  X+Y   | sub_ax | additional logic required
--! | DYNAMIC   | DYNAMIC   |  AX  | +/-BX |  X+Y   | sub_ax | additional logic required
--!
--! This implementation can be chained multiple times.
--! @image html signed_preadd_mult1_accu.stratixv.svg "" width=1000px

architecture stratixv of signed_preadd_mult1_accu is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := signed_preadd_mult1_accu'INSTANCE_NAME;

  -- number input registers within DSP and in LOGIC
  constant NUM_IREG_DSP : natural := NUM_IREG(DSP,NUM_INPUT_REG);
  constant NUM_IREG_LOGIC : natural := NUM_IREG(LOGIC,NUM_INPUT_REG);

  constant MAX_WIDTH_X : positive := 25;
  constant LIM_WIDTH_X : positive := 24;
  constant MAX_WIDTH_Y : positive := 22;

  -- derived constants
  constant ROUND_ENABLE : boolean := OUTPUT_ROUND and (OUTPUT_SHIFT_RIGHT/=0);
  constant PRODUCT_WIDTH : natural := MAXIMUM(ax'length,bx'length) + 1 + y'length;
  constant MAX_GUARD_BITS : natural := ACCU_WIDTH - PRODUCT_WIDTH;
  constant GUARD_BITS_EVAL : natural := accu_guard_bits(NUM_SUMMAND,MAX_GUARD_BITS,IMPLEMENTATION);
  constant ACCU_USED_WIDTH : natural := PRODUCT_WIDTH + GUARD_BITS_EVAL;
  constant ACCU_USED_SHIFTED_WIDTH : natural := ACCU_USED_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result'length;

  -- logic input register pipeline
  type r_logic_ireg is
  record
    rst, clr, vld : std_logic;
    sub_ax, sub_bx : std_logic;
    ax : signed(ax'length-1 downto 0);
    bx : signed(bx'length-1 downto 0);
    y  : signed(y'length-1 downto 0);
  end record;
  type array_logic_ireg is array(integer range <>) of r_logic_ireg;
  signal logic_ireg : array_logic_ireg(NUM_IREG_LOGIC downto 0);

  -- input register pipeline
  type r_dsp_ireg is
  record
    rst, vld : std_logic;
    negate : std_logic;
    accumulate, loadconst : std_logic;
    ax : signed(MAX_WIDTH_X-1 downto 0);
    ay : signed(MAX_WIDTH_X-1 downto 0);
    az : signed(MAX_WIDTH_Y-1 downto 0);
  end record;
  type array_dsp_ireg is array(integer range <>) of r_dsp_ireg;
  signal ireg : array_dsp_ireg(NUM_IREG_DSP downto 0);

  -- preadder subtract control - more details in description above
  function preadder_subtract(amode,bmode:string) return string is
  begin
    if (amode="ADD" and bmode="SUBTRACT") or (amode="SUBTRACT" and bmode="ADD")then return "true";
    else return "false"; end if;
  end function;

  -- negation control - more details in description above
  function negate(sub_ax:std_logic; amode:string) return std_logic is
  begin
   if    amode="ADD"      then return '0';
   elsif amode="SUBTRACT" then return '1';
   else return sub_ax; end if;
  end function;

  -- input BX control - more details in description above
  function get_bx(bx:signed; sub_ax,sub_bx:std_logic; amode,bmode:string) return signed is
    variable res : signed(MAX_WIDTH_X-1 downto 0);
    variable bx_n : signed(MAX_WIDTH_X-1 downto 0);
  begin
    bx_n := -resize(bx,MAX_WIDTH_X); -- negative BX
    if    (amode="ADD"      and bmode="DYNAMIC"  and sub_bx='1') then res:=bx_n;
    elsif (amode="SUBTRACT" and bmode="DYNAMIC"  and sub_bx='0') then res:=bx_n;
    elsif (amode="DYNAMIC"  and bmode="ADD"      and sub_ax='1') then res:=bx_n;
    elsif (amode="DYNAMIC"  and bmode="SUBTRACT" and sub_ax='0') then res:=bx_n;
    elsif (amode="DYNAMIC"  and bmode="DYNAMIC"  and (sub_ax xor sub_bx)='0') then res:=bx_n;
    else res:=resize(bx,MAX_WIDTH_X); end if;
    return res;
  end function;

  signal clr_q, clr_i : std_logic;
  signal chainin_i, chainout_i : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal accu : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal accu_vld : std_logic := '0';
  signal accu_used : signed(ACCU_USED_WIDTH-1 downto 0);

begin

  -- check input/output length
  assert (ax'length<=LIM_WIDTH_X and bx'length<=LIM_WIDTH_X)
    report "ERROR " & IMPLEMENTATION & ": Multiplier inputs AX and BX width cannot exceed " & integer'image(LIM_WIDTH_X)
    severity failure;
  assert (y'length<=MAX_WIDTH_Y)
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
  logic_ireg(NUM_IREG_LOGIC).clr <= clr;
  logic_ireg(NUM_IREG_LOGIC).vld <= vld;
  logic_ireg(NUM_IREG_LOGIC).sub_ax <= sub_ax;
  logic_ireg(NUM_IREG_LOGIC).sub_bx <= sub_bx;
  logic_ireg(NUM_IREG_LOGIC).ax <= ax;
  logic_ireg(NUM_IREG_LOGIC).bx <= bx;
  logic_ireg(NUM_IREG_LOGIC).y  <= y;

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
  ireg(NUM_IREG_DSP).negate <= negate(logic_ireg(0).sub_ax,PREADDER_INPUT_AX);
  ireg(NUM_IREG_DSP).accumulate <= logic_ireg(0).vld and (not clr_i); -- TODO - valid required ? or is accu clkena sufficient ?
  ireg(NUM_IREG_DSP).loadconst <= clr_i and to_01(ROUND_ENABLE);

  -- LSB bound data inputs
  ireg(NUM_IREG_DSP).ax <= resize(logic_ireg(0).ax, MAX_WIDTH_X);
  ireg(NUM_IREG_DSP).ay <= get_bx(logic_ireg(0).bx, logic_ireg(0).sub_ax, logic_ireg(0).sub_bx, PREADDER_INPUT_AX, PREADDER_INPUT_BX);
  ireg(NUM_IREG_DSP).az <= resize(logic_ireg(0).y, MAX_WIDTH_Y);

  -- DSP cell data input registers are used as first input register stage.
  g_dsp_ireg1 : if NUM_IREG_DSP>=1 generate
  begin
    ireg(0).rst <= ireg(1).rst when rising_edge(clk);
    ireg(0).vld <= ireg(1).vld when rising_edge(clk);
    -- DSP cell registers are used for first input register stage
    ireg(0).negate <= ireg(1).negate;
    ireg(0).accumulate <= ireg(1).accumulate;
    ireg(0).loadconst <= ireg(1).loadconst;
    ireg(0).ax <= ireg(1).ax;
    ireg(0).ay <= ireg(1).ay;
    ireg(0).az <= ireg(1).az;
  end generate;

  -- use only LSBs of chain input
  chainin_i <= std_logic_vector(chainin(ACCU_WIDTH-1 downto 0));

  dsp : stratixv_mac
  generic map (
    accumulate_clock          => clock(0,NUM_INPUT_REG),
    ax_clock                  => clock(0,NUM_INPUT_REG),
    ax_width                  => MAX_WIDTH_X,
    ay_scan_in_clock          => clock(0,NUM_INPUT_REG),
    ay_scan_in_width          => MAX_WIDTH_X,
    ay_use_scan_in            => "false",
    az_clock                  => clock(0,NUM_INPUT_REG),
    az_width                  => MAX_WIDTH_Y,
    bx_clock                  => "none", -- unused
    bx_width                  => 1, -- unused
    by_clock                  => "none", -- unused
    by_use_scan_in            => "false",
    by_width                  => 1, -- unused
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
    load_const_value          => load_const_value(OUTPUT_ROUND, OUTPUT_SHIFT_RIGHT),
    lpm_type                  => "stratixv_mac",
    mode_sub_location         => 0,
    negate_clock              => clock(0,NUM_INPUT_REG),
    operand_source_max        => "input",
    operand_source_may        => "preadder",
    operand_source_mbx        => "input",
    operand_source_mby        => "preadder",
    operation_mode            => "m27x27",
    output_clock              => clock(1,NUM_OUTPUT_REG),
    preadder_subtract_a       => preadder_subtract(PREADDER_INPUT_AX,PREADDER_INPUT_BX),
    preadder_subtract_b       => preadder_subtract(PREADDER_INPUT_AX,PREADDER_INPUT_BX),
    result_a_width            => ACCU_WIDTH,
    result_b_width            => 1,
    scan_out_width            => 1,
    signed_max                => "true",
    signed_may                => "true",
    signed_mbx                => "true",
    signed_mby                => "true",
    sub_clock                 => "none", -- unused
    use_chainadder            => use_chainadder(USE_CHAIN_INPUT)
  )
  port map (
    accumulate => ireg(0).accumulate,
    aclr(0)    => '0', -- clear input registers
    aclr(1)    => ireg(0).rst, -- clear output registers
    ax         => std_logic_vector(ireg(0).ax),
    ay         => std_logic_vector(ireg(0).ay),
    az         => std_logic_vector(ireg(0).az),
    bx         => open,
    by         => open,
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
    sub        => '0' -- unused
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
    OUTPUT_ROUND       => false, -- rounding within DSP cell!
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

