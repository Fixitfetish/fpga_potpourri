-------------------------------------------------------------------------------
-- FILE    : fft8_tb.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 05/Apr/2017
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

use std.textio.all;

entity fft8_tb is
end entity;

architecture sim of fft8_tb is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';
  signal fft1_start : std_logic := '0';
  signal finish : std_logic := '0';
  signal fft1_in : cplx_vector(0 to 7) := cplx_vector_reset(18,8,"R");
  signal fft1_out : cplx;
  signal fft1_out_idx : unsigned(2 downto 0);

  signal ifft1_start : std_logic := '0';
  signal ifft1_out : cplx_vector(0 to 7);

  type integer_vector is array(integer range <>) of integer;
  type integer_matrix8 is array(integer range <>) of integer_vector(0 to 7);

  constant RE : integer_matrix8(0 to 2) := (
    (  67272, -53923,  57111,  23748,-44332, -71022,  66992, -81005), -- first input
    (  54047, -54236,  64216, -59296, 63667, -39001,  60444, -52812), -- second input (1 expected overflow)
    ( -52268,  -4860, -39079, 104958,-49662,  -6843, -54892, 112924)  -- third input (2 expected overflows)
  );
  constant IM : integer_matrix8(0 to 2) := (
    (  33774, -71192, -21872, -76892, -63453,  68615, -59628, -61097), -- first input
    ( -49662,  46228, -54892,  59853, -52268,  48211, -39079,  51888), -- second input (1 expected overflow)
    (  87830, -34948,  -8143, -40008,  97450, -19713, -11914, -33524)  -- third input (2 expected overflows)
  );

  -- FFT Result Reference , Octave: fft(re+1i*im)/sqrt(8)
  --
  -- RE0 = -12431,  -8007,  12109,   9122, 116406, 113621, -83642,  43096
  -- RE1 =  13092,  -9684,  -8573,   5873, 158293,  -8300,   3661,  -1494
  -- RE2 =   3634,  -2531,   3858, -10172,-142157,   3354,  -9486,   5662
  --
  -- IM0 = -89005, -23598,  42253,  31421,  10390,  99334,  -5610,  30341
  -- IM1 =   3634,   2531,  -9486,  10172,-142157,  -3355,   3858,  -5662
  -- IM2 =  13092,  -9684, 153768,   5873, 103738,  -8300,  -8573,  -1494

begin

  clk <= not clk after 0.5 ns; -- 1000MHz

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
    for n in 0 to 7 loop
      fft1_in(n).rst <= '0';
    end loop;
    wait until rising_edge(clk);

    -- 1st FFT
    for n in 0 to 7 loop
      fft1_in(n).vld <= '1';
      fft1_in(n).re <= to_signed(RE(0)(n),18);
      fft1_in(n).im <= to_signed(IM(0)(n),18);
    end loop;
    fft1_start <= '1';
    wait until rising_edge(clk);
    fft1_start <= '0';
    -- 8-1 cycles
    for i in 1 to 7 loop 
      wait until rising_edge(clk);
    end loop;
    for n in 0 to 7 loop
      fft1_in(n).vld <= '0';
    end loop;
    wait until rising_edge(clk);
    
    -- 2nd FFT
    for n in 0 to 7 loop
      fft1_in(n).vld <= '1';
      fft1_in(n).re <= to_signed(RE(1)(n),18);
      fft1_in(n).im <= to_signed(IM(1)(n),18);
    end loop;
    fft1_start <= '1';
    wait until rising_edge(clk);
    fft1_start <= '0';
    -- 8-1 cycles
    for i in 1 to 7 loop 
      wait until rising_edge(clk);
    end loop;
    for n in 0 to 7 loop
      fft1_in(n).vld <= '0';
    end loop;
    wait until rising_edge(clk);

    -- 3rd FFT
    for n in 0 to 7 loop
      fft1_in(n).vld <= '1';
      fft1_in(n).re <= to_signed(RE(2)(n),18);
      fft1_in(n).im <= to_signed(IM(2)(n),18);
    end loop;
    fft1_start <= '1';
    wait until rising_edge(clk);
    fft1_start <= '0';
    -- 8-1 cycles
    for i in 1 to 7 loop 
      wait until rising_edge(clk);
    end loop;

    -- 1st FFT
    for n in 0 to 7 loop
      fft1_in(n).vld <= '1';
      fft1_in(n).re <= to_signed(RE(0)(n),18);
      fft1_in(n).im <= to_signed(IM(0)(n),18);
    end loop;
    fft1_start <= '1';
    wait until rising_edge(clk);
    fft1_start <= '0';
    -- 8-1 cycles
    for i in 1 to 7 loop 
      wait until rising_edge(clk);
    end loop;
    for n in 0 to 7 loop
      fft1_in(n).vld <= '0';
    end loop;
    wait until rising_edge(clk);

    -- endless loop
    loop
      wait for 1 ms;
    end loop;
  end process;

  i_fft1 : entity work.fft8_v1
  port map (
    clk      => clk,
    rst      => rst,
    start    => fft1_start,
    data_in  => fft1_in,
    idx_out  => fft1_out_idx,
    data_out => fft1_out
  );

  ifft1_start <= fft1_out.vld when fft1_out_idx=0 else '0';

  i_ifft1 : entity work.ifft8_v1
  port map (
    clk      => clk,
    rst      => rst,
    start    => ifft1_start,
    idx_in   => fft1_out_idx,
    data_in  => fft1_out,
    data_out => ifft1_out
  );

  i_log : entity work.cplx_logger4
  generic map(
    LOG_DECIMAL => true,
    LOG_INVALID => true,
    LOG_FILE => "result_log.txt",
    TITLE1 => "FFT1 OUT",
    TITLE2 => "UNUSED",
    TITLE3 => "UNUSED",
    TITLE4 => "UNUSED"
  )
  port map (
    clk    => clk,
    rst    => rst,
    din1   => fft1_out,
    din2   => open,
    din3   => open,
    din4   => open,
    finish => finish
  );

end architecture;
