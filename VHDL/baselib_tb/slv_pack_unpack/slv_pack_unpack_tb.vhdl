library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;

entity slv_pack_unpack_tb is
end entity;

architecture sim of slv_pack_unpack_tb is

  constant PERIOD : time := 10 ns; -- 100 MHz
  signal rst : std_logic := '1';
  signal clk : std_logic := '1';
  signal finish : std_logic := '0';

  constant WIDTH : positive := 32;
  constant MIN_RATIO_LOG2 : natural := 0;
  constant MAX_RATIO_LOG2 : positive := 4;
  constant MSB_BOUND : boolean := false;
  signal ratio_log2 : unsigned(2 downto 0) := to_unsigned(2,3);

  signal cnt       : unsigned(WIDTH-1 downto 0) := (others=>'0');  

  signal din_frame  : std_logic := '0';
  signal din_ena    : std_logic := '0';
  signal din        : std_logic_vector(WIDTH-1 downto 0);
  signal dpack_frame: std_logic;
  signal dpack_ena  : std_logic;
  signal dpack      : std_logic_vector(WIDTH-1 downto 0);
  signal dout_frame : std_logic;
  signal dout_ena   : std_logic;
  signal dout       : std_logic_vector(WIDTH-1 downto 0);

  signal unpack_ovfl : std_logic;

  signal toggle : std_logic := '1';

begin

  toggle <= toggle when rising_edge(clk);

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

  din <= std_logic_vector(cnt);
  din_ena <= din_frame and toggle;

  i_pack : entity baselib.slv_pack
  generic map(
    DATA_WIDTH        => WIDTH,
    MIN_RATIO_LOG2    => MIN_RATIO_LOG2,
    MAX_RATIO_LOG2    => MAX_RATIO_LOG2,
    MSB_BOUND_OUTPUT  => MSB_BOUND
  )
  port map (
    clk        => clk,
    rst        => rst,
    ratio_log2 => ratio_log2,
    din_frame  => din_frame,
    din_ena    => din_ena,
    din        => din,
    dout_frame => dpack_frame,
    dout_ena   => dpack_ena,
    dout       => dpack
  );

  i_unpack : entity baselib.slv_unpack
  generic map(
    DATA_WIDTH        => WIDTH,
    MIN_RATIO_LOG2    => MIN_RATIO_LOG2,
    MAX_RATIO_LOG2    => MAX_RATIO_LOG2,
    MSB_BOUND_INPUT   => MSB_BOUND
  )
  port map (
    clk        => clk,
    rst        => rst,
    ratio_log2 => ratio_log2,
    din_frame  => dpack_frame,
    din_ena    => dpack_ena,
    din        => dpack,
    din_ovfl   => unpack_ovfl,
    dout_frame => dout_frame,
    dout_ena   => dout_ena,
    dout       => dout
  );

  p_cnt : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' or din_frame='0' then
        cnt <= (others=>'0');
      elsif din_ena='1' then
        cnt <= cnt + 1;
      end if;
    end if;
  end process;


  p_stimuli: process
  begin
    while rst='1' loop
      wait until rising_edge(clk);
    end loop;
    
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    din_frame <= '1'; 
    
    for n in 1 to 51 loop
      wait until rising_edge(clk);
    end loop;

    din_frame <= '0'; 

    for n in 1 to 6 loop
      wait until rising_edge(clk);
    end loop;

    din_frame <= '1';
    ratio_log2 <= to_unsigned(0,3);

    for n in 1 to 21 loop
      wait until rising_edge(clk);
    end loop;

    din_frame <= '0'; 

    for n in 0 to 20 loop
      wait until rising_edge(clk);
    end loop;

    finish <= '1';
    wait until rising_edge(clk);
    wait; -- end of process
  end process;

end architecture;

