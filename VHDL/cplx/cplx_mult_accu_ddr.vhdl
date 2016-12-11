-------------------------------------------------------------------------------
-- FILE    : cplx_mult_accu_ddr.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 11/Dec/2016
-- VERSION : 0.30
-- VHDL    : 1993
-- LICENSE : MIT License
-------------------------------------------------------------------------------
-- Copyright (c) 2016 Fixitfetish
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library fixitfetish;
 use fixitfetish.cplx_pkg.all;

-- Complex Multiply and Accumulate - Double Data Rate
-- In general this multiplier can be used when FPGA DSP cells are capable to
-- run with the double rate of the standard system clock.
-- Hence, a complex multiplication can be performed within one system clock
-- cycle with only half the amount of multiplier resources.
--
-- This implementation requires the FPGA type dependent module 'signed_mult_accu'.
--
-- NOTE: Within the 'clk2' domain always an even number of register stages
--       must be implemented. 

architecture ddr of cplx_mult_accu is

  -- auxiliary phase control signals
  signal toggle1, toggle2, phase : std_logic := '0';

  -- ! for 1993/2008 compatibility reasons use local complex records here !
  type cplx_x is record
    rst, vld, ovf : std_logic;
    re, im : signed(x.re'length-1 downto 0); -- real/imag same size !
  end record;
  type cplx_y is record
    rst, vld, ovf : std_logic;
    re, im : signed(y.re'length-1 downto 0); -- real/imag same size !
  end record;

  --input signals
  signal clr_i, clr_q : std_logic;
  signal sub_i, sub_q, sub_re, sub_im : std_logic;
  signal x_i, x_q : cplx_x;
  signal y_i, y_q : cplx_y;

  -- merged input signals (after optional input register)
  signal rst, vld, ovf : std_logic;

  -- auxiliary signals
  signal rst_q, vld_q, ovf_q, ovf2 : std_logic := '0';
  signal clear, dv : std_logic;
  signal data_reset : boolean;

  -- DSP input data 
  signal re_x, im_x : signed(x.re'length-1 downto 0); -- real/imag same size !
  signal re_y, im_y : signed(y.re'length-1 downto 0); -- real/imag same size !

  -- output signals
  -- ! for 1993/2008 compatibility reasons do not use cplx record here !
  signal r_rst, r_vld, r_ovf, r_ovf_re, r_ovf_im : std_logic;
  signal r_out_re, r_re : signed(r.re'length-1 downto 0);
  signal r_out_im, r_im : signed(r.im'length-1 downto 0);

begin

  -- auxiliary phase control signals
  toggle1 <= not toggle1 when rising_edge(clk);
  toggle2 <= toggle1 when rising_edge(clk2);
  phase <= toggle1 xor toggle2;

  g_in : if not INPUT_REG generate
    clr_i <= clr;
    sub_i <= sub;
    x_i.rst<=x.rst; x_i.vld<=x.vld; x_i.ovf<=x.ovf;
    y_i.rst<=y.rst; y_i.vld<=y.vld; y_i.ovf<=y.ovf;
    x_i.re <= x.re; x_i.im <= x.im;
    y_i.re <= y.re; y_i.im <= y.im;
  end generate;

  g_in_reg : if INPUT_REG generate
    process(clk)
    begin if rising_edge(clk) then
      clr_i <= clr;
      sub_i <= sub;
      x_i.rst<=x.rst; x_i.vld<=x.vld; x_i.ovf<=x.ovf;
      y_i.rst<=y.rst; y_i.vld<=y.vld; y_i.ovf<=y.ovf;
      x_i.re <= x.re; x_i.im <= x.im;
      y_i.re <= y.re; y_i.im <= y.im;
    end if; end process;
  end generate;

  -- merge control signals
  rst <= (x_i.rst  or y_i.rst);
  vld <= (x_i.vld and y_i.vld) when rst='0' else '0';
  ovf <= (x_i.ovf  or y_i.ovf) when rst='0' else '0';

  -- input register 'clk2' domain
  clr_q <= clr_i when rising_edge(clk2);
  sub_q <= sub_i when rising_edge(clk2);
  x_q <= x_i when rising_edge(clk2);
  y_q <= y_i when rising_edge(clk2);
  
  -- use clr signal to reset data
  data_reset <= (m='R' and (x_q.rst='1' or y_q.rst='1'));
  clear <= '1'   when data_reset else
           clr_q when phase='0'  else '0';
  dv <= '0' when data_reset else (x_q.vld and y_q.vld);

  -- real part (input multiplexer)
  re_x <= x_q.re when phase='0' else x_q.im;
  re_y <= y_q.re when phase='0' else y_q.im;
  sub_re <= sub_q when phase='0' else (not sub_q);

  -- imaginary part (input multiplexer)
  im_x <= x_q.re when phase='0' else x_q.im;
  im_y <= y_q.im when phase='0' else y_q.re;
  sub_im <= sub_q;

  -- calculate real component in 'clk2' domain
  i_re : entity fixitfetish.signed_mult_accu
  generic map(
    GUARD_BITS         => GUARD_BITS,
    INPUT_REG          => true,
    OUTPUT_REG         => false, -- separate output register - see below
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => (m='N'),
    OUTPUT_CLIP        => (m='S'),
    OUTPUT_OVERFLOW    => (m='O')
  )
  port map (
   clk   => clk2,
   clr   => clear,
   sub   => sub_re,
   vld   => dv,
   x     => re_x,
   y     => re_y,
   r_vld => open, -- unused, bypassed
   r_out => r_out_re,
   r_ovf => r_ovf_re
  );

  -- calculate imaginary component in 'clk2' domain
  i_im : entity fixitfetish.signed_mult_accu
  generic map(
    GUARD_BITS         => GUARD_BITS,
    INPUT_REG          => true,
    OUTPUT_REG         => false, -- separate output register - see below
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => (m='N'),
    OUTPUT_CLIP        => (m='S'),
    OUTPUT_OVERFLOW    => (m='O')
  )
  port map (
   clk   => clk2,
   clr   => clear,
   sub   => sub_im,
   vld   => dv,
   x     => im_x,
   y     => im_y,
   r_vld => open, -- unused, bypassed
   r_out => r_out_im,
   r_ovf => r_ovf_im
  );

  -- accumulator delay compensation (multiply-accumulate bypassed!)
  rst_q <= rst when rising_edge(clk);
  vld_q <= vld when rising_edge(clk);
  ovf_q <= ovf when rising_edge(clk);
  ovf2 <= ovf_q when rising_edge(clk2);

  -- external SIGNED_MULT_ACC output register
  -- a.) merge overflow signals  b.) integrate bypassed signals
  r_rst <= rst_q when rising_edge(clk); -- multiply-accumulate bypassed!
  r_vld <= vld_q when rising_edge(clk); -- multiply-accumulate bypassed!
  r_ovf <= (ovf2 or r_ovf_re or r_ovf_im) when rising_edge(clk2);
  r_re <= r_out_re when rising_edge(clk2);
  r_im <= r_out_im when rising_edge(clk2);

  g_out : if not OUTPUT_REG generate
    -- result directly from 'clk2' output register
    r.rst<=r_rst; r.vld<=r_vld; r.ovf<=r_ovf; r.re<=r_re; r.im<=r_im;
  end generate;

  g_out_reg : if OUTPUT_REG generate
    process(clk)
    begin if rising_edge(clk) then
      -- result with additional output register in 'clk' domain
      r.rst<=r_rst; r.vld<=r_vld; r.ovf<=r_ovf; r.re<=r_re; r.im<=r_im;
    end if; end process;
  end generate;

end architecture;
