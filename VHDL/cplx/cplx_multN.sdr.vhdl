-------------------------------------------------------------------------------
--! @file       cplx_multN.sdr.vhdl
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

--! @brief Single Data Rate implementation of the entity cplx_multN .
--! N complex multiplications are performed.
--!
--! This implementation requires the FPGA device dependent entity signed_multN_sum.
--! @image html cplx_multN.sdr.svg "" width=800px
--!
--! In general this multiplier can be used when FPGA DSP cells are clocked with
--! the standard system clock. 
--!
--! NOTE: The double rate clock 'clk2' is irrelevant and unused here.

architecture sdr of cplx_multN is

  -- The number of pipeline stages is reported as constant at the output port
  -- of the DSP implementation. PIPE_DSP is not a generic and it cannot be used
  -- to constrain the length of a pipeline, hence a maximum pipeline length
  -- must be defined here. Increase the value if required.
  constant MAX_NUM_PIPE_DSP : positive := 16;

  -- number of elements of complex input vector x
  constant NUM_INPUTS : positive := x'length;
  
  -- number of elements of complex factor vector y
  -- (must be either 1 or the same length as x)
  constant NUM_FACTOR : positive := y'length;

  -- convert to default range
  alias neg_i : std_logic_vector(0 to NUM_INPUTS-1) is neg;
  alias x_i : cplx_vector(0 to NUM_INPUTS-1) is x;
  alias y_i : cplx_vector(0 to NUM_FACTOR-1) is y;

  signal x_re, x_im : signed_vector(0 to 2*NUM_INPUTS-1);
  signal y_re, y_im : signed_vector(0 to 2*NUM_INPUTS-1);
  signal sub_re, sub_im : std_logic_vector(0 to 2*NUM_INPUTS-1) := (others=>'0');

  -- merged input signals and compensate for multiplier pipeline stages
  type t_delay is array(integer range <>) of std_logic_vector(0 to NUM_INPUTS-1);
  signal rst, ovf : t_delay(0 to MAX_NUM_PIPE_DSP);

  -- auxiliary
  signal vld : std_logic_vector(0 to NUM_INPUTS-1) := (others=>'0');
  signal data_reset : std_logic_vector(0 to NUM_INPUTS-1) := (others=>'0');

  -- output signals
  -- ! for 1993/2008 compatibility reasons do not use cplx record here !
  signal r_ovf_re, r_ovf_im : std_logic_vector(0 to NUM_INPUTS-1);
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
  type t_pipe is array(integer range <>) of natural;
  signal PIPE_DSP : t_pipe(0 to NUM_INPUTS-1);

  -- dummy sink to avoid warnings
  procedure std_logic_sink(x:in std_logic) is
    variable y : std_logic := '1';
  begin y:=y or x; end procedure;

