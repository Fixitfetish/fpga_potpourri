-------------------------------------------------------------------------------
-- FILE    : dft8_tb.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 05/Apr/2017
-- VERSION : 0.10
-- VHDL    : 1993
-- LICENSE : MIT License
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library cplxlib;
  use cplxlib.cplx_pkg.all;

use std.textio.all;

entity dft8_tb is
end entity;

architecture sim of dft8_tb is
  
  constant PERIOD : time := 1 ns; -- 1000MHz

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';
  signal finish : std_logic := '0';

  signal fft1_in_start : std_logic := '0';
  signal fft1_in_idx : unsigned(2 downto 0);
  signal fft1_in_ser : cplx;

  signal fft1_out : cplx_vector(0 to 7) := cplx_vector_reset(18,8,"R");
  signal fft1_out_ser : cplx;

begin

  p_clk : process
  begin
    while finish='0' loop
      wait for PERIOD/2;
      clk <= not clk;
    end loop;
    -- epilog, 5 cycles
    for n in 1 to 10 loop
      wait for PERIOD/2;
      clk <= not clk;
    end loop;
    report "INFO: Clock stopped. End of simulation." severity note;
    wait; -- stop clock
  end process;

  -- release reset
  rst <= '0' after 2*PERIOD;

  i_stimuli : entity work.cplx_stimuli
  generic map(
    SKIP_PRECEDING_LINES => 0,
    GEN_DECIMAL => true,
    GEN_INVALID => true,
    GEN_FILE => "stimuli.txt"
  )
  port map (
    clk    => clk,
    rst    => rst,
    dout   => fft1_in_ser,
    finish => finish
  );

  p_start : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        fft1_in_idx <= (others=>'0');
      elsif fft1_in_ser.vld='1' then
        fft1_in_idx <= fft1_in_idx + 1;
      end if;
    end if;
  end process;

  fft1_in_start <= fft1_in_ser.vld when fft1_in_idx=0 else '0';

  i_fft1 : entity work.dft8_v2
  port map (
    clk      => clk,
    rst      => rst,
    inverse  => '0',
    start    => fft1_in_start,
    idx_in   => fft1_in_idx,
    data_in  => fft1_in_ser,
    data_out => fft1_out
  );

  i_fft1_out_ser : entity cplxlib.cplx_vector_serialization
  port map (
    clk      => clk,
    rst      => rst,
    start    => fft1_out(0).vld,
    vec_in   => fft1_out,
    idx_out  => open,
    ser_out  => fft1_out_ser
  );

  i_log : entity work.cplx_logger
  generic map(
    LOG_DECIMAL => true,
    LOG_INVALID => true,
    LOG_FILE => "result_log.txt",
    TITLE1 => "FFT1_OUT"
  )
  port map (
    clk    => clk,
    rst    => rst,
    din    => fft1_out_ser,
    finish => finish
  );

end architecture;
