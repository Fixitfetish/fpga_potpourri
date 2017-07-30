-------------------------------------------------------------------------------
--! @file       cplx_weight_accu.sdr.vhdl
--! @author     Fixitfetish
--! @date       16/Jun/2017
--! @version    0.20
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;
library cplxlib;
  use cplxlib.cplx_pkg.all;
library dsplib;

--! @brief Single Data Rate implementation of the entity cplx_weight_accu .
--! N complex values are weighted (scaled) with one scalar or N scalar
--! values. Finally the weighted results are accumulated.
--!
--! In general this multiplier can be used when FPGA DSP cells are clocked with
--! the standard system clock. 
--!
--! This implementation requires the entity signed_mult_accu .
--!
--! NOTE: The double rate clock 'clk2' is irrelevant and unused here.

architecture sdr of cplx_weight_accu is

  -- The number of pipeline stages is reported as constant at the output port
  -- of the DSP implementation. PIPE_DSP is not a generic and it cannot be used
  -- to constrain the length of a pipeline, hence a maximum pipeline length
  -- must be defined here. Increase the value if required.
  constant MAX_NUM_PIPE_DSP : positive := 16;

  -- bit resolution of input and output data
  constant WIDTH_W : positive := w(w'left)'length;
  constant WIDTH_X : positive := x(x'left).re'length;
  constant WIDTH_R : positive := result.re'length;

  -- number of elements of weight factor vector w
  -- (must be either 1 or the same length as x)
  constant NUM_FACTOR : positive := w'length;

  -- convert to default range
  alias w_i : signed_vector(0 to NUM_FACTOR-1)(WIDTH_W-1 downto 0) is w;

  signal x_re, x_im : signed_vector(0 to NUM_MULT-1)(WIDTH_X-1 downto 0);
  signal w_dsp : signed_vector(0 to NUM_MULT-1)(WIDTH_W-1 downto 0);
  signal neg_re, neg_im : std_logic_vector(0 to NUM_MULT-1) := (others=>'0');

  -- merged input signals and compensate for multiplier pipeline stages
  signal rst_x : std_logic_vector(0 to NUM_MULT-1);
  signal ovf_x : std_logic_vector(0 to NUM_MULT-1);
  signal vld_x : std_logic_vector(0 to NUM_MULT-1);
  signal rst : std_logic_vector(0 to MAX_NUM_PIPE_DSP) := (others=>'1');
  signal ovf : std_logic_vector(0 to MAX_NUM_PIPE_DSP) := (others=>'0');

  -- auxiliary
  signal vld : std_logic;
  signal data_reset : std_logic := '0';

  -- output signals
  signal r_ovf_re, r_ovf_im : std_logic;
  constant DEFAULT_RESULT : cplx_vector := cplx_vector_reset(NUM_OUTPUT_REG+1,WIDTH_R,"R");
  signal rslt : cplx_vector(0 to NUM_OUTPUT_REG)(re(WIDTH_R-1 downto 0),im(WIDTH_R-1 downto 0)) := DEFAULT_RESULT;

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
    rst_x(n) <= x(n).rst;
    vld_x(n) <= x(n).vld;
    ovf_x(n) <= x(n).ovf;
  end generate;

  -- merge input control signals
  rst(0) <= (ANY_ONES(rst_x));
  vld <= ALL_ONES(vld_x) when rst(0)='0' else '0';

  -- Consider overflow flags of all inputs that are summed.
  -- If the overflow flag of any input is set then also the result
  -- will have the overflow flag set.   
  ovf(0) <= '0' when (MODE='X' or rst(0)='1') else
            ANY_ONES(ovf_x);

  g_in : for n in 0 to NUM_MULT-1 generate
    -- mapping of complex inputs
    neg_re(n) <= neg(n);
    neg_im(n) <= neg(n);
    x_re(n) <= x(n).re;
    x_im(n) <= x(n).im;
    g_w1 : if NUM_FACTOR=1 generate
      -- same weighting factor for all complex vector elements
      w_dsp(n) <= w_i(0);
    end generate;
    g_wn : if NUM_FACTOR=NUM_MULT generate
      -- separate weighting factor for each complex vector element
      w_dsp(n) <= w_i(n);
    end generate;
  end generate;

  -- reset result data output to zero
  data_reset <= rst(0) when MODE='R' else '0';

  -- accumulator delay compensation (DSP bypassed!)
  g_delay : for n in 1 to MAX_NUM_PIPE_DSP generate
    rst(n) <= rst(n-1) when rising_edge(clk);
    ovf(n) <= ovf(n-1) when rising_edge(clk);
  end generate;

  -- weighting
  i_re : entity dsplib.signed_mult_accu
  generic map(
    NUM_MULT           => NUM_MULT,
    NUM_SUMMAND        => NUM_SUMMAND,
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
    neg        => neg_re,
    x          => x_re,
    y          => w_dsp,
    result     => rslt(0).re,
    result_vld => rslt(0).vld,
    result_ovf => r_ovf_re,
    chainin    => open, -- unused
    chainout   => open, -- unused
    PIPESTAGES => PIPE_DSP
  );

  -- weighting
  i_im : entity dsplib.signed_mult_accu
  generic map(
    NUM_MULT           => NUM_MULT,
    NUM_SUMMAND        => NUM_SUMMAND,
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
    neg        => neg_im,
    x          => x_im,
    y          => w_dsp,
    result     => rslt(0).im,
    result_vld => open, -- same as real component
    result_ovf => r_ovf_im,
    chainin    => open, -- unused
    chainout   => open, -- unused
    PIPESTAGES => open  -- same as real component
  );

  -- pipeline delay is the same for all
  rslt(0).rst <= rst(PIPE_DSP);
  rslt(0).ovf <= (r_ovf_re or r_ovf_im) when MODE='X' else
                 (r_ovf_re or r_ovf_im or ovf(PIPE_DSP));

  -- additional output registers
  g_out_reg : if NUM_OUTPUT_REG>=1 generate
    g_loop : for n in 1 to NUM_OUTPUT_REG generate
      rslt(n) <= rslt(n-1) when rising_edge(clk);
    end generate;
  end generate;

  -- map result to output port
  result <= rslt(NUM_OUTPUT_REG);

  -- report constant number of pipeline register stages (in 'clk' domain)
  PIPESTAGES <= PIPE_DSP + NUM_OUTPUT_REG;

end architecture;
