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

  constant OUTPUT_WIDTH : positive := 8;
  
  signal fib0_dout : std_logic_vector(OUTPUT_WIDTH-1 downto 0);
  signal fib0_dout_vld : std_logic;
  signal fib0_dout_first : std_logic;

  signal fib1_dout : std_logic_vector(OUTPUT_WIDTH-1 downto 0);
  signal fib1_dout_vld : std_logic;
  signal fib1_dout_first : std_logic;

  signal gal0_dout : std_logic_vector(OUTPUT_WIDTH-1 downto 0);
  signal gal0_dout_vld : std_logic;
  signal gal0_dout_first : std_logic;

  signal gal1_dout : std_logic_vector(OUTPUT_WIDTH-1 downto 0);
  signal gal1_dout_vld : std_logic;
  signal gal1_dout_first : std_logic;

  signal dout_3gpp : std_logic_vector(7 downto 0);
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


  i_lfsr_fib0 : entity siglib.lfsr
  generic map(
    TAPS             => (5,3),
    FIBONACCI        => true,
    SHIFTS_PER_CYCLE => 4,
    ACKNOWLEDGE_MODE => false,
    OFFSET           => 0,
    OFFSET_LOGIC     => "input",
    TRANSFORM_SEED   => false,
    OUTPUT_WIDTH     => OUTPUT_WIDTH,
    OUTPUT_REG       => false
  )
  port map (
    clk          => clk,
    load         => load,
    req_ack      => req_ack,
    seed         => open,
    dout         => fib0_dout,
    dout_vld_rdy => fib0_dout_vld,
    dout_first   => fib0_dout_first
  );


  i_lfsr_fib1 : entity siglib.lfsr
  generic map(
    TAPS             => (5,3),
    FIBONACCI        => true,
    SHIFTS_PER_CYCLE => 4,
    ACKNOWLEDGE_MODE => false,
    OFFSET           => 0,
    OFFSET_LOGIC     => "input",
    TRANSFORM_SEED   => true,
    OUTPUT_WIDTH     => OUTPUT_WIDTH,
    OUTPUT_REG       => false
  )
  port map (
    clk          => clk,
    load         => load,
    req_ack      => req_ack,
    seed         => open,
    dout         => fib1_dout,
    dout_vld_rdy => fib1_dout_vld,
    dout_first   => fib1_dout_first
  );


  i_lfsr_gal0 : entity siglib.lfsr
  generic map(
    TAPS             => (5,3),
    FIBONACCI        => false,
    SHIFTS_PER_CYCLE => 4,
    ACKNOWLEDGE_MODE => false,
    OFFSET           => 0,
    OFFSET_LOGIC     => "input",
    TRANSFORM_SEED   => false,
    OUTPUT_WIDTH     => OUTPUT_WIDTH,
    OUTPUT_REG       => false
  )
  port map (
    clk          => clk,
    load         => load,
    req_ack      => req_ack,
    seed         => open,
    dout         => gal0_dout,
    dout_vld_rdy => gal0_dout_vld,
    dout_first   => gal0_dout_first
  );


  i_lfsr_gal1 : entity siglib.lfsr
  generic map(
    TAPS             => (5,3),
    FIBONACCI        => false,
    SHIFTS_PER_CYCLE => 4,
    ACKNOWLEDGE_MODE => false,
    OFFSET           => 0,
    OFFSET_LOGIC     => "input",
    TRANSFORM_SEED   => true,
    OUTPUT_WIDTH     => OUTPUT_WIDTH,
    OUTPUT_REG       => false
  )
  port map (
    clk          => clk,
    load         => load,
    req_ack      => req_ack,
    seed         => open,
    dout         => gal1_dout,
    dout_vld_rdy => gal1_dout_vld,
    dout_first   => gal1_dout_first
  );


  i_3gpp : entity siglib.prbs_3gpp
  generic map(
    SHIFTS_PER_CYCLE => dout_3gpp'length,
    ACKNOWLEDGE_MODE => true,
    OUTPUT_WIDTH     => dout_3gpp'length,
    OUTPUT_REG       => true
  )
  port map (
    clk        => clk,
    load       => load,
    req_ack    => req_ack,
    seed       => (0=>'1', others=>'0'),
--    seed       => 31x"12345678",
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

