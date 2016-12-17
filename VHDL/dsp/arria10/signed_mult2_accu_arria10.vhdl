-------------------------------------------------------------------------------
-- FILE    : signed_mult2_accu_arria10.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 17/Dec/2016
-- VERSION : 0.70
-- VHDL    : 1993
-- LICENSE : MIT License
-------------------------------------------------------------------------------
-- Copyright (c) 2016 Fixitfetish
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library twentynm;
 use twentynm.twentynm_components.all;
library fixitfetish;
 use fixitfetish.ieee_extension.all;

-- This implementation requires a single Variable Precision DSP Block.
-- Please refer to Arria 10 Native Fixed Point DSP IP Core User Guide.
-- UG-01163,  2016.06.10 

architecture arria10 of signed_mult2_accu is

  -- local auxiliary
  function default_if_negative (x:integer; dflt: natural) return natural is
  begin
    if x<0 then return dflt; else return x; end if;
  end function;

  -- accumulator width in bits
  constant ACCU_WIDTH : positive := 64;

  -- derived constants
  constant PRODUCT_WIDTH : natural := a_x'length + a_y'length;
  constant MAX_GUARD_BITS : natural := ACCU_WIDTH - PRODUCT_WIDTH;
  constant GUARD_BITS_EVAL : natural := default_if_negative(GUARD_BITS,MAX_GUARD_BITS);
  constant ACCU_USED_WIDTH : natural := PRODUCT_WIDTH + GUARD_BITS_EVAL;
  constant ACCU_USED_SHIFTED_WIDTH : natural := ACCU_USED_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := r_out'length;

  signal rst_i : std_logic; 
  signal clr_q, clr_i : std_logic; 
  signal vld_i, vld_q : std_logic;
  signal ax_i, ay_i : signed(17 downto 0);
  signal bx_i, by_i : signed(17 downto 0);
  signal sub, negate, accumulate, loadconst : std_logic;
  signal accu : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal accu_used_shifted : signed(ACCU_USED_SHIFTED_WIDTH-1 downto 0);

  -- auxiliary functions
  function clock(b:boolean) return string is
  begin
    -- if input register enabled then use clock "0"
    if b then return "0"; else return "none"; end if;
  end function;

  function load_const_value(round: boolean; shifts:natural) return natural is
  begin
    -- if rounding is enabled then +0.5 in the beginning of accumulation
    if round and (shifts>0) then return (shifts-1); else return 0; end if;
  end function;

