-------------------------------------------------------------------------------
-- FILE    : ieee_extension.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 31/Oct/2016
-- VERSION : 0.4
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

package ieee_extension is

 type boolean_vector is array(natural range<>) of boolean;

 -- convert boolean into std_logic (false=>'0', true=>'1')
 function to_01(x:boolean) return std_logic;

 -- convert boolean vector into std_logic_vector (false=>'0', true=>'1')
 function to_01(x:boolean_vector) return std_logic_vector;

 -- This function returns the index of the leftmost one in the given vector.
 -- If the vector is all zeros the function returns the index -1.
 -- Examples:
 --   x1 : std_logic_vector( 4 downto  0) := "01010"
 --   x2 : std_logic_vector(23 downto 18) := "000110"
 --   INDEX_OF_LEFTMOST_ONE(x1) = 3
 --   INDEX_OF_LEFTMOST_ONE(x2) = 20
 function INDEX_OF_LEFTMOST_ONE(x:std_logic_vector) return integer;

 -- This function returns the index of the rightmost one in the given vector.
 -- If the vector is all zeros the function returns the index -1.
 -- Examples:
 --   x1 : std_logic_vector( 4 downto  0) := "01010"
 --   x2 : std_logic_vector(23 downto 18) := "000110"
 --   INDEX_OF_RIGHTMOST_ONE(x1) = 1
 --   INDEX_OF_RIGHTMOST_ONE(x2) = 19
 function INDEX_OF_RIGHTMOST_ONE(x:std_logic_vector) return integer;

 -- This function returns the index of the leftmost zero in the given vector.
 -- If the vector is all ones the function returns the index -1.
 -- Examples:
 --   x1 : std_logic_vector( 3 downto  0) := "1001"
 --   x2 : std_logic_vector(23 downto 18) := "110101"
 --   INDEX_OF_LEFTMOST_ZERO(x1) = 2
 --   INDEX_OF_LEFTMOST_ZERO(x2) = 21
 function INDEX_OF_LEFTMOST_ZERO(x:std_logic_vector) return integer;

 -- This function returns the index of the rightmost zero in the given vector.
 -- If the vector is all ones the function returns the index -1.
 -- Examples:
 --   x1 : std_logic_vector( 3 downto  0) := "1001"
 --   x2 : std_logic_vector(23 downto 18) := "110101"
 --   INDEX_OF_RIGHTMOST_ZERO(x1) = 1
 --   INDEX_OF_RIGHTMOST_ZERO(x2) = 19
 function INDEX_OF_RIGHTMOST_ZERO(x:std_logic_vector) return integer;

 -- Examples: 
 --   NUMBER_OF_SIGN_EXTENSION_BITS("00010101111") = 2
 --   NUMBER_OF_SIGN_EXTENSION_BITS("1101") = 1
 --   NUMBER_OF_SIGN_EXTENSION_BITS("0000000") = 5
 --   NUMBER_OF_SIGN_EXTENSION_BITS("01110101") = 0 
 function NUMBER_OF_SIGN_EXTENSION_BITS(x:std_logic_vector) return natural;
 function NUMBER_OF_SIGN_EXTENSION_BITS(x:signed) return natural;

 -- Examples: 
 --   NUMBER_OF_LEADING_BITS("00010101111",'0') = 3
 --   NUMBER_OF_LEADING_BITS("1101",'1') = 2
 --   NUMBER_OF_LEADING_BITS("0000000",'0') = 7
 --   NUMBER_OF_LEADING_BITS("00110101",'1') = 0 
 function NUMBER_OF_LEADING_BITS(x:std_logic_vector; b:std_logic) return natural;
 function NUMBER_OF_LEADING_BITS(x:unsigned; b:std_logic) return natural;
 function NUMBER_OF_LEADING_BITS(x:signed; b:std_logic) return natural;

 -- bitwise logic OR operation on specified number of leftmost MSB bits
 -- Function returns '1' when one or more of the n MSB bits are '1'.
 -- If n=0 (default) or when n is larger then the input vector length all
 -- input bits are considered.
 function SLV_OR(arg:std_logic_vector; n:natural:=0) return std_logic;
 
 -- bitwise logic NOR operation on specified number of leftmost MSB bits
 -- Function returns '1' when all n MSB bits are '0'.
 -- If n=0 (default) or when n is larger then the input vector length all
 -- input bits are considered.
 function SLV_NOR(arg:std_logic_vector; n:natural:=0) return std_logic;

 -- bitwise logic AND operation on specified number of leftmost MSB bits
 -- Function returns '1' when all n MSB bits are '1'.
 -- If n=0 (default) or when n is larger then the input vector length all
 -- input bits are considered.
 function SLV_AND(arg:std_logic_vector; n:natural:=0) return std_logic;
   
 -- bitwise logic NAND operation on specified number of leftmost MSB bits
 -- Function returns '1' when one or more of the n MSB bits are '0'.
 -- If n=0 (default) or when n is larger then the input vector length all
 -- input bits are considered.
 function SLV_NAND(arg:std_logic_vector; n:natural:=0) return std_logic;

 -- bitwise logic XOR operation, '1' when odd number of '1' bits
 function SLV_XOR(x:std_logic_vector) return std_logic;

 -- bitwise logic XNOR operation, '0' when odd number of '0' bits
 function SLV_XNOR(x:std_logic_vector) return std_logic;
  
