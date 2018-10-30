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
  constant RAM_ADDR_WIDTH : positive := 16;
  constant RAM_DATA_WIDTH : positive := 32;

  signal usr_out_port  : a_ram_arbiter_usr_out_port(0 to NUM_PORTS-1);
--  signal usr_out_port : a_ram_arbiter_usr_out_port(0 to NUM_PORTS-1)(
--                             cfg_addr_first(RAM_ADDR_WIDTH-1 downto 0),
--                             cfg_addr_last(RAM_ADDR_WIDTH-1 downto 0),
--                             req_data(RAM_DATA_WIDTH-1 downto 0)
--                           );
  signal usr_in_port  : a_ram_arbiter_usr_in_port(0 to NUM_PORTS-1);
--  signal usr_in_port  : a_ram_arbiter_usr_in_port(0 to NUM_PORTS-1)(
--                             addr_next(RAM_ADDR_WIDTH-1 downto 0),
--                            cpl_data(RAM_DATA_WIDTH-1 downto 0)
--                           );

  signal ram_out_rdy      : std_logic := '1';
  signal ram_in_addr      : std_logic_vector(RAM_ADDR_WIDTH - 1 downto 0);
  signal ram_in_addr_vld  : std_logic;
  signal ram_in_first     : std_logic;
  signal ram_in_last      : std_logic;
  signal ram_in_data      : std_logic_vector(RAM_DATA_WIDTH - 1 downto 0);

  signal usr_frame : std_logic_vector(NUM_PORTS-1 downto 0) := (others=>'0');

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

  
  usr0 : entity work.usr_write_emulator
  generic map (
    ARBITER_ADDR_WIDTH => RAM_ADDR_WIDTH,
    ARBITER_DATA_WIDTH => RAM_DATA_WIDTH,
    USER_DATA_WIDTH => RAM_DATA_WIDTH/2,
    ADDR_FIRST => to_unsigned(257,RAM_ADDR_WIDTH), 
    ADDR_LAST => to_unsigned(275,RAM_ADDR_WIDTH),
    SINGLE_SHOT => '0',
    INSTANCE_IDX => 0
  )
  port map(
    clk           => clk,
    rst           => rst,
    usr_req_frame => usr_frame(0),
    usr_req_ena   => usr_frame(0),
    arb_out       => usr_in_port(0),
    arb_in        => usr_out_port(0)
  );

  usr1 : entity work.usr_write_emulator
  generic map (
    ARBITER_ADDR_WIDTH => RAM_ADDR_WIDTH,
    ARBITER_DATA_WIDTH => RAM_DATA_WIDTH,
    USER_DATA_WIDTH => RAM_DATA_WIDTH/2,
    ADDR_FIRST => to_unsigned(785,RAM_ADDR_WIDTH), 
    ADDR_LAST => to_unsigned(797,RAM_ADDR_WIDTH),
    SINGLE_SHOT => '0',
    INSTANCE_IDX => 1
  )
  port map(
    clk           => clk,
    rst           => rst,
    usr_req_frame => usr_frame(1),
    usr_req_ena   => usr_frame(1),
    arb_out       => usr_in_port(1),
    arb_in        => usr_out_port(1)
  );

  -- currently unused usr ports
  usr_out_port(2 to NUM_PORTS-1) <= RESET(usr_out_port(2 to NUM_PORTS-1));

  i_arbiter : entity ramlib.ram_arbiter_write
  generic map(
    NUM_PORTS         => NUM_PORTS,
    DATA_WIDTH        => RAM_DATA_WIDTH,
    ADDR_WIDTH        => RAM_ADDR_WIDTH,
    BURST_SIZE        => 8
  )
  port map (
    clk              => clk,
    rst              => rst,
    usr_out_port     => usr_out_port,
    usr_in_port      => usr_in_port,
    ram_out_rdy      => ram_out_rdy,
    ram_in_addr      => ram_in_addr,
    ram_in_ena       => ram_in_addr_vld,
    ram_in_first     => ram_in_first,
    ram_in_last      => ram_in_last,
    ram_in_data      => ram_in_data
  );

  i_log : entity work.ram_logger
  generic map(
    LOG_FILE => "log.txt",
    TITLE => ""
  )
  port map(
    clk      => clk,
    rst      => rst,
    addr     => ram_in_addr,
    din      => ram_in_data,
    wren     => ram_in_addr_vld,
    sob      => ram_in_first,
    eob      => ram_in_last,
    finish   => finish
  );

  p_stimuli: process
  begin
    
    while rst='1' loop
      wait until rising_edge(clk);
    end loop;

    wait for 100 ns;
    wait until rising_edge(clk);
    usr_frame(0) <= '1';
    usr_frame(1) <= '1';
    wait until rising_edge(clk);

    for n in 1 to 97 loop
      wait until rising_edge(clk);
    end loop;
    
    usr_frame(0) <= '0';
    usr_frame(1) <= '0';

    wait for 500 ns;
    finish <= '1';

    wait until rising_edge(clk);
    wait; -- end of process
  end process;

end architecture;

