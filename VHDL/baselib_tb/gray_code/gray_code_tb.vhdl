-------------------------------------------------------------------------------
-- FILE    : gray_code_tb.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 08/May/2016
-- VERSION : 1.0
-- VHDL    : 1993
-- LICENSE : MIT License
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library baselib;
 use baselib.gray_code_pkg.all;

entity gray_code_tb is
end entity;

architecture rtl of gray_code_tb is

  constant PERIOD : time := 10 ns; -- 100 MHz
  signal rst : std_logic := '1';
  signal clk : std_logic := '1';
  signal finish : std_logic := '0';
  signal ena : unsigned(1 downto 0) := (others=>'0');

  constant COUNTER_WIDTH : natural := 4;
  signal bcnt : std_logic_vector(COUNTER_WIDTH-1 downto 0); -- binary counter
  signal gcnt : std_logic_vector(COUNTER_WIDTH-1 downto 0); -- gray counter

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
  rst <= '0' after 21 ns;

  finish <= '1' after 500 ns;

  p : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        ena <= (ena'range=>'0');
      else
        ena <= ena + 1;
      end if;  
    end if;
  end process;  

  i_cnt : entity baselib.gray_count
  port map (
    clock  => clk, -- clock
    reset  => rst, -- synchronous reset (clear counter) 
    enable => ena(1), -- count enable (two cycles ON, two cycles OFF)
    count  => gcnt  -- registered gray counter output value 
  );

  -- binary count for comparison (and also test of function)
  bcnt <= gray_to_binary(gcnt);

--  process
--  begin
--    wait for 500 ns;
--  end process; 

end architecture;