-- function LOG2_CEIL(x:unsigned) return natural;

 ----------------------------------------------------------
 -- MSB check (useful e,g, for overflow detection)
 ----------------------------------------------------------

 -- MSB check, returns '1' if the number of N MSBs are all '0'
 function MSB_ALL_ZEROS (arg:std_logic_vector; n:positive) return std_logic;
 -- MSB check, returns '1' if the number of N MSBs are all '0'
 function MSB_ALL_ZEROS (arg:unsigned; n:positive) return std_logic;
 -- MSB check, returns '1' if the number of N MSBs are all '0'
 function MSB_ALL_ZEROS (arg:signed; n:positive) return std_logic;

 -- MSB check, returns '1' if the number of N MSBs are all '1'
 function MSB_ALL_ONES (arg:std_logic_vector; n:positive) return std_logic;
 -- MSB check, returns '1' if the number of N MSBs are all '1'
 function MSB_ALL_ONES (arg:unsigned; n:positive) return std_logic;
 -- MSB check, returns '1' if the number of N MSBs are all '1'
 function MSB_ALL_ONES (arg:signed; n:positive) return std_logic;

 -- MSB check, returns '1' if the number of N MSBs are all equal
 function MSB_ALL_EQUAL (arg:std_logic_vector; n:positive) return std_logic;
 -- MSB check, returns '1' if the number of N MSBs are all equal
 function MSB_ALL_EQUAL (arg:unsigned; n:positive) return std_logic;
 -- MSB check, returns '1' if the number of N MSBs are all equal
 function MSB_ALL_EQUAL (arg:signed; n:positive) return std_logic;

 ----------------------------------------------------------
 -- RESIZE AND CLIP/SATURATE
 ----------------------------------------------------------

 -- UNSIGNED RESIZE with overflow detection and optional clipping
 -- This procedure implementation resizes from the input size to the output size
 -- without additional length parameter. Furthermore, overflows are detected.
 -- If output size is larger than the input size then the new MSBs are filled 
 -- with zeros. If output size is smaller than the input size then MSBs are
 -- removed and the output is clipped when clipping is enabled.
 procedure RESIZE_CLIP(
   din  :in  unsigned; -- data input
   dout :out unsigned; -- data output
   ovfl :out std_logic; -- '1' if overflow occured 
   clip :in  boolean:=false -- enable clipping
 );

 -- SIGNED RESIZE with overflow detection and optional clipping
 -- This procedure implementation resizes from the input size to the output size
 -- without additional length parameter. Furthermore, overflows are detected.
 -- If output size is larger than the input size then for the new MSBs the sign
 -- is extended. If output size is smaller than the input size then MSBs are
 -- removed and the output is clipped when clipping is enabled.
 procedure RESIZE_CLIP(
   din  :in  signed; -- data input
   dout :out signed; -- data output
   ovfl :out std_logic; -- '1' if overflow occured 
   clip :in  boolean:=false -- enable clipping
 );

 -- UNSIGNED RESIZE to N bits with optional clipping
 -- By default the function behaves like the standard RESIZE function.
 -- If N is larger than the input size then the new MSBs are filled with zeros.
 -- If N is smaller than the input size then MSBs are removed and the output is
 -- clipped when clipping is enabled.
 function RESIZE_CLIP(
   din  : unsigned; -- data input
   n    : positive; -- output size
   clip : boolean:=false -- enable clipping
 ) return unsigned;

 -- SIGNED RESIZE to N bits with optional clipping
 -- By default the function behaves like the standard RESIZE function.
 -- If N is larger than the input size then for the new MSBs the sign is extended.
 -- If N is smaller than the input size then MSBs are removed and the output is
 -- clipped when clipping is enabled.
 function RESIZE_CLIP(
   din  : signed; -- data input
   n    : positive; -- output size
   clip : boolean:=false -- enable clipping
 ) return signed;

 ----------------------------------------------------------
 -- SHIFT LEFT AND CLIP/SATURATE
 ----------------------------------------------------------

 -- UNSIGNED SHIFT LEFT with overflow detection and with optional clipping
 -- This procedure implementation shifts the input left by N bits and resizes
 -- the result to the output size without additional length parameter.
 -- Furthermore, overflows are detected and the output is clipped when clipping
 -- is enabled.
 procedure SHIFT_LEFT_CLIP(
   din  :in  unsigned; -- data input
   n    :in  natural; -- number of left shifts
   dout :out unsigned; -- data output
   ovfl :out std_logic; -- '1' if overflow occured
   clip :in  boolean:=false -- enable clipping
 );
 
 -- SIGNED SHIFT LEFT with overflow detection and with optional clipping
 -- This procedure implementation shifts the input left by N bits and resizes
 -- the result to the output size without additional length parameter.
 -- Furthermore, overflows are detected and the output is clipped when clipping
 -- is enabled.
 procedure SHIFT_LEFT_CLIP(
   din  :in  signed; -- data input
   n    :in  natural; -- number of left shifts
   dout :out signed; -- data output
   ovfl :out std_logic; -- '1' if overflow occured
   clip :in  boolean:=false -- enable clipping
 );
 
 -- UNSIGNED SHIFT LEFT by N bits with optional clipping
 -- By default the function behaves like the standard SHIFT_LEFT function.
 -- The LSBs are filled with zeros and the output has the same size as the input.
 function SHIFT_LEFT_CLIP(
   din  : unsigned; -- data input
   n    : natural; -- number of left shifts
   clip : boolean:=false -- enable clipping
 ) return unsigned;

 -- SIGNED SHIFT LEFT by N bits with optional clipping
 -- By default the function behaves like the standard SHIFT_LEFT function.
 -- The LSBs are filled with zeros and the output has the same size as the input.
 function SHIFT_LEFT_CLIP(
   din  : signed; -- data input
   n    : natural; -- number of left shifts
   clip : boolean:=false -- enable clipping
 ) return signed;

 ----------------------------------------------------------
 -- SHIFT RIGHT AND ROUND
 ----------------------------------------------------------

 type round_option is (
   floor,    -- round down towards minus infinity, floor (default, just remove LSBs)
   nearest,  -- round to nearest (standard rounding, i.e. +0.5 and remove LSBs)
   ceil,     -- round up towards plus infinity, ceil
   truncate, -- round towards zero, truncate
   infinity  -- round towards plus/minus infinity, i.e. away from zero
 );
 
 -- UNSIGNED SHIFT RIGHT by N bits with rounding options
 -- By default the function behaves like the standard SHIFT_RIGHT function.
 -- The new MSBs are set to 0 and the LSBs are lost.
 -- The output has the same size as the input.
 function SHIFT_RIGHT_ROUND(
   din : unsigned; -- data input
   n   : natural; -- number of right shifts
   rnd : round_option:=floor -- enable optional rounding
 ) return unsigned;

 -- SIGNED SHIFT RIGHT by N bits with rounding options
 -- By default the function behaves like the standard SHIFT_RIGHT function.
 -- For the new MSBs the sign is extended and the LSBs are lost.
 -- The output has the same size as the input.
 function SHIFT_RIGHT_ROUND(
   din : signed; -- data input
   n   : natural; -- number of right shifts
   rnd : round_option:=floor -- enable optional rounding
 ) return signed;

 -- UNSIGNED SHIFT RIGHT with optional rounding and clipping and overflow detection
 -- This procedure implementation shifts the input right by N bits with rounding.
 -- The result is resized to the output size without additional length parameter.
 -- Furthermore, overflows are detected and the output is clipped when clipping
 -- is enabled.
 procedure SHIFT_RIGHT_ROUND(
   din  :in  unsigned; -- data input
   n    :in  natural; -- number of right shifts
   dout :out unsigned; -- data output
   ovfl :out std_logic; -- '1' if overflow occured
   rnd  :in  round_option:=floor; -- enable optional rounding
   clip :in  boolean:=false -- enable clipping
 );

 -- SIGNED SHIFT RIGHT with optional rounding and clipping and overflow detection
 -- This procedure implementation shifts the input right by N bits with rounding.
 -- The result is resized to the output size without additional length parameter.
 -- Furthermore, overflows are detected and the output is clipped when clipping
 -- is enabled.
 procedure SHIFT_RIGHT_ROUND(
   din  :in  signed; -- data input
   n    :in  natural; -- number of right shifts
   dout :out signed; -- data output
   ovfl :out std_logic; -- '1' if overflow occured
   rnd  :in  round_option:=floor; -- enable optional rounding
   clip :in  boolean:=false -- enable clipping
 );

 ----------------------------------------------------------
 -- ADD AND CLIP/SATURATE
 ----------------------------------------------------------

 -- UNSIGNED ADDITION with overflow detection and with optional clipping
 -- This procedure implementation adds the two inputs and resizes
 -- the result to the output size without additional length parameter.
 -- Furthermore, overflows are detected and the output is clipped when clipping
 -- is enabled.
 procedure ADD_CLIP(
   l,r  :in  unsigned; -- data input
   dout :out unsigned; -- data output
   ovfl :out std_logic; -- '1' if overflow occured
   clip :in  boolean:=false -- enable clipping
 );
 
 -- SIGNED ADDITION with overflow detection and with optional clipping
 -- This procedure implementation adds the two inputs and resizes
 -- the result to the output size without additional length parameter.
 -- Furthermore, overflows are detected and the output is clipped when clipping
 -- is enabled.
 procedure ADD_CLIP(
   l,r  :in  signed; -- data input
   dout :out signed; -- data output
   ovfl :out std_logic; -- '1' if overflow occured
   clip :in  boolean:=false -- enable clipping
 );

 ----------------------------------------------------------
 -- SUBTRACT AND CLIP/SATURATE
 ----------------------------------------------------------

 -- UNSIGNED SUBTRACTION with overflow detection and with optional clipping
 -- This procedure implementation calculates dout = l - r and resizes
 -- the result to the output size without additional length parameter.
 -- Furthermore, overflows are detected and the output is clipped when clipping
 -- is enabled.
 procedure SUB_CLIP(
   l,r  :in  unsigned; -- data input
   dout :out unsigned; -- data output
   ovfl :out std_logic; -- '1' if overflow occured
   clip :in  boolean:=false -- enable clipping
 );
 
 -- SIGNED SUBTRACTION with overflow detection and with optional clipping
 -- This procedure implementation calculates dout = l - r and resizes
 -- the result to the output size without additional length parameter.
 -- Furthermore, overflows are detected and the output is clipped when clipping
 -- is enabled.
 procedure SUB_CLIP(
   l,r  :in  signed; -- data input
   dout :out signed; -- data output
   ovfl :out std_logic; -- '1' if overflow occured
   clip :in  boolean:=false -- enable clipping
 );

