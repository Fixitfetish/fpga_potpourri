-------------------------------------------------------------------------------
-- FILE    : cplx_mult2_accu_sdr.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 22/Jan/2017
-- VERSION : 0.10
-- VHDL    : 1993
-- LICENSE : MIT License
-------------------------------------------------------------------------------
-- Copyright (c) 2017 Fixitfetish
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library fixitfetish;
 use fixitfetish.cplx_pkg.all;
 use fixitfetish.ieee_extension.all;

-- Two complex multiplications and accumulate both - Single Data Rate
-- In general this multiplier can be used when FPGA DSP cells are clocked with
-- the standard system clock. 
--
-- This implementation requires the FPGA type dependent module 'signed_mult4_accu'.
--
-- NOTE: The double rate clock 'clk2' is irrelevant and unused here.

architecture sdr of cplx_mult2_accu is

  -- derived input signals
  signal sub_n : std_logic_vector(0 to 1);
  signal rst, vld, ovf : std_logic;

  -- auxiliary
  signal data_reset, rst_q, ovf_q, ovf_qq : std_logic := '0';
  signal dummy1, dummy2 : signed(15 downto 0);

  -- output signals
  -- ! for 1993/2008 compatibility reasons do not use cplx record here !
  signal r_rst, r_vld, r_ovf, r_ovf_re, r_ovf_im : std_logic;
  signal r_re : signed(r.re'length-1 downto 0);
  signal r_im : signed(r.im'length-1 downto 0);

  -- pipeline stages of used DSP cell
  signal PIPE_DSP : natural;

begin

  rst <= (x(0).rst or  y(0).rst or  x(1).rst or  y(1).rst);
  vld <= (x(0).vld and y(0).vld and x(1).vld and y(1).vld) when rst='0' else '0';
  ovf <= (x(0).ovf or  y(0).ovf or  x(1).ovf or  y(1).ovf) when rst='0' else '0';

  -- reset result data output to zero
  data_reset <= rst when m='R' else '0';

  -- add/subtract inversion
  sub_n <= not sub;

  -- calculate real component
  i_re : entity fixitfetish.signed_mult4_accu
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND, -- two multiplications per complex multiplication
    USE_CHAININ        => false, -- unused here
    NUM_INPUT_REG      => NUM_INPUT_REG+1, -- at least one input register
    OUTPUT_REG         => false, -- separate output register - see below
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => (m='N'),
    OUTPUT_CLIP        => (m='S'),
    OUTPUT_OVERFLOW    => (m='O')
  )
  port map (
   clk      => clk,
   rst      => data_reset, 
   clr      => clr,
   vld      => vld,
   sub(0)   => sub(0),
   sub(1)   => sub_n(0),
   sub(2)   => sub(1),
   sub(3)   => sub_n(1),
   x0       => x(0).re,
   y0       => y(0).re,
   x1       => x(0).im,
   y1       => y(0).im,
   x2       => x(1).re,
   y2       => y(1).re,
   x3       => x(1).im,
   y3       => y(1).im,
   r_vld    => r_vld,
   r_out    => r_re,
   r_ovf    => r_ovf_re,
   chainin  => "00", -- unused, default required
   chainout => dummy1, -- unused
   PIPE     => PIPE_DSP
  );

  -- calculate imaginary component
  i_im : entity fixitfetish.signed_mult4_accu
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND, -- two multiplications per complex multiplication
    USE_CHAININ        => false, -- unused here
    NUM_INPUT_REG      => NUM_INPUT_REG+1, -- at least one input register
    OUTPUT_REG         => false, -- separate output register - see below
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => (m='N'),
    OUTPUT_CLIP        => (m='S'),
    OUTPUT_OVERFLOW    => (m='O')
  )
  port map (
   clk      => clk,
   rst      => data_reset, 
   clr      => clr,
   vld      => vld,
   sub(0)   => sub(0),
   sub(1)   => sub(0),
   sub(2)   => sub(1),
   sub(3)   => sub(1),
   x0       => x(0).re,
   y0       => y(0).im,
   x1       => x(0).im,
   y1       => y(0).re,
   x2       => x(1).re,
   y2       => y(1).im,
   x3       => x(1).im,
   y3       => y(1).re,
   r_vld    => open, -- same as real component
   r_out    => r_im,
   r_ovf    => r_ovf_im,
   chainin  => "00", -- unused, default required
   chainout => dummy2, -- unused
   PIPE     => open  -- same as real component
  );

  -- accumulator delay compensation (multiply-accumulate bypassed!)
  rst_q <= rst when rising_edge(clk);
  r_rst <= rst_q when rising_edge(clk);
  ovf_q <= ovf when rising_edge(clk);
  ovf_qq <= ovf_q when rising_edge(clk);
  r_ovf <= (ovf_qq or r_ovf_re or r_ovf_im);

  g_out : if not OUTPUT_REG generate
    r.rst<=r_rst; r.vld<=r_vld; r.ovf<=r_ovf; r.re<=r_re; r.im<=r_im;
--    r <= reset_on_demand((rst=>r_rst,vld=>r_vld,ovf=>r_ovf,re=>r_re,im=>r_im), m=>m);
  end generate;

  g_out_reg : if OUTPUT_REG generate
    process(clk)
    begin if rising_edge(clk) then
      r.rst<=r_rst; r.vld<=r_vld; r.ovf<=r_ovf; r.re<=r_re; r.im<=r_im;
--      r <= reset_on_demand((rst=>r_rst,vld=>r_vld,ovf=>r_ovf,re=>r_re,im=>r_im), m=>m);
    end if; end process;
  end generate;

  -- report constant number of pipeline register stages
  PIPE <= PIPE_DSP+1 when OUTPUT_REG else PIPE_DSP;

end architecture;
