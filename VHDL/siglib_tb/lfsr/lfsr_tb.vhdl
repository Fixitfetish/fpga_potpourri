library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library siglib;

entity lfsr_tb is
end entity;

architecture sim of lfsr_tb is

  constant PERIOD : time := 500 ms; -- 0.5 Hz
  signal rst : std_logic := '1';
  signal clk : std_logic := '1';
  signal finish : std_logic := '0';

  signal req_ack: std_logic := '0';
  signal dout : std_logic_vector(15 downto 0);
  signal dout_3gpp : std_logic_vector(30 downto 0);
  signal dout_vld,dout_vld_3gpp : std_logic;

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

  i_lfsr : entity siglib.lfsr
  generic map(
    TAPS             => (16,14,13,11),
    FIBONACCI        => false,
    BITS_PER_CYCLE   => 8,
    ACKNOWLEDGE_MODE => false,
    OFFSET           => 199,
    OFFSET_AT_OUTPUT => false
  )
  port map (
    clk        => clk,
    load       => rst,
    req_ack    => req_ack,
    seed       => open,
    dout       => dout,
    dout_vld   => dout_vld
  );

  i_3gpp : entity work.prbs_3gpp
  generic map(
    BITS_PER_CYCLE => 16,
    ACKNOWLEDGE_MODE => true,
    OUTPUT_REG => false
  )
  port map (
    clk        => clk,
    load       => rst,
    req_ack    => req_ack,
    seed       => (0=>'1', others=>'0'),
    dout       => dout_3gpp,
    dout_vld   => dout_vld_3gpp
  );


  p_stimuli: process
  begin
    while rst='1' loop
      wait until rising_edge(clk);
    end loop;

    -- time forward
    for n in 0 to 1024 loop
       wait until rising_edge(clk);
       req_ack <= '1'; 
       wait until rising_edge(clk);
       req_ack <= '0'; 
    end loop;
        
    wait until rising_edge(clk);
    req_ack <= '0'; 
    wait until rising_edge(clk);
    finish <= '1';
    wait until rising_edge(clk);
    wait; -- end of process
  end process;

end architecture;