end package;

-------------------------------------------------------------------------------

package body ieee_extension is

  ------------------------------------------
  -- local auxiliary
  ------------------------------------------

  function max (l,r: integer) return integer is
  begin
    if l > r then return l; else return r; end if;
  end function;

--  function min (l,r: integer) return integer is
--  begin
--    if l < r then return l; else return r; end if;
--  end function;

 ---------------------
 --  BOOLEAN STUFF
 ---------------------

 function to_01(x:boolean) return std_logic is
   variable r : std_logic := '0';
 begin
   if x then r:='1'; end if;
   return r;
 end function;
 
 function to_01(x:boolean_vector) return std_logic_vector is
   variable r : std_logic_vector(x'range) := (others=>'0');
 begin
   for i in x'range loop
     if x(i) then r(i):='1'; end if;
   end loop;
   return r;
 end function;

 ----------------
 --  BIT MISC
 ----------------

 function INDEX_OF_LEFTMOST_ONE(x:std_logic_vector) return integer is
   variable idx : integer := -1;
 begin
   for i in x'range loop
     if x(i)='1' then idx:=i; exit; end if;
   end loop;
   return idx;
 end function; 
 
 function INDEX_OF_RIGHTMOST_ONE(x:std_logic_vector) return integer is
   variable idx : integer := -1;
 begin
   for i in x'reverse_range loop
     if x(i)='1' then idx:=i; exit; end if;
   end loop;
   return idx;
 end function; 

 function INDEX_OF_LEFTMOST_ZERO(x:std_logic_vector) return integer is
   variable idx : integer := -1;
 begin
   for i in x'range loop
     if x(i)='0' then idx:=i; exit; end if;
   end loop;
   return idx;
 end function; 
 
 function INDEX_OF_RIGHTMOST_ZERO(x:std_logic_vector) return integer is
   variable idx : integer := -1;
 begin
   for i in x'reverse_range loop
     if x(i)='0' then idx:=i; exit; end if;
   end loop;
   return idx;
 end function; 

 function NUMBER_OF_SIGN_EXTENSION_BITS(x:std_logic_vector) return natural is
   constant L : integer range 2 to integer'high := x'length;
   alias xx : std_logic_vector(L-1 downto 0) is x; -- default range
   variable n : natural;
 begin
   n:=0;
   for i in L-2 downto 1 loop
     exit when xx(i)/=xx(L-1);
     n:=n+1;
   end loop;
   return n;
 end function;

 function NUMBER_OF_SIGN_EXTENSION_BITS(x:signed) return natural is
   constant L : integer range 2 to integer'high := x'length;
   variable y : std_logic_vector(L-1 downto 0);
 begin
   y:=std_logic_vector(x);
   return NUMBER_OF_SIGN_EXTENSION_BITS(y);
 end function;

 function NUMBER_OF_LEADING_BITS(x:std_logic_vector; b:std_logic) return natural is
   constant L : integer range 2 to integer'high := x'length;
   alias xx : std_logic_vector(L-1 downto 0) is x; -- default range
   variable n : natural;
 begin
   n:=0; 
   for i in L-1 downto 0 loop
     exit when xx(i)/=b;
     n:=n+1;
   end loop;
   return n;
 end function;

 function NUMBER_OF_LEADING_BITS(x:unsigned; b:std_logic) return natural is
   constant L : integer range 2 to integer'high := x'length;
   variable y : std_logic_vector(L-1 downto 0);
 begin
   y:=std_logic_vector(x);
   return NUMBER_OF_LEADING_BITS(y,b);
 end function;

 function NUMBER_OF_LEADING_BITS(x:signed; b:std_logic) return natural is
   constant L : integer range 2 to integer'high := x'length;
   variable y : std_logic_vector(L-1 downto 0);
 begin
   y:=std_logic_vector(x);
   return NUMBER_OF_LEADING_BITS(y,b);
 end function;

 -- bitwise logic OR operation on specified number of leftmost MSB bits
 -- Function returns '1' when one or more of the n MSB bits are '1'.
 -- If n=0 (default) or when n is larger then the input vector length all
 -- input bits are considered.
 function SLV_OR(arg:std_logic_vector; n:natural:=0) return std_logic is
   constant L : positive := arg'length;
   alias x : std_logic_vector(L-1 downto 0) is arg; -- default range
   variable NMSB : positive := L; -- by default all bits
   variable r : std_logic := '0';
 begin
   if (n/=0 and n<L) then NMSB:=n; end if;
   for i in L-1 downto L-NMSB loop r:=(r or x(i)); end loop;
   return r;
 end function;

 -- bitwise logic NOR operation on specified number of leftmost MSB bits
 -- Function returns '1' when all n MSB bits are '0'.
 -- If n=0 (default) or when n is larger then the input vector length all
 -- input bits are considered.
 function SLV_NOR(arg:std_logic_vector; n:natural:=0) return std_logic is
 begin
   return (not SLV_OR(arg,n));
 end function;

 -- bitwise logic AND operation on specified number of leftmost MSB bits
 -- Function returns '1' when all n MSB bits are '1'.
 -- If n=0 (default) or when n is larger then the input vector length all
 -- input bits are considered.
 function SLV_AND(arg:std_logic_vector; n:natural:=0) return std_logic is
   constant L : positive := arg'length;
   alias x : std_logic_vector(L-1 downto 0) is arg; -- default range
   variable NMSB : positive := L; -- by default all bits
   variable r : std_logic := '1';
 begin
   if (n/=0 and n<L) then NMSB:=n; end if;
   for i in L-1 downto L-NMSB loop r:=(r and x(i)); end loop;
   return r;
 end function;

 -- bitwise logic NAND operation on specified number of leftmost MSB bits
 -- Function returns '1' when one or more of the n MSB bits are '0'.
 -- If n=0 (default) or when n is larger then the input vector length all
 -- input bits are considered.
 function SLV_NAND(arg:std_logic_vector; n:natural:=0) return std_logic is
 begin
   return (not SLV_AND(arg,n));
 end function;

 -- bitwise logic XOR operation, returns '1' when odd number of '1' bits
 function SLV_XOR(x:std_logic_vector) return std_logic is
   variable r : std_logic := '0';
 begin
   for i in x'range loop r:=(r xor x(i)); end loop;
   return r;
 end function;

 -- bitwise logic XNOR operation, returns '0' when odd number of '0' bits
 function SLV_XNOR(x:std_logic_vector) return std_logic is
   variable r : std_logic := '1';
 begin
   for i in x'range loop r:=(r xnor x(i)); end loop;
   return r;
 end function;

 ----------------------------------------------------------
 -- MSB check (useful e,g, for overflow detection)
 ----------------------------------------------------------

 -- MSB check, returns '1' if the number of N MSBs are all '0'
 function MSB_ALL_ZEROS (arg:std_logic_vector; n:positive) return std_logic is
   variable res : std_logic := 'X';
 begin
   if (n/=0 and n<=arg'length) then res:=SLV_NOR(arg,n); end if; 
   return res;
 end function;

 -- MSB check, returns '1' if the number of N MSBs are all '0'
 function MSB_ALL_ZEROS (arg:unsigned; n:positive) return std_logic is
 begin
   return MSB_ALL_ZEROS(std_logic_vector(arg),n);
 end function;

 -- MSB check, returns '1' if the number of N MSBs are all '0'
 function MSB_ALL_ZEROS (arg:signed; n:positive) return std_logic is
 begin
   return MSB_ALL_ZEROS(std_logic_vector(arg),n);
 end function;

 -- MSB check, returns '1' if the number of N MSBs are all '1'
 function MSB_ALL_ONES (arg:std_logic_vector; n:positive) return std_logic is
   variable res : std_logic := 'X';
 begin
   if (n/=0 and n<=arg'length) then res:=SLV_AND(arg,n); end if;
   return res;
 end function;

 -- MSB check, returns '1' if the number of N MSBs are all '1'
 function MSB_ALL_ONES (arg:unsigned; n:positive) return std_logic is
   variable res : std_logic := 'X';
 begin
   return MSB_ALL_ONES(std_logic_vector(arg),n);
 end function;

 -- MSB check, returns '1' if the number of N MSBs are all '1'
 function MSB_ALL_ONES (arg:signed; n:positive) return std_logic is
   variable res : std_logic := 'X';
 begin
   return MSB_ALL_ONES(std_logic_vector(arg),n);
 end function;

 -- MSB check, returns '1' if the number of N MSBs are all equal
 function MSB_ALL_EQUAL (arg:std_logic_vector; n:positive) return std_logic is
 begin
   return (MSB_ALL_ZEROS(arg,n) or MSB_ALL_ONES(arg,n));
 end function;

 -- MSB check, returns '1' if the number of N MSBs are all equal
 function MSB_ALL_EQUAL (arg:unsigned; n:positive) return std_logic is
 begin
   return MSB_ALL_EQUAL(std_logic_vector(arg),n);
 end function;

 -- MSB check, returns '1' if the number of N MSBs are all equal
 function MSB_ALL_EQUAL (arg:signed; n:positive) return std_logic is
 begin
   return MSB_ALL_EQUAL(std_logic_vector(arg),n);
 end function;

 ----------------------------------------------------------
 -- RESIZE AND CLIP/SATURATE
 ----------------------------------------------------------

 -- UNSIGNED RESIZE with overflow detection and optional clipping
 procedure RESIZE_CLIP(
   din  :in  unsigned; -- data input
   dout :out unsigned; -- data output
   ovfl :out std_logic; -- '1' if overflow occured 
   clip :in  boolean:=false -- enable clipping
 ) is
   constant LIN : positive := din'length; 
   constant LOUT : positive := dout'length;
   constant N : integer := LIN-LOUT; -- N<0 add MSBs , N>0 remove MSBs
   alias xdout : unsigned(LOUT-1 downto 0) is dout; -- default range
 begin
   xdout := resize(din,LOUT); -- by default standard resize
   ovfl := '0'; -- by default no overflow
   if N>0 then
     -- resize down with potential overflow and clipping
     if MSB_ALL_ZEROS(din,N)='0' then
       -- overflow
       ovfl := '1';
       if clip then
         xdout := (others=>'1'); -- clipping
       end if;
     end if;
   end if;
 end procedure;

 -- SIGNED RESIZE with overflow detection and optional clipping
 procedure RESIZE_CLIP(
   din  :in  signed; -- data input
   dout :out signed; -- data output
   ovfl :out std_logic; -- '1' if overflow occured 
   clip :in  boolean:=false -- enable clipping
 ) is
   constant LIN : positive := din'length; 
   constant LOUT : positive := dout'length;
   constant N : integer := LIN-LOUT; -- N<0 add MSBs , N>0 remove MSBs
   alias xdout : signed(LOUT-1 downto 0) is dout; -- default range
 begin
   xdout := resize(din,LOUT); -- by default standard resize
   ovfl := '0'; -- by default no overflow
   if N>0 then
     -- resize down with potential overflow and clipping
     if din(din'left)='0' and MSB_ALL_ZEROS(din,N+1)='0' then
       ovfl := '1'; -- positive overflow
       if clip then
         xdout(LOUT-1) := '0'; -- positive clipping
         xdout(LOUT-2 downto 0) := (others=>'1');
       end if;
     elsif din(din'left)='1' and MSB_ALL_ONES(din,N+1)='0' then
       ovfl := '1'; -- negative overflow
       if clip then
         xdout(LOUT-1) := '1'; -- negative clipping
         xdout(LOUT-2 downto 0) := (others=>'0');
       end if;
     end if;
   end if;
 end procedure;

 -- UNSIGNED RESIZE to N bits with optional clipping
 function RESIZE_CLIP(din:unsigned; n:positive; clip:boolean:=false) return unsigned is
   variable ovfl : std_logic; -- dummy
   variable dout : unsigned(n-1 downto 0);
 begin
   RESIZE_CLIP(din=>din, dout=>dout, ovfl=>ovfl, clip=>clip);
   return dout;
 end function;

 -- SIGNED RESIZE to N bits with optional clipping
 function RESIZE_CLIP(din:signed; n:positive; clip:boolean:=false) return signed is
   variable ovfl : std_logic; -- dummy
   variable dout : signed(n-1 downto 0);
 begin
   RESIZE_CLIP(din=>din, dout=>dout, ovfl=>ovfl, clip=>clip);
   return dout;
 end function;

 ----------------------------------------------------------
 -- SHIFT LEFT AND CLIP/SATURATE
 ----------------------------------------------------------

 -- UNSIGNED SHIFT LEFT with overflow detection and with optional clipping
 procedure SHIFT_LEFT_CLIP(
   din  :in  unsigned; -- data input
   n    :in  natural; -- number of left shifts
   dout :out unsigned; -- data output
   ovfl :out std_logic; -- '1' if overflow occured
   clip :in  boolean:=false -- enable clipping
 ) is
   constant LIN : positive := din'length;
   variable temp : unsigned(LIN+n-1 downto 0) := (others=>'0');
 begin
   temp(LIN+n-1 downto n) := din;
   RESIZE_CLIP(din=>temp, dout=>dout, ovfl=>ovfl, clip=>clip);
 end procedure;
 
 -- SIGNED SHIFT LEFT with overflow detection and with optional clipping
 procedure SHIFT_LEFT_CLIP(
   din  :in  signed; -- data input
   n    :in  natural; -- number of left shifts
   dout :out signed; -- data output
   ovfl :out std_logic; -- '1' if overflow occured
   clip :in  boolean:=false -- enable clipping
 ) is
   constant LIN : positive := din'length; 
   variable temp : signed(LIN+n-1 downto 0) := (others=>'0');
 begin
   temp(LIN+n-1 downto n) := din;
   RESIZE_CLIP(din=>temp, dout=>dout, ovfl=>ovfl, clip=>clip);
 end procedure;
 
 -- UNSIGNED SHIFT LEFT by N bits with optional clipping
 function SHIFT_LEFT_CLIP(
   din  : unsigned; -- data input
   n    : natural; -- number of left shifts
   clip : boolean:=false -- enable clipping
 ) return unsigned is -- data output
   constant L : positive := din'length;
   variable dout : unsigned(L-1 downto 0); -- := (others=>'0'); -- default when n>=L
   variable ovfl : std_logic; -- dummy
 begin
   SHIFT_LEFT_CLIP(din=>din, n=>n, dout=>dout, ovfl=>ovfl, clip=>clip);
   return dout;
 end function;

 -- SIGNED SHIFT LEFT by N bits with optional clipping
 function SHIFT_LEFT_CLIP(
   din  : signed; -- data input
   n    : natural; -- number of left shifts
   clip : boolean:=false -- enable clipping
 ) return signed is -- data output
   constant L : positive := din'length;
   variable dout : signed(L-1 downto 0); -- := (others=>'0'); -- default, LSBs = '0'
   variable ovfl : std_logic; -- dummy
 begin
   SHIFT_LEFT_CLIP(din=>din, n=>n, dout=>dout, ovfl=>ovfl, clip=>clip);
   return dout;
 end function;

 ----------------------------------------------------------
 -- SHIFT RIGHT AND ROUND
 ----------------------------------------------------------

 -- UNSIGNED SHIFT RIGHT by N bits with rounding options
 function SHIFT_RIGHT_ROUND(
   din : unsigned; -- data input
   n   : natural; -- number of right shifts
   rnd : round_option:=floor -- enable optional rounding
 ) return unsigned is
   constant L : positive := din'length;
   alias d : unsigned(L-1 downto 0) is din; -- default range
   variable tnear : unsigned(L-n+1 downto 0) := (others=>'0');
   variable tceil : unsigned(L-n downto 0) := (others=>'0');
   variable dout : unsigned(L-1 downto 0) := (others=>'0'); -- default when n>=L
 begin
   if n=0 then
     dout := din;
   elsif n<L then
     -- by default output floor result
     -- floor = round down towards minus infinity (default, just remove LSBs)
     -- (same: truncate, round towards zero)
     dout(L-n-1 downto 0) := d(L-1 downto n);
     -- if not floor (or truncate) then overwrite default output
     if rnd=nearest then
       -- round to nearest (standard rounding, i.e. +0.5 and remove LSBs)
       tnear(L-n downto 0) := d(L-1 downto n-1);
       tnear := tnear + 1;
       dout(L-n downto 0) := tnear(L-n+1 downto 1); -- remove rounding LSB
     elsif (rnd=ceil or rnd=infinity) then
       -- ceil, round up towards plus infinity
       -- (same: round towards plus/minus infinity, i.e. away from zero)
       tceil(L-n-1 downto 0) := d(L-1 downto n);
       if SLV_OR(std_logic_vector(d(n-1 downto 0)))='1' then
         tceil := tceil + 1;
       end if;
       dout(L-n downto 0) := tceil(L-n downto 0);
     end if;
   elsif n=L then
     if rnd=nearest then
       dout(0) := d(L-1);
     elsif (rnd=ceil or rnd=infinity) then
       dout(0) := SLV_OR(std_logic_vector(d(L-1 downto 0)));
     end if;
   end if;  
   return dout;
 end function;

 -- SIGNED SHIFT RIGHT by N bits with rounding options
 function SHIFT_RIGHT_ROUND(
   din : signed; -- data input
   n   : natural; -- number of right shifts
   rnd : round_option:=floor -- enable optional rounding
 ) return signed is
   constant L : positive := din'length;
   alias d : signed(L-1 downto 0) is din; -- default range
   variable tnear : signed(L-n+1 downto 0) := (others=>din(din'left)); -- sign extension bits
   variable tceil : signed(L-n downto 0) := (others=>din(din'left)); -- sign extension bits
   variable dout : signed(L-1 downto 0) := (others=>'0'); -- default when n>=L
 begin
   if n=0 then
     dout := din;
   elsif n<L then
     -- ceil, round up towards plus infinity
     tceil(L-n-1 downto 0) := d(L-1 downto n);
     if SLV_OR(std_logic_vector(d(n-1 downto 0)))='1' then
       tceil := tceil + 1;
     end if;
     -- by default output floor result
     -- floor = round down towards minus infinity (default, just remove LSBs)
     dout(L-n-1 downto 0) := d(L-1 downto n);
     dout(L-1 downto L-n) := (others=>d(L-1)); -- sign bits
     -- if floor is not wanted then overwrite default output
     if rnd=nearest then
       -- round to nearest (standard rounding, i.e. +0.5 and remove LSBs)
       tnear(L-n downto 0) := d(L-1 downto n-1);
       tnear := tnear + 1;
       dout(L-n-1 downto 0) := tnear(L-n downto 1); -- remove sign and rounding LSB
       dout(L-1 downto L-n) := (others=>tnear(L-n+1)); -- sign bits
     elsif rnd=ceil then
       -- ceil, round up towards plus infinity
       dout(L-n-1 downto 0) := tceil(L-n-1 downto 0); -- without sign bit
       dout(L-1 downto L-n) := (others=>tceil(L-n)); -- sign bits
     elsif rnd=truncate then
       -- truncate, round towards zero
       -- if negative then ceil - if positive then use default floor
       if d(L-1)='1' then 
         dout(L-n-1 downto 0) := tceil(L-n-1 downto 0); -- without sign bit
         dout(L-1 downto L-n) := (others=>tceil(L-n)); -- sign bits
       end if;
     elsif rnd=infinity then
       -- round towards plus/minus infinity, i.e. away from zero
       -- if positive then ceil - if negative then use default floor
       if d(L-1)='0' then
         dout(L-n-1 downto 0) := tceil(L-n-1 downto 0); -- without sign bit
         dout(L-1 downto L-n) := (others=>tceil(L-n)); -- sign bits
       end if;
     end if;  
   end if;  
   return dout;
 end function;

 -- UNSIGNED SHIFT RIGHT with optional rounding and clipping and overflow detection
 procedure SHIFT_RIGHT_ROUND(
   din  :in  unsigned; -- data input
   n    :in  natural; -- number of right shifts
   dout :out unsigned; -- data output
   ovfl :out std_logic; -- '1' if overflow occured
   rnd  :in  round_option:=floor; -- enable optional rounding
   clip :in  boolean:=false -- enable clipping
 ) is
   constant LIN : positive := din'length; 
   variable temp : unsigned(LIN-1 downto 0);
 begin
   temp := SHIFT_RIGHT_ROUND(din=>din, n=>n, rnd=>rnd);
   RESIZE_CLIP(din=>temp, dout=>dout, ovfl=>ovfl, clip=>clip);
 end procedure;

 -- SIGNED SHIFT RIGHT with optional rounding and clipping and overflow detection
 procedure SHIFT_RIGHT_ROUND(
   din  :in  signed; -- data input
   n    :in  natural; -- number of right shifts
   dout :out signed; -- data output
   ovfl :out std_logic; -- '1' if overflow occured
   rnd  :in  round_option:=floor; -- enable optional rounding
   clip :in  boolean:=false -- enable clipping
 ) is
   constant LIN : positive := din'length; 
   variable temp : signed(LIN-1 downto 0);
 begin
   temp := SHIFT_RIGHT_ROUND(din=>din, n=>n, rnd=>rnd);
   RESIZE_CLIP(din=>temp, dout=>dout, ovfl=>ovfl, clip=>clip);
 end procedure;

 ----------------------------------------------------------
 -- ADD AND CLIP/SATURATE
 ----------------------------------------------------------

 -- UNSIGNED ADDITION with overflow detection and with optional clipping
 procedure ADD_CLIP(
   l,r  :in  unsigned; -- data input
   dout :out unsigned; -- data output
   ovfl :out std_logic; -- '1' if overflow occured
   clip :in  boolean:=false -- enable clipping
 ) is
   constant SIZE : positive := max(l'length,r'length);
   alias xl : unsigned(l'length-1 downto 0) is l; -- default range
   alias xr : unsigned(r'length-1 downto 0) is r; -- default range
--   alias xs : unsigned(s'length-1 downto 0) is s; -- default range
   variable t : unsigned(SIZE downto 0);
 begin
   t := RESIZE(xl,SIZE+1) + RESIZE(xr,SIZE+1);
   RESIZE_CLIP(din=>t, dout=>dout, ovfl=>ovfl, clip=>clip);
 end procedure;
 
 -- SIGNED ADDITION with overflow detection and with optional clipping
 procedure ADD_CLIP(
   l,r  :in  signed; -- data input
   dout :out signed; -- data output
   ovfl :out std_logic; -- '1' if overflow occured
   clip :in  boolean:=false -- enable clipping
 ) is
   constant SIZE : positive := max(l'length,r'length);
   alias xl : signed(l'length-1 downto 0) is l; -- default range
   alias xr : signed(r'length-1 downto 0) is r; -- default range
--   alias xs : signed(s'length-1 downto 0) is s; -- default range
   variable t : signed(SIZE downto 0);
 begin
   t := RESIZE(xl,SIZE+1) + RESIZE(xr,SIZE+1);
   RESIZE_CLIP(din=>t, dout=>dout, ovfl=>ovfl, clip=>clip);
 end procedure;

 ----------------------------------------------------------
 -- SUBTRACT AND CLIP/SATURATE
 ----------------------------------------------------------

 -- UNSIGNED SUBTRACTION with overflow detection and with optional clipping
 procedure SUB_CLIP(
   l,r  :in  unsigned; -- data input
   dout :out unsigned; -- data output
   ovfl :out std_logic; -- '1' if overflow occured
   clip :in  boolean:=false -- enable clipping
 ) is
   constant SIZE : positive := max(l'length,r'length);
   alias xl : unsigned(l'length-1 downto 0) is l; -- default range
   alias xr : unsigned(r'length-1 downto 0) is r; -- default range
   variable t : signed(SIZE+1 downto 0); -- additional sign bit for underflow detection
   variable uvf, ovf : std_logic;
   variable sdout : signed(dout'length-1 downto 0);
 begin
   t := signed(RESIZE(xl,SIZE+2)) - signed(RESIZE(xr,SIZE+2));
   uvf := t(SIZE+1); -- underflow ?
   if clip and t(SIZE+1)='1' then
     sdout := (others=>'0'); -- negative saturation
   else
     RESIZE_CLIP(din=>t, dout=>sdout, ovfl=>ovf, clip=>clip);
   end if;
   ovfl := uvf  or ovf;
   dout := unsigned(sdout);
 end procedure;
 
 -- SIGNED SUBTRACTION with overflow detection and with optional clipping
 procedure SUB_CLIP(
   l,r  :in  signed; -- data input
   dout :out signed; -- data output
   ovfl :out std_logic; -- '1' if overflow occured
   clip :in  boolean:=false -- enable clipping
 ) is
   constant SIZE : positive := max(l'length,r'length);
   alias xl : signed(l'length-1 downto 0) is l; -- default range
   alias xr : signed(r'length-1 downto 0) is r; -- default range
   variable t : signed(SIZE downto 0);
 begin
   t := RESIZE(xl,SIZE+1) - RESIZE(xr,SIZE+1);
   RESIZE_CLIP(din=>t, dout=>dout, ovfl=>ovfl, clip=>clip);
 end procedure;
 
end package body;
 