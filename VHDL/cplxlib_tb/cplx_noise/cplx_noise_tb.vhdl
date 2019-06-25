-------------------------------------------------------------------------------
-- FILE    : cplx_noise_tb.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 24/Jun/2019
-- VERSION : 0.20
-- VHDL    : 1993
-- LICENSE : MIT License
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library cplxlib;
  use cplxlib.cplx_pkg.all;

use std.textio.all;

entity cplx_noise_tb is
end entity;

architecture sim of cplx_noise_tb is
  
  constant PERIOD : time := 1 ns; -- 1000MHz
  constant NOUT : natural := 2; 

  constant FILENAME_R : string := "result_log.txt"; -- result

  signal rst : std_logic := '1';
  signal clk : std_logic := '1';
  signal clkena : std_logic := '0';
  signal finish : std_logic := '0';

  signal dout : cplx18_vector(0 to NOUT-1) := cplx_vector_reset(18,NOUT,"R");
  
  signal PIPESTAGES : natural;

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

  finish <= '1' after 1000*PERIOD;

  p_start : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        clkena <= '0';
      else
        clkena <= not clkena;
      end if;
    end if;
  end process;

  i_normal : entity cplxlib.cplx_noise_normal
  generic map(
    RESOLUTION       => 18
  )
  port map(
    clk        => clk,
    rst        => rst,
    req_ack    => clkena,
    dout       => dout(0),
    PIPESTAGES => PIPESTAGES
  );

  i_uniform : entity cplxlib.cplx_noise_uniform
  generic map(
    RESOLUTION       => 18
  )
  port map(
    clk        => clk,
    rst        => rst,
    req_ack    => clkena,
    dout       => dout(1),
    PIPESTAGES => PIPESTAGES
  );

  i_log : entity work.cplx_logger
  generic map(
    NUM_CPLX => 1,
    LOG_FILE => FILENAME_R,
    LOG_DECIMAL => true,
    LOG_INVALID => true,
    STR_INVALID => open,
    TITLE => "NOISE"
  )
  port map (
    clk     => clk,
    rst     => rst,
    din     => dout,
    finish  => finish
  );

end architecture;
