library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;
library dsplib;

entity signed_add_accu_tb is
end entity;

architecture sim of signed_add_accu_tb is

  constant PERIOD : time := 10 ns; -- 100 MHz
  signal rst : std_logic := '1';
  signal clk : std_logic := '1';
  signal finish : std_logic := '0';

  constant NUM_ACCU : positive := 4;
  constant GUARD_BITS : natural := 1;
  constant NUM_INPUT_REG_A : positive := 1;
  constant OUTPUT_SHIFT_RIGHT : natural := 1;
  constant OUTPUT_ROUND : boolean := true;

  constant A_WIDTH : positive := 10;
  signal cnt_a : std_logic_vector(A_WIDTH-1 downto 0);
  signal a : signed_vector(0 to NUM_ACCU-1)(A_WIDTH-1 downto 0) := (others=>(others=>'0'));

  constant Z_WIDTH : positive := 10;
  signal cnt_z : std_logic_vector(Z_WIDTH-1 downto 0);
  signal z : signed_vector(0 to NUM_ACCU-1)(Z_WIDTH-1 downto 0) := (others=>(others=>'0'));

  signal clr : std_logic := '0';
  signal vld : std_logic := '0';
  signal clkena : std_logic := '1';
  signal last : std_logic := '0';

  constant R_WIDTH : positive := 24;
  type r_result is
  record
    dat  : signed_vector(0 to NUM_ACCU-1)(R_WIDTH-1 downto 0);
    vld  : std_logic;
    last : std_logic;
    ovf  : std_logic_vector(0 to NUM_ACCU-1);
    pipestages : natural;
  end record;
  signal result : r_result;
  signal result_us : r_result;

  -- debug
  signal r0, r1, r2, r3 : signed(R_WIDTH-1 downto 0) := (others=>'0');

begin

  -- debug
  r0 <= result.dat(0)(23 downto 0);
  r1 <= result.dat(1)(23 downto 0);
  r2 <= result.dat(2)(23 downto 0);
  r3 <= result.dat(3)(23 downto 0);

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
--  clkena <= not clkena when rising_edge(clk);
  clkena <= vld;
  
  -- A input
  i_cnt_a : entity baselib.counter
  generic map(
    COUNTER_WIDTH => A_WIDTH
  )
  port map (
    clk        => clk,
    rst        => rst,
    load_init  => std_logic_vector(to_signed(4,A_WIDTH)),
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

  a(0) <=  signed(cnt_a);
  a(1) <=  signed(cnt_a);
  a(2) <= -signed(cnt_a);
  a(3) <= -signed(cnt_a);
  z(0) <=  signed(cnt_z);
  z(1) <= -signed(cnt_z);
  z(2) <=  signed(cnt_z);
  z(3) <= -signed(cnt_z);

  i_dut : entity dsplib.signed_add_accu(behave)
  generic map(
    NUM_ACCU           => NUM_ACCU,
    GUARD_BITS         => GUARD_BITS,
    NUM_INPUT_REG_A    => NUM_INPUT_REG_A,
    NUM_INPUT_REG_Z    => 1,
    NUM_OUTPUT_REG     => 1,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => OUTPUT_ROUND,
    OUTPUT_CLIP        => false,
    OUTPUT_OVERFLOW    => false,
    NUM_AUXILIARY_BITS => open
  )
  port map (
    clk         => clk,
    rst         => rst,
    clkena      => clkena,
    clr         => clr,
    vld         => vld,
    aux(0)      => last,
    a           => a,
    z           => z,
    result      => result.dat,
    result_vld  => result.vld,
    result_ovf  => result.ovf,
    result_aux(0) => result.last,
    PIPESTAGES  => result.pipestages
  );

--  i_dut_us : entity dsplib.signed_add_accu(ultrascale)
--  generic map(
--    NUM_ACCU           => NUM_ACCU,
--    GUARD_BITS         => GUARD_BITS,
--    NUM_INPUT_REG_A    => NUM_INPUT_REG_A,
--    NUM_INPUT_REG_Z    => 1,
--    NUM_OUTPUT_REG     => 1,
--    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
--    OUTPUT_ROUND       => OUTPUT_ROUND,
--    OUTPUT_CLIP        => false,
--    OUTPUT_OVERFLOW    => false,
--    NUM_AUXILIARY_BITS => open
--  )
--  port map (
--    clk         => clk,
--    rst         => rst,
--    clkena      => clkena,
--    clr         => clr,
--    vld         => vld,
--    aux(0)      => last,
--    a           => a,
--    z           => z,
--    result      => result_us.dat,
--    result_vld  => result_us.vld,
--    result_ovf  => result_us.ovf,
--    result_aux(0) => result_us.last,
--    PIPESTAGES  => result_us.pipestages
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
       if (n=9) then last<='1'; end if; 
       if (n=0 or n=10) then clr<='1'; end if; 
       wait until rising_edge(clk);
       vld <= '0';
       clr <= '0';
       last <= '0';
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

