library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;
library ramlib;

entity awstb_tb is
end entity;

architecture sim of awstb_tb is

  constant PERIOD : time := 10 ns; -- 100MHz
  signal rst : std_logic := '1';
  signal clk : std_logic := '1';
  signal finish : std_logic := '0';

  constant NUM_PORTS : positive := 4;
  constant DATA_WIDTH : positive := 16;

  signal din_frame : std_logic_vector(NUM_PORTS-1 downto 0) := (others=>'0');
  signal din_vld : std_logic_vector(NUM_PORTS-1 downto 0) := (others=>'0');
  signal din : slv16_array(0 to NUM_PORTS-1) := (others=>(others=>'1'));
  signal din_ovf : std_logic_vector(NUM_PORTS-1 downto 0);
  signal dout_rdy : std_logic := '1';
  signal dout : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal dout_ena, dout_first, dout_last : std_logic;
  signal dout_vld : std_logic_vector(NUM_PORTS-1 downto 0);
  signal dout_idx : unsigned(log2ceil(NUM_PORTS)-1 downto 0);
  signal dout_frame : std_logic_vector(NUM_PORTS-1 downto 0);
  signal fifo_ovf : std_logic_vector(NUM_PORTS-1 downto 0);

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


  usr0 : entity work.din_emulator
  generic map (
    DATA_WIDTH => DATA_WIDTH,
    INSTANCE_IDX => 0
  )
  port map(
    clk             => clk,
    rst             => rst_usr(0),
    vld_pattern     => "1100",
    din             => din(0),
    din_vld         => din_vld(0),
    din_frame       => din_frame(0)
  );

  usr1 : entity work.din_emulator
  generic map (
    DATA_WIDTH => DATA_WIDTH,
    INSTANCE_IDX => 1
  )
  port map(
    clk             => clk,
    rst             => rst_usr(1),
    vld_pattern     => "0100",
    din             => din(1),
    din_vld         => din_vld(1),
    din_frame       => din_frame(1)
  );

  usr2 : entity work.din_emulator
  generic map (
    DATA_WIDTH => DATA_WIDTH,
    INSTANCE_IDX => 2
  )
  port map(
    clk             => clk,
    rst             => rst_usr(2),
    vld_pattern     => "0000",
    din             => din(2),
    din_vld         => din_vld(2),
    din_frame       => din_frame(2)
  );

  usr3 : entity work.din_emulator
  generic map (
    DATA_WIDTH => DATA_WIDTH,
    INSTANCE_IDX => 3
  )
  port map(
    clk             => clk,
    rst             => rst_usr(3),
    vld_pattern     => "0000",
    din             => din(3),
    din_vld         => din_vld(3),
    din_frame       => din_frame(3)
  );


  i_fifo : entity ramlib.arbiter_write_single_to_burst
  generic map(
    NUM_PORTS  => NUM_PORTS, -- for now up to 4 supported
    DATA_WIDTH => DATA_WIDTH,
    BURST_SIZE => 8,
    FIFO_DEPTH_LOG2 => 4
  )
  port map (
    clk                     => clk,
    rst                     => rst,
    usr_out_req_frame       => din_frame,
    usr_out_req_wr_ena      => din_vld,
    usr_out_req_wr_data     => din,
    usr_in_req_wr_ovfl      => din_ovf,
    usr_in_req_wr_fifo_ovfl => fifo_ovf,
    bus_out_req_rdy         => dout_rdy,
    bus_in_req_wr_ena       => dout_ena,
    bus_in_req_wr_data      => dout,
    bus_in_req_first        => dout_first,
    bus_in_req_last         => dout_last,
    bus_in_req_port_frame   => dout_frame,
    bus_in_req_port_ena     => dout_vld,
    bus_in_req_port_idx     => dout_idx
  );


  p_stimuli: process
  begin
    while rst='1' loop
      wait until rising_edge(clk);
    end loop;

    wait for 100 ns;
    wait until rising_edge(clk);

    rst_usr(0) <= '0';
    rst_usr(1) <= '0';
    wait until rising_edge(clk);

    for n in 1 to 25 loop
      wait until rising_edge(clk);
    end loop;

    dout_rdy <= '0';
    
    for n in 1 to 10 loop
      wait until rising_edge(clk);
    end loop;

    dout_rdy <= '1';
    
    for n in 1 to 20 loop
      wait until rising_edge(clk);
    end loop;

    rst_usr(0) <= '1';
    rst_usr(1) <= '1';

    wait for 400 ns;
    finish <= '1';

    wait until rising_edge(clk);
    wait; -- end of process
  end process;

end architecture;

