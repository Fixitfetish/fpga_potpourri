-------------------------------------------------------------------------------
--! @file       gray_code.vhdl
--! @author     Fixitfetish
--! @date       02/May/2016
--! @version    1.0
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;

--! @brief Gray code package with conversion functions
--!
package gray_code_pkg is

  --! create gray code from binary
  function gray_from_binary(binary:std_logic_vector) return std_logic_vector;
  --! convert gray code to binary
  function gray_to_binary(gray:std_logic_vector) return std_logic_vector;

end package;

package body gray_code_pkg is

  --! create gray code from binary
  function gray_from_binary(binary:std_logic_vector) return std_logic_vector is
    constant L : natural := binary'length;
    alias b : std_logic_vector(L-1 downto 0) is binary; -- default range
    variable g : std_logic_vector(L-1 downto 0);
  begin
    g(L-1) := b(L-1);
    g(L-2 downto 0) := b(L-2 downto 0) xor b(L-1 downto 1); 
    return g;
  end function;

  --! convert gray code to binary
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
library baselib;
 use baselib.gray_code_pkg.all;

--! @brief Gray code counter
--!
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
