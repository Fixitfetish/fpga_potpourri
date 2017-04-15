-------------------------------------------------------------------------------
--! @file       cplx_mult_accu.sdr.vhdl
--! @author     Fixitfetish
--! @date       14/Apr/2017
--! @version    0.30
--! @copyright  MIT License
--! @note       VHDL-1993
-------------------------------------------------------------------------------
-- Copyright (c) 2017 Fixitfetish
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library fixitfetish;
 use fixitfetish.cplx_pkg.all;
 use fixitfetish.ieee_extension.all;
 use fixitfetish.ieee_extension_types.all;

--! @brief N complex multiplications and accumulate all (Single Data Rate).
--!
--! This implementation requires the FPGA device dependent module signed_multN_accu.
--! @image html cplx_mult_accu.sdr.svg "" width=800px
--!
--! In general this multiplier can be used when FPGA DSP cells are clocked with
--! the standard system clock. 
--!
--! NOTE: The double rate clock 'clk2' is irrelevant and unused here.

architecture sdr of cplx_mult_accu is

  -- The number of pipeline stages is reported as constant at the output port
  -- of the DSP implementation. PIPE_DSP is not a generic and it cannot be used
  -- to constrain the length of a pipeline, hence a maximum pipeline length
  -- must be defined here. Increase the value if required.
  constant MAX_NUM_PIPE_DSP : positive := 16;

  -- number of elements of complex factor vector y
  -- (must be either 1 or the same length as x)
  constant NUM_FACTOR : positive := y'length;

  -- convert to default range
  alias y_i : cplx_vector(0 to NUM_FACTOR-1) is y;

  signal x_re, x_im : signed_vector(0 to 2*NUM_MULT-1);
  signal y_re, y_im : signed_vector(0 to 2*NUM_MULT-1);
  signal neg_re, neg_im : std_logic_vector(0 to 2*NUM_MULT-1) := (others=>'0');

  -- merged input signals and compensate for multiplier pipeline stages
  signal rst_x, rst_y : std_logic_vector(0 to NUM_MULT-1);
  signal ovf_x, ovf_y : std_logic_vector(0 to NUM_MULT-1);
  signal vld_x, vld_y : std_logic_vector(0 to NUM_MULT-1);
  signal rst : std_logic_vector(0 to MAX_NUM_PIPE_DSP) := (others=>'1');
  signal ovf : std_logic_vector(0 to MAX_NUM_PIPE_DSP) := (others=>'0');

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

  g_merge : for n in 0 to NUM_MULT-1 generate
    rst_x(n) <= x(n).rst; rst_y(n) <= y_i(n).rst;
    vld_x(n) <= x(n).vld; vld_y(n) <= y_i(n).vld;
    ovf_x(n) <= x(n).ovf; ovf_y(n) <= y_i(n).ovf;
  end generate;

  -- merge input control signals
  rst(0) <= (ANY_ONES(rst_x) or  ANY_ONES(rst_y));
  vld <= (ALL_ONES(vld_x) and ALL_ONES(vld_y)) when rst(0)='0' else '0';

  -- Consider overflow flags of all inputs that are summed.
  -- If the overflow flag of any input is set then also the result
  -- will have the overflow flag set.   
  ovf(0) <= '0' when (INPUT_OVERFLOW_IGNORE or rst(0)='1') else
            (ANY_ONES(ovf_x) or  ANY_ONES(ovf_y));

  g_in : for n in 0 to NUM_MULT-1 generate
    -- map inputs for calculation of real component
    neg_re(2*n)   <= neg(n); -- +/-(+x.re*y.re)
    neg_re(2*n+1) <= not neg(n); -- +/-(-x.im*y.im)
    x_re(2*n)     <= x(n).re;
    x_re(2*n+1)   <= x(n).im;
    -- map inputs for calculation of imaginary component
    neg_im(2*n)   <= neg(n); -- +/-(+x.re*y.im)
    neg_im(2*n+1) <= neg(n); -- +/-(+x.im*y.re)
    x_im(2*n)     <= x(n).re;
    x_im(2*n+1)   <= x(n).im;
    g_y1 : if NUM_FACTOR=1 generate
      -- map inputs for calculation of real component
      y_re(2*n)     <= y_i(0).re;
      y_re(2*n+1)   <= y_i(0).im;
      -- map inputs for calculation of imaginary component
      y_im(2*n)     <= y_i(0).im;
      y_im(2*n+1)   <= y_i(0).re;
    end generate;
    g_yn : if NUM_FACTOR=NUM_MULT generate
      -- map inputs for calculation of real component
      y_re(2*n)     <= y_i(n).re;
      y_re(2*n+1)   <= y_i(n).im;
      -- map inputs for calculation of imaginary component
      y_im(2*n)     <= y_i(n).im;
      y_im(2*n+1)   <= y_i(n).re;
    end generate;
  end generate;

  -- reset result data output to zero
  data_reset <= rst(0) when MODE='R' else '0';

  -- accumulator delay compensation (DSP bypassed!)
  g_delay : for n in 1 to MAX_NUM_PIPE_DSP generate
    rst(n) <= rst(n-1) when rising_edge(clk);
    ovf(n) <= ovf(n-1) when rising_edge(clk);
  end generate;

  -- calculate real component
  i_re : entity fixitfetish.signed_multN_accu
  generic map(
    NUM_MULT           => 2*NUM_MULT, -- two multiplications per complex multiplication
    NUM_SUMMAND        => 2*NUM_SUMMAND, -- two multiplications per complex multiplication
    USE_CHAIN_INPUT    => false, -- unused here
    NUM_INPUT_REG      => NUM_INPUT_REG,
    NUM_OUTPUT_REG     => 1, -- always enable accumulator (= first output register)
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => (MODE='N'),
    OUTPUT_CLIP        => (MODE='S'),
    OUTPUT_OVERFLOW    => (MODE='O')
  )
  port map (
    clk        => clk,
    rst        => data_reset,
    clr        => clr,
    vld        => vld,
    sub        => neg_re,
    x          => x_re,
    y          => y_re,
    result     => rslt(0).re,
    result_vld => rslt(0).vld,
    result_ovf => r_ovf_re,
    chainin    => open, -- unused
    chainout   => open, -- unused
    PIPESTAGES => PIPE_DSP
  );

  -- calculate imaginary component
  i_im : entity fixitfetish.signed_multN_accu
  generic map(
    NUM_MULT           => 2*NUM_MULT, -- two multiplications per complex multiplication
    NUM_SUMMAND        => 2*NUM_SUMMAND, -- two multiplications per complex multiplication
    USE_CHAIN_INPUT    => false, -- unused here
    NUM_INPUT_REG      => NUM_INPUT_REG,
    NUM_OUTPUT_REG     => 1, -- always enable accumulator (= first output register)
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => (MODE='N'),
    OUTPUT_CLIP        => (MODE='S'),
    OUTPUT_OVERFLOW    => (MODE='O')
  )
  port map (
    clk        => clk,
    rst        => data_reset,
    clr        => clr,
    vld        => vld,
    sub        => neg_im,
    x          => x_im,
    y          => y_im,
    result     => rslt(0).im,
    result_vld => open, -- same as real component
    result_ovf => r_ovf_im,
    chainin    => open, -- unused
    chainout   => open, -- unused
    PIPESTAGES => open  -- same as real component
  );

  -- pipeline delay is the same for all
  rslt(0).rst <= rst(PIPE_DSP);
  rslt(0).ovf <= (r_ovf_re or r_ovf_im) when INPUT_OVERFLOW_IGNORE else
                 (r_ovf_re or r_ovf_im or ovf(PIPE_DSP));

  -- additional output registers
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
