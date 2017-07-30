-------------------------------------------------------------------------------
--! @file       cplx_mult.sdr_1993.vhdl
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
library cplxlib;
  use cplxlib.cplx_pkg.all;
library dsplib;

--! @brief Single Data Rate implementation of the entity cplx_mult .
--! N complex multiplications are performed.
--!
--! This implementation requires the entity signed_mult_sum.
--! @image html cplx_mult.sdr.svg "" width=600px
--!
--! In general this multiplier can be used when FPGA DSP cells are clocked with
--! the standard system clock. 
--!
--! NOTE: The double rate clock 'clk2' is irrelevant and unused here.

architecture sdr_1993 of cplx_mult is

  -- The number of pipeline stages is reported as constant at the output port
  -- of the DSP implementation. PIPE_DSP is not a generic and it cannot be used
  -- to constrain the length of a pipeline, hence a maximum pipeline length
  -- must be defined here. Increase the value if required.
  constant MAX_NUM_PIPE_DSP : positive := 16;

  -- bit resolution of input and output data
  constant WIDTH_R : positive := result(result'left).re'length;

  -- number of elements of factor vector
  -- (must be either 1 or the same length as x)
  constant NUM_FACTOR : positive := y'length;

  -- convert to default range
  alias y_i : cplx_vector(0 to NUM_FACTOR-1) is y;

  signal x_re, x_im : signed_vector(0 to 2*NUM_MULT-1);
  signal y_re, y_im : signed_vector(0 to 2*NUM_MULT-1);
  signal neg_re, neg_im : std_logic_vector(0 to 2*NUM_MULT-1) := (others=>'0');

  -- merged input signals and compensate for multiplier pipeline stages
  type t_delay is array(integer range <>) of std_logic_vector(0 to NUM_MULT-1);
  signal rst : t_delay(0 to MAX_NUM_PIPE_DSP) := (others=>(others=>'1'));
  signal ovf : t_delay(0 to MAX_NUM_PIPE_DSP) := (others=>(others=>'0'));

  -- auxiliary
  signal vld : std_logic_vector(0 to NUM_MULT-1) := (others=>'0');
  signal data_reset : std_logic_vector(0 to NUM_MULT-1) := (others=>'0');

  -- output signals
  -- ! for 1993/2008 compatibility reasons do not use cplx record here !
  signal r_ovf_re, r_ovf_im : std_logic_vector(0 to NUM_MULT-1);
  type record_result is
  record
    rst, vld, ovf : std_logic;
    re : signed(WIDTH_R-1 downto 0);
    im : signed(WIDTH_R-1 downto 0);
  end record;
  constant DEFAULT_RESULT : record_result := (rst=>'1',vld|ovf=>'0',re|im=>(others=>'0'));
  type vector_result is array(integer range<>) of record_result;
  type matrix_result is array(integer range<>) of vector_result(0 to NUM_MULT-1);
  signal rslt : matrix_result(0 to NUM_OUTPUT_REG) := (others=>(others=>DEFAULT_RESULT)); 

  -- pipeline stages of used DSP cell
  type t_pipe is array(integer range <>) of natural;
  signal PIPE_DSP : t_pipe(0 to NUM_MULT-1);

  -- dummy sink to avoid warnings
  procedure std_logic_sink(x:in std_logic) is
    variable y : std_logic := '1';
  begin y:=y or x; end procedure;

begin

  -- dummy sink for unused clock
  std_logic_sink(clk2);

  g_merge : for n in 0 to NUM_MULT-1 generate
    g1 : if NUM_FACTOR=1 generate
      -- merge input control signals
      rst(0)(n) <= (x(n).rst or y_i(0).rst);
      vld(n) <= (x(n).vld and y_i(0).vld) when rst(0)(n)='0' else '0';
      -- Consider overflow flags of all inputs.
      -- If the overflow flag of any input is set then also the result
      -- will have the overflow flag set.   
      ovf(0)(n) <= '0' when (MODE='X' or rst(0)(n)='1') else
                   (x(n).ovf or y_i(0).ovf);
    end generate;
    gn : if NUM_FACTOR=NUM_MULT generate
      -- merge input control signals
      rst(0)(n) <= (x(n).rst or y_i(n).rst);
      vld(n) <= (x(n).vld and y_i(n).vld) when rst(0)(n)='0' else '0';
      -- Consider overflow flags of all inputs.
      -- If the overflow flag of any input is set then also the result
      -- will have the overflow flag set.   
      ovf(0)(n) <= '0' when (MODE='X' or rst(0)(n)='1') else
                   (x(n).ovf or y_i(n).ovf);
    end generate;
  end generate;

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
    g1 : if NUM_FACTOR=1 generate
      -- map inputs for calculation of real component
      y_re(2*n)     <= y_i(0).re;
      y_re(2*n+1)   <= y_i(0).im;
      -- map inputs for calculation of imaginary component
      y_im(2*n)     <= y_i(0).im;
      y_im(2*n+1)   <= y_i(0).re;
    end generate;
    gn : if NUM_FACTOR=NUM_MULT generate
      -- map inputs for calculation of real component
      y_re(2*n)     <= y_i(n).re;
      y_re(2*n+1)   <= y_i(n).im;
      -- map inputs for calculation of imaginary component
      y_im(2*n)     <= y_i(n).im;
      y_im(2*n+1)   <= y_i(n).re;
    end generate;
  end generate;

  -- reset result data output to zero
  data_reset <= rst(0) when MODE='R' else (others=>'0');

  -- accumulator delay compensation (DSP bypassed!)
  g_delay : for n in 1 to MAX_NUM_PIPE_DSP generate
    rst(n) <= rst(n-1) when rising_edge(clk);
    ovf(n) <= ovf(n-1) when rising_edge(clk);
  end generate;

  g_mult : for n in 0 to NUM_MULT-1 generate
    -- calculate real component
    i_re : entity dsplib.signed_mult_sum
    generic map(
      NUM_MULT           => 2, -- two multiplications per complex multiplication
      HIGH_SPEED_MODE    => HIGH_SPEED_MODE,
      NUM_INPUT_REG      => NUM_INPUT_REG,
      NUM_OUTPUT_REG     => 1, -- always enable DSP cell output register (= first output register)
      OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
      OUTPUT_ROUND       => (MODE='N'),
      OUTPUT_CLIP        => (MODE='S'),
      OUTPUT_OVERFLOW    => (MODE='O')
    )
    port map (
     clk        => clk,
     rst        => data_reset(n),
     vld        => vld(n),
     neg        => neg_re(2*n to 2*n+1),
     x          => x_re(2*n to 2*n+1),
     y          => y_re(2*n to 2*n+1),
     result     => rslt(0)(n).re,
     result_vld => rslt(0)(n).vld,
     result_ovf => r_ovf_re(n),
     PIPESTAGES => PIPE_DSP(n)
    );

    -- calculate imaginary component
    i_im : entity dsplib.signed_mult_sum
    generic map(
      NUM_MULT           => 2, -- two multiplications per complex multiplication
      HIGH_SPEED_MODE    => HIGH_SPEED_MODE,
      NUM_INPUT_REG      => NUM_INPUT_REG,
      NUM_OUTPUT_REG     => 1, -- always enable DSP cell output register (= first output register)
      OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
      OUTPUT_ROUND       => (MODE='N'),
      OUTPUT_CLIP        => (MODE='S'),
      OUTPUT_OVERFLOW    => (MODE='O')
    )
    port map (
     clk        => clk,
     rst        => data_reset(n),
     vld        => vld(n),
     neg        => neg_im(2*n to 2*n+1),
     x          => x_im(2*n to 2*n+1),
     y          => y_im(2*n to 2*n+1),
     result     => rslt(0)(n).im,
     result_vld => open, -- same as real component
     result_ovf => r_ovf_im(n),
     PIPESTAGES => open  -- same as real component
    );

    -- pipeline delay is the same for all
    rslt(0)(n).rst <= rst(PIPE_DSP(0))(n);
    rslt(0)(n).ovf <= (r_ovf_re(n) or r_ovf_im(n)) when MODE='X' else
                      (r_ovf_re(n) or r_ovf_im(n) or ovf(PIPE_DSP(0))(n));
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
  PIPESTAGES <= PIPE_DSP(0) + NUM_OUTPUT_REG;

end architecture;
