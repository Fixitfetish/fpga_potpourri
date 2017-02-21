-------------------------------------------------------------------------------
--! @file       cplx_mult1_accu1.ddr.vhdl
--! @author     Fixitfetish
--! @date       18/Feb/2017
--! @version    0.50
--! @copyright  MIT License
--! @note       VHDL-1993
-------------------------------------------------------------------------------
-- Copyright (c) 2016-2017 Fixitfetish
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library fixitfetish;
 use fixitfetish.cplx_pkg.all;
 use fixitfetish.ieee_extension.all;

--! @brief Complex Multiply and Accumulate - Double Data Rate.
--! In general this multiplier can be used when FPGA DSP cells are capable to
--! run with the double rate of the standard system clock.
--! Hence, a complex multiplication can be performed within one system clock
--! cycle with only half the amount of multiplier resources.
--!
--! This implementation requires the FPGA type dependent module signed_mult1_accu1.
--! @image html cplx_mult1_accu1.ddr.svg "" width=600px
--!
--! NOTE: Within the 'clk2' domain always an even number of register stages
--! must be implemented. 

architecture ddr of cplx_mult1_accu1 is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "cplx_mult1_accu1(ddr)";

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
  signal r_out_re, r_re : signed(result.re'length-1 downto 0);
  signal r_out_im, r_im : signed(result.im'length-1 downto 0);

  -- pipeline stages of used DSP cell
  signal PIPE_DSP : natural;

begin

  -- check input/output register settings
  assert (NUM_INPUT_REG>=1)
    report "ERROR " & IMPLEMENTATION & ": Number of input registers must be at least 1"
    severity failure;

  assert (NUM_OUTPUT_REG>=1)
    report "ERROR " & IMPLEMENTATION & ": Number of output registers must be at least 1"
    severity failure;

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
  
  -- use clear signal to reset data
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
  i_re : entity fixitfetish.signed_mult1_accu1
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND, -- two multiplications per complex multiplication
    USE_CHAIN_INPUT    => false,
    NUM_INPUT_REG      => 1,
    NUM_OUTPUT_REG     => 1, -- additional output register - see below
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => (m='N'),
    OUTPUT_CLIP        => (m='S'),
    OUTPUT_OVERFLOW    => (m='O')
  )
  port map (
   clk        => clk2,
   rst        => '0', -- TODO
   clr        => clear,
   vld        => dv,
   sub        => sub_re,
   x          => re_x,
   y          => re_y,
   result     => r_out_re,
   result_vld => open, -- unused, bypassed
   result_ovf => r_ovf_re,
   chainin    => open, -- unused
   chainout   => open, -- unused
   PIPESTAGES => PIPE_DSP
  );

  -- calculate imaginary component in 'clk2' domain
  i_im : entity fixitfetish.signed_mult1_accu1
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND, -- two multiplications per complex multiplication
    USE_CHAIN_INPUT    => false,
    NUM_INPUT_REG      => 1,
    NUM_OUTPUT_REG     => 1, -- additional output register - see below
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => (m='N'),
    OUTPUT_CLIP        => (m='S'),
    OUTPUT_OVERFLOW    => (m='O')
  )
  port map (
   clk        => clk2,
   rst        => '0', -- TODO
   clr        => clear,
   vld        => dv,
   sub        => sub_im,
   x          => im_x,
   y          => im_y,
   result     => r_out_im,
   result_vld => open, -- unused, bypassed
   result_ovf => r_ovf_im,
   chainin    => open, -- unused
   chainout   => open, -- unused
   PIPESTAGES => open  -- same as real component
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
    result.rst<=r_rst; result.vld<=r_vld; result.ovf<=r_ovf; result.re<=r_re; result.im<=r_im;
  end generate;

  g_out_reg : if OUTPUT_REG generate
    process(clk)
    begin if rising_edge(clk) then
      -- result with additional output register in 'clk' domain
      result.rst<=r_rst; result.vld<=r_vld; result.ovf<=r_ovf; result.re<=r_re; result.im<=r_im;
    end if; end process;
  end generate;

  -- report constant number of pipeline register stages (in 'clk' domain)
  PIPESTAGES <= (PIPE_DSP+2)/2 + 2 when (INPUT_REG and OUTPUT_REG) else
                (PIPE_DSP+2)/2 + 1 when (INPUT_REG or OUTPUT_REG) else
                (PIPE_DSP+2)/2;

end architecture;

