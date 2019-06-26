library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library cplxlib;
  use cplxlib.cplx_pkg.all;

entity cplx_noise_tb is
end entity;

architecture sim of cplx_noise_tb is

  constant PERIOD : time := 500 ms; -- 0.5 Hz
  signal load : std_logic := '1';
  signal clk : std_logic := '1';
  signal finish : std_logic := '0';

  signal req_ack: std_logic := '1';

  constant RESOLUTION : positive := 16;

  signal n0_dout : cplx(re(RESOLUTION-1 downto 0),im(RESOLUTION-1 downto 0));
  signal n1_dout : cplx(re(RESOLUTION-1 downto 0),im(RESOLUTION-1 downto 0));

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


  i_wgn0 : entity cplxlib.cplx_noise_normal
  generic map(
    RESOLUTION       => RESOLUTION,
    ACKNOWLEDGE_MODE => false,
    INSTANCE_IDX     => 0
  )
  port map (
    clk         => clk,
    rst         => load,
    req_ack     => req_ack,
    dout        => n0_dout,
    PIPESTAGES  => PIPESTAGES
  );

  i_wgn1 : entity cplxlib.cplx_noise_normal
  generic map(
    RESOLUTION       => RESOLUTION,
    ACKNOWLEDGE_MODE => true,
    INSTANCE_IDX     => 0
  )
  port map (
    clk         => clk,
    rst         => load,
    req_ack     => req_ack,
    dout        => n1_dout,
    PIPESTAGES  => open
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

