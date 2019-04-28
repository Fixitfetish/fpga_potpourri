-------------------------------------------------------------------------------
-- FILE    : maxmin_tb.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 23/Oct/2018
-- VERSION : 0.10
-- LICENSE : MIT License
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library baselib;
 use baselib.ieee_extension.all;

entity maxmin_tb is
end entity;

architecture rtl of maxmin_tb is

  constant PERIOD : time := 1 us; -- 1 MHz
  signal rst : std_logic := '1';
  signal clk : std_logic := '1';
  signal finish : std_logic := '0';

  signal intvec : integer_vector(3 to 10);
  signal max, min : integer;
  signal idx_max, idx_min : integer;

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
  rst <= '0' after 2*PERIOD;

  p_stimuli: process
  begin
    while rst='1' loop
      wait until rising_edge(clk);
    end loop;
    
    wait until rising_edge(clk);
    intvec <= (21,33,13,-14,27,15,18,-7); 

    wait until rising_edge(clk);
    intvec <= (23,11,-43,14,27,15,-18,-17); 
    
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    finish <= '1';
    wait until rising_edge(clk);
    wait; -- end of process
  end process;

  max <= MAXIMUM(intvec);
  min <= MINIMUM(intvec);
  idx_max <= INDEX_OF_MAXIMUM(intvec);
  idx_min <= INDEX_OF_MINIMUM(intvec);

end architecture;
