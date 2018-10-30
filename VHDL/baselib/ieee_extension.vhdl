-------------------------------------------------------------------------------
--! @file       ieee_extension.vhdl
--! @author     Fixitfetish
--! @date       30/Oct/2018
--! @version    0.90
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;

--! @brief This package provides additional functions and procedures on top of
--! IEEE standard functions. Features like rounding, clipping, overflow detection
--! and others are added.

package ieee_extension is

 --! convert boolean into std_logic (false=>'0', true=>'1')
 function to_01(x:boolean) return std_logic;

 --! convert boolean vector into std_logic_vector (false=>'0', true=>'1')
 function to_01(x:boolean_vector) return std_logic_vector;

 --! @brief This function calculates ceil(log2(n)).
 --! Optionally, the maximum result can be limited to 'bits' (bits = 2..32)
 --! | n           | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10| 11| 12| 13| .. |
 --! |-------------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:--:|
 --! | log2ceil(n) | 1 | 1 | 2 | 2 | 3 | 3 | 3 | 3 | 4 | 4 | 4 | 4 | 4 | .. |
 function LOG2CEIL (n:positive; bits:positive:=32) return natural;

 --! @brief Element-wise ceil(log2(n(i))) of and integer vector
 function LOG2CEIL (n:integer_vector; bits:positive:=32) return integer_vector;

 ----------------------------------------------------------
 -- MAXIMUM and MINIMUM
 ----------------------------------------------------------

 --! maximum of two integers
 function MAXIMUM (l,r: integer) return integer;

 --! minimum of two integers
 function MINIMUM (l,r: integer) return integer;

 --! Leftmost maximum and corresponding index of integer vector.
 --! For rightmost maximum consider using REVERSE() in addition.
 --! (Note: this is a recursive procedure)
 procedure MAXIMUM(
   din : in  integer_vector;
   max : out integer;
   idx : out integer
 );

 --! Leftmost minimum and corresponding index of integer vector.
 --! For rightmost minimum consider using REVERSE() in addition.
 --! (Note: this is a recursive procedure)
 procedure MINIMUM(
   din : in  integer_vector;
   min : out integer;
   idx : out integer
 );

 --! Leftmost maximum of integer vector
 --! For rightmost maximum consider using REVERSE() in addition.
 function MAXIMUM(x:integer_vector) return integer;

 --! Leftmost minimum of integer vector
 --! For rightmost minimum consider using REVERSE() in addition.
 function MINIMUM(x:integer_vector) return integer;

 --! Leftmost index of integer vector maximum
 --! For rightmost maximum consider using REVERSE() in addition.
 function INDEX_OF_MAXIMUM(x:integer_vector) return integer;

 --! Leftmost index of integer vector minimum
 --! For rightmost minimum consider using REVERSE() in addition.
 function INDEX_OF_MINIMUM(x:integer_vector) return integer;

 --! Maximum of two unsigned
 function MAXIMUM (l,r: unsigned) return unsigned;

 --! Minimum of two unsigned
 function MINIMUM (l,r: unsigned) return unsigned;

 --! Leftmost maximum and corresponding index of unsigned vector.
 --! For rightmost maximum consider using REVERSE() in addition.
 procedure MAXIMUM(
   din : in  unsigned_vector;
   max : out unsigned;
   idx : out integer
 );
  
 --! Leftmost minimum and corresponding index of unsigned vector.
 --! For rightmost minimum consider using REVERSE() in addition.
 procedure MINIMUM(
   din : in  unsigned_vector;
   min : out unsigned;
   idx : out integer
 );
  
 --! Leftmost maximum of unsigned vector
 --! For rightmost maximum consider using REVERSE() in addition.
 function MAXIMUM(x:unsigned_vector) return unsigned;

 --! Leftmost minimum of unsigned vector
 --! For rightmost minimum consider using REVERSE() in addition.
 function MINIMUM(x:unsigned_vector) return unsigned;

 --! Leftmost index of unsigned vector maximum
 --! For rightmost maximum consider using REVERSE() in addition.
 function INDEX_OF_MAXIMUM(x:unsigned_vector) return integer;

 --! Leftmost index of unsigned vector minimum
 --! For rightmost minimum consider using REVERSE() in addition.
 function INDEX_OF_MINIMUM(x:unsigned_vector) return integer;

 ----------------------------------------------------------
 -- REVERSE order of vector elements
 ----------------------------------------------------------

 --! @brief Reverse order of vector elements without changing the index direction.  
 --! Example:
 --! * signal x : std_logic_vector(3 to 7) := "10110";
 --! * signal y : std_logic_vector(x'reverse_range);
 --! * REVERSE(x) reverses just the vector elements : std_logic_vector(3 to 7) = "01101"
 --! * y<=x reverses just the index direction : y = std_logic_vector(7 downto 3) = "10110"
 --! * y<=REVERSE(x) reverses index direction and vector elements : y = std_logic_vector(7 downto 3) = "01101"
 function REVERSE(arg:std_logic_vector) return std_logic_vector;

 --! @brief Reverse order of vector elements without changing the index direction.  
 --! Example:
 --! * signal x : integer_vector(3 to 7) := (8,-3,15,-2,41);
 --! * signal y : integer_vector(x'reverse_range);
 --! * REVERSE(x) reverses just the vector elements : integer_vector(3 to 7) = (41,-2,15,-3,8)
 --! * y<=x reverses just the index direction : y = integer_vector(7 downto 3) = (8,-3,15,-2,41)
 --! * y<=REVERSE(x) reverses index direction and vector elements : y = integer_vector(7 downto 3) = (41,-2,15,-3,8)
 function REVERSE(arg:integer_vector) return integer_vector;

 --! @brief Reverse order of vector elements without changing the index direction.  
 --! Example:
 --! * signal x : boolean_vector(3 to 5) := (false,true,true);
 --! * signal y : boolean_vector(x'reverse_range);
 --! * REVERSE(x) reverses just the vector elements : boolean_vector(3 to 5) = (true,true,false)
 --! * y<=x reverses just the index direction : y = boolean_vector(5 downto 3) = (false,true,true) 
 --! * y<=REVERSE(x) reverses index direction and vector elements : y = boolean_vector(5 downto 3) = (true,true,false)
 function REVERSE(arg:boolean_vector) return boolean_vector;

 --! @brief Reverse order of vector elements without changing the index direction.  
 --! Example:
 --! * signal x : unsigned_vector(3 to 5)(2 downto 0) := ("011","100","101");
 --! * signal y : unsigned_vector(x'reverse_range)(x(x'low)'range);
 --! * REVERSE(x) results in : unsigned_vector(3 to 5)(2 downto 0) = ("101","100","011")
 --! * y<=x results in : y = unsigned_vector(5 downto 3)(2 downto 0) = ("011","100","101")
 --! * y<=REVERSE(x) results in : y = unsigned_vector(5 downto 3)(2 downto 0) = ("101","100","011")
 function REVERSE(arg:unsigned_vector) return unsigned_vector;

 --! @brief Reverse order of vector elements without changing the index direction.  
 --! Example:
 --! * signal x : signed_vector(3 to 5)(2 downto 0) := ("011","100","101");
 --! * signal y : signed_vector(x'reverse_range)(x(x'low)'range);
 --! * REVERSE(x) results in : signed_vector(3 to 5)(2 downto 0) = ("101","100","011")
 --! * y<=x results in : y = signed_vector(5 downto 3)(2 downto 0) = ("011","100","101")
 --! * y<=REVERSE(x) results in : y = signed_vector(5 downto 3)(2 downto 0) = ("101","100","011")
 function REVERSE(arg:signed_vector) return signed_vector;

 ----------------------------------------------------------
 -- bitwise logic operations on std_logic_vector
 ----------------------------------------------------------

 --! bitwise logic OR operation on input vector
 --! Function returns '1' when one or more bits are '1'.
 function SLV_OR(arg:std_logic_vector) return std_logic;
 
 --! bitwise logic NOR operation on input vector
 --! Function returns '1' when all bits are '0'.
 function SLV_NOR(arg:std_logic_vector) return std_logic;

 -- bitwise logic AND operation on input vector
 -- Function returns '1' when all bits are '1'.
 function SLV_AND(arg:std_logic_vector) return std_logic;
   
 -- bitwise logic NAND operation on input vector
 -- Function returns '1' when one or more bits are '0'.
 function SLV_NAND(arg:std_logic_vector) return std_logic;

 -- bitwise logic XOR operation on input vector
 -- Function returns '1' when odd number of '1' bits.
 function SLV_XOR(x:std_logic_vector) return std_logic;

 -- bitwise logic XNOR operation  on input vector
 -- Function returns '0' when odd number of '0' bits.
 function SLV_XNOR(x:std_logic_vector) return std_logic;

 ----------------------------------------------------------
 -- MSB/LSB check (useful e.g. for overflow detection)
 ----------------------------------------------------------

 --! @brief The ALL_ONES function returns '1' if all selected bits are '1' (logical AND).
 --! More details about the optional argument n can be found below.
 --! * for n=0 : considers all bits (default)
 --! * for n>0 : considers only the |n| rightmost LSBs
 --! * for n<0 : considers only the |n| leftmost MSBs
 --! * for |n| > arg'length : returns 'X'
 function ALL_ONES (arg:std_logic_vector; n:integer:=0) return std_logic;
 function ALL_ONES (arg:unsigned; n:integer:=0) return std_logic;
 function ALL_ONES (arg:signed; n:integer:=0) return std_logic;

 --! @brief The ANY_ONES function returns '1' if any of the selected bits is '1' (logical OR).
 --! More details about the optional argument n can be found below.
 --! * for n=0 : considers all bits (default)
 --! * for n>0 : considers only the |n| rightmost LSBs
 --! * for n<0 : considers only the |n| leftmost MSBs
 --! * for |n| > arg'length : returns 'X'
 function ANY_ONES (arg:std_logic_vector; n:integer:=0) return std_logic;
 function ANY_ONES (arg:unsigned; n:integer:=0) return std_logic;
 function ANY_ONES (arg:signed; n:integer:=0) return std_logic;

 --! @brief The ALL_ZEROS function returns '1' if all selected bits are '0' (logical NOR).
 --! More details about the optional argument n can be found below.
 --! * for n=0 : considers all bits (default)
 --! * for n>0 : considers only the |n| rightmost LSBs
 --! * for n<0 : considers only the |n| leftmost MSBs
 --! * for |n| > arg'length : returns 'X'
 function ALL_ZEROS (arg:std_logic_vector; n:integer:=0) return std_logic;
 function ALL_ZEROS (arg:unsigned; n:integer:=0) return std_logic;
 function ALL_ZEROS (arg:signed; n:integer:=0) return std_logic;
   
 --! @brief The ANY_ZEROS function returns '1' if any of the selected bits is '0' (logical NAND).
 --! More details about the optional argument n can be found below.
 --! * for n=0 : considers all bits (default)
 --! * for n>0 : considers only the |n| rightmost LSBs
 --! * for n<0 : considers only the |n| leftmost MSBs
 --! * for |n| > arg'length : returns 'X'
 function ANY_ZEROS (arg:std_logic_vector; n:integer:=0) return std_logic;
 function ANY_ZEROS (arg:unsigned; n:integer:=0) return std_logic;
 function ANY_ZEROS (arg:signed; n:integer:=0) return std_logic;

 --! @brief The ALL_EQUAL function returns '1' if all selected bits are equal, i.e. all '0' or all '1'
 --! More details about the optional argument n can be found below.
 --! * for n=0 : considers all bits (default)
 --! * for n>0 : considers only the |n| rightmost LSBs
 --! * for n<0 : considers only the |n| leftmost MSBs
 --! * for |n| > arg'length : returns 'X'
 function ALL_EQUAL (arg:std_logic_vector; n:integer:=0) return std_logic;
 function ALL_EQUAL (arg:unsigned; n:integer:=0) return std_logic;
 function ALL_EQUAL (arg:signed; n:integer:=0) return std_logic;

 function NUMBER_OF_ONES (arg:std_logic_vector) return natural;
 function NUMBER_OF_ONES (arg:boolean_vector) return natural;

 function NUMBER_OF_ZEROS (arg:std_logic_vector) return natural;
 function NUMBER_OF_ZEROS (arg:boolean_vector) return natural;

 --! @brief This function returns the index of the leftmost one in the given vector x.
 --! The valid input range of x is within 0 to integer'high.
 --! If the vector is all zeros the function returns the index -1.
 --! Find some examples below.
 --! * x1 : std_logic_vector( 4 downto  0) := "01010"
 --! * x2 : std_logic_vector(23 downto 18) := "000110"
 --! * INDEX_OF_LEFTMOST_ONE(x1) = 3
 --! * INDEX_OF_LEFTMOST_ONE(x2) = 20
 function INDEX_OF_LEFTMOST_ONE(x:std_logic_vector) return integer;

 --! @brief This function returns the index of the rightmost one in the given vector x.
 --! The valid input range of x is within 0 to integer'high.
 --! If the vector is all zeros the function returns the index -1.
 --! Find some examples below.
 --! * x1 : std_logic_vector( 4 downto  0) := "01010"
 --! * x2 : std_logic_vector(23 downto 18) := "000110"
 --! * INDEX_OF_RIGHTMOST_ONE(x1) = 1
 --! * INDEX_OF_RIGHTMOST_ONE(x2) = 19
 function INDEX_OF_RIGHTMOST_ONE(x:std_logic_vector) return integer;

 --! @brief This function returns the index of the leftmost zero in the given vector x.
 --! The valid input range of x is within 0 to integer'high.
 --! If the vector is all ones the function returns the index -1.
 --! Find some examples below.
 --! * x1 : std_logic_vector( 3 downto  0) := "1001"
 --! * x2 : std_logic_vector(23 downto 18) := "110101"
 --! * INDEX_OF_LEFTMOST_ZERO(x1) = 2
 --! * INDEX_OF_LEFTMOST_ZERO(x2) = 21
 function INDEX_OF_LEFTMOST_ZERO(x:std_logic_vector) return integer;

 --! @brief This function returns the index of the rightmost zero in the given vector x.
 --! The valid input range of x is within 0 to integer'high.
 --! If the vector is all ones the function returns the index -1.
 --! Find some examples below.
 --! * x1 : std_logic_vector( 3 downto  0) := "1001"
 --! * x2 : std_logic_vector(23 downto 18) := "110101"
 --! * INDEX_OF_RIGHTMOST_ZERO(x1) = 1
 --! * INDEX_OF_RIGHTMOST_ZERO(x2) = 19
 function INDEX_OF_RIGHTMOST_ZERO(x:std_logic_vector) return integer;

 -- This function determines the number of additional sign extension bits.
 -- The input is assumed to be a signed number of size>=3. Otherwise sign
 -- extension bits cannot exist.
 -- Examples: 
 --   NUMBER_OF_SIGN_EXTENSION_BITS("00010101111") = 2
 --   NUMBER_OF_SIGN_EXTENSION_BITS("11001") = 1
 --   NUMBER_OF_SIGN_EXTENSION_BITS("000") = 1
 --   NUMBER_OF_SIGN_EXTENSION_BITS("01110101") = 0 
 function NUMBER_OF_SIGN_EXTENSION_BITS(x:std_logic_vector) return natural;

 -- This function determines the number of additional sign extension bits.
 -- The input is assumed to be a signed number of size>=3. Otherwise sign
 -- extension bits cannot exist.
 -- Examples: 
 --   NUMBER_OF_SIGN_EXTENSION_BITS("00010101111") = 2
 --   NUMBER_OF_SIGN_EXTENSION_BITS("11001") = 1
 --   NUMBER_OF_SIGN_EXTENSION_BITS("000") = 1
 --   NUMBER_OF_SIGN_EXTENSION_BITS("01110101") = 0 
 function NUMBER_OF_SIGN_EXTENSION_BITS(x:signed) return natural;

 -- This function determines the number of consecutive leading bits of value b.
 -- Examples: 
 --   NUMBER_OF_LEADING_BITS("00010101111",'0') = 3
 --   NUMBER_OF_LEADING_BITS("1101",'1') = 2
 --   NUMBER_OF_LEADING_BITS("0000000",'0') = 7
 --   NUMBER_OF_LEADING_BITS("00110101",'1') = 0 
 function NUMBER_OF_LEADING_BITS(x:std_logic_vector; b:std_logic) return natural;

 -- This function determines the number of consecutive leading bits of value b.
 -- Examples: 
 --   NUMBER_OF_LEADING_BITS("00010101111",'0') = 3
 --   NUMBER_OF_LEADING_BITS("1101",'1') = 2
 --   NUMBER_OF_LEADING_BITS("0000000",'0') = 7
 --   NUMBER_OF_LEADING_BITS("00110101",'1') = 0 
 function NUMBER_OF_LEADING_BITS(x:unsigned; b:std_logic) return natural;

 -- This function determines the number of consecutive leading bits of value b.
 -- Examples: 
 --   NUMBER_OF_LEADING_BITS("00010101111",'0') = 3
 --   NUMBER_OF_LEADING_BITS("1101",'1') = 2
 --   NUMBER_OF_LEADING_BITS("0000000",'0') = 7
 --   NUMBER_OF_LEADING_BITS("00110101",'1') = 0 
 function NUMBER_OF_LEADING_BITS(x:signed; b:std_logic) return natural;

 ----------------------------------------------------------
 -- RESIZE AND CLIP/SATURATE
 ----------------------------------------------------------

 --! @brief UNSIGNED RESIZE with overflow detection and clipping
 --! This procedure implementation resizes from the input size to the output size
 --! without additional length parameter. Furthermore, overflows are detected.
 --! If output size is larger than the input size then the new MSBs are filled 
 --! with zeros. If output size is smaller than the input size then MSBs are
 --! removed and the output is clipped by default. Clipping can be disabled.
 procedure RESIZE_CLIP (
   din  :in  unsigned; -- data input
   dout :out unsigned; -- data output
   ovfl :out std_logic; -- '1' if overflow occurred 
   clip :in  boolean:=true -- enable/disable clipping
 );

 --! @brief SIGNED RESIZE with overflow detection and clipping
 --! This procedure implementation resizes from the input size to the output size
 --! without additional length parameter. Furthermore, overflows are detected.
 --! If output size is larger than the input size then for the new MSBs the sign
 --! is extended. If output size is smaller than the input size then MSBs are
 --! removed and the output is clipped by default. Clipping can be disabled.
 procedure RESIZE_CLIP (
   din  :in  signed; -- data input
   dout :out signed; -- data output
   ovfl :out std_logic; -- '1' if overflow occurred 
   clip :in  boolean:=true -- enable/disable clipping
 );

 --! @brief UNSIGNED RESIZE to N bits with clipping
 --! If N is larger than the input size then the new MSBs are filled with zeros.
 --! If N is smaller than the input size then MSBs are removed and the output is
 --! clipped by default. When clipping is disabled the function behaves like the
 --! standard RESIZE function.
 function RESIZE_CLIP (
   din  : unsigned; -- data input
   n    : positive; -- output size
   clip : boolean:=true -- enable/disable clipping
 ) return unsigned;

 --! @brief SIGNED RESIZE to N bits with clipping
 --! If N is larger than the input size then for the new MSBs the sign is extended.
 --! If N is smaller than the input size then MSBs are removed and the output is
 --! clipped by default. When clipping is disabled the function behaves like the
 --! standard RESIZE function.
 function RESIZE_CLIP (
   din  : signed; -- data input
   n    : positive; -- output size
   clip : boolean:=true -- enable/disable clipping
 ) return signed;

 ----------------------------------------------------------
 -- SHIFT LEFT AND CLIP/SATURATE
 ----------------------------------------------------------

 --! @brief UNSIGNED SHIFT LEFT with overflow detection and clipping
 --! This procedure implementation shifts the input left by N bits and resizes
 --! the result to the output size without additional length parameter.
 --! Furthermore, overflows are detected and the output is clipped by default.
 --! Clipping can be disabled.
 procedure SHIFT_LEFT_CLIP (
   din  :in  unsigned; -- data input
   n    :in  natural; -- number of left shifts
   dout :out unsigned; -- data output
   ovfl :out std_logic; -- '1' if overflow occurred
   clip :in  boolean:=true -- enable/disable clipping
 );
 
 --! @brief SIGNED SHIFT LEFT with overflow detection and with optional clipping
 --! This procedure implementation shifts the input left by N bits and resizes
 --! the result to the output size without additional length parameter.
 --! Furthermore, overflows are detected and the output is clipped by default.
 --! Clipping can be disabled.
 procedure SHIFT_LEFT_CLIP (
   din  :in  signed; -- data input
   n    :in  natural; -- number of left shifts
   dout :out signed; -- data output
   ovfl :out std_logic; -- '1' if overflow occurred
   clip :in  boolean:=true -- enable/disable clipping
 );
 
 --! @brief UNSIGNED SHIFT LEFT by N bits with clipping
 --! The N MSBs are removed and the output is clipped by default. The N new LSBs
 --! are filled with zeros and the output has the same size as the input. When
 --! clipping is disabled the function behaves like the standard SHIFT_LEFT function.
 function SHIFT_LEFT_CLIP (
   din  : unsigned; -- data input
   n    : natural; -- number of left shifts
   clip : boolean:=true -- enable/disable clipping
 ) return unsigned;

 --! @brief SIGNED SHIFT LEFT by N bits with clipping
 --! The N MSBs are removed and the output is clipped by default. The N new LSBs
 --! are filled with zeros and the output has the same size as the input. When
 --! clipping is disabled the function behaves like the standard SHIFT_LEFT function.
 function SHIFT_LEFT_CLIP (
   din  : signed; -- data input
   n    : natural; -- number of left shifts
   clip : boolean:=true -- enable/disable clipping
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
 
 --! @brief UNSIGNED SHIFT RIGHT by N bits with rounding options
 --! By default the function behaves like the standard SHIFT_RIGHT function.
 --! The new MSBs are set to 0 and the LSBs are lost.
 --! The output has the same size as the input.
 function SHIFT_RIGHT_ROUND (
   din : unsigned; -- data input
   n   : natural; -- number of right shifts
   rnd : round_option:=floor -- enable optional rounding
 ) return unsigned;

 --! @brief SIGNED SHIFT RIGHT by N bits with rounding options
 --! By default the function behaves like the standard SHIFT_RIGHT function.
 --! For the new MSBs the sign is extended and the LSBs are lost.
 --! The output has the same size as the input.
 function SHIFT_RIGHT_ROUND (
   din : signed; -- data input
   n   : natural; -- number of right shifts
   rnd : round_option:=floor -- enable optional rounding
 ) return signed;

 --! @brief UNSIGNED SHIFT RIGHT with optional rounding and clipping and overflow detection
 --! This procedure implementation shifts the input right by N bits with rounding.
 --! The result is resized to the output size without additional length parameter.
 --! Furthermore, overflows are detected and the output is clipped when clipping
 --! is enabled.
 procedure SHIFT_RIGHT_ROUND (
   din  :in  unsigned; -- data input
   n    :in  natural; -- number of right shifts
   dout :out unsigned; -- data output
   ovfl :out std_logic; -- '1' if overflow occurred
   rnd  :in  round_option:=floor; -- enable optional rounding
   clip :in  boolean:=false -- enable clipping
 );

 --! @brief SIGNED SHIFT RIGHT with optional rounding and clipping and overflow detection
 --! This procedure implementation shifts the input right by N bits with rounding.
 --! The result is resized to the output size without additional length parameter.
 --! Furthermore, overflows are detected and the output is clipped when clipping
 --! is enabled.
 procedure SHIFT_RIGHT_ROUND (
   din  :in  signed; -- data input
   n    :in  natural; -- number of right shifts
   dout :out signed; -- data output
   ovfl :out std_logic; -- '1' if overflow occurred
   rnd  :in  round_option:=floor; -- enable optional rounding
   clip :in  boolean:=false -- enable clipping
 );

 ----------------------------------------------------------
 -- ADD AND CLIP/SATURATE
 ----------------------------------------------------------

 --! @brief UNSIGNED ADDITION with overflow detection and with optional clipping
 --! This procedure implementation adds the two inputs and resizes
 --! the result to the output size without additional length parameter.
 --! Furthermore, overflows are detected and the output is clipped when clipping
 --! is enabled.
 procedure ADD (
   l    :in  unsigned; -- data input, left summand
   r    :in  unsigned; -- data input, right summand
   dout :out unsigned; -- data output
   ovfl :out std_logic; -- '1' if overflow occurred
   clip :in  boolean:=false -- enable clipping
 );
 
 --! @brief SIGNED ADDITION with overflow detection and with optional clipping
 --! This procedure implementation adds the two inputs and resizes
 --! the result to the output size without additional length parameter.
 --! Furthermore, overflows are detected and the output is clipped when clipping
 --! is enabled.
 procedure ADD (
   l    :in  signed; -- data input, left summand
   r    :in  signed; -- data input, right summand
   dout :out signed; -- data output
   ovfl :out std_logic; -- '1' if overflow occurred
   clip :in  boolean:=false -- enable clipping
 );

 --! @brief UNSIGNED ADDITION with optional clipping
 --! Result if n=0 : unsigned(max(l'length,r'length)-1 downto 0)
 --! Result if n>0 : unsigned(n-1 downto 0)
 function ADD (
   l    : unsigned; -- data input, left summand
   r    : unsigned; -- data input, right summand
   n    : natural:=0; -- output length
   clip : boolean:=false -- enable clipping
 ) return unsigned;

 --! @brief UNSIGNED ADDITION with optional clipping
 --! Result if n=0 : unsigned(l'length-1 downto 0)
 --! Result if n>0 : unsigned(n-1 downto 0)
 function ADD (
   l    : unsigned; -- data input, left summand
   r    : natural; -- data input, right summand
   n    : natural:=0; -- output length
   clip : boolean:=false -- enable clipping
 ) return unsigned;

 --! @brief UNSIGNED ADDITION with optional clipping
 --! Result if n=0 : unsigned(r'length-1 downto 0)
 --! Result if n>0 : unsigned(n-1 downto 0)
 function ADD (
   l    : natural; -- data input, left summand
   r    : unsigned; -- data input, right summand
   n    : natural:=0; -- output length
   clip : boolean:=false -- enable clipping
 ) return unsigned;

 --! @brief SIGNED ADDITION with optional clipping
 --! Result if n=0 : signed(max(l'length,r'length)-1 downto 0)
 --! Result if n>0 : signed(n-1 downto 0)
 function ADD (
   l    : signed; -- data input, left summand
   r    : signed; -- data input, right summand
   n    : natural:=0; -- output length
   clip : boolean:=false -- enable clipping
 ) return signed;

 --! @brief SIGNED ADDITION with optional clipping
 --! Result if n=0 : signed(l'length-1 downto 0)
 --! Result if n>0 : signed(n-1 downto 0)
 function ADD (
   l    : signed; -- data input, left summand
   r    : integer; -- data input, right summand
   n    : natural:=0; -- output length
   clip : boolean:=false -- enable clipping
 ) return signed;

 --! @brief SIGNED ADDITION with optional clipping
 --! Result if n=0 : signed(r'length-1 downto 0)
 --! Result if n>0 : signed(n-1 downto 0)
 function ADD (
   l    : integer; -- data input, left summand
   r    : signed; -- data input, right summand
   n    : natural:=0; -- output length
   clip : boolean:=false -- enable clipping
 ) return signed;

 ----------------------------------------------------------
 -- SUBTRACT AND CLIP/SATURATE
 ----------------------------------------------------------

 --! @brief UNSIGNED SUBTRACTION with overflow detection and with optional clipping
 --! This procedure implementation calculates dout = l - r and resizes
 --! the result to the output size without additional length parameter.
 --! Furthermore, overflows are detected and the output is clipped when clipping
 --! is enabled.
 procedure SUB (
   l    :in  unsigned; -- data input, left minuend
   r    :in  unsigned; -- data input, right subtrahend
   dout :out unsigned; -- data output, difference
   ovfl :out std_logic; -- '1' if overflow occurred
   clip :in  boolean:=false -- enable clipping
 );
 
 --! @brief SIGNED SUBTRACTION with overflow detection and with optional clipping
 --! This procedure implementation calculates dout = l - r and resizes
 --! the result to the output size without additional length parameter.
 --! Furthermore, overflows are detected and the output is clipped when clipping
 --! is enabled.
 procedure SUB (
   l    :in  signed; -- data input, left minuend
   r    :in  signed; -- data input, right subtrahend
   dout :out signed; -- data output, difference
   ovfl :out std_logic; -- '1' if overflow occurred
   clip :in  boolean:=false -- enable clipping
 );

 --! @brief UNSIGNED SUBTRACTION with optional clipping.
 --! If n=0 then result = unsigned(max(l'length,r'length)-1 downto 0).
 --! If n>0 then result = unsigned(n-1 downto 0).
 function SUB (
   l    : unsigned; -- data input, left minuend
   r    : unsigned; -- data input, right subtrahend
   n    : natural:=0; -- output length
   clip : boolean:=false -- enable clipping
 ) return unsigned;

 --! @brief UNSIGNED SUBTRACTION with optional clipping.
 --! If n=0 then result = unsigned(l'length-1 downto 0).
 --! If n>0 then result = unsigned(n-1 downto 0).
 function SUB (
   l    : unsigned; -- data input, left minuend
   r    : natural; -- data input, right subtrahend
   n    : natural:=0; -- output length
   clip : boolean:=false -- enable clipping
 ) return unsigned;

 --! @brief UNSIGNED SUBTRACTION with optional clipping.
 --! If n=0 then result = unsigned(r'length-1 downto 0).
 --! If n>0 then result = unsigned(n-1 downto 0).
 function SUB (
   l    : natural; -- data input, left minuend
   r    : unsigned; -- data input, right subtrahend
   n    : natural:=0; -- output length
   clip : boolean:=false -- enable clipping
 ) return unsigned;

 --! @brief SIGNED SUBTRACTION with optional clipping.
 --! If n=0 then result = signed(max(l'length,r'length)-1 downto 0).
 --! If n>0 then result = signed(n-1 downto 0).
 function SUB (
   l    : signed; -- data input, left minuend
   r    : signed; -- data input, right subtrahend
   n    : natural:=0; -- output length
   clip : boolean:=false -- enable clipping
 ) return signed;

 --! @brief SIGNED SUBTRACTION with optional clipping.
 --! If n=0 then result = signed(l'length-1 downto 0).
 --! If n>0 then result = signed(n-1 downto 0).
 function SUB (
   l    : signed; -- data input, left minuend
   r    : integer; -- data input, right subtrahend
   n    : natural:=0; -- output length
   clip : boolean:=false -- enable clipping
 ) return signed;

 --! @brief SIGNED SUBTRACTION with optional clipping.
 --! If n=0 then result = signed(r'length-1 downto 0).
 --! If n>0 then result = signed(n-1 downto 0).
 function SUB (
   l    : integer; -- data input, left minuend
   r    : signed; -- data input, right subtrahend
   n    : natural:=0; -- output length
   clip : boolean:=false -- enable clipping
 ) return signed;

end package;

-------------------------------------------------------------------------------

package body ieee_extension is

 ------------------------------------------
 -- local auxiliary
 ------------------------------------------

 -- if x/=0 then return x
 -- if x=0  then return default
 function default_if_zero (x,dflt: integer) return integer is
 begin
   if x=0 then return dflt; else return x; end if;
 end function;

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

 function LOG2CEIL (n:positive; bits:positive:=32) return natural is
   variable x : unsigned(bits downto 1);
 begin
   x := to_unsigned(n-1,bits);
   for i in x'range loop
     if x(i) = '1' then return i; end if;
   end loop;
   return 1;
 end function;

 function LOG2CEIL (n:integer_vector; bits:positive:=32) return integer_vector is
   variable res : integer_vector(n'range);
 begin
   for i in n'range loop
     res(i) := LOG2CEIL(n(i),bits);
   end loop;
   return res;
 end function;

 ----------------------------------------------------------
 -- MAXIMUM and MINIMUM
 ----------------------------------------------------------

 function MAXIMUM (l,r: integer) return integer is
 begin
   if l > r then return l; else return r; end if;
 end function;

 function MINIMUM (l,r: integer) return integer is
 begin
   if l < r then return l; else return r; end if;
 end function;

 procedure MAXIMUM(
   din : in  integer_vector;
   max : out integer;
   idx : out integer
 ) is
   constant N : positive := din'length;
   constant M : integer := (din'left+din'right+1)/2;
   variable max_temp : integer;
   variable idx_temp : integer;
 begin
   max := din(din'left);
   idx := din'left;
   if N=2 then
     if din(din'right)>max then 
       max := din(din'right);
       idx := din'right;
     end if;
   elsif N>=3 then
     if din'ascending then
       MAXIMUM(din=>din(din'left to M), max=>max, idx=>idx);
       MAXIMUM(din=>din(M+1 to din'right), max=>max_temp, idx=>idx_temp);
    else
       MAXIMUM(din=>din(din'left downto M), max=>max, idx=>idx);
       MAXIMUM(din=>din(M-1 downto din'right), max=>max_temp, idx=>idx_temp);
    end if;
     if max_temp>max then
       max := max_temp;
       idx := idx_temp;
     end if;
   end if;
 end procedure;

  function MAXIMUM(x:integer_vector) return integer is
    variable max, idx : integer;
  begin
    MAXIMUM(din=>x, max=>max, idx=>idx);
    idx := idx; -- avoid warning "idx never read"
    return max;
  end function;

  function INDEX_OF_MAXIMUM(x:integer_vector) return integer is
    variable max, idx : integer;
  begin
    MAXIMUM(din=>x, max=>max, idx=>idx);
    max := max; -- avoid warning "max never read"
    return idx;
  end function;

  procedure MINIMUM(
    din : in  integer_vector;
    min : out integer;
    idx : out integer
  ) is
    constant N : positive := din'length;
    constant M : integer := (din'left+din'right+1)/2;
    variable min_temp : integer;
    variable idx_temp : integer;
  begin
    min := din(din'left);
    idx := din'left;
    if N=2 then
      if din(din'right)<min then 
        min := din(din'right);
        idx := din'right;
      end if;
    elsif N>=3 then
      if din'ascending then
        MINIMUM(din=>din(din'left to M), min=>min, idx=>idx);
        MINIMUM(din=>din(M+1 to din'right), min=>min_temp, idx=>idx_temp);
     else
        MINIMUM(din=>din(din'left downto M), min=>min, idx=>idx);
        MINIMUM(din=>din(M-1 downto din'right), min=>min_temp, idx=>idx_temp);
     end if;
      if min_temp<min then
        min := min_temp;
        idx := idx_temp;
      end if;
    end if;
  end procedure;

  function MINIMUM(x:integer_vector) return integer is
    variable min, idx : integer;
  begin
    MINIMUM(din=>x, min=>min, idx=>idx);
    idx := idx; -- avoid warning "idx never read"
    return min;
  end function;

  function INDEX_OF_MINIMUM(x:integer_vector) return integer is
    variable min, idx : integer;
  begin
    MINIMUM(din=>x, min=>min, idx=>idx);
    min := min; -- avoid warning "min never read"
    return idx;
  end function;

 function MAXIMUM (l,r: unsigned) return unsigned is
   constant N : positive := MAXIMUM(l'length,r'length);
   variable LL : unsigned(N-1 downto 0);
   variable RR : unsigned(N-1 downto 0);
 begin
   LL := resize(l,N);
   RR := resize(r,N);
   if LL > RR then return LL; else return RR; end if;
 end function;

 function MINIMUM (l,r: unsigned) return unsigned is
   constant N : positive := MAXIMUM(l'length,r'length);
   variable LL : unsigned(N-1 downto 0);
   variable RR : unsigned(N-1 downto 0);
 begin
   LL := resize(l,N);
   RR := resize(r,N);
   if LL < RR then return LL; else return RR; end if;
 end function;

  procedure MAXIMUM(
    din : in  unsigned_vector;
    max : out unsigned;
    idx : out integer
  ) is
    constant N : positive := din'length;
--    constant M : integer := (din'left+din'right+1)/2;
--    constant W : integer := din(din'left)'length;
--    variable max_temp : unsigned(W-1 downto 0);
--    variable idx_temp : integer;
  begin
    max := din(din'left);
    idx := din'left;
    if N=2 then
      if din(din'right)>max then 
        max := din(din'right);
        idx := din'right;
      end if;
    elsif N>=3 then
      for i in din'range loop
        if din(i)>max then
          max := din(i);
          idx := i;
        end if;
      end loop;
--      -- Recursive implementation preferred but currently not yet supported by GHDL
--      if din'ascending then
--        MAXIMUM(din=>din(din'left to M), max=>max, idx=>idx);
--        MAXIMUM(din=>din(M+1 to din'right), max=>max_temp, idx=>idx_temp);
--      else
--        MAXIMUM(din=>din(din'left downto M), max=>max, idx=>idx);
--        MAXIMUM(din=>din(M-1 downto din'right), max=>max_temp, idx=>idx_temp);
--      end if;
--      if max_temp>max then
--        max := max_temp;
--        idx := idx_temp;
--      end if;
    end if;
  end procedure;

  procedure MINIMUM(
    din : in  unsigned_vector;
    min : out unsigned;
    idx : out integer
  ) is
    constant N : positive := din'length;
  begin
    min := din(din'left);
    idx := din'left;
    if N=2 then
      if din(din'right)<min then 
        min := din(din'right);
        idx := din'right;
      end if;
    elsif N>=3 then
      for i in din'range loop
        if din(i)<min then
          min := din(i);
          idx := i;
        end if;
      end loop;
    end if;
  end procedure;

  function MAXIMUM(x:unsigned_vector) return unsigned is
    variable max : unsigned(x(x'left)'range);
    variable idx : integer;
  begin
    MAXIMUM(din=>x, max=>max, idx=>idx);
    idx := idx; -- avoid warning "idx never read"
    return max;
  end function;

  function MINIMUM(x:unsigned_vector) return unsigned is
    variable min : unsigned(x(x'left)'range);
    variable idx : integer;
  begin
    MINIMUM(din=>x, min=>min, idx=>idx);
    idx := idx; -- avoid warning "idx never read"
    return min;
  end function;

  function INDEX_OF_MAXIMUM(x:unsigned_vector) return integer is
    variable max : unsigned(x(x'left)'range);
    variable idx : integer;
  begin
    MAXIMUM(din=>x, max=>max, idx=>idx);
    max := max; -- avoid warning "max never read"
    return idx;
  end function;

  function INDEX_OF_MINIMUM(x:unsigned_vector) return integer is
    variable min : unsigned(x(x'left)'range);
    variable idx : integer;
  begin
    MINIMUM(din=>x, min=>min, idx=>idx);
    min := min; -- avoid warning "min never read"
    return idx;
  end function;

 ----------------------------------------------------------
 -- REVERSE order of vector elements
 ----------------------------------------------------------

 function REVERSE(arg:std_logic_vector) return std_logic_vector is
   variable res : std_logic_vector(arg'range);
   alias xarg : std_logic_vector(arg'reverse_range) is arg;
 begin
   for i in xarg'range loop res(i) := xarg(i); end loop;
   return res;
 end function;   

 function REVERSE(arg:integer_vector) return integer_vector is
   variable res : integer_vector(arg'range);
   alias xarg : integer_vector(arg'reverse_range) is arg;
 begin
   for i in xarg'range loop res(i) := xarg(i); end loop;
   return res;
 end function;
   
 function REVERSE(arg:boolean_vector) return boolean_vector is
   variable res : boolean_vector(arg'range);
   alias xarg : boolean_vector(arg'reverse_range) is arg;
 begin
   for i in xarg'range loop res(i) := xarg(i); end loop;
   return res;
 end function;
   
 function REVERSE(arg:unsigned_vector) return unsigned_vector is
   variable res : unsigned_vector(arg'range)(arg(arg'low)'range);
   alias xarg : unsigned_vector(arg'reverse_range)(arg(arg'low)'range) is arg;
 begin
   for i in xarg'range loop res(i) := xarg(i); end loop;
   return res;
 end function;
   
 function REVERSE(arg:signed_vector) return signed_vector is
   variable res : signed_vector(arg'range)(arg(arg'low)'range);
   alias xarg : signed_vector(arg'reverse_range)(arg(arg'low)'range) is arg;
 begin
   for i in xarg'range loop res(i) := xarg(i); end loop;
   return res;
 end function;

 ----------------------------------------------------------
 -- bitwise logic operations on std_logic_vector
 ----------------------------------------------------------

 -- bitwise logic OR operation on input vector
 -- Function returns '1' when one or more bits are '1'.
 function SLV_OR(arg:std_logic_vector) return std_logic is
   variable r : std_logic := '0';
 begin
   for i in arg'range loop r:=(r or arg(i)); end loop;
   return r;
 end function;

 -- bitwise logic NOR operation on input vector
 -- Function returns '1' when all bits are '0'.
 function SLV_NOR(arg:std_logic_vector) return std_logic is
 begin
   return (not SLV_OR(arg));
 end function;

 -- bitwise logic AND operation on input vector
 -- Function returns '1' when all bits are '1'.
 function SLV_AND(arg:std_logic_vector) return std_logic is
   variable r : std_logic := '1';
 begin
   for i in arg'range loop r:=(r and arg(i)); end loop;
   return r;
 end function;

 -- bitwise logic NAND operation on input vector
 -- Function returns '1' when one or more bits are '0'.
 function SLV_NAND(arg:std_logic_vector) return std_logic is
 begin
   return (not SLV_AND(arg));
 end function;

 -- bitwise logic XOR operation on input vector
 -- Function returns '1' when odd number of '1' bits.
 function SLV_XOR(x:std_logic_vector) return std_logic is
   variable r : std_logic := '0';
 begin
   for i in x'range loop r:=(r xor x(i)); end loop;
   return r;
 end function;

 -- bitwise logic XNOR operation  on input vector
 -- Function returns '0' when odd number of '0' bits.
 function SLV_XNOR(x:std_logic_vector) return std_logic is
   variable r : std_logic := '1';
 begin
   for i in x'range loop r:=(r xnor x(i)); end loop;
   return r;
 end function;

 ----------------------------------------------------------
 -- MSB/LSB check (useful e.g. for overflow detection)
 ----------------------------------------------------------

 function ALL_ONES (arg:std_logic_vector; n:integer:=0) return std_logic is
   constant L :positive := arg'length;
   alias x : std_logic_vector(L-1 downto 0) is arg; -- default range
   variable r : std_logic := '1';
 begin
   if (n=0) then -- test all
     for i in x'range loop r:=(r and x(i)); end loop;
   elsif (n>0 and n<=L) then -- test LSBs
     for i in n-1 downto 0 loop r:=(r and x(i)); end loop;
   elsif (n<0 and n>=-L) then -- test MSBs
     for i in L-1 downto L+n loop r:=(r and x(i)); end loop;
   else return 'X'; end if; 
   return r;
 end function;

 function ALL_ONES (arg:unsigned; n:integer:=0) return std_logic is
 begin
   return ALL_ONES(std_logic_vector(arg),n);
 end function;

 function ALL_ONES (arg:signed; n:integer:=0) return std_logic is
 begin
   return ALL_ONES(std_logic_vector(arg),n);
 end function;

 function ANY_ONES (arg:std_logic_vector; n:integer:=0) return std_logic is
   constant L :positive := arg'length;
   alias x : std_logic_vector(L-1 downto 0) is arg; -- default range
   variable r : std_logic := '0';
 begin
   if (n=0) then -- test all
     for i in x'range loop r:=(r or x(i)); end loop;
   elsif (n>0 and n<=L) then -- test LSBs
     for i in n-1 downto 0 loop r:=(r or x(i)); end loop;
   elsif (n<0 and n>=-L) then -- test MSBs
     for i in L-1 downto L+n loop r:=(r or x(i)); end loop;
   else return 'X'; end if; 
   return r;
 end function;

 function ANY_ONES (arg:unsigned; n:integer:=0) return std_logic is
 begin
   return ANY_ONES(std_logic_vector(arg),n);
 end function;

 function ANY_ONES (arg:signed; n:integer:=0) return std_logic is
 begin
   return ANY_ONES(std_logic_vector(arg),n);
 end function;

 function ALL_ZEROS (arg:std_logic_vector; n:integer:=0) return std_logic is
 begin
   return (not ANY_ONES(arg,n));
 end function;

 function ALL_ZEROS (arg:unsigned; n:integer:=0) return std_logic is
 begin
   return ALL_ZEROS(std_logic_vector(arg),n);
 end function;

 function ALL_ZEROS (arg:signed; n:integer:=0) return std_logic is
 begin
   return ALL_ZEROS(std_logic_vector(arg),n);
 end function;

 function ANY_ZEROS (arg:std_logic_vector; n:integer:=0) return std_logic is
 begin
   return (not ALL_ONES(arg,n));
 end function;

 function ANY_ZEROS (arg:unsigned; n:integer:=0) return std_logic is
 begin
   return ANY_ZEROS(std_logic_vector(arg),n);
 end function;

 function ANY_ZEROS (arg:signed; n:integer:=0) return std_logic is
 begin
   return ANY_ZEROS(std_logic_vector(arg),n);
 end function;

 function ALL_EQUAL (arg:std_logic_vector; n:integer:=0) return std_logic is
 begin
   return (ALL_ZEROS(arg,n) or ALL_ONES(arg,n));
 end function;

 function ALL_EQUAL (arg:unsigned; n:integer:=0) return std_logic is
 begin
   return ALL_EQUAL(std_logic_vector(arg),n);
 end function;

 function ALL_EQUAL (arg:signed; n:integer:=0) return std_logic is
 begin
   return ALL_EQUAL(std_logic_vector(arg),n);
 end function;

 ----------------
 --  BIT MISC
 ----------------

 function NUMBER_OF_ONES (arg:std_logic_vector) return natural is
   variable r : natural := 0;
 begin
   for n in arg'range loop
     if arg(n)='1' then r:=r+1; end if;
   end loop;
   return r;
 end function;
 
 function NUMBER_OF_ONES (arg:boolean_vector) return natural is
 begin
   return NUMBER_OF_ONES(to_01(arg));
 end function;

 function NUMBER_OF_ZEROS (arg:std_logic_vector) return natural is
   variable r : natural := 0;
 begin
   for n in arg'range loop
     if arg(n)='0' then r:=r+1; end if;
   end loop;
   return r;
 end function;
 
 function NUMBER_OF_ZEROS (arg:boolean_vector) return natural is
 begin
   return NUMBER_OF_ZEROS(to_01(arg));
 end function;

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
   constant L : integer range 3 to integer'high := x'length;
   alias xx : std_logic_vector(L-1 downto 0) is x; -- default range
   variable n : natural := 0;
 begin
   for i in L-2 downto 1 loop
     exit when xx(i)/=xx(L-1);
     n:=n+1;
   end loop;
   return n;
 end function;

 function NUMBER_OF_SIGN_EXTENSION_BITS(x:signed) return natural is
 begin
   return NUMBER_OF_SIGN_EXTENSION_BITS(std_logic_vector(x));
 end function;

 function NUMBER_OF_LEADING_BITS(x:std_logic_vector; b:std_logic) return natural is
   constant L : integer range 2 to integer'high := x'length;
   alias xx : std_logic_vector(L-1 downto 0) is x; -- default range
   variable n : natural := 0;
 begin
   for i in L-1 downto 0 loop
     exit when xx(i)/=b;
     n:=n+1;
   end loop;
   return n;
 end function;

 function NUMBER_OF_LEADING_BITS(x:unsigned; b:std_logic) return natural is
 begin
   return NUMBER_OF_LEADING_BITS(std_logic_vector(x),b);
 end function;

 function NUMBER_OF_LEADING_BITS(x:signed; b:std_logic) return natural is
 begin
   return NUMBER_OF_LEADING_BITS(std_logic_vector(x),b);
 end function;

 ----------------------------------------------------------
 -- RESIZE AND CLIP/SATURATE
 ----------------------------------------------------------

 -- UNSIGNED RESIZE with overflow detection and optional clipping
 procedure RESIZE_CLIP (
   din  :in  unsigned; -- data input
   dout :out unsigned; -- data output
   ovfl :out std_logic; -- '1' if overflow occurred 
   clip :in  boolean:=true -- enable/disable clipping
 ) is
   constant LIN : positive := din'length; 
   constant LOUT : positive := dout'length;
   constant N : integer := LOUT-LIN; -- N>0 add |N| MSBs , N<0 remove |N| MSBs
   alias xdout : unsigned(LOUT-1 downto 0) is dout; -- default range
 begin
   xdout := resize(din,LOUT); -- by default standard resize
   ovfl := '0'; -- by default no overflow
   if N<0 then
     -- resize down with potential overflow and clipping
     if ANY_ONES(din,N)='1' then
       -- overflow
       ovfl := '1';
       if clip then
         xdout := (others=>'1'); -- clipping
       end if;
     end if;
   end if;
 end procedure;

 -- SIGNED RESIZE with overflow detection and optional clipping
 procedure RESIZE_CLIP (
   din  :in  signed; -- data input
   dout :out signed; -- data output
   ovfl :out std_logic; -- '1' if overflow occurred 
   clip :in  boolean:=true -- enable/disable clipping
 ) is
   constant LIN : positive := din'length; 
   constant LOUT : positive := dout'length;
   constant N : integer := LOUT-LIN; -- N>0 add |N| MSBs , N<0 remove |N| MSBs
   alias xdout : signed(LOUT-1 downto 0) is dout; -- default range
 begin
   xdout := resize(din,LOUT); -- by default standard resize
   ovfl := '0'; -- by default no overflow
   if N<0 then
     -- resize down with potential overflow and clipping
     if din(din'left)='0' and ANY_ONES(din,N-1)='1' then
       ovfl := '1'; -- positive overflow
       if clip then
         xdout(LOUT-1) := '0'; -- positive clipping
         xdout(LOUT-2 downto 0) := (others=>'1');
       end if;
     elsif din(din'left)='1' and ANY_ZEROS(din,N-1)='1' then
       ovfl := '1'; -- negative overflow
       if clip then
         xdout(LOUT-1) := '1'; -- negative clipping
         xdout(LOUT-2 downto 0) := (others=>'0');
       end if;
     end if;
   end if;
 end procedure;

 -- UNSIGNED RESIZE to N bits with optional clipping
 function RESIZE_CLIP (
   din  : unsigned; -- data input
   n    : positive; -- output size
   clip : boolean:=true -- enable/disable clipping
 ) return unsigned is
   variable dummy : std_logic;
   variable dout : unsigned(n-1 downto 0);
 begin
   RESIZE_CLIP(din=>din, dout=>dout, ovfl=>dummy, clip=>clip);
   dummy := dummy; -- avoid warning "dummy never read"
   return dout;
 end function;

 -- SIGNED RESIZE to N bits with optional clipping
 function RESIZE_CLIP (
   din  : signed; -- data input
   n    : positive; -- output size
   clip : boolean:=true -- enable/disable clipping
 ) return signed is
   variable dummy : std_logic;
   variable dout : signed(n-1 downto 0);
 begin
   RESIZE_CLIP(din=>din, dout=>dout, ovfl=>dummy, clip=>clip);
   dummy := dummy; -- avoid warning "dummy never read"
   return dout;
 end function;

 ----------------------------------------------------------
 -- SHIFT LEFT AND CLIP/SATURATE
 ----------------------------------------------------------

 -- UNSIGNED SHIFT LEFT with overflow detection and with optional clipping
 procedure SHIFT_LEFT_CLIP (
   din  :in  unsigned; -- data input
   n    :in  natural; -- number of left shifts
   dout :out unsigned; -- data output
   ovfl :out std_logic; -- '1' if overflow occurred
   clip :in  boolean:=true -- enable/disable clipping
 ) is
   constant LIN : positive := din'length;
   variable temp : unsigned(LIN+n-1 downto 0) := (others=>'0');
 begin
   temp(LIN+n-1 downto n) := din;
   RESIZE_CLIP(din=>temp, dout=>dout, ovfl=>ovfl, clip=>clip);
 end procedure;
 
 -- SIGNED SHIFT LEFT with overflow detection and with optional clipping
 procedure SHIFT_LEFT_CLIP (
   din  :in  signed; -- data input
   n    :in  natural; -- number of left shifts
   dout :out signed; -- data output
   ovfl :out std_logic; -- '1' if overflow occurred
   clip :in  boolean:=true -- enable/disable clipping
 ) is
   constant LIN : positive := din'length; 
   variable temp : signed(LIN+n-1 downto 0) := (others=>'0');
 begin
   temp(LIN+n-1 downto n) := din;
   RESIZE_CLIP(din=>temp, dout=>dout, ovfl=>ovfl, clip=>clip);
 end procedure;
 
 -- UNSIGNED SHIFT LEFT by N bits with optional clipping
 function SHIFT_LEFT_CLIP (
   din  : unsigned; -- data input
   n    : natural; -- number of left shifts
   clip : boolean:=true -- enable/disable clipping
 ) return unsigned is -- data output
   constant L : positive := din'length;
   variable dout : unsigned(L-1 downto 0);
   variable dummy : std_logic;
 begin
   SHIFT_LEFT_CLIP(din=>din, n=>n, dout=>dout, ovfl=>dummy, clip=>clip);
   dummy := dummy; -- avoid warning "dummy never read"
   return dout;
 end function;

 -- SIGNED SHIFT LEFT by N bits with optional clipping
 function SHIFT_LEFT_CLIP (
   din  : signed; -- data input
   n    : natural; -- number of left shifts
   clip : boolean:=true -- enable/disable clipping
 ) return signed is -- data output
   constant L : positive := din'length;
   variable dout : signed(L-1 downto 0);
   variable dummy : std_logic;
 begin
   SHIFT_LEFT_CLIP(din=>din, n=>n, dout=>dout, ovfl=>dummy, clip=>clip);
   dummy := dummy; -- avoid warning "dummy never read"
   return dout;
 end function;

 ----------------------------------------------------------
 -- SHIFT RIGHT AND ROUND
 ----------------------------------------------------------

 -- UNSIGNED SHIFT RIGHT by N bits with rounding options
 function SHIFT_RIGHT_ROUND (
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
       if ANY_ONES(d,n)='1' then -- check LSBs
         tceil := tceil + 1;
       end if;
       dout(L-n downto 0) := tceil(L-n downto 0);
     end if;
   elsif n=L then
     if rnd=nearest then
       dout(0) := d(L-1);
     elsif (rnd=ceil or rnd=infinity) then
       dout(0) := ANY_ONES(d);
     end if;
   end if;  
   return dout;
 end function;

 -- SIGNED SHIFT RIGHT by N bits with rounding options
 function SHIFT_RIGHT_ROUND (
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
     if ANY_ONES(d,n)='1' then -- check LSBs
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
 procedure SHIFT_RIGHT_ROUND (
   din  :in  unsigned; -- data input
   n    :in  natural; -- number of right shifts
   dout :out unsigned; -- data output
   ovfl :out std_logic; -- '1' if overflow occurred
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
 procedure SHIFT_RIGHT_ROUND (
   din  :in  signed; -- data input
   n    :in  natural; -- number of right shifts
   dout :out signed; -- data output
   ovfl :out std_logic; -- '1' if overflow occurred
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
 procedure ADD (
   l    :in  unsigned; -- data input, left summand
   r    :in  unsigned; -- data input, right summand
   dout :out unsigned; -- data output
   ovfl :out std_logic; -- '1' if overflow occurred
   clip :in  boolean:=false -- enable clipping
 ) is
   constant LIN : positive := MAXIMUM(l'length,r'length);
   constant LT : positive := LIN+1; -- additional bit for overflow detection
   variable t : unsigned(LT-1 downto 0);
 begin
   t := RESIZE(l,LT) + RESIZE(r,LT);
   RESIZE_CLIP(din=>t, dout=>dout, ovfl=>ovfl, clip=>clip);
 end procedure;

 -- SIGNED ADDITION with overflow detection and with optional clipping
 procedure ADD (
   l    :in  signed; -- data input, left summand
   r    :in  signed; -- data input, right summand
   dout :out signed; -- data output
   ovfl :out std_logic; -- '1' if overflow occurred
   clip :in  boolean:=false -- enable clipping
 ) is
   constant LIN : positive := MAXIMUM(l'length,r'length);
   constant LT : positive := LIN+1; -- additional bit for overflow detection
   variable t : signed(LT-1 downto 0);
 begin
   t := RESIZE(l,LT) + RESIZE(r,LT);
   RESIZE_CLIP(din=>t, dout=>dout, ovfl=>ovfl, clip=>clip);
 end procedure;

 -- UNSIGNED ADDITION with optional clipping
 function ADD (
   l    : unsigned; -- data input, left summand
   r    : unsigned; -- data input, right summand
   n    : natural:=0; -- output length
   clip : boolean:=false -- enable clipping
 ) return unsigned is
   constant LIN : natural := MAXIMUM(l'length,r'length);
   constant LOUT : natural := default_if_zero(n, LIN);
   variable res : unsigned(LOUT-1 downto 0);
   variable dummy : std_logic;
 begin
   -- overflow not possible when LOUT>LIN
   ADD(l=>l, r=>r, dout=>res, ovfl=>dummy, clip=>(LOUT<=LIN and clip));
   dummy := dummy; -- avoid warning "dummy never read"
   return res;
 end function;

 -- UNSIGNED ADDITION with optional clipping
 function ADD (
   l    : unsigned; -- data input, left summand
   r    : natural; -- data input, right summand
   n    : natural:=0; -- output length
   clip : boolean:=false -- enable clipping
 ) return unsigned is
   constant LIN : natural := l'length;
   constant LOUT : natural := default_if_zero(n, LIN);
   variable res : unsigned(LOUT-1 downto 0);
   variable dummy : std_logic;
 begin
   ADD(l=>l, r=>to_unsigned(r,LOUT), dout=>res, ovfl=>dummy, clip=>clip);
   dummy := dummy; -- avoid warning "dummy never read"
   return res;
 end function;

 -- UNSIGNED ADDITION with optional clipping
 function ADD (
   l    : natural; -- data input, left summand
   r    : unsigned; -- data input, right summand
   n    : natural:=0; -- output length
   clip : boolean:=false -- enable clipping
 ) return unsigned is
   constant LIN : natural := r'length;
   constant LOUT : natural := default_if_zero(n, LIN);
   variable res : unsigned(LOUT-1 downto 0);
   variable dummy : std_logic;
 begin
   ADD(l=>to_unsigned(l,LOUT), r=>r, dout=>res, ovfl=>dummy, clip=>clip);
   dummy := dummy; -- avoid warning "dummy never read"
   return res;
 end function;

 -- SIGNED ADDITION with optional clipping
 function ADD (
   l    : signed; -- data input, left summand
   r    : signed; -- data input, right summand
   n    : natural:=0; -- output length
   clip : boolean:=false -- enable clipping
 ) return signed is
   constant LIN : natural := MAXIMUM(l'length,r'length);
   constant LOUT : natural := default_if_zero(n, LIN);
   variable res : signed(LOUT-1 downto 0);
   variable dummy : std_logic;
 begin
   -- overflow not possible when LOUT>LIN
   ADD(l=>l, r=>r, dout=>res, ovfl=>dummy, clip=>(LOUT<=LIN and clip));
   dummy := dummy; -- avoid warning "dummy never read"
   return res;
 end function;

 -- SIGNED ADDITION with optional clipping
 function ADD (
   l    : signed; -- data input, left summand
   r    : integer; -- data input, right summand
   n    : natural:=0; -- output length
   clip : boolean:=false -- enable clipping
 ) return signed is
   constant LIN : natural := l'length;
   constant LOUT : natural := default_if_zero(n, LIN);
   variable res : signed(LOUT-1 downto 0);
   variable dummy : std_logic;
 begin
   ADD(l=>l, r=>to_signed(r,LOUT), dout=>res, ovfl=>dummy, clip=>clip);
   dummy := dummy; -- avoid warning "dummy never read"
   return res;
 end function;

 -- SIGNED ADDITION with optional clipping
 function ADD (
   l    : integer; -- data input, left summand
   r    : signed; -- data input, right summand
   n    : natural:=0; -- output length
   clip : boolean:=false -- enable clipping
 ) return signed is
   constant LIN : natural := r'length;
   constant LOUT : natural := default_if_zero(n, LIN);
   variable res : signed(LOUT-1 downto 0);
   variable dummy : std_logic;
 begin
   ADD(l=>to_signed(l,LOUT), r=>r, dout=>res, ovfl=>dummy, clip=>clip);
   dummy := dummy; -- avoid warning "dummy never read"
   return res;
 end function;

 ----------------------------------------------------------
 -- SUBTRACT AND CLIP/SATURATE
 ----------------------------------------------------------

 -- UNSIGNED SUBTRACTION with overflow detection and with optional clipping
 procedure SUB (
   l    :in  unsigned; -- data input, left minuend
   r    :in  unsigned; -- data input, right subtrahend
   dout :out unsigned; -- data output, difference
   ovfl :out std_logic; -- '1' if overflow occurred
   clip :in  boolean:=false -- enable clipping
 ) is
   constant LIN : positive := MAXIMUM(l'length,r'length);
   constant LOUT : positive := dout'length;
   constant LT : positive := MAXIMUM(LIN+1,LOUT); -- additional bit for overflow detection
   variable t : unsigned(LT-1 downto 0);
   variable uvf, ovf : std_logic;
 begin
   t := RESIZE(l,LT) - RESIZE(r,LT);
   uvf := t(LT-1); -- underflow ?
   if clip and t(LT-1)='1' then
     dout := (dout'range=>'0'); -- negative saturation
   else
     RESIZE_CLIP(din=>t, dout=>dout, ovfl=>ovf, clip=>clip);
   end if;
   ovfl := uvf  or ovf;
 end procedure;

 -- SIGNED SUBTRACTION with overflow detection and with optional clipping
 procedure SUB (
   l    :in  signed; -- data input, left minuend
   r    :in  signed; -- data input, right subtrahend
   dout :out signed; -- data output, difference
   ovfl :out std_logic; -- '1' if overflow occurred
   clip :in  boolean:=false -- enable clipping
 ) is
   constant LIN : positive := MAXIMUM(l'length,r'length);
   constant LOUT : positive := dout'length;
   constant LT : positive := MAXIMUM(LIN+1,LOUT);-- additional bit for overflow detection
   variable t : signed(LT-1 downto 0);
 begin
   t := RESIZE(l,LT) - RESIZE(r,LT);
   RESIZE_CLIP(din=>t, dout=>dout, ovfl=>ovfl, clip=>clip);
 end procedure;

 -- UNSIGNED SUBTRACTION with optional clipping
 function SUB (
   l    : unsigned; -- data input, left minuend
   r    : unsigned; -- data input, right subtrahend
   n    : natural:=0; -- output length
   clip : boolean:=false -- enable clipping
 ) return unsigned is
   constant LIN : natural := MAXIMUM(l'length,r'length);
   constant LOUT : natural := default_if_zero(n, LIN);
   variable res : unsigned(LOUT-1 downto 0);
   variable dummy : std_logic;
 begin
   -- overflow not possible when LOUT>LIN
   SUB(l=>l, r=>r, dout=>res, ovfl=>dummy, clip=>(LOUT<=LIN and clip));
   dummy := dummy; -- avoid warning "dummy never read"
   return res;
 end function;

 -- UNSIGNED SUBTRACTION with optional clipping
 function SUB (
   l    : unsigned; -- data input, left minuend
   r    : natural; -- data input, right subtrahend
   n    : natural:=0; -- output length
   clip : boolean:=false -- enable clipping
 ) return unsigned is
   constant LIN : natural := l'length;
   constant LOUT : natural := default_if_zero(n, LIN);
   variable res : unsigned(LOUT-1 downto 0);
   variable dummy : std_logic;
 begin
   SUB(l=>l, r=>to_unsigned(r,LOUT), dout=>res, ovfl=>dummy, clip=>clip);
   dummy := dummy; -- avoid warning "dummy never read"
   return res;
 end function;

 -- UNSIGNED SUBTRACTION with optional clipping
 function SUB (
   l    : natural; -- data input, left minuend
   r    : unsigned; -- data input, right subtrahend
   n    : natural:=0; -- output length
   clip : boolean:=false -- enable clipping
 ) return unsigned is
   constant LIN : natural := r'length;
   constant LOUT : natural := default_if_zero(n, LIN);
   variable res : unsigned(LOUT-1 downto 0);
   variable dummy : std_logic;
 begin
   SUB(l=>to_unsigned(l,LOUT), r=>r, dout=>res, ovfl=>dummy, clip=>clip);
   dummy := dummy; -- avoid warning "dummy never read"
   return res;
 end function;

 -- SIGNED SUBTRACTION with optional clipping
 function SUB (
   l    : signed; -- data input, left minuend
   r    : signed; -- data input, right subtrahend
   n    : natural:=0; -- output length
   clip : boolean:=false -- enable clipping
 ) return signed is
   constant LIN : natural := MAXIMUM(l'length,r'length);
   constant LOUT : natural := default_if_zero(n, LIN);
   variable res : signed(LOUT-1 downto 0);
   variable dummy : std_logic;
 begin
   -- overflow not possible when LOUT>LIN
   SUB(l=>l, r=>r, dout=>res, ovfl=>dummy, clip=>(LOUT<=LIN and clip));
   dummy := dummy; -- avoid warning "dummy never read"
   return res;
 end function;

 -- SIGNED SUBTRACTION with optional clipping
 function SUB (
   l    : signed; -- data input, left minuend
   r    : integer; -- data input, right subtrahend
   n    : natural:=0; -- output length
   clip : boolean:=false -- enable clipping
 ) return signed is
   constant LIN : natural := l'length;
   constant LOUT : natural := default_if_zero(n, LIN);
   variable res : signed(LOUT-1 downto 0);
   variable dummy : std_logic;
 begin
   SUB(l=>l, r=>to_signed(r,LOUT), dout=>res, ovfl=>dummy, clip=>clip);
   dummy := dummy; -- avoid warning "dummy never read"
   return res;
 end function;

 -- SIGNED SUBTRACTION with optional clipping
 function SUB (
   l    : integer; -- data input, left minuend
   r    : signed; -- data input, right subtrahend
   n    : natural:=0; -- output length
   clip : boolean:=false -- enable clipping
 ) return signed is
   constant LIN : natural := r'length;
   constant LOUT : natural := default_if_zero(n, LIN);
   variable res : signed(LOUT-1 downto 0);
   variable dummy : std_logic;
 begin
   SUB(l=>to_signed(l,LOUT), r=>r, dout=>res, ovfl=>dummy, clip=>clip);
   dummy := dummy; -- avoid warning "dummy never read"
   return res;
 end function;

end package body;
 