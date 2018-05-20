library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;
library ramlib;

entity bfa_tb is
end entity;

architecture sim of bfa_tb is

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
  signal dout_req : std_logic := '1';
  signal dout : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal dout_en, dout_first, dout_last : std_logic;
  signal dout_vld : std_logic_vector(NUM_PORTS-1 downto 0);
  signal dout_chan : unsigned(log2ceil(NUM_PORTS)-1 downto 0);
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

  
  i_fifo : entity ramlib.burst_forming_arbiter
  generic map(
    NUM_PORTS  => NUM_PORTS, -- for now up to 4 supported
    DATA_WIDTH => DATA_WIDTH,
    BURST_SIZE => 8
  )
  port map (
    clk         => clk,
    rst         => rst,
    din         => din,
    din_frame   => din_frame,
    din_vld     => din_vld,
    din_ovf     => din_ovf,
    dout_req    => dout_req,
    dout        => dout,
    dout_en     => dout_en,
    dout_first  => dout_first,
    dout_last   => dout_last,
    dout_chan   => dout_chan,
    dout_vld    => dout_vld,
    dout_frame  => dout_frame,
    fifo_ovf    => fifo_ovf
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

    for n in 1 to 55 loop
      wait until rising_edge(clk);
    end loop;
    
    rst_usr(0) <= '1';
    rst_usr(1) <= '1';

--    din_frame <= "1111";
--    wait until rising_edge(clk);
--    din_vld <= "1010"; wait until rising_edge(clk);
--    din_vld <= "0100"; wait until rising_edge(clk);
--    din_vld <= "0001"; wait until rising_edge(clk);
--    din_vld <= "0000"; wait until rising_edge(clk);
--    din_vld <= "1111"; wait until rising_edge(clk);
--    din_vld <= "0000"; wait until rising_edge(clk);
--    din_vld <= "0000"; wait until rising_edge(clk);
--    din_vld <= "0000"; wait until rising_edge(clk);
--    din_vld <= "0000"; wait until rising_edge(clk);
--    din_vld <= "0001"; wait until rising_edge(clk);
--    din_vld <= "0100"; wait until rising_edge(clk);
--    din_vld <= "0011"; wait until rising_edge(clk);
--    din_vld <= "0000"; wait until rising_edge(clk);
--    din_vld <= "1110"; wait until rising_edge(clk);
--    din_vld <= "0000"; wait until rising_edge(clk);
--    din_vld <= "0000"; wait until rising_edge(clk);
--    din_vld <= "0000"; wait until rising_edge(clk);
--    din_vld <= "1000"; wait until rising_edge(clk);
--    din_vld <= "1001"; wait until rising_edge(clk);
--    din_vld <= "0000"; wait until rising_edge(clk);
--    din_vld <= "1001"; wait until rising_edge(clk);
--    din_vld <= "0000"; wait until rising_edge(clk);
--    din_vld <= "1001"; wait until rising_edge(clk);
--    din_vld <= "0000"; wait until rising_edge(clk);
--    din_vld <= "0100"; wait until rising_edge(clk);
--    din_vld <= "0100"; wait until rising_edge(clk);
--    din_vld <= "0100"; wait until rising_edge(clk);
--    din_vld <= "0100"; wait until rising_edge(clk);
--    din_vld <= "0100"; wait until rising_edge(clk);
--    din_vld <= "0010"; wait until rising_edge(clk);
--    din_vld <= "0010"; wait until rising_edge(clk);
--    din_vld <= "0010"; wait until rising_edge(clk);
--    din_vld <= "0010"; wait until rising_edge(clk);
--    din_vld <= "0010"; wait until rising_edge(clk);
--    din_vld <= "0100"; wait until rising_edge(clk);
--    din_vld <= "0010"; wait until rising_edge(clk);
--    din_vld <= "0100"; wait until rising_edge(clk);
--    din_vld <= "0010"; wait until rising_edge(clk);
--    din_vld <= "0100"; wait until rising_edge(clk);
--    din_vld <= "0010"; wait until rising_edge(clk);
--    din_vld <= "1001"; wait until rising_edge(clk);
--    din_vld <= "0000"; wait until rising_edge(clk);
--    din_vld <= "0100"; wait until rising_edge(clk);
--    din_vld <= "0010"; wait until rising_edge(clk);
--    din_vld <= "0100"; wait until rising_edge(clk);
--    din_vld <= "0010"; wait until rising_edge(clk);
--    din_vld <= "0100"; wait until rising_edge(clk);
--    din_vld <= "0010"; wait until rising_edge(clk);
--    din_vld <= "0100"; wait until rising_edge(clk);
--    din_vld <= "0010"; wait until rising_edge(clk);
--    din_vld <= "1000"; wait until rising_edge(clk);
--    din_vld <= "1000"; wait until rising_edge(clk);
--    din_vld <= "0100"; wait until rising_edge(clk);
--    din_vld <= "0010"; wait until rising_edge(clk);
--
--    din_frame <= "0011";
--    din_vld <= "0000"; wait until rising_edge(clk);
    wait for 400 ns;
    finish <= '1';

    wait until rising_edge(clk);
    wait; -- end of process
  end process;

end architecture;

