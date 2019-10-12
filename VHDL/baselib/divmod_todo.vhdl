-------------------------------------------------------------------------------
--! @file       divmod_todo.vhdl
--! @author     Fixitfetish
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

--! @brief This is a package with a collection of some ideas for efficient DIV and MOD ... under development
package divmod_todo is

 -- Division by 3 with unsigned dividend y of max length 28-bit
  -- remainder r = mod(y,3)
  -- quotient  d = mod(floor(y/3),4) 
  constant DIV3_WIDTH : natural := 2;
  constant REM3_WIDTH : natural := 2;
  type divmod3_result is
    record
      d : unsigned(DIV3_WIDTH-1 downto 0); -- division result
      r : unsigned(REM3_WIDTH-1 downto 0); -- remainder
    end record;

  function divmod3(y: unsigned) return divmod3_result;
  -- unsigned division by 3 giving the quotient and remainder

  -- TODO : see also internal procedure DIVMOD in numeric_std-body.vhd
  -- * Are versions with fix denominator more efficient in terms of logic usage?
  -- * just primes 3, 5, 7, 11, etc. enough ?
  procedure divmod5(
    xnum  : in  unsigned; -- numerator
    xquot : out unsigned; -- quotient
    xrem  : out unsigned  -- remainder
  );

end package;

package body divmod_todo is

  -- Division by 3 with unsigned dividend y of max length 28-bit
  -- remainder r = mod(y,3)
  -- quotient  d = mod(floor(y/3),4) 
  function divmod3(y: unsigned) return divmod3_result is
    constant NUMNIBBLE : integer := (y'length + 3) / 4; -- ceil(y/4)
    variable nibble    : unsigned(3 downto 0);
    variable modsum    : unsigned(3 downto 0);
    variable numerator : unsigned(NUMNIBBLE*4-1 downto 0);
    variable temp      : unsigned(1 downto 0);
    variable carry     : unsigned(1 downto 0);
    variable result    : divmod3_result;
  begin
    assert NUMNIBBLE <= 7
      report "Input of divmod3 must be unsigned of max length 28 bit"
      severity ERROR;
    numerator := RESIZE(y,NUMNIBBLE*4);
    modsum    := (others=>'0');
    for i in 0 to (NUMNIBBLE-1) loop
      -- mod3 of each nibble separately
      nibble := numerator((i+1)*4-1 downto i*4);
      case nibble is
        when "0001" =>  temp := "01"; --  1 mod 3 = 1
        when "0100" =>  temp := "01"; --  4 mod 3 = 1
        when "0111" =>  temp := "01"; --  7 mod 3 = 1
        when "1010" =>  temp := "01"; -- 10 mod 3 = 1
        when "1101" =>  temp := "01"; -- 13 mod 3 = 1
        when "0010" =>  temp := "10"; --  2 mod 3 = 2
        when "0101" =>  temp := "10"; --  5 mod 3 = 2
        when "1000" =>  temp := "10"; --  8 mod 3 = 2
        when "1011" =>  temp := "10"; -- 11 mod 3 = 2
        when "1110" =>  temp := "10"; -- 14 mod 3 = 2
        when others =>  temp := "00";
      end case;
      -- accumulate results of each nibble
      modsum := modsum + RESIZE(temp,4);
    end loop;
    -- mod3 mod previously accumulated result is the remainder
    case modsum is
      when "0001" =>  result.r := "01";
      when "0100" =>  result.r := "01";
      when "0111" =>  result.r := "01";
      when "1010" =>  result.r := "01";
      when "1101" =>  result.r := "01";
      when "0010" =>  result.r := "10";
      when "0101" =>  result.r := "10";
      when "1000" =>  result.r := "10";
      when "1011" =>  result.r := "10";
      when "1110" =>  result.r := "10";
      when others =>  result.r := "00";
    end case;
    --
    --   If the remainder of the "division by 3" is known the following applies:
    --
    --     .. D3 D2 D1 D0  0   (2*D)
    --   + .. D4 D3 D2 D1 D0   (1*D)
    --   + ..  0  0  0 R1 R0   (R=remainder)
    --   + .. C3 C2 C1 C0  0   (C=carry)
    --   ------------------------------------
    --   = .. Y4 Y3 Y2 Y1 Y0   (Y = 3*D + R)
    --
    --   For mod(D,4) only the two LSBs of D are of interest.  
    --
    --   D0 = Y0 xor R0
    --   C0 = D0 and R0
    --   D1 = D0 xor C0 xor Y1 xor R1
    --
    result.d(0) := y(0) xor result.r(0);
    carry(0)    := result.d(0) and result.r(0);
    result.d(1) := result.d(0) xor carry(0) xor y(1) xor result.r(1);
    return result;

  end function;

  -- * choose NIBBLE step size N in way that mod(N^2,prime) = 1
  --   => mod(16,3) = 1
  --   => mod(16,5) = 1
  --   => mod( 8,7) = 1

  -- can this be done is a recursive way ?
  procedure divmod5(
    xnum  : in  unsigned; -- numerator
    xquot : out unsigned; -- quotient
    xrem  : out unsigned  -- remainder
  ) is
    constant NUMNIBBLE : integer := (xnum'length + 3) / 4; -- ceil(xnum/4)
    variable nibble    : unsigned(3 downto 0);
    variable modsum    : unsigned(3 downto 0);
    variable numerator : unsigned(NUMNIBBLE*4-1 downto 0);
    variable temp      : unsigned(2 downto 0);
    variable carry     : unsigned(2 downto 0);
  begin
    assert NUMNIBBLE <= 7
      report "Input of divmod5 must be unsigned of max length 28 bit"
      severity ERROR;
    numerator := RESIZE(y,NUMNIBBLE*4);
    modsum    := (others=>'0');
    for i in 0 to (NUMNIBBLE-1) loop
      -- mod5 of each nibble separately
      nibble := numerator((i+1)*4-1 downto i*4);
      case nibble is
        when 1|6|11 =>  temp := "001";
        when 2|7|12 =>  temp := "010";
        when 3|8|13 =>  temp := "011";
        when 4|9|14 =>  temp := "100";
        when others =>  temp := "000";
      end case;
      -- accumulate results of each nibble
      modsum := modsum + RESIZE(temp,4);
    end loop;
    -- mod5 mod previously accumulated result is the remainder
    case modsum is
      when 1|6|11 =>  xrem := "001";
      when 2|7|12 =>  xrem := "010";
      when 3|8|13 =>  xrem := "011";
      when 4|9|14 =>  xrem := "100";
      when others =>  xrem := "000";
    end case;

    --   If the remainder of the "division by 5" is known the following applies:
    --
    --     .. D2 D1 D0  0  0   (4*D)
    --   + .. D4 D3 D2 D1 D0   (1*D)
    --   + ..  0  0 R2 R1 R0   (R=remainder)
    --   + .. C3 C2 C1 C0  0   (C=carry)
    --   ------------------------------------
    --   = .. Y4 Y3 Y2 Y1 Y0   (Y = 5*D + R)
    --
  end procedure;

end package body;
