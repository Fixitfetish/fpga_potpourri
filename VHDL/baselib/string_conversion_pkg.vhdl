-------------------------------------------------------------------------------
--! @file       string_conversion_pkg.vhdl
--! @author     Fixitfetish
--! @date       03/Jun/2016
--! @version    0.70
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

--! @brief This package includes string related conversion functions and procedures as
--! they are useful for
--!   * testbenches and simulations
--!   * conversion of constants and generics
--!   * numbers with more than 32 bits precision
--!
--! Typically two similar implementations, i.e. function and procedure, are 
--! available to have more flexibility in applying the conversion. The functions
--! and procedures are not meant to be used in code that will be synthesized. 
--! Please consider standard functions like to_unsigned(), to_signed(), 
--! to_integer(), std_logic_vector(), unsigned() and signed() in addition to the
--! functions below.

package string_conversion_pkg is

 -- Conversion of a decimal string to standard types.
 -- The decimal string allows the characters 0-9 with one preceding sign
 -- character ('+' or '-'). Decimal strings without sign are interpreted as
 -- positive numbers. A white space ' ' will be interpreted as end of the
 -- decimal string. Currently, the minimum output width is 4 bits.  
 procedure decstr_to_slv(s:in string; l:out std_logic_vector);
 procedure decstr_to_unsigned(s:in string; l:out unsigned);
 procedure decstr_to_signed(s:in string; l:out signed);
 procedure decstr_to_integer(s:in string; l:out integer);
 function decstr_to_slv(s:string; w:integer range 4 to integer'high) return std_logic_vector;
 function decstr_to_unsigned(s:string; w:integer range 4 to integer'high) return unsigned;
 function decstr_to_signed(s:string; w:integer range 4 to integer'high) return signed;
 function decstr_to_integer(s:string) return integer;
  
 -- Conversion of a hexadecimal string to standard types. 
 -- The hexadecimal string allows the following characters:  0-9, a-f, A-F.
 -- A white space ' ' will be interpreted as end of the hexadecimal string.
 -- The conversion will ignore a preceding "x", "X", "0x" or "0X".
 -- Currently, the minimum output width is 4 bits (i.e. one nibble).  
 procedure hexstr_to_slv(s:in string; l:out std_logic_vector);
 procedure hexstr_to_unsigned(s:in string; l:out unsigned);
 procedure hexstr_to_signed(s:in string; l:out signed);
 function hexstr_to_slv(s:string; w:integer range 4 to integer'high) return std_logic_vector;
 function hexstr_to_unsigned(s:string; w:integer range 4 to integer'high) return unsigned;
 function hexstr_to_signed(s:string; w:integer range 4 to integer'high) return signed;

 -- Conversion of standard types to a hexadecimal string. 
 -- The hexadecimal string uses the following characters:  0-9, A-F
 -- Note that the standard logic vector is interpreted as unsigned vector.
 -- For integers the default number of output characters N is 8 (=32 bit number).
 procedure hexstr_from_slv(l: in std_logic_vector; s: out string);
 procedure hexstr_from_unsigned(l: in unsigned; s: out string);
 procedure hexstr_from_signed(l: in signed; s: out string);
 procedure hexstr_from_integer(l: in integer; s: out string; N:in positive:=8);
 function hexstr_from_slv(l:std_logic_vector) return string;
 function hexstr_from_unsigned(l:unsigned) return string;
 function hexstr_from_signed(l:signed) return string;
 function hexstr_from_integer(l:integer; N:positive:=8) return string;

 function hexstr_validate(s:string; err:string:="nan") return string;

end package;

-------------------------------------------------------------------------------

package body string_conversion_pkg is

 -- local auxiliary functions

 -- integer minimum of x and y
 function IMIN(x,y:integer) return integer is
 begin
   if y<x then return y;
   else        return x; end if;
 end function;

 -- integer maximum of x and y
 function IMAX(x,y:integer) return integer is
 begin
   if y>x then return y;
   else        return x; end if;
 end function;

 -- integer x^y
 function IPOW(x,y:integer) return integer is
   variable r : integer;
 begin
   if y=0 then
     r := 1;
   elsif y<0 then
     r := 0;
   else
     r := x;
     for i in 2 to y loop r:=r*x; end loop;
   end if;
   return r; 
 end function;
 
 ----------------------------------------------------------
 -- Conversion of a decimal string to standard logic types.
 ----------------------------------------------------------
 procedure decstr_to_slv(s:in string; l:out std_logic_vector) is
   constant w : integer range 4 to integer'high := l'length;
   variable sign : std_logic; 
   variable first_digit : positive; 
   variable ndigit : natural; 
   variable digit : signed(4 downto 0); 
   variable result : signed(w+3 downto 0); -- 4 sign extension bits for overflow detection
 begin
   -- by default positive value
   first_digit := 1;
   sign := '0';
   -- detection of optional sign character
   if (s(1)='+') then
     first_digit := 2;
   elsif (s(1)='-') then
     first_digit := 2;
     sign := '1';
   end if;
   -- for loop over all characters/digits (except for the sign!)
   result := (others=>'0'); -- initialize to 0
   ndigit := 0;
   for n in first_digit to s'length loop
     case s(n) is
       when '0' => digit:=to_signed(0,digit'length);
       when '1' => digit:=to_signed(1,digit'length);
       when '2' => digit:=to_signed(2,digit'length);
       when '3' => digit:=to_signed(3,digit'length);
       when '4' => digit:=to_signed(4,digit'length);
       when '5' => digit:=to_signed(5,digit'length);
       when '6' => digit:=to_signed(6,digit'length);
       when '7' => digit:=to_signed(7,digit'length);
       when '8' => digit:=to_signed(8,digit'length);
       when '9' => digit:=to_signed(9,digit'length);
       when ' ' => exit; -- end of number
       when others => assert false
         report "ERROR: decstr_to_slv(), decimal input string '" & s & "' contains unexpected character."
         severity error;
         ndigit := 0; exit;
     end case;
     if sign='1' then
       result := RESIZE(10*result,w+4) - digit;
     else
       result := RESIZE(10*result,w+4) + digit;
     end if;
     -- overflow detection
     if result(w+3 downto w-1)/="00000" and result(w+3 downto w-1)/="11111" then
       assert false
         report "ERROR: decstr_to_slv(), decimal input '" & s & "' exceeds range. Please increase output width."
         severity error;
       ndigit := 0; exit;
     else
       ndigit := ndigit + 1;
     end if;
   end loop;
   if ndigit=0 then result:=(others=>'X'); end if;
   l := std_logic_vector(result(w-1 downto 0));
 end procedure;

 function decstr_to_slv(s:string; w:integer range 4 to integer'high) return std_logic_vector is
   variable l : std_logic_vector(w-1 downto 0); 
 begin
   decstr_to_slv(s=>s, l=>l);
   return l;
 end function; 

 -- decimal string to unsigned (numeric_std)
 procedure decstr_to_unsigned(s:in string; l:out unsigned) is
   constant w : integer range 4 to integer'high := l'length;
   variable result : std_logic_vector(w downto 0); 
 begin
   if s(1)='-' then
     l := (w-1 downto 0 =>'X');
     assert false
       report "ERROR: decstr_to_unsigned(), negative decimal input '" & s & "' not allowed."
       severity error;
   else
     decstr_to_slv(s=>s, l=>result);
     if result(0)='X' then
       l := (w-1 downto 0 =>'X');
       assert false
         report "ERROR: decstr_to_unsigned(), invalid output value"
         severity error;
     else    
       l := RESIZE(unsigned(result),w);
     end if;
   end if;
 end procedure;

 function decstr_to_unsigned(s:string; w:integer range 4 to integer'high) return unsigned is
   variable result : unsigned(w-1 downto 0); 
 begin
   decstr_to_unsigned(s=>s, l=>result);
   return result;
 end function;

 -- decimal string to signed (numeric_std)
 procedure decstr_to_signed(s:in string; l:out signed) is
   constant w : integer range 4 to integer'high := l'length;
   variable result : std_logic_vector(w-1 downto 0); 
 begin
   decstr_to_slv(s=>s, l=>result);
   if result(0)='X' then
     l := (w-1 downto 0 =>'X');
     assert false
       report "ERROR: decstr_to_signed(), invalid output value"
       severity error;
   else    
     l := signed(result);
   end if;
 end procedure;
 
 function decstr_to_signed(s:string; w:integer range 4 to integer'high) return signed is
   variable result : signed(w-1 downto 0); 
 begin
   decstr_to_signed(s=>s, l=>result);
   return result;
 end function;

 -- decimal string to integer
 procedure decstr_to_integer(s:in string; l:out integer) is
   variable result : signed(31 downto 0); 
 begin
   decstr_to_signed(s=>s, l=>result);
   l := to_integer(result);
 end procedure;

 function decstr_to_integer(s:string) return integer is
   variable result : integer; 
 begin
   decstr_to_integer(s=>s, l=>result);
   return result;
 end function;

 
 --------------------------------------------------------------
 -- Conversion of a hexadecimal string to standard logic types.
 --------------------------------------------------------------
 procedure hexstr_to_slv(s:in string; l:out std_logic_vector) is
   constant w : integer range 4 to integer'high := l'length;
   variable n_nibble : natural;
   variable first_nibble : positive; 
   variable nibble : std_logic_vector(3 downto 0); 
   variable result : std_logic_vector(w+3 downto 0); 
 begin
   -- default without any hex prefix
   first_nibble := 1; 
   if s'length>1 and (s(1)='x' or s(1)='X') then
     first_nibble := 2; -- ignore hex prefix 'x' or 'X'
   elsif s'length>2 then
     if (s(1 to 2)="0x" or s(1 to 2)="0X") then
       first_nibble := 3; -- ignore hex prefix '0x' or '0X'
     end if;
   end if;
   -- for loop over all characters/nibbles (except for the prefix!)
   n_nibble := 0;
   result := (others=>'0');
   for n in first_nibble to s'length loop
     case s(n) is
       when '0'     => nibble:=x"0";
       when '1'     => nibble:=x"1";
       when '2'     => nibble:=x"2";
       when '3'     => nibble:=x"3";
       when '4'     => nibble:=x"4";
       when '5'     => nibble:=x"5";
       when '6'     => nibble:=x"6";
       when '7'     => nibble:=x"7";
       when '8'     => nibble:=x"8";
       when '9'     => nibble:=x"9";
       when 'a'|'A' => nibble:=x"A";
       when 'b'|'B' => nibble:=x"B";
       when 'c'|'C' => nibble:=x"C";
       when 'd'|'D' => nibble:=x"D";
       when 'e'|'E' => nibble:=x"E";
       when 'f'|'F' => nibble:=x"F";
       when ' '     => exit; -- end of number
       when others  => assert false
         report "ERROR: hexstr_to_slv(), input string '" & s & "' contains unexpected character."
         severity error;
         n_nibble := 0; exit;
     end case;
     result(w+3 downto 4) := result(w-1 downto 0);
     result(3 downto 0) := nibble;
     if result(w+3 downto w)/=x"0" then
       assert false
         report "ERROR: hexstr_to_slv(), hexadecimal input '" & s & "' exceeds range. Please increase output width."
         severity error;
       n_nibble := 0; exit;
     else
       n_nibble := n_nibble + 1;
     end if;
   end loop;
   if n_nibble=0 then result:=(others=>'X'); end if;
   l := result(w-1 downto 0);
 end procedure; 

 function hexstr_to_slv(s:string; w:integer range 4 to integer'high) return std_logic_vector is
   variable l : std_logic_vector(w-1 downto 0); 
 begin
   hexstr_to_slv(s=>s, l=>l);
   return l;
 end function; 

 -- hexadecimal string to unsigned (numeric_std)
 procedure hexstr_to_unsigned(s:in string; l:out unsigned) is
   constant w : integer range 4 to integer'high := l'length;
   variable result : std_logic_vector(w-1 downto 0);
 begin
   hexstr_to_slv(s=>s, l=>result);
   if result(0)='X' then
     l := (w-1 downto 0 =>'X');
     assert false
       report "ERROR: hexstr_to_unsigned(), invalid output value"
       severity error;
   else    
     l := unsigned(result);
   end if;
 end procedure;
 
 function hexstr_to_unsigned(s:string; w:integer range 4 to integer'high) return unsigned is
   variable l : unsigned(w-1 downto 0); 
 begin
   hexstr_to_unsigned(s=>s, l=>l);
   return l;
 end function; 

 -- hexadecimal string to signed (numeric_std)
 procedure hexstr_to_signed(s:in string; l:out signed) is
   constant w : integer range 4 to integer'high := l'length;
   variable result : std_logic_vector(w-1 downto 0); 
 begin
   hexstr_to_slv(s=>s, l=>result);
   if result(0)='X' then
     l := (w-1 downto 0 =>'X');
     assert false
       report "ERROR: hexstr_to_signed(), invalid output value"
       severity error;
   else    
     l := signed(result);
   end if;
 end procedure;
 
 function hexstr_to_signed(s:string; w:integer range 4 to integer'high) return signed is
   variable l : signed(w-1 downto 0); 
 begin
   hexstr_to_signed(s=>s, l=>l);
   return l;
 end function; 


 --------------------------------------------------------------
 -- Conversion of standard logic types to a hexadecimal string 
 --------------------------------------------------------------

 procedure hexstr_from_slv(l:in std_logic_vector; s:out string) is
   constant N : natural := (l'length-1)/4+1; -- number of nibbles
   variable slv : std_logic_vector(4*N-1 downto 0); 
   variable nibble : std_logic_vector(3 downto 0); 
   variable result : string(1 to N); 
 begin
   slv := (others=>'0'); -- default (set additional MSBs to zero)
   slv(l'length-1 downto 0) := l;
   for i in 1 to N loop
     nibble := slv(4*(N-i)+3 downto 4*(N-i));
     case nibble is
       when x"0" => result(i) := '0';
       when x"1" => result(i) := '1';
       when x"2" => result(i) := '2';
       when x"3" => result(i) := '3';
       when x"4" => result(i) := '4';
       when x"5" => result(i) := '5';
       when x"6" => result(i) := '6';
       when x"7" => result(i) := '7';
       when x"8" => result(i) := '8';
       when x"9" => result(i) := '9';
       when x"A" => result(i) := 'A';
       when x"B" => result(i) := 'B';
       when x"C" => result(i) := 'C';
       when x"D" => result(i) := 'D';
       when x"E" => result(i) := 'E';
       when x"F" => result(i) := 'F';
       when others  => assert false
         report "ERROR: hexstr_from_slv(), input contains unexpected value."
         severity error;
         result := (others=>'X'); exit;
     end case; 
   end loop; 
   s := result;
 end procedure;

 function hexstr_validate(s:string; err:string:="nan") return string is
 begin
   if err'length>0 then
     -- only replace invalid values when error string has been provided
     for i in s'range loop
       case s(i) is
         when '0'|'1'|'2'|'3'|'4'|'5'|'6'|'7'|'8'|'9'|
              'A'|'B'|'C'|'D'|'E'|'F'|'a'|'b'|'c'|'d'|'e'|'f' => -- do nothing
         when others => return err;
       end case;
     end loop;
   end if;
   return s;
 end function; 


 -- The standard logic vector is interpreted as unsigned vector.
 function hexstr_from_slv(l:std_logic_vector) return string is
   constant N : natural := (l'length-1)/4+1; -- number of nibbles
   variable result : string(1 to N); 
 begin
   hexstr_from_slv(l,result);
   return result;
 end function; 

 procedure hexstr_from_unsigned(l:in unsigned; s:out string) is
   constant N : natural := (l'length-1)/4+1; -- number of nibbles
   variable result : string(1 to N); 
 begin
   hexstr_from_slv(std_logic_vector(l),result);
   s := result;
 end procedure;

 function hexstr_from_unsigned(l:unsigned) return string is
   constant N : natural := (l'length-1)/4+1; -- number of nibbles
   variable result : string(1 to N); 
 begin
   hexstr_from_unsigned(l,result);
   return result;
 end function; 

 procedure hexstr_from_signed(l:in signed; s:out string) is
   constant N : natural := (l'length-1)/4+1; -- number of nibbles
   variable slv : std_logic_vector(4*N-1 downto 0); 
   variable result : string(1 to N); 
 begin
   slv(l'length-1 downto 0) := std_logic_vector(l);
   -- sign extension
   for i in (4*N-1) downto l'length loop 
     slv(i) := slv(l'length-1);
   end loop;
   hexstr_from_slv(slv,result);
   s := result;
 end procedure;

 function hexstr_from_signed(l:signed) return string is
   constant N : natural := (l'length-1)/4+1; -- number of nibbles
   variable result : string(1 to N); 
 begin
   hexstr_from_signed(l,result);
   return result;
 end function; 

-- procedure hexstr_from_integer(l: in integer; s: out string; N:in positive:=8) is
--   constant PLIM : integer :=  IPOW(2,(4*IMIN(N,8)-1))-1; -- positive integer limit
--   constant NLIM : integer := -IPOW(2,(4*IMIN(N,8)-1));   -- negative integer limit
--   variable t : signed(31 downto 0);
--   variable result : string(1 to N); 
-- begin
--   t := to_signed(l,32);
--   if t>PLIM or t<NLIM then
--     result := (others=>'X');
--     assert false
--       report "ERROR: hexstr_from_integer(), input exceeds given output range."
--       severity error;
--   else
--     hexstr_from_signed(RESIZE(t,4*N),result);
--   end if;
--   s := result;
-- end procedure;

 procedure hexstr_from_integer(l: in integer; s: out string; N:in positive:=8) is
   constant E : integer := 4*(8-IMIN(N,8)); -- expected integer sign extension bits
   variable t : signed(31 downto 0);
   variable result : string(1 to N); 
 begin
   t := to_signed(l,32);
   -- integer range check
   if t(31 downto 31-E)=(31 downto 31-E=>'0') or 
      t(31 downto 31-E)=(31 downto 31-E=>'1') then 
     hexstr_from_signed(RESIZE(t,4*N),result);
   else
     result := (others=>'X');
     assert false
       report "ERROR: hexstr_from_integer(), input exceeds given output range."
       severity error;
   end if;
   s := result;
 end procedure;

 function hexstr_from_integer(l:integer; N:positive:=8) return string is
   variable result : string(1 to N); 
 begin
   hexstr_from_integer(l,result,N);
   return result;
 end function; 

end package body;
