-------------------------------------------------------------------------------
--! @file       cplx_mult1_accu.sdr.vhdl
--! @author     Fixitfetish
--! @date       01/May/2017
--! @version    0.85
--! @copyright  MIT License
--! @note       VHDL-1993
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension.all;
library cplxlib;
  use cplxlib.cplx_pkg.all;
library dsplib;

--! @brief Complex Multiply and Accumulate (Single Data Rate).
--! In general this multiplier can be used when FPGA DSP cells are clocked with
--! the standard system clock. 
--!
--! This implementation requires the FPGA device dependent module signed_mult2_accu.
--! @image html cplx_mult1_accu.sdr.svg "" width=600px
--!
--! NOTE: The double rate clock 'clk2' is irrelevant and unused here.

architecture sdr of cplx_mult1_accu is

  -- The number of pipeline stages is reported as constant at the output port
  -- of the DSP implementation. PIPE_DSP is not a generic and it cannot be used
  -- to constrain the length of a pipeline, hence a maximum pipeline length
  -- must be defined here. Increase the value if required.
  constant MAX_NUM_PIPE_DSP : positive := 16;

  -- merged input signals and compensate for multiplier pipeline stages
  signal rst, ovf : std_logic_vector(0 to MAX_NUM_PIPE_DSP);

  -- auxiliary
  signal vld : std_logic;
  signal sub_n : std_logic;
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

  -- merge input control signals
  rst(0) <= (x.rst or y.rst);
  vld <= (x.vld and y.vld) when rst(0)='0' else '0';

  -- Consider overflow flags of all inputs that are accumulated.
  -- If the overflow flag of any input is set then also the accumulation result
  -- will have the overflow flag set.   
  ovf(0) <= '0' when (INPUT_OVERFLOW_IGNORE or rst(0)='1') else -- reset overflow flag
            (x.ovf  or y.ovf) when (vld='1' and clr='1') else -- restart accumulation
            ovf(1) or (x.ovf  or y.ovf) when (vld='1') else -- consider every new input
            ovf(1); -- hold overflow flag when invalid

  -- reset result data output to zero
  data_reset <= rst(0) when MODE='R' else '0';

  -- add/subtract inversion
  sub_n <= not sub;

  -- calculate real component
  i_re : entity dsplib.signed_mult2_accu
  generic map(
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
   sub(0)     => sub,
   sub(1)     => sub_n,
   x0         => x.re,
   y0         => y.re,
   x1         => x.im,
   y1         => y.im,
   result     => rslt(0).re,
   result_vld => rslt(0).vld,
   result_ovf => r_ovf_re,
   chainin    => open, -- unused
   chainout   => open, -- unused
   PIPESTAGES => PIPE_DSP
  );

  -- calculate imaginary component
  i_im : entity dsplib.signed_mult2_accu
  generic map(
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
   sub(0)     => sub,
   sub(1)     => sub,
   x0         => x.re,
   y0         => y.im,
   x1         => x.im,
   y1         => y.re,
   result     => rslt(0).im,
   result_vld => open, -- same as real component
   result_ovf => r_ovf_im,
   chainin    => open, -- unused
   chainout   => open, -- unused
   PIPESTAGES => open  -- same as real component
  );

  -- accumulator delay compensation (DSP bypassed!)
  g_loop : for n in 1 to MAX_NUM_PIPE_DSP generate
    rst(n) <= rst(n-1) when rising_edge(clk);
    ovf(n) <= ovf(n-1) when rising_edge(clk);
  end generate;
  rslt(0).rst <= rst(PIPE_DSP);
  rslt(0).ovf <= (r_ovf_re or r_ovf_im) when INPUT_OVERFLOW_IGNORE else
                 (r_ovf_re or r_ovf_im or ovf(PIPE_DSP));

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
