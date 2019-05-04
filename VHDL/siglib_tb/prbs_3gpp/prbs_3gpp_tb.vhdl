library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library siglib;

entity prbs_3gpp_tb is
end entity;

architecture sim of prbs_3gpp_tb is

  constant PERIOD : time := 500 ms; -- 0.5 Hz
  signal load : std_logic := '1';
  signal clk : std_logic := '1';
  signal finish : std_logic := '0';

  signal req_ack: std_logic := '1';

  constant OUTPUT_WIDTH : positive := 8;
  
  signal dout : std_logic_vector(OUTPUT_WIDTH-1 downto 0);
  signal dout_vld : std_logic;
  signal dout_first : std_logic;

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


  p_load: process
  begin
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    load <= '0'; 
    for n in 1 to 6 loop wait until rising_edge(clk); end loop;
    load <= '1'; 
    for n in 1 to 1 loop wait until rising_edge(clk); end loop;
    load <= '0'; 
    for n in 1 to 6 loop wait until rising_edge(clk); end loop;
    load <= '1'; 
    for n in 1 to 1 loop wait until rising_edge(clk); end loop;
    load <= '0'; 
    wait until rising_edge(clk);
    wait; -- end of process
  end process;


  i_3gpp : entity siglib.prbs_3gpp
  generic map(
    SHIFTS_PER_CYCLE => dout'length,
    ACKNOWLEDGE_MODE => true,
    OUTPUT_WIDTH     => dout'length,
    OUTPUT_REG       => true
  )
  port map (
    clk        => clk,
    load       => load,
    req_ack    => req_ack,
    seed       => (0=>'1', others=>'0'),
--    seed       => 31x"12345678",
    dout       => dout,
    dout_vld   => dout_vld,
    dout_first => dout_first
  );


  p_stimuli: process
  begin
    while load='1' loop
      wait until rising_edge(clk);
    end loop;

    -- time forward
    for n in 0 to 256 loop
       req_ack <= '1'; 
       wait until rising_edge(clk);
       req_ack <= '0'; 
       wait until rising_edge(clk);
       req_ack <= '1'; 
       wait until rising_edge(clk);
       req_ack <= '1'; 
       wait until rising_edge(clk);
       req_ack <= '1'; 
       wait until rising_edge(clk);
       req_ack <= '0'; 
       wait until rising_edge(clk);
       req_ack <= '0'; 
       wait until rising_edge(clk);
       req_ack <= '0'; 
       wait until rising_edge(clk);
    end loop;
        
    wait until rising_edge(clk);
    req_ack <= '0'; 
    wait until rising_edge(clk);
    finish <= '1';
    wait until rising_edge(clk);
    wait; -- end of process
  end process;

end architecture;

