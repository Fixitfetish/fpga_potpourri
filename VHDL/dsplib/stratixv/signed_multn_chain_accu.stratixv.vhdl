-------------------------------------------------------------------------------
--! @file       signed_multn_chain_accu.stratixv.vhdl
--! @author     Fixitfetish
--! @date       17/Apr/2017
--! @version    0.10
--! @copyright  MIT License
--! @note       VHDL-1993
-------------------------------------------------------------------------------
-- Copyright (c) 2017 Fixitfetish
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library fixitfetish;
 use fixitfetish.ieee_extension.all;

--! @brief This implementation chains Stratix-V specific instances to accumulate
--! several product results in a single cycle. 
--!
--! * Input Data      : Nx2 signed values
--! * Input Register  : optional, at least one is strongly recommended
--! * Accu Register   : width is implementation specific, always enabled
--! * Rounding        : optional half-up
--! * Output Data     : 1x signed value, max width is implementation specific
--! * Output Register : optional, after rounding, shift-right and saturation
--! * Pipeline stages : NUM_INPUT_REG + NUM_PIPELINE_REG + NUM_OUTPUT_REG
--!
--! This implementation can be chained multiple times.
--! @image html signed_multn_chain_accu.stratixv.svg "" width=800px

architecture stratixv of signed_multn_chain_accu is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := signed_multn_chain_accu'INSTANCE_NAME;

  constant IS_HIGH_SPEED : boolean := HIGH_SPEED_MODE or NUM_MULT<=4;

  -- number of elements of complex factor vector y
  -- (must be either 1 or the same length as x)
  constant NUM_FACTOR : positive := y'length;

  -- multipliers per DSP cell depends on input widths
  function mult_per_dsp(lx,ly:integer) return natural is
  begin
    if (lx<=18 and ly<=18) then return 2; else return 1; end if;
  end function;

  constant DSP_TYPE : natural := mult_per_dsp(x(x'left)'length,y(y'left)'length);
  constant DSP_NUM : natural := (NUM_MULT-1)/DSP_TYPE + 1;

  function enable_chain_input(n:natural) return boolean is
  begin
    if n=1 then return USE_CHAIN_INPUT; else return true; end if;
  end function;

  function get_num_output_reg(n:natural) return natural is
  begin
    if n=DSP_NUM then return NUM_OUTPUT_REG; else return 1; end if;
  end function;

  function get_output_shift(n:natural) return natural is
  begin
    if n=DSP_NUM then return OUTPUT_SHIFT_RIGHT; else return 0; end if;
  end function;

  function get_output_round(n:natural) return boolean is
  begin
    if n=DSP_NUM then return OUTPUT_ROUND; else return false; end if;
  end function;

  function get_output_clip(n:natural) return boolean is
  begin
    if n=DSP_NUM then return OUTPUT_CLIP; else return false; end if;
  end function;

  function get_output_overflow(n:natural) return boolean is
  begin
    if n=DSP_NUM then return OUTPUT_OVERFLOW; else return false; end if;
  end function;

  -- convert to default range
  alias y_i : signed_vector(0 to NUM_FACTOR-1) is y; -- default range

  -- DSP cell inputs
  signal x_dsp : signed_vector(0 to DSP_TYPE*DSP_NUM-1) := (others=>(others=>'0'));
  signal y_dsp : signed_vector(0 to DSP_TYPE*DSP_NUM-1) := (others=>(others=>'0'));
  signal neg_dsp : std_logic_vector(0 to DSP_TYPE*DSP_NUM-1) := (others=>'0');
  signal clr_dsp : std_logic_vector(0 to DSP_NUM-1) := (others=>'1'); -- disable all accumulators

  type a_result is array(integer range <>) of signed(result'length-1 downto 0);
  signal rslt : a_result(0 to DSP_NUM-1) := (others=>(others=>'-'));
  signal rslt_vld : std_logic_vector(0 to DSP_NUM-1) := (others=>'0');
  signal rslt_ovf : std_logic_vector(0 to DSP_NUM-1) := (others=>'0');

  -- chain width in bits - implementation and device specific !
  type array_chain is array(integer range <>) of signed(chainout'length-1 downto 0);
  signal chainout_i : array_chain(-1 to DSP_NUM-1) := (others=>(others=>'0'));

  type natural_vector is array(integer range <>) of natural;
  signal PIPESTAGES_DSP : natural_vector(0 to DSP_NUM-1);

begin

  -- Map inputs to internal signals
  g_in: for n in 0 to (NUM_MULT-1) generate
    x_dsp(n) <= x(n);
    neg_dsp(n) <= neg(n);
    g1: if NUM_FACTOR=1 generate
      y_dsp(n) <= y_i(0);
    end generate;
    gn: if NUM_FACTOR=NUM_MULT generate
      y_dsp(n) <= y_i(n);
    end generate;
  end generate;

  -- enable accumulator only for last instance in the chain
  clr_dsp(DSP_NUM-1) <= clr;

  g_chainin : if USE_CHAIN_INPUT generate
    chainout_i(-1) <= chainin; 
  end generate;

  -- one multiplication per DSP cell (max width is 36 bit)
  g_type1 : if DSP_TYPE=1 generate
  begin
    gn : for n in 0 to DSP_NUM-1 generate
      inst : entity fixitfetish.signed_mult1_accu(stratixv)
      generic map(
        NUM_SUMMAND        => NUM_SUMMAND,
        USE_CHAIN_INPUT    => enable_chain_input(n+1),
        NUM_INPUT_REG      => NUM_INPUT_REG+n,
        NUM_OUTPUT_REG     => get_num_output_reg(n+1),
        OUTPUT_SHIFT_RIGHT => get_output_shift(n+1),
        OUTPUT_ROUND       => get_output_round(n+1),
        OUTPUT_CLIP        => get_output_clip(n+1),
        OUTPUT_OVERFLOW    => get_output_overflow(n+1) 
      )
      port map (
       clk        => clk,
       rst        => rst,
       clr        => clr_dsp(n),
       vld        => vld,
       sub        => neg_dsp(n),
       x          => x_dsp(n),
       y          => y_dsp(n),
       result     => rslt(n),
       result_vld => rslt_vld(n),
       result_ovf => rslt_ovf(n),
       chainin    => chainout_i(n-1),
       chainout   => chainout_i(n),
       PIPESTAGES => PIPESTAGES_DSP(n)
      );
    end generate;
  end generate;


  -- two multiplications per DSP cell (max width is 18 bit)
  g_type2 : if DSP_TYPE=2 generate
    
   g_fast : if IS_HIGH_SPEED generate
    -- only use "sum-of-2" mode
    gn : for n in 0 to DSP_NUM-1 generate
      inst : entity fixitfetish.signed_mult2_accu(stratixv)
      generic map(
        NUM_SUMMAND        => NUM_SUMMAND,
        USE_CHAIN_INPUT    => enable_chain_input(n+1),
        NUM_INPUT_REG      => NUM_INPUT_REG+n,
        NUM_OUTPUT_REG     => get_num_output_reg(n+1),
        OUTPUT_SHIFT_RIGHT => get_output_shift(n+1),
        OUTPUT_ROUND       => get_output_round(n+1),
        OUTPUT_CLIP        => get_output_clip(n+1),
        OUTPUT_OVERFLOW    => get_output_overflow(n+1) 
      )
      port map (
       clk        => clk,
       rst        => rst,
       clr        => clr_dsp(n),
       vld        => vld,
       sub        => neg_dsp(2*n to 2*n+1),
       x0         => x_dsp(2*n),
       y0         => y_dsp(2*n),
       x1         => x_dsp(2*n+1),
       y1         => y_dsp(2*n+1),
       result     => rslt(n),
       result_vld => rslt_vld(n),
       result_ovf => rslt_ovf(n),
       chainin    => chainout_i(n-1),
       chainout   => chainout_i(n),
       PIPESTAGES => PIPESTAGES_DSP(n)
      );
    end generate;
   end generate;
  
   g_slow : if not IS_HIGH_SPEED generate
    -- First four multiplications with "sum-of-4" mode. Using chain input is not possible.
    -- (saves one input register stage, only with lower frequency possible) 
    assert (not USE_CHAIN_INPUT)
      report "ERROR in " & IMPLEMENTATION & ": " &
             "Chain input not possible with disabled HIGH_SPEED_MODE."
      severity failure;

    i1 : entity fixitfetish.signed_mult4_sum(stratixv)
    generic map(
      NUM_INPUT_REG      => NUM_INPUT_REG,
      NUM_OUTPUT_REG     => 1,
      OUTPUT_SHIFT_RIGHT => 0,
      OUTPUT_ROUND       => false,
      OUTPUT_CLIP        => false,
      OUTPUT_OVERFLOW    => false 
    )
    port map (
     clk        => clk,
     rst        => rst,
     vld        => vld,
     sub        => neg_dsp(0 to 3),
     x0         => x_dsp(0),
     y0         => y_dsp(0),
     x1         => x_dsp(1),
     y1         => y_dsp(1),
     x2         => x_dsp(2),
     y2         => y_dsp(2),
     x3         => x_dsp(3),
     y3         => y_dsp(3),
     result     => rslt(1),
     result_vld => rslt_vld(1),
     result_ovf => rslt_ovf(1),
     chainout   => chainout_i(1),
     PIPESTAGES => PIPESTAGES_DSP(1)
    );
    gn : for n in 2 to DSP_NUM-1 generate
      inst : entity fixitfetish.signed_mult2_accu(stratixv)
      generic map(
        NUM_SUMMAND        => NUM_SUMMAND,
        USE_CHAIN_INPUT    => true,
        NUM_INPUT_REG      => NUM_INPUT_REG+n-1,
        NUM_OUTPUT_REG     => get_num_output_reg(n+1),
        OUTPUT_SHIFT_RIGHT => get_output_shift(n+1),
        OUTPUT_ROUND       => get_output_round(n+1),
        OUTPUT_CLIP        => get_output_clip(n+1),
        OUTPUT_OVERFLOW    => get_output_overflow(n+1) 
      )
      port map (
       clk        => clk,
       rst        => rst,
       clr        => clr_dsp(n),
       vld        => vld,
       sub        => neg_dsp(2*n to 2*n+1),
       x0         => x_dsp(2*n),
       y0         => y_dsp(2*n),
       x1         => x_dsp(2*n+1),
       y1         => y_dsp(2*n+1),
       result     => rslt(n),
       result_vld => rslt_vld(n),
       result_ovf => rslt_ovf(n),
       chainin    => chainout_i(n-1),
       chainout   => chainout_i(n),
       PIPESTAGES => PIPESTAGES_DSP(n)
      );
    end generate;
   end generate;
  end generate;

  -- output result of last instance in the chain
  result <= rslt(DSP_NUM-1);
  result_vld <= rslt_vld(DSP_NUM-1);
  result_ovf <= rslt_ovf(DSP_NUM-1);

  PIPESTAGES <= PIPESTAGES_DSP(DSP_NUM-1);
  
end architecture;
