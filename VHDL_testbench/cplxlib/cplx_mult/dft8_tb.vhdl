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

-- FFT1 requires a CPLX_VECTOR as input, i.e. the complete input data in one cycle.
-- The FFT1 output is a single CPLX, i.e. a serialized stream over 8 cycles.
-- Hence, the input data needs a vectorization.

-- FFT2 requires a single CPLX as input, i.e. serialized stream over 8 cycles.
-- The FFT1 output is a CPLX_VECTOR, i.e. the complete output data in one cycle.
-- Hence, the output data needs to be serialized.


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
  signal fft1_in : cplx_vector(0 to 7) := cplx_vector_reset(18,8,"R");
  signal fft1_out_idx : unsigned(2 downto 0);
  signal fft1_out_ser : cplx;

  signal fft2_in_start : std_logic := '0';
  signal fft2_in_idx : unsigned(2 downto 0);
  signal fft2_in_ser : cplx;
  signal fft2_out : cplx_vector(0 to 7) := cplx_vector_reset(18,8,"R");
  signal fft2_out_ser : cplx;

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
    NUM_CPLX => 2,
    SKIP_PRECEDING_LINES => 2,
    GEN_DECIMAL => true,
    GEN_INVALID => true,
    GEN_FILE => "input_sti.txt"
  )
  port map (
    clk     => clk,
    rst     => rst,
    dout(0) => fft1_in_ser,
    dout(1) => fft2_in_ser,
    finish  => finish
  );

  p_start : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        fft1_in_idx <= (others=>'0');
        fft2_in_idx <= (others=>'0');
      else
        if fft1_in_ser.vld='1' then
          fft1_in_idx <= fft1_in_idx + 1;
        end if;
        if fft2_in_ser.vld='1' then
          fft2_in_idx <= fft2_in_idx + 1;
        end if;
      end if;
    end if;
  end process;

  fft1_in_start <= fft1_in_ser.vld when fft1_in_idx=0 else '0';
  fft2_in_start <= fft2_in_ser.vld when fft2_in_idx=0 else '0';

  i_fft1_in : entity cplxlib.cplx_vectorization
  port map (
    clk      => clk,
    rst      => rst,
    start    => fft1_in_start,
    ser_in   => fft1_in_ser,
    vec_out  => fft1_in
  );
 
  i_fft1 : entity work.dft8_v1
  port map (
    clk      => clk,
    rst      => rst,
    inverse  => '0',
    start    => fft1_in(0).vld,
    data_in  => fft1_in,
    idx_out  => fft1_out_idx,
    data_out => fft1_out_ser
  );

  i_fft2 : entity work.dft8_v2
  port map (
    clk      => clk,
    rst      => rst,
    inverse  => '0',
    start    => fft2_in_start,
    idx_in   => fft2_in_idx,
    data_in  => fft2_in_ser,
    data_out => fft2_out
  );

  i_fft2_out_ser : entity cplxlib.cplx_vector_serialization
  port map (
    clk      => clk,
    rst      => rst,
    start    => fft2_out(0).vld,
    vec_in   => fft2_out,
    idx_out  => open,
    ser_out  => fft2_out_ser
  );

  i_log : entity work.cplx_logger
  generic map(
    NUM_CPLX => 2,
    LOG_DECIMAL => true,
    LOG_INVALID => true,
    LOG_FILE => "result_log.txt",
    TITLE => "FFT_OUT"
  )
  port map (
    clk    => clk,
    rst    => rst,
    din(0) => fft1_out_ser,
    din(1) => fft2_out_ser,
    finish => finish
  );

end architecture;