begin

  -- dummy sink for unused clock
  std_logic_sink(clk2);

  g_in : for n in 0 to NUM_INPUTS-1 generate
    -- map inputs for calculation of real component
    sub_re(2*n)   <= neg_i(n); -- +/-(+x.re*y.re)
    sub_re(2*n+1) <= not neg_i(n); -- +/-(-x.im*y.im)
    x_re(2*n)     <= x_i(n).re;
    x_re(2*n+1)   <= x_i(n).im;
    -- map inputs for calculation of imaginary component
    sub_im(2*n)   <= neg_i(n); -- +/-(+x.re*y.im)
    sub_im(2*n+1) <= neg_i(n); -- +/-(+x.im*y.re)
    x_im(2*n)     <= x_i(n).re;
    x_im(2*n+1)   <= x_i(n).im;
    g_y1 : if NUM_FACTOR=1 generate
      -- map inputs for calculation of real component
      y_re(2*n)     <= y_i(0).re;
      y_re(2*n+1)   <= y_i(0).im;
      -- map inputs for calculation of imaginary component
      y_im(2*n)     <= y_i(0).im;
      y_im(2*n+1)   <= y_i(0).re;
      -- merge input control signals
      rst(0)(n) <= (x_i(n).rst or y_i(0).rst);
      ovf(0)(n) <= (x_i(n).ovf or y_i(0).ovf) when rst(0)(n)='0' else '0';
      vld(n) <= (x_i(n).vld and y_i(0).vld) when rst(0)(n)='0' else '0';
    end generate;
    g_yn : if NUM_FACTOR=NUM_INPUTS generate
      -- map inputs for calculation of real component
      y_re(2*n)     <= y_i(n).re;
      y_re(2*n+1)   <= y_i(n).im;
      -- map inputs for calculation of imaginary component
      y_im(2*n)     <= y_i(n).im;
      y_im(2*n+1)   <= y_i(n).re;
      -- merge input control signals
      rst(0)(n) <= (x_i(n).rst or y_i(n).rst);
      ovf(0)(n) <= (x_i(n).ovf or y_i(n).ovf) when rst(0)(n)='0' else '0';
      vld(n) <= (x_i(n).vld and y_i(n).vld) when rst(0)(n)='0' else '0';
    end generate;
  end generate;

  -- reset result data output to zero
  data_reset <= rst(0) when m='R' else (others=>'0');

  -- accumulator delay compensation (DSP bypassed!)
  g_loop : for n in 1 to MAX_NUM_PIPE_DSP generate
    rst(n) <= rst(n-1) when rising_edge(clk);
    ovf(n) <= ovf(n-1) when rising_edge(clk);
  end generate;

  g_mult : for n in 0 to NUM_INPUTS-1 generate
    -- calculate real component
    i_re : entity fixitfetish.signed_multN_sum
    generic map(
      NUM_MULT           => 2, -- two multiplications per complex multiplication
      FAST_MODE          => false,
      NUM_INPUT_REG      => NUM_INPUT_REG,
      NUM_OUTPUT_REG     => 1, -- always enable DSP cell output register (= first output register)
      OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
      OUTPUT_ROUND       => (m='N'),
      OUTPUT_CLIP        => (m='S'),
      OUTPUT_OVERFLOW    => (m='O')
    )
    port map (
     clk        => clk,
     rst        => data_reset(n),
     vld        => vld(n),
     sub        => sub_re(2*n to 2*n+1),
     x          => x_re(2*n to 2*n+1),
     y          => y_re(2*n to 2*n+1),
     result     => rslt(0)(n).re,
     result_vld => rslt(0)(n).vld,
     result_ovf => r_ovf_re(n),
     PIPESTAGES => PIPE_DSP(n)
    );

    -- calculate imaginary component
    i_im : entity fixitfetish.signed_multN_sum
    generic map(
      NUM_MULT           => 2, -- two multiplications per complex multiplication
      FAST_MODE          => false,
      NUM_INPUT_REG      => NUM_INPUT_REG,
      NUM_OUTPUT_REG     => 1, -- always enable DSP cell output register (= first output register)
      OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
      OUTPUT_ROUND       => (m='N'),
      OUTPUT_CLIP        => (m='S'),
      OUTPUT_OVERFLOW    => (m='O')
    )
    port map (
     clk        => clk,
     rst        => data_reset(n),
     vld        => vld(n),
     sub        => sub_im(2*n to 2*n+1),
     x          => x_im(2*n to 2*n+1),
     y          => y_im(2*n to 2*n+1),
     result     => rslt(0)(n).im,
     result_vld => open, -- same as real component
     result_ovf => r_ovf_im(n),
     PIPESTAGES => open  -- same as real component
    );

    -- pipeline delay is the same for all
    rslt(0)(n).rst <= rst(PIPE_DSP(0))(n);
    rslt(0)(n).ovf <= ovf(PIPE_DSP(0))(n) or r_ovf_re(n) or r_ovf_im(n);
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
  PIPESTAGES <= PIPE_DSP(0) + NUM_OUTPUT_REG;

end architecture;
