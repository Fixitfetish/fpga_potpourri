-------------------------------------------------------------------------------
-- FILE    : cplx_mult_accu_sdr.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 17/Dec/2016
-- VERSION : 0.40
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
 use fixitfetish.ieee_extension.all;

-- Complex Multiply and Accumulate - Single Data Rate
-- In general this multiplier can be used when FPGA DSP cells are clocked with
-- the standard system clock. 
--
-- This implementation requires the FPGA type dependent module 'signed_mult2_accu'.
--
-- NOTE: The double rate clock 'clk2' is irrelevant and unused here.

architecture sdr of cplx_mult_accu is

  --input signals
  -- ! for 1993/2008 compatibility reasons do not use cplx record here !
  signal clr_i, sub_i, sub_i_n : std_logic;
  signal x_rst, x_vld, x_ovf : std_logic;
  signal x_re : signed(x.re'length-1 downto 0);
  signal x_im : signed(x.im'length-1 downto 0);
  signal y_rst, y_vld, y_ovf : std_logic;
  signal y_re : signed(y.re'length-1 downto 0);
  signal y_im : signed(y.im'length-1 downto 0);

  -- merged input signals (after optional input register)
  signal rst, vld, ovf : std_logic;

  -- auxiliary
  signal data_reset, rst_q, ovf_q, ovf_qq : std_logic := '0';

  -- output signals
  -- ! for 1993/2008 compatibility reasons do not use cplx record here !
  signal r_rst, r_vld, r_ovf, r_ovf_re, r_ovf_im : std_logic;
  signal r_re : signed(r.re'length-1 downto 0);
  signal r_im : signed(r.im'length-1 downto 0);

  -- determine number of required additional guard bits (MSBs)
  function guard_bits(num_summand:natural) return integer is
    variable res : integer;
  begin
    if num_summand=0 then
      res := -1; -- maximum possible
    elsif num_summand=1 then
      -- just complex multiplication - no accumulation
      res := 1; -- always one additional guard bit for complex multiplication 
    else
      res := LOG2CEIL(num_summand)+1;
    end if;
    return res; 
  end function;

begin

  g_in : if not INPUT_REG generate
    clr_i <= clr;
    sub_i <= sub;
    x_rst<=x.rst; x_vld<=x.vld; x_ovf<=x.ovf;
    y_rst<=y.rst; y_vld<=y.vld; y_ovf<=y.ovf;
    x_re <= x.re; x_im <= x.im;
    y_re <= y.re; y_im <= y.im;
  end generate;

  g_in_reg : if INPUT_REG generate
    process(clk)
    begin if rising_edge(clk) then
      clr_i <= clr;
      sub_i <= sub;
      x_rst<=x.rst; x_vld<=x.vld; x_ovf<=x.ovf;
      y_rst<=y.rst; y_vld<=y.vld; y_ovf<=y.ovf;
      x_re <= x.re; x_im <= x.im;
      y_re <= y.re; y_im <= y.im;
    end if; end process;
  end generate;

  rst <= (x_rst  or y_rst);
  vld <= (x_vld and y_vld) when rst='0' else '0';
  ovf <= (x_ovf  or y_ovf) when rst='0' else '0';

  -- reset result data output to zero
  data_reset <= rst when m='R' else '0';

  -- add/subtract inversion
  sub_i_n <= not sub_i;

  -- calculate real component
  i_re : entity fixitfetish.signed_mult2_accu
  generic map(
    GUARD_BITS         => guard_bits(NUM_SUMMAND),
    INPUT_REG          => true,
    OUTPUT_REG         => false, -- separate output register - see below
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => (m='N'),
    OUTPUT_CLIP        => (m='S'),
    OUTPUT_OVERFLOW    => (m='O')
  )
  port map (
   clk   => clk,
   rst   => data_reset, 
   clr   => clr_i,
   vld   => vld,
   a_sub => sub_i,
   a_x   => x_re,
   a_y   => y_re,
   b_sub => sub_i_n,
   b_x   => x_im,
   b_y   => y_im,
   r_vld => r_vld,
   r_out => r_re,
   r_ovf => r_ovf_re
  );

  -- calculate imaginary component
  i_im : entity fixitfetish.signed_mult2_accu
  generic map(
    GUARD_BITS         => guard_bits(NUM_SUMMAND),
    INPUT_REG          => true,
    OUTPUT_REG         => false, -- separate output register - see below
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => (m='N'),
    OUTPUT_CLIP        => (m='S'),
    OUTPUT_OVERFLOW    => (m='O')
  )
  port map (
   clk   => clk,
   rst   => data_reset, 
   clr   => clr_i,
   vld   => vld,
   a_sub => sub_i,
   a_x   => x_re,
   a_y   => y_im,
   b_sub => sub_i,
   b_x   => x_im,
   b_y   => y_re,
   r_vld => open, -- same as real component
   r_out => r_im,
   r_ovf => r_ovf_im
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

end architecture;
