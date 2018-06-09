library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;
library ramlib;

entity arstb_tb is
end entity;

architecture sim of arstb_tb is

  constant PERIOD : time := 10 ns; -- 100MHz
  signal rst : std_logic := '1';
  signal clk : std_logic := '1';
  signal finish : std_logic := '0';

  constant NUM_PORTS : positive := 4;
  constant DATA_WIDTH : positive := 16;

  signal usr_out_req_frame : std_logic_vector(NUM_PORTS-1 downto 0) := (others=>'0');
  signal usr_out_req_ena : std_logic_vector(NUM_PORTS-1 downto 0) := (others=>'0');
  signal usr_in_req_ovfl : std_logic_vector(NUM_PORTS-1 downto 0);
  signal usr_in_req_fifo_ovfl : std_logic_vector(NUM_PORTS-1 downto 0);

  signal bus_in_req_ena       : std_logic;
  signal bus_in_req_sob       : std_logic;
  signal bus_in_req_eob       : std_logic;
  signal bus_in_req_usr_id    : unsigned(log2ceil(NUM_PORTS)-1 downto 0);
  signal bus_in_req_usr_frame : std_logic_vector(NUM_PORTS-1 downto 0);
  signal bus_out_req_rdy      : std_logic := '1';
  signal bus_out_cpl_data     : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal bus_out_cpl_data_vld : std_logic;

  signal usr_in_cpl_rdy       : std_logic_vector(NUM_PORTS-1 downto 0);
  signal usr_out_cpl_ack      : std_logic_vector(NUM_PORTS-1 downto 0);
  signal usr_in_cpl_ack_ovfl  : std_logic_vector(NUM_PORTS-1 downto 0);
  signal usr_in_cpl_data      : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal usr_in_cpl_data_vld  : std_logic_vector(NUM_PORTS-1 downto 0);
  signal usr_in_cpl_data_eof  : std_logic_vector(NUM_PORTS-1 downto 0);
  signal usr_in_cpl_fifo_ovfl : std_logic_vector(NUM_PORTS-1 downto 0);

  signal toggle : std_logic_vector(NUM_PORTS-1 downto 0) := (others=>'1');
  signal rst_usr : std_logic_vector(NUM_PORTS-1 downto 0) := (others=>'1');

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
  rst <= '0' after 10*PERIOD;


  usr0 : entity work.usr_req_emulator
  generic map (
    DATA_WIDTH => DATA_WIDTH,
    INSTANCE_IDX => 0
  )
  port map(
    clk             => clk,
    rst             => rst_usr(0),
    vld_pattern     => "1100",
    din             => open,
    din_vld         => usr_out_req_ena(0),
    din_frame       => usr_out_req_frame(0)
  );

  usr1 : entity work.usr_req_emulator
  generic map (
    DATA_WIDTH => DATA_WIDTH,
    INSTANCE_IDX => 1
  )
  port map(
    clk             => clk,
    rst             => rst_usr(1),
    vld_pattern     => "0000",
    din             => open,
    din_vld         => usr_out_req_ena(1),
    din_frame       => usr_out_req_frame(1)
  );

  usr2 : entity work.usr_req_emulator
  generic map (
    DATA_WIDTH => DATA_WIDTH,
    INSTANCE_IDX => 2
  )
  port map(
    clk             => clk,
    rst             => rst_usr(2),
    vld_pattern     => "0000",
    din             => open,
    din_vld         => usr_out_req_ena(2),
    din_frame       => usr_out_req_frame(2)
  );

  usr3 : entity work.usr_req_emulator
  generic map (
    DATA_WIDTH => DATA_WIDTH,
    INSTANCE_IDX => 3
  )
  port map(
    clk             => clk,
    rst             => rst_usr(3),
    vld_pattern     => "0100",
    din             => open,
    din_vld         => usr_out_req_ena(3),
    din_frame       => usr_out_req_frame(3)
  );

  -- TODO ... currently just auto-ack
  toggle <= not toggle when rising_edge(clk);
  usr_out_cpl_ack <= usr_in_cpl_rdy and toggle;

  i_arbiter : entity ramlib.arbiter_read_single_to_burst
  generic map(
    NUM_PORTS  => NUM_PORTS, -- for now up to 4 supported
    DATA_WIDTH => DATA_WIDTH,
    BURST_SIZE => 8,
    FIFO_DEPTH_LOG2 => 4,
    MAX_CPL_DELAY => 256
  )
  port map (
    clk                  => clk,
    rst                  => rst,
    usr_out_req_frame    => usr_out_req_frame,
    usr_out_req_ena      => usr_out_req_ena,
    usr_in_req_ovfl      => usr_in_req_ovfl,
    usr_in_req_fifo_ovfl => usr_in_req_fifo_ovfl,
    usr_in_cpl_rdy       => usr_in_cpl_rdy,
    usr_out_cpl_ack      => usr_out_cpl_ack,
    usr_in_cpl_ack_ovfl  => usr_in_cpl_ack_ovfl,
    usr_in_cpl_data      => usr_in_cpl_data,
    usr_in_cpl_data_vld  => usr_in_cpl_data_vld,
    usr_in_cpl_data_eof  => usr_in_cpl_data_eof,
    usr_in_cpl_fifo_ovfl => usr_in_cpl_fifo_ovfl,
    bus_in_req_ena       => bus_in_req_ena,
    bus_in_req_sob       => bus_in_req_sob,
    bus_in_req_eob       => bus_in_req_eob,
    bus_in_req_usr_id    => bus_in_req_usr_id,
    bus_in_req_usr_frame => bus_in_req_usr_frame,
    bus_in_req_data      => open, -- unused
    bus_in_req_data_vld  => open, -- unused
    bus_out_req_rdy      => bus_out_req_rdy,
    bus_out_cpl_data     => bus_out_cpl_data,
    bus_out_cpl_data_vld => bus_out_cpl_data_vld
  );

  i_bus : entity work.bus_cpl_emulator
  generic map (
    DATA_WIDTH => DATA_WIDTH,
    CPL_DELAY => 12
  )
  port map(
    clk           => clk,
    rst           => rst,
    req_ena       => bus_in_req_ena, 
    req_usr_id    => bus_in_req_usr_id, 
    cpl_data      => bus_out_cpl_data, 
    cpl_data_vld  => bus_out_cpl_data_vld 
  );


  p_stimuli: process
  begin
    while rst='1' loop
      wait until rising_edge(clk);
    end loop;

    wait for 100 ns;
    wait until rising_edge(clk);

    rst_usr(0) <= '0';
    rst_usr(3) <= '0';
    wait until rising_edge(clk);

    for n in 1 to 25 loop
      wait until rising_edge(clk);
    end loop;

    bus_out_req_rdy <= '0';
    
    for n in 1 to 10 loop
      wait until rising_edge(clk);
    end loop;

    bus_out_req_rdy <= '1';
    
    for n in 1 to 20 loop
      wait until rising_edge(clk);
    end loop;

    rst_usr(0) <= '1';
    rst_usr(3) <= '1';

    wait for 400 ns;
    finish <= '1';

    wait until rising_edge(clk);
    wait; -- end of process
  end process;

end architecture;

