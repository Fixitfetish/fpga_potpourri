-------------------------------------------------------------------------------
--! @file       cplx_weightN_sum.sdr.vhdl
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

--! @brief Single Data Rate implementation of the entity cplx_weightN_sum .
--! N complex values are weighted (scaled) with one scalar or N scalar
--! values. Finally the weighted results are summed.
--!
--! In general this multiplier can be used when FPGA DSP cells are clocked with
--! the standard system clock. 
--!
--! This implementation requires the FPGA type dependent entity signed_multN_sum .
--!
--! NOTE: The double rate clock 'clk2' is irrelevant and unused here.

architecture sdr of cplx_weightN_sum is

  -- The number of pipeline stages is reported as constant at the output port
  -- of the DSP implementation. PIPE_DSP is not a generic and it cannot be used
  -- to constrain the length of a pipeline, hence a maximum pipeline length
  -- must be defined here. Increase the value if required.
  constant MAX_NUM_PIPE_DSP : positive := 16;

  -- number of complex vector elements
  constant NUM_INPUTS : positive := x'length;

  -- The number of weight factors must be either 1 or the same as the number
  -- as complex input values X.
  constant NUM_WEIGHTS : positive := w'length;

  -- convert to default range
  alias sub_i : std_logic_vector(0 to NUM_INPUTS-1) is sub;
  alias x_i : cplx_vector(0 to NUM_INPUTS-1) is x;
  alias w_i : signed_vector(0 to NUM_WEIGHTS-1) is w;

  -- multiplier input signals
  signal sub_dsp : std_logic_vector(0 to NUM_INPUTS-1);
  signal x_re_dsp : signed_vector(0 to NUM_INPUTS-1);
  signal x_im_dsp : signed_vector(0 to NUM_INPUTS-1);
  signal w_dsp : signed_vector(0 to NUM_INPUTS-1);

  -- merged input signals and compensate for multiplier pipeline stages
--  type t_delay is array(integer range <>) of std_logic_vector(0 to NUM_INPUTS-1);
  signal rst, ovf : std_logic_vector(0 to MAX_NUM_PIPE_DSP);

  -- auxiliary
  signal vld : std_logic;
  signal data_reset : std_logic := '0';

  -- output signals
  -- ! for 1993/2008 compatibility reasons do not use cplx record here !
  signal r_ovf_re, r_ovf_im : std_logic;
  type record_result is
  record
    rst, vld, ovf : std_logic;
    re : signed(result.re'length-1 downto 0);
    im : signed(result.im'length-1 downto 0);
  end record;
  type array_result is array(integer range<>) of record_result;
  signal rslt : array_result(0 to NUM_OUTPUT_REG);

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
    sub_dsp(k)  <= sub_i(k);
    x_re_dsp(k) <= x_i(k).re;
    x_im_dsp(k) <= x_i(k).im;

    -- mapping of weighting factor(s)
    g_w1 : if NUM_WEIGHTS=1 generate
      -- same weighting factor for all complex vector elements
      w_dsp(k) <= w_i(0);
    end generate;
    g_wn : if NUM_WEIGHTS=NUM_INPUTS generate
      -- separate weighting factor for each complex vector element
      w_dsp(k) <= w_i(k);
    end generate;

  end generate;

  -- merge input control signals
  rst(0) <= x_i(0).rst;
  ovf(0) <= x_i(0).ovf when x_i(0).rst='0' else '0';

  -- valid must be the same for all inputs (derive from first vector element)
  vld <= x_i(0).vld when x_i(0).rst='0' else '0';

  -- reset result data output to zero
  data_reset <= x_i(0).rst when m='R' else '0';

  -- weighting
  i_real : entity fixitfetish.signed_multN_sum
  generic map(
    NUM_MULT           => NUM_INPUTS,
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
    sub           => sub_dsp,
    x             => x_re_dsp,
    y             => w_dsp,
    result        => rslt(0).re,
    result_vld    => rslt(0).vld,
    result_ovf    => r_ovf_re,
    PIPESTAGES    => PIPE_DSP
  );

  -- weighting
  i_imag : entity fixitfetish.signed_multN_sum
  generic map(
    NUM_MULT           => NUM_INPUTS,
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
    sub           => sub_dsp,
    x             => x_im_dsp,
    y             => w_dsp,
    result        => rslt(0).im,
    result_vld    => open, -- same as real component
    result_ovf    => r_ovf_im,
    PIPESTAGES    => open -- same as real component
  );

  -- accumulator delay compensation (DSP bypassed!)
  g_delay : for n in 1 to MAX_NUM_PIPE_DSP generate
    rst(n) <= rst(n-1) when rising_edge(clk);
    ovf(n) <= ovf(n-1) when rising_edge(clk);
  end generate;
  rslt(0).rst <= rst(PIPE_DSP);
  rslt(0).ovf <= ovf(PIPE_DSP) or r_ovf_re or r_ovf_im;

  -- output registers
  g_out_reg : if NUM_OUTPUT_REG>=1 generate
    g_loop : for n in 1 to NUM_OUTPUT_REG generate
      rslt(n) <= rslt(n-1) when rising_edge(clk);
    end generate;
  end generate;

  -- map result to output port
  result.rst <= rslt(NUM_OUTPUT_REG).rst;
  result.vld <= rslt(NUM_OUTPUT_REG).vld;
  result.ovf <= rslt(NUM_OUTPUT_REG).ovf;
  result.re  <= rslt(NUM_OUTPUT_REG).re;
  result.im  <= rslt(NUM_OUTPUT_REG).im;

  -- report constant number of pipeline register stages (in 'clk' domain)
  PIPESTAGES <= PIPE_DSP + NUM_OUTPUT_REG;

end architecture;
