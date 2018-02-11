library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
library dsplib;

entity signed_add2_accu_tb is
end entity;

architecture sim of signed_add2_accu_tb is

  constant PERIOD : time := 10 ns; -- 100 MHz
  signal rst : std_logic := '1';
  signal clk : std_logic := '1';
  signal finish : std_logic := '0';
  
  constant A_WIDTH : positive := 16;
  signal cnt_a : std_logic_vector(A_WIDTH-1 downto 0);
  signal a : signed(A_WIDTH-1 downto 0);

  constant Z_WIDTH : positive := 8;
  signal cnt_z : std_logic_vector(Z_WIDTH-1 downto 0);
  signal z : signed(Z_WIDTH-1 downto 0);

  signal clr : std_logic := '0';
  signal vld : std_logic := '0';

  constant R_WIDTH : positive := 32;
  type r_result is
  record
    dat : signed(R_WIDTH-1 downto 0);
    vld : std_logic;
    ovf : std_logic;
    pipestages : natural;
  end record;
  signal result : r_result;
  signal result_us : r_result;

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
  rst <= '0' after 4*PERIOD;

  -- A input
  i_cnt_a : entity baselib.counter
  generic map(
    COUNTER_WIDTH => A_WIDTH
  )
  port map (
    clk        => clk,
    rst        => rst,
    load_init  => std_logic_vector(to_signed(3,A_WIDTH)),
    load_min   => std_logic_vector(to_signed(-128,A_WIDTH)),
    load_max   => std_logic_vector(to_signed(+127,A_WIDTH)), 
    incr       => vld,
    decr       => '0',
    count      => cnt_a,
    count_min  => open,
    count_max  => open
  );

  -- Z input
  i_cnt_z : entity baselib.counter
  generic map(
    COUNTER_WIDTH => Z_WIDTH
  )
  port map (
    clk        => clk,
    rst        => rst,
    load_init  => std_logic_vector(to_signed(7,Z_WIDTH)),
    load_min   => std_logic_vector(to_signed(-128,Z_WIDTH)),
    load_max   => std_logic_vector(to_signed(+127,Z_WIDTH)), 
    incr       => '0',
    decr       => '1',
    count      => cnt_z,
    count_min  => open,
    count_max  => open
  );

  a <= signed(cnt_a);
  z <= signed(cnt_z);

  i_dut : entity dsplib.signed_add2_accu(behave)
  generic map(
    NUM_SUMMAND        => 64,
    USE_CHAIN_INPUT    => false,
    NUM_INPUT_REG_A    => 1,
    NUM_INPUT_REG_Z    => 1,
    NUM_OUTPUT_REG     => 1,
    OUTPUT_SHIFT_RIGHT => 0,
    OUTPUT_ROUND       => false,
    OUTPUT_CLIP        => false,
    OUTPUT_OVERFLOW    => false
  )
  port map (
    clk        => clk,
    rst        => rst,
    clr        => clr,
    vld        => vld,
    a          => a,
    z          => z,
    result     => result.dat,
    result_vld => result.vld,
    result_ovf => result.ovf,
    chainin    => open,
    chainout   => open,
    PIPESTAGES => result.pipestages
  );

--  i_dut_us : entity dsplib.signed_add2_accu(ultrascale)
--  generic map(
--    NUM_SUMMAND        => 64,
--    USE_CHAIN_INPUT    => false,
--    NUM_INPUT_REG_A    => 1,
--    NUM_INPUT_REG_Z    => 1,
--    NUM_OUTPUT_REG     => 1,
--    OUTPUT_SHIFT_RIGHT => 0,
--    OUTPUT_ROUND       => false,
--    OUTPUT_CLIP        => false,
--    OUTPUT_OVERFLOW    => false
--  )
--  port map (
--    clk        => clk,
--    rst        => rst,
--    clr        => clr,
--    vld        => vld,
--    a          => a,
--    z          => z,
--    result     => result_us.dat,
--    result_vld => result_us.vld,
--    result_ovf => result_us.ovf,
--    chainin    => open,
--    chainout   => open,
--    PIPESTAGES => result_us.pipestages
--  );

  p_stimuli: process
  begin
    while rst='1' loop
      wait until rising_edge(clk);
    end loop;
    
    -- time forward
    for n in 0 to 50 loop
       wait until rising_edge(clk);
       vld <= '1';
       if (n=0 or n=10) then clr<='1'; end if; 
       wait until rising_edge(clk);
       vld <= '0';
       clr <= '0';
       wait until rising_edge(clk);
       wait until rising_edge(clk);
       wait until rising_edge(clk);
    end loop;
    
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    finish <= '1';
    wait until rising_edge(clk);
    wait; -- end of process
  end process;

end architecture;

