-------------------------------------------------------------------------------
--! @file       cplx_weight.sdr.vhdl
--! @author     Fixitfetish
--! @date       15/May/2019
--! @version    0.60
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
  use baselib.pipereg_pkg.all;
library cplxlib;
  use cplxlib.cplx_pkg.all;
library dsplib;

--! @brief Single Data Rate implementation of the entity cplx_weight .
--! N complex values are weighted (signed scaling) with one scalar or N scalar values.
--! Can be used for scalar multiplication.
--!
--! This implementation requires the entity signed_mult .
--! @image html cplx_weight.sdr.svg "" width=600px
--!
--! In general this multiplier can be used when FPGA DSP cells are clocked with
--! the standard system clock. 
--!
--! NOTE: The double rate clock 'clk2' is irrelevant and unused here.
--!
architecture sdr of cplx_weight is

  -- The number of pipeline stages is reported as constant at the output port
  -- of the DSP implementation. PIPE_DSP is not a generic and it cannot be used
  -- to constrain the length of a pipeline, hence a maximum pipeline length
  -- must be defined here. Increase the value if required.
  constant MAX_NUM_PIPE_DSP : positive := 16;

  -- bit resolution of input and output data
  constant WIDTH_X : positive := x(x'left).re'length;
  constant WIDTH_W : positive := w(w'left)'length;
  constant WIDTH_R : positive := result(result'left).re'length;

  -- number of elements of factor vector
  -- (must be either 1 or the same length as x)
  constant NUM_FACTOR : positive := w'length;

  -- convert to default range
  alias w_i : signed_vector(0 to NUM_FACTOR-1)(WIDTH_W-1 downto 0) is w;

  -- multiplier input signals
  signal vld_dsp : std_logic := '0';
  signal neg_dsp : std_logic_vector(0 to 2*NUM_MULT-1);
  signal x_dsp : signed_vector(0 to 2*NUM_MULT-1)(WIDTH_X-1 downto 0);
  signal w_dsp : signed_vector(0 to 2*NUM_MULT-1)(WIDTH_W-1 downto 0);

  -- merged input signals and compensate for multiplier pipeline stages
  type t_delay is array(integer range <>) of std_logic_vector(0 to NUM_MULT-1);
  signal reset : t_delay(0 to MAX_NUM_PIPE_DSP) := (others=>(others=>'1'));
  signal ovf : t_delay(0 to MAX_NUM_PIPE_DSP) := (others=>(others=>'0'));

  -- auxiliary
  signal vld : std_logic_vector(0 to NUM_MULT-1) := (others=>'0');
  signal reset_mult : std_logic := '0';

  -- DSP output signals
  signal r_vld, r_ovf : std_logic_vector(0 to 2*NUM_MULT-1);
  signal r : signed_vector(0 to 2*NUM_MULT-1)(WIDTH_R-1 downto 0);
  signal rslt : cplx_vector(0 to NUM_MULT-1)(re(WIDTH_R-1 downto 0),im(WIDTH_R-1 downto 0));
  signal PIPE_DSP : natural; -- pipeline stages of used DSP cell

  -- dummy sink to avoid warnings
  procedure dummy_sink(si:in std_logic) is
    variable sv : std_logic := '1';
  begin sv:=sv or si; end procedure;

begin

  -- dummy sink for unused clock
  dummy_sink(clk2);

  g_merge : for n in 0 to NUM_MULT-1 generate
    -- merge input control signals
    reset(0)(n) <= x(n).rst;
    vld(n) <= x(n).vld when reset(0)(n)='0' else '0';
    -- Consider overflow flags of all inputs.
    -- If the overflow flag of any input is set then also the result
    -- will have the overflow flag set.   
    ovf(0)(n) <= '0' when (MODE='X' or reset(0)(n)='1') else x(n).ovf;
  end generate;
  vld_dsp <= ANY_ONES(vld);

  g_in : for n in 0 to NUM_MULT-1 generate
    -- mapping of complex inputs
    neg_dsp(2*n)   <= neg(n) when USE_NEGATION else '0';
    neg_dsp(2*n+1) <= neg(n) when USE_NEGATION else '0';
    x_dsp(2*n)     <= x(n).re;
    x_dsp(2*n+1)   <= x(n).im;
    g1 : if NUM_FACTOR=1 generate
      -- same weighting factor for all complex vector elements
      w_dsp(2*n)   <= w_i(0);
      w_dsp(2*n+1) <= w_i(0);
    end generate;
    gn : if NUM_FACTOR=NUM_MULT generate
      -- separate weighting factor for each complex vector element
      w_dsp(2*n)   <= w_i(n);
      w_dsp(2*n+1) <= w_i(n);
    end generate;
  end generate;

  -- reset multiplier pipeline (set invalid)
  reset_mult <= rst or reset(0)(0);

  -- accumulator delay compensation (DSP bypassed!)
  g_delay : for n in 1 to MAX_NUM_PIPE_DSP generate
  begin
--    reset(n) <= reset(n-1) when rising_edge(clk);
--    ovf(n) <= ovf(n-1) when rising_edge(clk);
    pipereg(xout=>reset(n), xin=>reset(n-1), clk=>clk, ce=>clkena);
    pipereg(xout=>ovf(n), xin=>ovf(n-1), clk=>clk, ce=>clkena);
  end generate;

  -- weighting
  i_weight : entity dsplib.signed_mult
  generic map(
    NUM_MULT           => 2*NUM_MULT,
    USE_NEGATION       => USE_NEGATION,
    NUM_INPUT_REG      => NUM_INPUT_REG,
    NUM_OUTPUT_REG     => 1, -- always enable DSP internal output register
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => (MODE='N'),
    OUTPUT_CLIP        => (MODE='S'),
    OUTPUT_OVERFLOW    => (MODE='O')
  )
  port map (
    clk           => clk,
    rst           => reset_mult,
    clkena        => clkena,
    vld           => vld_dsp,
    neg           => neg_dsp,
    x             => x_dsp,
    y             => w_dsp,
    result        => r,
    result_vld    => r_vld,
    result_ovf    => r_ovf,
    PIPESTAGES    => PIPE_DSP
  );

  g_rslt : for n in 0 to NUM_MULT-1 generate
    rslt(n).rst <= reset(PIPE_DSP)(n);
    rslt(n).ovf <= (r_ovf(2*n) or r_ovf(2*n+1)) when MODE='X' else
                   (r_ovf(2*n) or r_ovf(2*n+1) or ovf(PIPE_DSP)(n));
    rslt(n).vld <= r_vld(2*n) and (not reset(PIPE_DSP)(n)); -- valid signal is the same for all product results
    rslt(n).re  <= r(2*n);
    rslt(n).im  <= r(2*n+1);
  end generate;

  -- result output pipeline
  i_out : entity cplxlib.cplx_vector_pipeline
  generic map(
    NUM_PIPELINE_STAGES => NUM_OUTPUT_REG,
    MODE                => MODE
  )
  port map(
    clk        => clk,
    rst        => rst,
    clkena     => clkena,
    din        => rslt,
    dout       => result
  );

  -- report constant number of pipeline register stages (in 'clk' domain)
  PIPESTAGES <= PIPE_DSP + NUM_OUTPUT_REG;

end architecture;
