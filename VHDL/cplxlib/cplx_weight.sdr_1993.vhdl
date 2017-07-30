-------------------------------------------------------------------------------
--! @file       cplx_weight.sdr_1993.vhdl
--! @author     Fixitfetish
--! @date       16/Jun/2017
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
  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;
library cplxlib;
  use cplxlib.cplx_pkg.all;
library dsplib;

--! @brief Single Data Rate implementation of the entity cplx_weight .
--! N complex values are weighted (scaled) with one scalar or N scalar values.
--! Can be used for scalar multiplication.
--!
--! This implementation requires the entity signed_mult .
--! @image html cplx_weight.sdr.svg "" width=600px
--!
--! In general this multiplier can be used when FPGA DSP cells are clocked with
--! the standard system clock. 
--!
--! NOTE: The double rate clock 'clk2' is irrelevant and unused here.

architecture sdr_1993 of cplx_weight is

  -- The number of pipeline stages is reported as constant at the output port
  -- of the DSP implementation. PIPE_DSP is not a generic and it cannot be used
  -- to constrain the length of a pipeline, hence a maximum pipeline length
  -- must be defined here. Increase the value if required.
  constant MAX_NUM_PIPE_DSP : positive := 16;

  -- bit resolution of input and output data
  constant WIDTH_R : positive := result(result'left).re'length;

  -- number of elements of factor vector
  -- (must be either 1 or the same length as x)
  constant NUM_FACTOR : positive := w'length;

  -- convert to default range
  alias w_i : signed_vector(0 to NUM_FACTOR-1) is w;

  -- multiplier input signals
  signal vld_dsp : std_logic := '0';
  signal neg_dsp : std_logic_vector(0 to 2*NUM_MULT-1);
  signal x_dsp : signed_vector(0 to 2*NUM_MULT-1);
  signal w_dsp : signed_vector(0 to 2*NUM_MULT-1);

  -- merged input signals and compensate for multiplier pipeline stages
  type t_delay is array(integer range <>) of std_logic_vector(0 to NUM_MULT-1);
  signal rst : t_delay(0 to MAX_NUM_PIPE_DSP) := (others=>(others=>'1'));
  signal ovf : t_delay(0 to MAX_NUM_PIPE_DSP) := (others=>(others=>'0'));

  -- auxiliary
  signal vld : std_logic_vector(0 to NUM_MULT-1) := (others=>'0');
  signal data_reset : std_logic := '0';

  -- output signals
  -- ! for 1993/2008 compatibility reasons do not use cplx record here !
  signal r_vld, r_ovf : std_logic_vector(0 to 2*NUM_MULT-1);
  signal r : signed_vector(0 to 2*NUM_MULT-1);
  type record_result is
  record
    rst, vld, ovf : std_logic;
    re : signed(WIDTH_R-1 downto 0);
    im : signed(WIDTH_R-1 downto 0);
  end record;
  type vector_result is array(integer range<>) of record_result;
  type matrix_result is array(integer range<>) of vector_result(0 to NUM_MULT-1);
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

  g_merge : for n in 0 to NUM_MULT-1 generate
    -- merge input control signals
    rst(0)(n) <= x(n).rst;
    vld(n) <= x(n).vld when rst(0)(n)='0' else '0';
    -- Consider overflow flags of all inputs.
    -- If the overflow flag of any input is set then also the result
    -- will have the overflow flag set.   
    ovf(0)(n) <= '0' when (MODE='X' or rst(0)(n)='1') else x(n).ovf;
  end generate;
  vld_dsp <= ANY_ONES(vld);

  g_in : for n in 0 to NUM_MULT-1 generate
    -- mapping of complex inputs
    neg_dsp(2*n)   <= neg(n);
    neg_dsp(2*n+1) <= neg(n);
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

  -- reset result data output to zero
  data_reset <= rst(0)(0) when MODE='R' else '0';

  -- accumulator delay compensation (DSP bypassed!)
  g_delay : for n in 1 to MAX_NUM_PIPE_DSP generate
    rst(n) <= rst(n-1) when rising_edge(clk);
    ovf(n) <= ovf(n-1) when rising_edge(clk);
  end generate;

  -- weighting
  i_weight : entity dsplib.signed_mult
  generic map(
    NUM_MULT           => 2*NUM_MULT,
    NUM_INPUT_REG      => NUM_INPUT_REG,
    NUM_OUTPUT_REG     => 1, -- always enable DSP internal output register
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => (MODE='N'),
    OUTPUT_CLIP        => (MODE='S'),
    OUTPUT_OVERFLOW    => (MODE='O')
  )
  port map (
    clk           => clk,
    rst           => data_reset,
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
    rslt(0)(n).rst <= rst(PIPE_DSP)(n);
    rslt(0)(n).ovf <= (r_ovf(2*n) or r_ovf(2*n+1)) when MODE='X' else
                      (r_ovf(2*n) or r_ovf(2*n+1) or ovf(PIPE_DSP)(n));
    rslt(0)(n).vld <= r_vld(2*n) and (not rst(PIPE_DSP)(n)); -- valid signal is the same for all product results
    rslt(0)(n).re <= r(2*n);
    rslt(0)(n).im <= r(2*n+1);
  end generate;

  -- additional output registers
  g_out_reg : if NUM_OUTPUT_REG>=1 generate
    g_loop : for n in 1 to NUM_OUTPUT_REG generate
      rslt(n) <= rslt(n-1) when rising_edge(clk);
    end generate;
  end generate;

  -- map result to output port
  g_out : for k in 0 to NUM_MULT-1 generate
    result(k).rst <= rslt(NUM_OUTPUT_REG)(k).rst;
    result(k).vld <= rslt(NUM_OUTPUT_REG)(k).vld;
    result(k).ovf <= rslt(NUM_OUTPUT_REG)(k).ovf;
    result(k).re  <= rslt(NUM_OUTPUT_REG)(k).re;
    result(k).im  <= rslt(NUM_OUTPUT_REG)(k).im;
  end generate;

  -- report constant number of pipeline register stages (in 'clk' domain)
  PIPESTAGES <= PIPE_DSP + NUM_OUTPUT_REG;

end architecture;
