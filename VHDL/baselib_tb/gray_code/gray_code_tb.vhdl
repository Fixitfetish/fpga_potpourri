-------------------------------------------------------------------------------
-- FILE    : gray_code_tb.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 08/May/2016
-- VERSION : 1.0
-- VHDL    : 1993
-- LICENSE : MIT License
-------------------------------------------------------------------------------
-- Copyright (c) 2016 Fixitfetish
-- 
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
-- 
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
-- IN THE SOFTWARE.
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library fixitfetish;
 use fixitfetish.gray_code_pkg.all;

entity gray_code_tb is
end entity;

architecture rtl of gray_code_tb is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';
  signal ena : unsigned(1 downto 0) := (others=>'0');

  constant COUNTER_WIDTH : natural := 4;
  signal bcnt : std_logic_vector(COUNTER_WIDTH-1 downto 0); -- binary counter
  signal gcnt : std_logic_vector(COUNTER_WIDTH-1 downto 0); -- gray counter

begin

  clk <= not clk after 5 ns; -- 100 MHz
  rst <= '0' after 21 ns; -- release reset

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

  i_cnt : entity fixitfetish.gray_count
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
