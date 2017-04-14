-------------------------------------------------------------------------------
--! @file       cplx_weight.sdr.vhdl
--! @author     Fixitfetish
--! @date       25/Mar/2017
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
 use fixitfetish.ieee_extension_types.all;
 use fixitfetish.cplx_pkg.all;

--! @brief Single Data Rate implementation of the entity cplx_weight .
--! N complex values are weighted (scaled) with one scalar or N scalar values.
--! Can be used for scalar multiplication.
--!
--! This implementation requires the FPGA device dependent entity signed_multN .
--! @image html cplx_weight.sdr.svg "" width=800px
--!
--! In general this multiplier can be used when FPGA DSP cells are clocked with
--! the standard system clock. 
--!
--! NOTE: The double rate clock 'clk2' is irrelevant and unused here.

architecture sdr of cplx_weight is

  -- The number of pipeline stages is reported as constant at the output port
  -- of the DSP implementation. PIPE_DSP is not a generic and it cannot be used
  -- to constrain the length of a pipeline, hence a maximum pipeline length
  -- must be defined here. Increase the value if required.
  constant MAX_NUM_PIPE_DSP : positive := 16;

  -- number of elements of complex input vector x
  constant NUM_INPUTS : positive := x'length;
  
  -- number of elements of complex factor vector y
  -- (must be either 1 or the same length as x)
  constant NUM_WEIGHTS : positive := w'length;
  
  -- convert to default range
  alias neg_i : std_logic_vector(0 to NUM_INPUTS-1) is neg;
  alias x_i : cplx_vector(0 to NUM_INPUTS-1) is x;
  alias w_i : signed_vector(0 to NUM_WEIGHTS-1) is w;

  -- multiplier input signals
  signal neg_dsp : std_logic_vector(0 to 2*NUM_INPUTS-1);
  signal x_dsp : signed_vector(0 to 2*NUM_INPUTS-1);
  signal w_dsp : signed_vector(0 to 2*NUM_INPUTS-1);

  -- merged input signals and compensate for multiplier pipeline stages
  type t_delay is array(integer range <>) of std_logic_vector(0 to NUM_INPUTS-1);
  signal rst, ovf : t_delay(0 to MAX_NUM_PIPE_DSP);

  -- auxiliary
  signal vld : std_logic;
  signal data_reset : std_logic := '0';

  -- output signals
  -- ! for 1993/2008 compatibility reasons do not use cplx record here !
  signal r_vld, r_ovf : std_logic_vector(0 to 2*NUM_INPUTS-1);
  signal r : signed_vector(0 to 2*NUM_INPUTS-1);
  type record_result is
  record
    rst, vld, ovf : std_logic;
    re : signed(result(result'left).re'length-1 downto 0);
    im : signed(result(result'left).im'length-1 downto 0);
  end record;
  type vector_result is array(integer range<>) of record_result;
  type matrix_result is array(integer range<>) of vector_result(0 to NUM_INPUTS-1);
  signal rslt : matrix_result(0 to NUM_OUTPUT_REG);

  -- pipeline stages of used DSP cell
  signal PIPE_DSP : natural;

  -- dummy sink to avoid warnings
  procedure std_logic_sink(x:in std_logic) is
    variable y : std_logic := '1';
  begin y:=y or x; end procedure;

begin

  -- dummy sink for unused clock
  std_logic_sink(clk2);

  g_in : for k in 0 to NUM_INPUTS-1 generate 
    -- mapping of complex inputs
    neg_dsp(2*k) <= neg_i(k);    neg_dsp(2*k+1) <= neg_i(k);
    x_dsp(2*k)   <= x_i(k).re;   x_dsp(2*k+1)   <= x_i(k).im;

    -- duplicate weighting factor
    g_w1 : if NUM_WEIGHTS=1 generate
      -- same weighting factor for all complex vector elements
      w_dsp(2*k) <= w_i(0);      w_dsp(2*k+1)   <= w_i(0);
    end generate;
    g_wn : if NUM_WEIGHTS=NUM_INPUTS generate
      -- separate weighting factor for each complex vector element
      w_dsp(2*k) <= w_i(k);      w_dsp(2*k+1)   <= w_i(k);
    end generate;

    -- merge input control signals
    rst(0)(k) <= x_i(k).rst;
    ovf(0)(k) <= x_i(k).ovf when x_i(k).rst='0' else '0';
  end generate;

  -- valid must be the same for all inputs
  vld <= x_i(0).vld when x_i(0).rst='0' else '0';

  -- reset result data output to zero
  data_reset <= x_i(0).rst when m='R' else '0';

  -- accumulator delay compensation (DSP bypassed!)
  g_loop : for n in 1 to MAX_NUM_PIPE_DSP generate
    rst(n) <= rst(n-1) when rising_edge(clk);
    ovf(n) <= ovf(n-1) when rising_edge(clk);
  end generate;

  -- weighting
  i_weight : entity fixitfetish.signed_multN
  generic map(
    NUM_MULT           => 2*NUM_INPUTS,
    NUM_INPUT_REG      => NUM_INPUT_REG,
    NUM_OUTPUT_REG     => 1, -- always enable DSP internal output register
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => (m='N'),
    OUTPUT_CLIP        => (m='S'),
    OUTPUT_OVERFLOW    => (m='O')
  )
  port map (
    clk           => clk,
    rst           => data_reset,
    vld           => vld,
    neg           => neg_dsp,
    x             => x_dsp,
    y             => w_dsp,
    result        => r,
    result_vld    => r_vld,
    result_ovf    => r_ovf,
    PIPESTAGES    => PIPE_DSP
  );

  g_rslt : for k in 0 to NUM_INPUTS-1 generate
    rslt(0)(k).rst <= rst(PIPE_DSP)(k);
    rslt(0)(k).ovf <= ovf(PIPE_DSP)(k) or r_ovf(2*k) or r_ovf(2*k+1);
    rslt(0)(k).vld <= r_vld(2*k) and (not rst(PIPE_DSP)(k)); -- valid signal is the same for all product results
    rslt(0)(k).re <= r(2*k);
    rslt(0)(k).im <= r(2*k+1);
  end generate;

  -- output registers
  g_out_reg : if NUM_OUTPUT_REG>=1 generate
    g_loop : for n in 1 to NUM_OUTPUT_REG generate
      rslt(n) <= rslt(n-1) when rising_edge(clk);
    end generate;
  end generate;

  -- map result to output port
  g_out : for k in 0 to NUM_INPUTS-1 generate
    result(k).rst <= rslt(NUM_OUTPUT_REG)(k).rst;
    result(k).vld <= rslt(NUM_OUTPUT_REG)(k).vld;
    result(k).ovf <= rslt(NUM_OUTPUT_REG)(k).ovf;
    result(k).re  <= rslt(NUM_OUTPUT_REG)(k).re;
    result(k).im  <= rslt(NUM_OUTPUT_REG)(k).im;
  end generate;

  -- report constant number of pipeline register stages (in 'clk' domain)
  PIPESTAGES <= PIPE_DSP + NUM_OUTPUT_REG;

end architecture;
