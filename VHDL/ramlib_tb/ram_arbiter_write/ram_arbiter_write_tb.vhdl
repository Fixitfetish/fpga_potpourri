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
  constant DATA_WIDTH : positive := 16;
  constant ADDR_WIDTH : positive := 16;

  signal usr_out_wr_port  : a_ram_arbiter_usr_out_wr_port(0 to NUM_PORTS-1);
--  signal usr_out_wr_port : a_ram_arbiter_usr_out_wr_port(0 to NUM_PORTS-1)(
--                             cfg_addr_first(ADDR_WIDTH-1 downto 0),
--                             cfg_addr_last(ADDR_WIDTH-1 downto 0),
--                             data(DATA_WIDTH-1 downto 0)
--                           );
  signal usr_in_wr_port  : a_ram_arbiter_usr_in_wr_port(0 to NUM_PORTS-1);
--  signal usr_in_wr_port  : a_ram_arbiter_usr_in_wr_port(0 to NUM_PORTS-1)(
--                             addr_next(ADDR_WIDTH-1 downto 0)
--                           );
  signal ram_out_wr_ready  : std_logic := '1';
  signal ram_in_wr_addr    : std_logic_vector(ADDR_WIDTH - 1 downto 0);
  signal ram_in_wr_data    : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal ram_in_wr_ena     : std_logic;
  signal ram_in_wr_first   : std_logic;
  signal ram_in_wr_last    : std_logic;

  signal usr_rst : std_logic_vector(NUM_PORTS-1 downto 0) := (others=>'1');

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
    ADDR_WIDTH => ADDR_WIDTH,
    DATA_WIDTH => DATA_WIDTH,
    ADDR_FIRST => to_unsigned(257,ADDR_WIDTH), 
    ADDR_LAST => to_unsigned(275,ADDR_WIDTH),
    SINGLE_SHOT => '1',
    INSTANCE_IDX => 0
  )
  port map(
    clk             => clk,
    rst             => usr_rst(0),
    vld_pattern     => "1100",
    usr_out_wr_port => usr_out_wr_port(0),
    usr_in_wr_port  => usr_in_wr_port(0)
  );

  usr1 : entity work.usr_emulator
  generic map (
    ADDR_WIDTH => ADDR_WIDTH,
    DATA_WIDTH => DATA_WIDTH,
    ADDR_FIRST => to_unsigned(785,ADDR_WIDTH), 
    ADDR_LAST => to_unsigned(797,ADDR_WIDTH),
    SINGLE_SHOT => '0',
    INSTANCE_IDX => 1
  )
  port map(
    clk             => clk,
    rst             => usr_rst(1),
    vld_pattern     => "0101",
    usr_out_wr_port => usr_out_wr_port(1),
    usr_in_wr_port  => usr_in_wr_port(1)
  );

  -- currently unused usr ports
  usr_out_wr_port(2 to NUM_PORTS-1) <= RESET(usr_out_wr_port(2 to NUM_PORTS-1));

  i_arbiter : entity ramlib.ram_arbiter_write
  generic map(
    NUM_PORTS         => NUM_PORTS,
    DATA_WIDTH        => DATA_WIDTH,
    ADDR_WIDTH        => ADDR_WIDTH,
    OUTPUT_BURST_SIZE => 8
  )
  port map (
    clk              => clk,
    rst              => rst,
    usr_out_wr_port  => usr_out_wr_port,
    usr_in_wr_port   => usr_in_wr_port,
    ram_out_wr_ready => ram_out_wr_ready,
    ram_in_wr_addr   => ram_in_wr_addr,
    ram_in_wr_data   => ram_in_wr_data,
    ram_in_wr_ena    => ram_in_wr_ena,
    ram_in_wr_first  => ram_in_wr_first,
    ram_in_wr_last   => ram_in_wr_last
  );

  p_stimuli: process
  begin
    
    while rst='1' loop
      wait until rising_edge(clk);
    end loop;

    wait for 100 ns;
    wait until rising_edge(clk);
    usr_rst(0) <= '0';
    usr_rst(1) <= '0';
    wait until rising_edge(clk);

    for n in 1 to 97 loop
      wait until rising_edge(clk);
    end loop;
    
    usr_rst(0) <= '1';
    usr_rst(1) <= '1';

    wait for 400 ns;
    finish <= '1';

    wait until rising_edge(clk);
    wait; -- end of process
  end process;

end architecture;

