library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;
library ramlib;
  use ramlib.ram_arbiter_pkg.all;

entity ram_arbiter_write_tb is
end entity;

architecture sim of ram_arbiter_write_tb is

  constant PERIOD : time := 10 ns; -- 100MHz
  signal rst : std_logic := '1';
  signal clk : std_logic := '1';
  signal finish : std_logic := '0';

  constant NUM_PORTS : positive := 4;
  constant DATA_WIDTH : positive := ramlib.ram_arbiter_pkg.DATA_WIDTH;
  constant ADDR_WIDTH : positive := ramlib.ram_arbiter_pkg.ADDR_WIDTH;

  signal usr_wr_port_tx  : a_ram_arbiter_wr_port_tx(0 to NUM_PORTS-1);
--  signal usr_wr_port_tx  : a_ram_arbiter_wr_port_tx(0 to NUM_PORTS-1)(
--                             cfg_addr_first(ADDR_WIDTH-1 downto 0),
--                             cfg_addr_last(ADDR_WIDTH-1 downto 0),
--                             data(DATA_WIDTH-1 downto 0)
--                           );
  signal usr_wr_port_rx  : a_ram_arbiter_wr_port_rx(0 to NUM_PORTS-1);
  signal ram_wr_ready    : std_logic := '1';
  signal ram_wr_addr     : std_logic_vector(ADDR_WIDTH - 1 downto 0);
  signal ram_wr_data     : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal ram_wr_ena      : std_logic;
  signal ram_wr_first    : std_logic;
  signal ram_wr_last     : std_logic;

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

  
  usr0 : entity work.usr_emulator
  generic map (
    ADDR_FIRST => to_unsigned(257,ADDR_WIDTH), 
    ADDR_LAST => to_unsigned(275,ADDR_WIDTH),
    SINGLE_SHOT => '1',
    INSTANCE_IDX => 0
  )
  port map(
    clk             => clk,
    rst             => rst_usr(0),
    vld_pattern     => "1100",
    usr_wr_port_tx  => usr_wr_port_tx(0),
    usr_wr_port_rx  => usr_wr_port_rx(0)
  );

  usr1 : entity work.usr_emulator
  generic map (
    ADDR_FIRST => to_unsigned(785,ADDR_WIDTH), 
    ADDR_LAST => to_unsigned(797,ADDR_WIDTH),
    SINGLE_SHOT => '0',
    INSTANCE_IDX => 1
  )
  port map(
    clk             => clk,
    rst             => rst_usr(1),
    vld_pattern     => "0101",
    usr_wr_port_tx  => usr_wr_port_tx(1),
    usr_wr_port_rx  => usr_wr_port_rx(1)
  );

  -- currently unused usr ports
  usr_wr_port_tx(2 to NUM_PORTS-1) <= RESET(usr_wr_port_tx(2 to NUM_PORTS-1));
--  usr_wr_port_tx(2 to NUM_PORTS-1) <= (others=>DEFAULT_RAM_ARBITER_WR_PORT_TX);

  i_arbiter : entity ramlib.ram_arbiter_write
  generic map(
    NUM_PORTS         => NUM_PORTS,
    DATA_WIDTH        => DATA_WIDTH,
    ADDR_WIDTH        => ADDR_WIDTH,
    OUTPUT_BURST_SIZE => 8
  )
  port map (
    clk             => clk,
    rst             => rst,
    usr_wr_port_tx  => usr_wr_port_tx,
    usr_wr_port_rx  => usr_wr_port_rx,
    ram_wr_ready    => ram_wr_ready,
    ram_wr_addr     => ram_wr_addr,
    ram_wr_data     => ram_wr_data,
    ram_wr_ena      => ram_wr_ena,
    ram_wr_first    => ram_wr_first,
    ram_wr_last     => ram_wr_last
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

    for n in 1 to 97 loop
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

