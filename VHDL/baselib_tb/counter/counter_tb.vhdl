library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;

entity counter_tb is
end entity;

architecture sim of counter_tb is

  constant PERIOD : time := 500 ms; -- 0.5 Hz
  signal rst : std_logic := '1';
  signal clk : std_logic := '1';
  signal finish : std_logic := '0';

  constant SECOND_WIDTH : positive := 6; -- 0..59
  signal second : std_logic_vector(SECOND_WIDTH-1 downto 0);
  signal second_incr, second_decr : std_logic := '0';
  signal second_min, second_max : std_logic;

  constant MINUTE_WIDTH : positive := 6; -- 0..59
  signal minute : std_logic_vector(MINUTE_WIDTH-1 downto 0);
  signal minute_incr, minute_decr : std_logic := '0';
  signal minute_min, minute_max : std_logic;

  constant HOUR_WIDTH : positive := 5; -- 0..23
  signal hour : std_logic_vector(HOUR_WIDTH-1 downto 0);
  signal hour_incr, hour_decr : std_logic := '0';
  signal hour_min, hour_max : std_logic;

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

  -- count seconds
  i_second : entity baselib.counter
  generic map(
    COUNTER_WIDTH => SECOND_WIDTH
  )
  port map (
    clk        => clk,
    rst        => rst,
    load_init  => b"01_0010", -- 18
    load_min   => b"00_0000", --  0
    load_max   => b"11_1011", -- 59 
    incr       => second_incr,
    decr       => second_decr,
    count      => second,
    count_min  => second_min,
    count_max  => second_max
  );

  minute_incr <= second_max and second_incr;
  minute_decr <= second_min and second_decr;

  -- count minutes
  i_minute : entity baselib.counter
  generic map(
    COUNTER_WIDTH => MINUTE_WIDTH
  )
  port map (
    clk        => clk,
    rst        => rst,
    load_init  => b"00_1001", --  9
    load_min   => b"00_0000", --  0
    load_max   => b"11_1011", -- 59 
    incr       => minute_incr,
    decr       => minute_decr,
    count      => minute,
    count_min  => minute_min,
    count_max  => minute_max
  );

  hour_incr <= minute_max and minute_incr;
  hour_decr <= minute_min and minute_decr;

  -- count hours
  i_hour : entity baselib.counter
  generic map(
    COUNTER_WIDTH => HOUR_WIDTH
  )
  port map (
    clk        => clk,
    rst        => rst,
    load_init  => b"0_1101", -- 13
    load_min   => b"0_0000", --  0
    load_max   => b"1_0111", -- 23
    incr       => hour_incr,
    decr       => hour_decr,
    count      => hour,
    count_min  => open, -- unused
    count_max  => open  -- unused
  );

  p_stimuli: process
  begin
    while rst='1' loop
      wait until rising_edge(clk);
    end loop;
    
    -- time forward
    for n in 0 to 3599 loop
       wait until rising_edge(clk);
       second_incr <= '1'; 
       wait until rising_edge(clk);
       second_incr <= '0'; 
    end loop;
    
    -- time backward
    for n in 0 to 3599 loop
       wait until rising_edge(clk);
       second_decr <= '1'; 
       wait until rising_edge(clk);
       second_decr <= '0'; 
    end loop;
    
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    finish <= '1';
    wait until rising_edge(clk);
    wait; -- end of process
  end process;

end architecture;

