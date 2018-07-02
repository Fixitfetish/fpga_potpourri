library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;

entity lfsr_tb is
end entity;

architecture sim of lfsr_tb is

  constant PERIOD : time := 500 ms; -- 0.5 Hz
  signal rst : std_logic := '1';
  signal clk : std_logic := '1';
  signal finish : std_logic := '0';

  signal clk_ena : std_logic := '0';
  signal data_out : std_logic;

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

  i_lfsr : entity baselib.lfsr
  generic map(
    EXPONENTS => (12,11,8,6)
  )
  port map (
    clk        => clk,
    rst        => rst,
    load_init  => b"0000_0000_0001",
    clk_ena    => clk_ena,
    data_out   => data_out
  );

  p_stimuli: process
  begin
    while rst='1' loop
      wait until rising_edge(clk);
    end loop;
    
    -- time forward
    for n in 0 to 1024 loop
       wait until rising_edge(clk);
       clk_ena <= '1'; 
       wait until rising_edge(clk);
       clk_ena <= '1'; 
    end loop;
        
    wait until rising_edge(clk);
    clk_ena <= '0'; 
    wait until rising_edge(clk);
    finish <= '1';
    wait until rising_edge(clk);
    wait; -- end of process
  end process;

end architecture;

