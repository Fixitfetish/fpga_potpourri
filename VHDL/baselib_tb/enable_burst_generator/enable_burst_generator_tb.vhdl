library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;

entity enable_burst_generator_tb is
end entity;

architecture sim of enable_burst_generator_tb is

  constant PERIOD : time := 10 ns; -- 100MHz
  signal rst : std_logic := '1';
  signal clk : std_logic := '1';
  signal clkena : std_logic := '1';
  signal finish : std_logic := '0';

  constant ACCURACY : positive := 16;
  signal numerator : unsigned(ACCURACY-1 downto 0);
  signal denominator : unsigned(ACCURACY-1 downto 0);
  signal burst_length, equidistant_count, dutycycle_count : unsigned(23 downto 0);
  signal dutycycle_enable, dutycycle_active : std_logic;
  signal equidistant_enable, equidistant_active : std_logic;

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
  numerator <= to_unsigned(2,ACCURACY);
  denominator <= to_unsigned(7,denominator'length);
  burst_length <= to_unsigned(18,burst_length'length);

  finish <= '1' after 1000*PERIOD;


  i_dutycycle : entity baselib.enable_burst_generator(rtl)
  port map (
    reset        => rst,
    clock        => clk,
    clock_enable => clkena,
    equidistant  => open,
    numerator    => numerator,
    denominator  => denominator,
    burst_length => burst_length,
    enable_out   => dutycycle_enable,
    burst_count  => dutycycle_count,
    active       => dutycycle_active
  );

  i_equidistant : entity baselib.enable_burst_generator(rtl)
  port map (
    reset        => rst,
    clock        => clk,
    clock_enable => clkena,
    equidistant  => '1',
    numerator    => numerator,
    denominator  => denominator,
    burst_length => burst_length,
    enable_out   => equidistant_enable,
    burst_count  => equidistant_count,
    active       => equidistant_active
  );

end architecture;

