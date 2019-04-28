library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library siglib;

entity lfsr_tb is
end entity;

architecture sim of lfsr_tb is

  constant PERIOD : time := 500 ms; -- 0.5 Hz
  signal load : std_logic := '1';
  signal clk : std_logic := '1';
  signal finish : std_logic := '0';

  signal req_ack: std_logic := '1';
  signal req_dout, ack_dout : std_logic_vector(15 downto 0);
  signal req_dout_vld, ack_dout_vld : std_logic;
  signal req_dout_first, ack_dout_first : std_logic;

  signal dout_3gpp : std_logic_vector(31 downto 0);
  signal dout_vld_3gpp : std_logic;
  signal dout_first_3gpp : std_logic;

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

--  -- release reset
--  load <= '0' after  3*PERIOD+PERIOD/100 ,
--          '1' after  9*PERIOD ,
--          '0' after 10*PERIOD ,
--          '1' after 16*PERIOD ,
--          '0' after 17*PERIOD ;

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

  i_lfsr_req : entity siglib.lfsr
  generic map(
    TAPS             => (16,14,13,11),
    FIBONACCI        => true,
    SHIFTS_PER_CYCLE => 8,
    ACKNOWLEDGE_MODE => false,
    OFFSET           => 0,
    OFFSET_AT_OUTPUT => false,
    OUTPUT_REG       => false
  )
  port map (
    clk        => clk,
    load       => load,
    req_ack    => req_ack,
    seed       => open,
    dout       => req_dout,
    dout_vld   => req_dout_vld,
    dout_first => req_dout_first
  );

  i_lfsr_ack : entity siglib.lfsr
  generic map(
    TAPS             => (16,14,13,11),
    FIBONACCI        => true,
    SHIFTS_PER_CYCLE => 8,
    ACKNOWLEDGE_MODE => true,
    OFFSET           => 0,
    OFFSET_AT_OUTPUT => false,
    OUTPUT_REG       => false
  )
  port map (
    clk        => clk,
    load       => load,
    req_ack    => req_ack,
    seed       => open,
    dout       => ack_dout,
    dout_vld   => ack_dout_vld,
    dout_first => ack_dout_first
  );

  i_3gpp : entity work.prbs_3gpp
  generic map(
    SHIFTS_PER_CYCLE => 32,
    ACKNOWLEDGE_MODE => false,
    OUTPUT_WIDTH     => dout_3gpp'length,
    OUTPUT_REG       => true
  )
  port map (
    clk        => clk,
    load       => load,
    req_ack    => req_ack,
    seed       => (0=>'1', others=>'0'),
    dout       => dout_3gpp,
    dout_vld   => dout_vld_3gpp,
    dout_first => dout_first_3gpp
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

