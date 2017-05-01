-------------------------------------------------------------------------------
-- FILE    : sincos_tb.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 01/May/2017
-- VERSION : 0.20
-- VHDL    : 1993
-- LICENSE : MIT License
-------------------------------------------------------------------------------
-- Copyright (c) 2017 Fixitfetish
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library cplxlib;
 use cplxlib.cplx_pkg.all;
library siglib;

use std.textio.all;

entity sincos_tb is
end entity;

architecture sim of sincos_tb is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';
  signal finish : std_logic := '0';

  constant PHASE_MAJOR_WIDTH : positive := 11;
  constant PHASE_MINOR_WIDTH : natural := 2;
  constant PHASE_WIDTH : positive := PHASE_MAJOR_WIDTH+PHASE_MINOR_WIDTH;
  constant OUTPUT_WIDTH : positive := 18;

  constant PHASE_MAX : positive := 2**PHASE_WIDTH-1;
  signal phase_vld : std_logic := '0';
  signal phase : unsigned(PHASE_WIDTH-1 downto 0);

  signal dout_vld : std_logic;
  signal dout_sin : signed(OUTPUT_WIDTH-1 downto 0);
  signal dout_cos : signed(OUTPUT_WIDTH-1 downto 0);
  signal dout_cplx : cplx;

  signal PIPESTAGES : natural;

begin

  p_clk : process
  begin
    while finish='0' loop
      wait for 0.5 ns; -- 1GHz
      clk <= not clk;
    end loop;
    wait;
  end process;

  p_stimuli: process
  begin
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rst <= '0';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    for n in 0 to PHASE_MAX loop
      phase_vld <= '1';
      phase <= to_unsigned(n,PHASE_WIDTH);
      wait until rising_edge(clk);
    end loop;

    phase_vld <= '0';
    for n in 0 to 10 loop
      wait until rising_edge(clk);
    end loop;

    finish <= '1';
    for n in 0 to 10 loop
      wait until rising_edge(clk);
    end loop;
    wait;
  end process;

  i_sincos : entity siglib.signed_sincos
  generic map (
    PHASE_MAJOR_WIDTH => PHASE_MAJOR_WIDTH,
    PHASE_MINOR_WIDTH => PHASE_MINOR_WIDTH,
    OUTPUT_WIDTH => OUTPUT_WIDTH,
    OUTPUT_SHIFT_RIGHT => false
  )
  port map (
    clk        => clk,
    rst        => rst,
    clkena     => '1',
    phase_vld  => phase_vld,
    phase      => std_logic_vector(phase),
    dout_vld   => dout_vld,
    dout_cos   => dout_cos,
    dout_sin   => dout_sin,
    PIPESTAGES => PIPESTAGES
  );

  dout_cplx.rst <= rst;
  dout_cplx.vld <= dout_vld;
  dout_cplx.ovf <= '0';
  dout_cplx.re <= dout_cos;
  dout_cplx.im <= dout_sin;

  i_log : entity work.cplx_logger4
  generic map(
    LOG_DECIMAL => true,
    LOG_INVALID => true,
    LOG_FILE => "result_log.txt",
    TITLE1 => "SINCOS OUT",
    TITLE2 => "UNUSED",
    TITLE3 => "UNUSED",
    TITLE4 => "UNUSED"
  )
  port map (
    clk    => clk,
    rst    => rst,
    din1   => dout_cplx,
    din2   => open,
    din3   => open,
    din4   => open,
    finish => finish
  );

end architecture;
