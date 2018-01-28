-------------------------------------------------------------------------------
-- FILE    : gray_code.vhdl
-- AUTHOR  : Fixitfetish     
-- DATE    : 02/May/2016
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

package gray_code_pkg is

  -- create gray code from binary
  function gray_from_binary(binary:std_logic_vector) return std_logic_vector;
  -- convert gray code to binary
  function gray_to_binary(gray:std_logic_vector) return std_logic_vector;

end package;

package body gray_code_pkg is

  -- create gray code from binary
  function gray_from_binary(binary:std_logic_vector) return std_logic_vector is
    constant L : natural := binary'length;
    alias b : std_logic_vector(L-1 downto 0) is binary; -- default range
    variable g : std_logic_vector(L-1 downto 0);
  begin
    g(L-1) := b(L-1);
    g(L-2 downto 0) := b(L-2 downto 0) xor b(L-1 downto 1); 
    return g;
  end function;

  -- convert gray code to binary
  function gray_to_binary(gray:std_logic_vector) return std_logic_vector is
    constant L : natural := gray'length;
    alias g : std_logic_vector(L-1 downto 0) is gray; -- default range
    variable b : std_logic_vector(L-1 downto 0);
  begin
    b(L-1) := g(L-1);
    for i in L-2 downto 0 loop
      b(i) := b(i+1) xor g(i);
    end loop; 
    return b;
  end function;

end package body;

---------------------------------------------------------------------------------------------------

library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library fixitfetish;
 use fixitfetish.gray_code_pkg.all;

entity gray_count is
port (
  clock  : in  std_logic; -- clock
  reset  : in  std_logic; -- synchronous reset (clear counter) 
  enable : in  std_logic; -- count enable
  count  : out std_logic_vector -- registered gray counter output value 
);
end entity;

architecture rtl of gray_count is

  constant CNT_WIDTH : natural := count'length;
  signal bcnt : unsigned(CNT_WIDTH-1 downto 0); -- binary counter

begin

  process(clock)
  begin
    if rising_edge(clock) then
      if reset='1' then
        count <= (count'range=>'0');
        bcnt <= to_unsigned(1,CNT_WIDTH);
      elsif enable='1' then
        count <= gray_from_binary(std_logic_vector(bcnt));
        bcnt <= bcnt + 1;
      end if;  
    end if;
  end process;  

end architecture;