begin

  -- check input/output length
  assert (a_x'length<=18 and a_y'length<=18 and b_x'length<=18 and b_y'length<=18)
    report "ERROR signed_mult2_accu(arria10): Multiplier input width cannot exceed 18 bits."
    severity failure;

  assert GUARD_BITS_EVAL<=MAX_GUARD_BITS
    report "ERROR signed_mult2_accu(arria10) : " & 
           "Maximum number of accumulator bits is " & integer'image(ACCU_WIDTH) & " ." &
           "Input bit widths allow only maximum number of guard bits = " & integer'image(MAX_GUARD_BITS)
    severity failure;

  assert OUTPUT_WIDTH<ACCU_USED_SHIFTED_WIDTH or not(OUTPUT_CLIP or OUTPUT_OVERFLOW)
    report "ERROR signed_mult2_accu(arria10) : " & 
           "More guard bits required for saturation/clipping and/or overflow detection."
    severity failure;

  g_din : if not INPUT_REG generate
    vld_i <= vld;
    rst_i <= rst;
  end generate;

  g_din_reg : if INPUT_REG generate
    vld_i <= vld when rising_edge(clk);
    rst_i <= rst when rising_edge(clk);
  end generate;
 
  -- LSB bound inputs
  ax_i <= resize(a_x,18);
  ay_i <= resize(a_y,18);
  bx_i <= resize(b_x,18);
  by_i <= resize(b_y,18);

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

  -- accumulator control signals
  negate <= b_sub;
  sub <= a_sub xor b_sub;
  accumulate <= vld and (not clr_i); --- TODO - valid required ? or is accu clkena sufficient ?
  
  g_r1 : if OUTPUT_ROUND and (OUTPUT_SHIFT_RIGHT>0) generate
    loadconst <= clr_i;
  end generate;
  g_r2 : if (not OUTPUT_ROUND) or (OUTPUT_SHIFT_RIGHT=0) generate
    loadconst <= '0';
  end generate;

  dsp : twentynm_mac
  generic map (
    accum_pipeline_clock      => "none",
    accumulate_clock          => clock(INPUT_REG),
    ax_clock                  => clock(INPUT_REG),
    ax_width                  => 18,
    ay_scan_in_clock          => clock(INPUT_REG),
    ay_scan_in_width          => 18,
    ay_use_scan_in            => "false",
    az_clock                  => "none", -- unused here
    az_width                  => 1, -- unused here
    bx_clock                  => clock(INPUT_REG),
    bx_width                  => 18,
    by_clock                  => clock(INPUT_REG),
    by_use_scan_in            => "false",
    by_width                  => 18,
    bz_clock                  => clock(INPUT_REG),
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
    input_pipeline_clock      => "none",
    load_const_clock          => clock(INPUT_REG),
    load_const_pipeline_clock => "none",
    load_const_value          => load_const_value(OUTPUT_ROUND, OUTPUT_SHIFT_RIGHT),
    lpm_type                  => "twentynm_mac",
    mode_sub_location         => 0,
    negate_clock              => clock(INPUT_REG),
    negate_pipeline_clock     => "none",
    operand_source_max        => "input",
    operand_source_may        => "input",
    operand_source_mbx        => "input",
    operand_source_mby        => "input",
    operation_mode            => "m18x18_sumof2",
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
    sub_clock                 => clock(INPUT_REG),
    sub_pipeline_clock        => "none",
    use_chainadder            => "false"
  )
  port map (
    accumulate => accumulate,
    aclr(0)    => '0', -- clear input registers
    aclr(1)    => rst_i, -- clear output registers
    ax         => std_logic_vector(ax_i),
    ay         => std_logic_vector(ay_i),
    az         => (others=>'0'),
    bx         => std_logic_vector(bx_i),
    by         => std_logic_vector(by_i),
    bz         => (others=>'0'),
    chainin    => open,
    chainout   => open,
    clk(0)     => clk, -- input clock
    clk(1)     => clk, -- output clock
    clk(2)     => clk, -- unused
    coefsela   => open,
    coefselb   => open,
    dftout     => open,
    ena(0)     => '1', -- clk(0) enable
    ena(1)     => vld_i, -- clk(1) enable
    ena(2)     => '0', -- clk(2) enable - unused
    loadconst  => loadconst,
    negate     => negate,
    resulta    => accu,
    resultb    => open,
    scanin     => open,
    scanout    => open,
    sub        => sub
  );

  -- accumulator delay compensation
  vld_q <= vld_i when rising_edge(clk);

  -- a.) just shift right without rounding because rounding bit is has been added 
  --     within the DSP cell already.
  -- b.) cut off unused sign extension bits
  --    (This reduces the logic consumption in the following steps when rounding,
  --     saturation and/or overflow detection is enabled.)
  accu_used_shifted <= signed(accu(ACCU_USED_WIDTH-1 downto OUTPUT_SHIFT_RIGHT));

--  -- shift right and round 
--  g_rnd_off : if ((not OUTPUT_ROUND) or OUTPUT_SHIFT_RIGHT=0) generate
--    accu_used_shifted <= RESIZE(SHIFT_RIGHT_ROUND(accu_used, OUTPUT_SHIFT_RIGHT),ACCU_USED_SHIFTED_WIDTH);
--  end generate;
--  g_rnd_on : if (OUTPUT_ROUND and OUTPUT_SHIFT_RIGHT>0) generate
--    accu_used_shifted <= RESIZE(SHIFT_RIGHT_ROUND(accu_used, OUTPUT_SHIFT_RIGHT, nearest),ACCU_USED_SHIFTED_WIDTH);
--  end generate;

  g_dout : if not OUTPUT_REG generate
    process(accu_used_shifted, vld_q)
      variable v_dout : signed(OUTPUT_WIDTH-1 downto 0);
      variable v_ovfl : std_logic;
    begin
      RESIZE_CLIP(din=>accu_used_shifted, dout=>v_dout, ovfl=>v_ovfl, clip=>OUTPUT_CLIP);
      r_vld <= vld_q; 
      r_out <= v_dout; 
      if OUTPUT_OVERFLOW then r_ovf<=v_ovfl; else r_ovf<='0'; end if;
    end process;
  end generate;

  g_dout_reg : if OUTPUT_REG generate
    process(clk)
      variable v_dout : signed(OUTPUT_WIDTH-1 downto 0);
      variable v_ovfl : std_logic;
    begin
      if rising_edge(clk) then
        RESIZE_CLIP(din=>accu_used_shifted, dout=>v_dout, ovfl=>v_ovfl, clip=>OUTPUT_CLIP);
        r_vld <= vld_q; 
        r_out <= v_dout; 
        if OUTPUT_OVERFLOW then r_ovf<=v_ovfl; else r_ovf<='0'; end if;
      end if;
    end process;
  end generate;

  -- report constant number of pipeline register stages
  PIPE <= 3 when (INPUT_REG and OUTPUT_REG) else
          2 when (INPUT_REG or OUTPUT_REG) else
          1;

end architecture;

