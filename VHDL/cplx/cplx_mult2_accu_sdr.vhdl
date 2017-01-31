-------------------------------------------------------------------------------
--! @file       cplx_mult2_accu_sdr.vhdl
--! @author     Fixitfetish
--! @date       30/Jan/2017
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

--! @brief Two complex multiplications and accumulate all (Single Data Rate).
--! In general this multiplier can be used when FPGA DSP cells are clocked with
--! the standard system clock. 
--!
--! This implementation requires the FPGA device dependent module signed_mult4_accu.
--! @image html cplx_mult2_accu_sdr.svg "" width=800px
--!
--! NOTE: The double rate clock 'clk2' is irrelevant and unused here.

architecture sdr of cplx_mult2_accu is

  -- The number of pipeline stages is reported as constant at the output port
  -- of the DSP implementation. PIPE_DSP is not a generic and it cannot be used
  -- to constrain the length of a pipeline, hence a maximum pipeline length
  -- must be defined here. Increase the value if required.
  constant MAX_NUM_PIPE_DSP : positive := 16;

  -- merged input signals and compensate for multiplier pipeline stages
  signal rst, ovf : std_logic_vector(0 to MAX_NUM_PIPE_DSP);

  -- auxiliary
  signal vld : std_logic;
  signal sub_n : std_logic_vector(sub'range);
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

  rst(0) <= (x(0).rst or  y(0).rst or  x(1).rst or  y(1).rst);
  ovf(0) <= (x(0).ovf or  y(0).ovf or  x(1).ovf or  y(1).ovf) when rst(0)='0' else '0';
  vld <= (x(0).vld and y(0).vld and x(1).vld and y(1).vld) when rst(0)='0' else '0';

  -- reset result data output to zero
  data_reset <= rst(0) when m='R' else '0';

  -- add/subtract inversion
  sub_n <= not sub;

  -- calculate real component
  i_re : entity fixitfetish.signed_mult4_accu
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND, -- two multiplications per complex multiplication
    USE_CHAIN_INPUT    => false, -- unused here
    NUM_INPUT_REG      => NUM_INPUT_REG,
    NUM_OUTPUT_REG     => 0, -- separate output register - see below
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => (m='N'),
    OUTPUT_CLIP        => (m='S'),
    OUTPUT_OVERFLOW    => (m='O')
  )
  port map (
   clk        => clk,
   rst        => data_reset, 
   clr        => clr,
   vld        => vld,
   sub(0)     => sub(0),
   sub(1)     => sub_n(0),
   sub(2)     => sub(1),
   sub(3)     => sub_n(1),
   x0         => x(0).re,
   y0         => y(0).re,
   x1         => x(0).im,
   y1         => y(0).im,
   x2         => x(1).re,
   y2         => y(1).re,
   x3         => x(1).im,
   y3         => y(1).im,
   result     => rslt(0).re,
   result_vld => rslt(0).vld,
   result_ovf => r_ovf_re,
   chainin    => open, -- unused
   chainout   => open, -- unused
   PIPESTAGES => PIPE_DSP
  );

  -- calculate imaginary component
  i_im : entity fixitfetish.signed_mult4_accu
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND, -- two multiplications per complex multiplication
    USE_CHAIN_INPUT    => false, -- unused here
    NUM_INPUT_REG      => NUM_INPUT_REG,
    NUM_OUTPUT_REG     => 0, -- separate output register - see below
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => (m='N'),
    OUTPUT_CLIP        => (m='S'),
    OUTPUT_OVERFLOW    => (m='O')
  )
  port map (
   clk        => clk,
   rst        => data_reset, 
   clr        => clr,
   vld        => vld,
   sub(0)     => sub(0),
   sub(1)     => sub(0),
   sub(2)     => sub(1),
   sub(3)     => sub(1),
   x0         => x(0).re,
   y0         => y(0).im,
   x1         => x(0).im,
   y1         => y(0).re,
   x2         => x(1).re,
   y2         => y(1).im,
   x3         => x(1).im,
   y3         => y(1).re,
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
