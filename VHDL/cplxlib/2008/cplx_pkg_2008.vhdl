-------------------------------------------------------------------------------
--! @file       cplx_pkg_2008.vhdl
--! @author     Fixitfetish
--! @date       25/Sep/2019
--! @version    1.30
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension.all;
  use baselib.ieee_extension_types.all;

--! @brief This package provides types, functions and procedures that allow basic
--! operations with complex integer numbers. Only the most common signals are
--! taken into account. The functions and procedures are designed in a way to
--! use as few logic elements as possible. 
--! 
--! Please note that multiplications, divisions and so on are not part of this
--! package since they typically make use of hardware specific DSP cells and
--! require registers in addition. Corresponding entities have been (or can be)
--! developed based on this package.
--!
package cplx_pkg is

  ------------------------------------------
  -- TYPES
  ------------------------------------------

  --! General unconstrained complex type
  type cplx is
  record
    rst : std_logic; --! reset
    vld : std_logic; --! data valid
    ovf : std_logic; --! data overflow (or clipping)
    re  : signed; --! data real component ("downto" direction assumed)
    im  : signed; --! data imaginary component ("downto" direction assumed)
  end record;

  subtype cplx4  is cplx(re( 3 downto 0), im( 3 downto 0));
  subtype cplx5  is cplx(re( 4 downto 0), im( 4 downto 0));
  subtype cplx6  is cplx(re( 5 downto 0), im( 5 downto 0));
  subtype cplx7  is cplx(re( 6 downto 0), im( 6 downto 0));
  subtype cplx8  is cplx(re( 7 downto 0), im( 7 downto 0));
  subtype cplx9  is cplx(re( 8 downto 0), im( 8 downto 0));
  subtype cplx10 is cplx(re( 9 downto 0), im( 9 downto 0));
  subtype cplx11 is cplx(re(10 downto 0), im(10 downto 0));
  subtype cplx12 is cplx(re(11 downto 0), im(11 downto 0));
  subtype cplx13 is cplx(re(12 downto 0), im(12 downto 0));
  subtype cplx14 is cplx(re(13 downto 0), im(13 downto 0));
  subtype cplx15 is cplx(re(14 downto 0), im(14 downto 0));
  subtype cplx16 is cplx(re(15 downto 0), im(15 downto 0));
  subtype cplx17 is cplx(re(16 downto 0), im(16 downto 0));
  subtype cplx18 is cplx(re(17 downto 0), im(17 downto 0));
  subtype cplx19 is cplx(re(18 downto 0), im(18 downto 0));
  subtype cplx20 is cplx(re(19 downto 0), im(19 downto 0));
  subtype cplx21 is cplx(re(20 downto 0), im(20 downto 0));
  subtype cplx22 is cplx(re(21 downto 0), im(21 downto 0));
  subtype cplx23 is cplx(re(22 downto 0), im(22 downto 0));
  subtype cplx24 is cplx(re(23 downto 0), im(23 downto 0));
  subtype cplx25 is cplx(re(24 downto 0), im(24 downto 0));
  subtype cplx26 is cplx(re(25 downto 0), im(25 downto 0));
  subtype cplx27 is cplx(re(26 downto 0), im(26 downto 0));
  subtype cplx28 is cplx(re(27 downto 0), im(27 downto 0));
  subtype cplx29 is cplx(re(28 downto 0), im(28 downto 0));
  subtype cplx30 is cplx(re(29 downto 0), im(29 downto 0));
  subtype cplx31 is cplx(re(30 downto 0), im(30 downto 0));
  subtype cplx32 is cplx(re(31 downto 0), im(31 downto 0));
  subtype cplx33 is cplx(re(32 downto 0), im(32 downto 0));
  subtype cplx34 is cplx(re(33 downto 0), im(33 downto 0));
  subtype cplx35 is cplx(re(34 downto 0), im(34 downto 0));
  subtype cplx36 is cplx(re(35 downto 0), im(35 downto 0));

  --! General unconstrained complex vector type (preferably "to" direction)
  type cplx_vector is array(integer range <>) of cplx;

  subtype cplx4_vector  is cplx_vector(open)(re( 3 downto 0), im( 3 downto 0));
  subtype cplx5_vector  is cplx_vector(open)(re( 4 downto 0), im( 4 downto 0));
  subtype cplx6_vector  is cplx_vector(open)(re( 5 downto 0), im( 5 downto 0));
  subtype cplx7_vector  is cplx_vector(open)(re( 6 downto 0), im( 6 downto 0));
  subtype cplx8_vector  is cplx_vector(open)(re( 7 downto 0), im( 7 downto 0));
  subtype cplx9_vector  is cplx_vector(open)(re( 8 downto 0), im( 8 downto 0));
  subtype cplx10_vector is cplx_vector(open)(re( 9 downto 0), im( 9 downto 0));
  subtype cplx11_vector is cplx_vector(open)(re(10 downto 0), im(10 downto 0));
  subtype cplx12_vector is cplx_vector(open)(re(11 downto 0), im(11 downto 0));
  subtype cplx13_vector is cplx_vector(open)(re(12 downto 0), im(12 downto 0));
  subtype cplx14_vector is cplx_vector(open)(re(13 downto 0), im(13 downto 0));
  subtype cplx15_vector is cplx_vector(open)(re(14 downto 0), im(14 downto 0));
  subtype cplx16_vector is cplx_vector(open)(re(15 downto 0), im(15 downto 0));
  subtype cplx17_vector is cplx_vector(open)(re(16 downto 0), im(16 downto 0));
  subtype cplx18_vector is cplx_vector(open)(re(17 downto 0), im(17 downto 0));
  subtype cplx19_vector is cplx_vector(open)(re(18 downto 0), im(18 downto 0));
  subtype cplx20_vector is cplx_vector(open)(re(19 downto 0), im(19 downto 0));
  subtype cplx21_vector is cplx_vector(open)(re(20 downto 0), im(20 downto 0));
  subtype cplx22_vector is cplx_vector(open)(re(21 downto 0), im(21 downto 0));
  subtype cplx23_vector is cplx_vector(open)(re(22 downto 0), im(22 downto 0));
  subtype cplx24_vector is cplx_vector(open)(re(23 downto 0), im(23 downto 0));
  subtype cplx25_vector is cplx_vector(open)(re(24 downto 0), im(24 downto 0));
  subtype cplx26_vector is cplx_vector(open)(re(25 downto 0), im(25 downto 0));
  subtype cplx27_vector is cplx_vector(open)(re(26 downto 0), im(26 downto 0));
  subtype cplx28_vector is cplx_vector(open)(re(27 downto 0), im(27 downto 0));
  subtype cplx29_vector is cplx_vector(open)(re(28 downto 0), im(28 downto 0));
  subtype cplx30_vector is cplx_vector(open)(re(29 downto 0), im(29 downto 0));
  subtype cplx31_vector is cplx_vector(open)(re(30 downto 0), im(30 downto 0));
  subtype cplx32_vector is cplx_vector(open)(re(31 downto 0), im(31 downto 0));
  subtype cplx33_vector is cplx_vector(open)(re(32 downto 0), im(32 downto 0));
  subtype cplx34_vector is cplx_vector(open)(re(33 downto 0), im(33 downto 0));
  subtype cplx35_vector is cplx_vector(open)(re(34 downto 0), im(34 downto 0));
  subtype cplx36_vector is cplx_vector(open)(re(35 downto 0), im(35 downto 0));

  --! Definition of options
  type cplx_option is (
    '-', -- don't care, use defaults
    'D', -- round down towards minus infinity, floor (default, just remove LSBs)
    'I', -- round towards plus/minus infinity, i.e. away from zero
    'N', -- round to nearest (standard rounding, i.e. +0.5 and then remove LSBs)
    'O', -- enable overflow/underflow detection (by default off)
    'R', -- use reset on RE/IM (set RE=0 and IM=0)
    'S', -- enable saturation/clipping (by default off)
    'U', -- round up towards plus infinity, ceil
    'X', -- ignore/discard input overflow flag
    'Z'  -- round towards zero, truncate
--  'F'  -- flush, required/needed ?
--  'C'  -- clear, required/needed ?
--  'H'  -- hold last valid output data when invalid (toggle rate reduction)
  );
  
  --! @brief Complex operations can be used with one or more of the following options.
  --! Note that some options can not be combined, e.g. different rounding options.
  --! Use options carefully and only when really required. Some options can have
  --! a negative influence on logic consumption and timing. @link cplx_mode More...
  --!
  --! * '-' -- don't care, use defaults
  --! * 'D' -- round down towards minus infinity, floor (default, just remove LSBs)
  --! * 'I' -- round towards plus/minus infinity, i.e. away from zero
  --! * 'N' -- round to nearest (standard rounding, i.e. +0.5 and then remove LSBs)
  --! * 'O' -- enable overflow/underflow detection (by default off)
  --! * 'R' -- use reset on RE/IM (set RE=0 and IM=0)
  --! * 'S' -- enable saturation/clipping (by default off)
  --! * 'U' -- round up towards plus infinity, ceil
  --! * 'X' -- ignore/discard input overflow flag
  --! * 'Z' -- round towards zero, truncate
  --! 
  --! Option X : By default the overflow flags of the inputs are propagated
  --! to the output to not loose the overflow flags in processing chains.
  --! If the input overflow flag is ignored in a module then output overflow
  --! flag only reports overflows that occur within the module. Note that
  --! ignoring the input overflows can save a little bit of logic.
  type cplx_mode is array(integer range <>) of cplx_option;

  ------------------------------------------
  -- auxiliary
  ------------------------------------------

  --! check if a certain option is enabled
  function "=" (l:cplx_mode; r:cplx_option) return boolean;

  --! check if a certain option is disabled
  function "/=" (l:cplx_mode; r:cplx_option) return boolean;

  ------------------------------------------
  -- RESET
  ------------------------------------------


  --! @brief Get complex reset value.
  --! RE/IM data will be 0 with option 'R', otherwise data is do-not-care.
  function cplx_reset (
    constant w : positive range 2 to integer'high; -- RE/IM data width in bits
    constant m : cplx_mode:="-" -- mode, supported options: 'R'
  ) return cplx;

  --! @brief Get complex vector reset value.
  --! RE/IM data will be 0 with option 'R', otherwise data is do-not-care.
  function cplx_vector_reset (
    w : positive range 2 to integer'high; -- RE/IM data width in bits
    n : positive; -- number of vector elements
    m : cplx_mode:="-" -- mode, supported options: 'R'
  ) return cplx_vector;

  --! @brief Complex data reset on demand - to be placed into the data path.
  --! Forces VLD and OVF and with 'R' option also RE/IM to '0' when RST='1'.
  function cplx_reset (
    din : cplx; -- data input
    m   : cplx_mode:="-" -- mode, supported options: 'R'
  ) return cplx;

  --! @brief Complex data reset on demand - to be placed into the data path.
  --! Forces VLD and OVF and with 'R' option also RE/IM to '0' when RST='1'.
  function cplx_vector_reset (
    din : cplx_vector; -- data input
    m   : cplx_mode:="-" -- mode, supported options: 'R'
  ) return cplx_vector;

  ------------------------------------------
  -- RESIZE
  ------------------------------------------

  --! @brief Resize to given bit width (similar to NUMERIC_STD).
  --! Supported options: 'R', 'O', 'X' and/or 'S'
  function resize(
    din : cplx; -- data input
    w   : positive range 2 to integer'high; -- output bit width
    m   : cplx_mode:="-" -- mode, supported options: 'R', 'O', 'X' and/or 'S'
  ) return cplx;

  --! @brief Resize to size of connected output.
  --! Supported options: 'R', 'O', 'X' and/or 'S'
  procedure resize (
    din  : in  cplx; -- data input
    dout : out cplx; -- data output
    m    : in  cplx_mode:="-" -- mode, supported options: 'R', 'O', 'X' and/or 'S'
  );

  --! @brief Resize each vector element to given bit width.
  --! Supported options: 'R', 'O', 'X' and/or 'S'
  function resize (
    din : cplx_vector; -- data input vector
    w   : positive range 2 to integer'high; -- output bit width
    m   : cplx_mode:="-" -- mode, supported options: 'R', 'O', 'X and/or 'S'
  ) return cplx_vector;

  ------------------------------------------
  -- Basic complex arithmetic
  ------------------------------------------

  --! @brief Complex negation with overflow detection.
  --! Wrap only occurs when input is most-negative number
  --! (bit width of output equals the bit width of input)
  function "-" (din:cplx) return cplx;

  --! @brief Complex vector negation with overflow detection.
  --! Wrap only occurs when input is most-negative number
  --! (bit width of output equals the bit width of input)
  function "-" (din:cplx_vector) return cplx_vector;

  --! @brief Complex conjugate.
  --! w=0 : output bit width is equal to the maximum input bit width
  --! w>0 : output bit width is w (includes resize)
  -- supported options: 'R', 'O' and/or 'S'
  function conj (
    din  : cplx; -- data input
    w    : natural:=0; -- output bit width
    m    : cplx_mode:="-" -- mode, supported options: 'R', 'O', 'X' and/or 'S'
  ) return cplx;

  --! @brief Complex vector conjugate.
  function conj (
    din  : cplx_vector; -- data input
    w    : natural:=0; -- output bit width
    m    : cplx_mode:="-" -- mode, supported options: 'R', 'O', 'X' and/or 'S'
  ) return cplx_vector;

  --! @brief Swap real and imaginary components.
  --! (bit width of output equals the bit width of input)
  function swap (din:cplx) return cplx;
    
  --! @brief Swap real and imaginary components for each vector element.
  function swap (din:cplx_vector) return cplx_vector;

  ------------------------------------------
  -- ADDITION and ACCUMULATION
  ------------------------------------------

  --! @brief Complex addition with optional clipping and overflow detection.
  --! dout = l + r  (result sum is resized to size of connected output).
  --! Supported options: 'R', 'O', 'X' and/or 'S'
  procedure add (
    l,r  : in  cplx; -- left/right summand
    dout : out cplx; -- data output, sum
    m    : in  cplx_mode:="-" -- mode, supported options: 'R', 'O', 'X' and/or 'S'
  );

  --! @brief Complex addition with optional clipping and overflow detection.
  --! w=0 : output bit width is equal to the maximum input bit width,
  --! w>0 : output bit width is w (includes resize).
  --! Supported options: 'R', 'O', 'X' and/or 'S'
  function add (
    l,r  : cplx; -- left/right summand
    w    : natural:=0; -- output bit width
    m    : cplx_mode:="-" -- mode, supported options: 'R', 'O', 'X' and/or 'S'
  ) return cplx;

  function add (
    l,r  : cplx_vector; -- left/right summand
    w    : natural:=0; -- output bit width
    m    : cplx_mode:="-" -- mode, supported options: 'R', 'O', 'X' and/or 'S'
  ) return cplx_vector;

  --! @brief Complex addition with wrap and overflow detection.
  --! The output width of sum equals the max width of summands.
  --! Alternatively use function ADD() for more options.
  function "+" (l,r: cplx) return cplx;

  function "+" (l,r: cplx_vector) return cplx_vector;

  --! @brief Sum of vector elements with optional clipping and overflow detection.
  --! w=0 : output bit width is equal to input bit width,
  --! w>0 : output bit width is w (includes resize).
  --! Supported options: 'R', 'O', 'X' and/or 'S'
  function sum (
    din  : cplx_vector; -- data input vector
    w    : natural:=0; -- output bit width
    m    : cplx_mode:="-" -- mode, supported options: 'R', 'O', 'X' and/or 'S'
  ) return cplx;

  --! @brief Sum of vector elements with optional clipping and overflow detection.
  --! (sum result is resized to size of connected output).
  --! Supported options: 'R', 'O', 'X' and/or 'S'
  procedure sum (
    din  : in  cplx_vector; -- data input vector
    dout : out cplx; -- data output, sum
    m    : in  cplx_mode:="-" -- mode, supported options: 'R', 'O', 'X' and/or 'S'
  );

  ------------------------------------------
  -- SUBTRACTION
  ------------------------------------------

  --! @brief Complex subtraction with optional clipping and overflow detection.
  --! dout = l - r  (difference result is resized to size of connected output).
  --! Supported options: 'R', 'O', 'X' and/or 'S'
  procedure sub (
    l,r  : in  cplx; -- data input, left minuend, right subtrahend
    dout : out cplx; -- data output, difference
    m    : in  cplx_mode:="-" -- mode, supported options: 'R', 'O', 'X' and/or 'S'
  );

  --! @brief Complex subtraction with optional clipping and overflow detection
  --! w=0 : output bit width is equal to the maximum input bit width,
  --! w>0 : output bit width is w (includes resize).
  --! Supported options: 'R', 'O', 'X' and/or 'S'
  function sub (
    l,r  : cplx; -- data input, left minuend, right subtrahend
    w    : natural:=0; -- output bit width
    m    : cplx_mode:="-" -- mode, supported options: 'R', 'O', 'X' and/or 'S'
  ) return cplx;

  function sub (
    l,r  : cplx_vector; -- data input, left minuend, right subtrahend
    w    : natural:=0; -- output bit width
    m    : cplx_mode:="-" -- mode, supported options: 'R', 'O', 'X' and/or 'S'
  ) return cplx_vector;

  --! @brief Complex subtraction with wrap and overflow detection.
  --! The output width of difference equals the max width of left minuend and right subtrahend.
  --! Alternatively use function SUB() for more options.
  function "-" (l,r: cplx) return cplx;

  function "-" (l,r: cplx_vector) return cplx_vector;

  ------------------------------------------
  -- SHIFT LEFT AND SATURATE/CLIP
  ------------------------------------------

  --! @brief Complex signed shift left by n bits with optional clipping/saturation and overflow detection.
  --! Result dout is resized to size of connected output.
  --! Supported options: 'R', 'O', 'X' and/or 'S'
  procedure shift_left (
    din  : in  cplx; -- data input
    n    : in  natural; -- number of left shifts
    dout : out cplx; -- data output
    m    : in  cplx_mode:="-" -- mode
  );

  --! @brief Complex signed shift left by n bits with optional clipping/saturation and overflow detection.
  --! The output bit width equals the input bit width.
  --! Supported options: 'R', 'O', 'X' and/or 'S'
  function shift_left (
    din  : cplx; -- data input
    n    : natural; -- number of left shifts
    m    : cplx_mode:="-" -- mode
  ) return cplx;

  --! @brief Complex signed shift left by n bits with optional clipping/saturation and overflow detection.
  --! The output bit width equals the input bit width.
  --! Supported options: 'R', 'O', 'X' and/or 'S'
  function shift_left (
    din  : cplx_vector; -- data input
    n    : natural; -- number of left shifts
    m    : cplx_mode:="-" -- mode
  ) return cplx_vector;

  ------------------------------------------
  -- SHIFT RIGHT and ROUND
  ------------------------------------------

  --! @brief Complex signed shift right by n bits with optional rounding.
  --! The output bit width equals the input bit width.
  --! Supported options: 'R', 'X and/or ('D','N','U','Z' or 'I')
  function shift_right (
    din  : cplx; -- data input
    n    : natural; -- number of right shifts
    m    : cplx_mode:="-" -- mode
  ) return cplx;

  --! @brief Complex signed shift right by n bits with optional rounding.
  --! The output bit width equals the input bit width.
  --! Supported options: 'R', 'X' and/or ('D','N','U','Z' or 'I')
  function shift_right (
    din  : cplx_vector; -- data input
    n    : natural; -- number of right shifts
    m    : cplx_mode:="-" -- mode
  ) return cplx_vector;

  --! @brief Complex signed shift right by n bits with optional rounding.
  --! Result dout is resized to size of connected output.
  --! Supported options: 'R', 'O', 'X', 'S' and/or ('D','N','U','Z' or 'I')
  procedure shift_right (
    din  : in  cplx; -- data input
    n    : in  natural; -- number of right shifts
    dout : out cplx; -- data output
    m    : in  cplx_mode:="-" -- mode
  );

  ------------------------------------------
  -- Conversion
  ------------------------------------------

  --! @brief Reverse order of vector elements without changing the index direction.
  --! To reverse the index direction (to<=>downto) use reverse_range attribute instead.
  function REVERSE(arg:cplx_vector) return cplx_vector;

  --! @brief Merge separate vectors of signed real and imaginary values into one CPLX vector.
  --! Input real and imaginary vectors must have same length.
  function to_cplx_vector (
    re  : signed_vector; -- vector of real values (same length as imaginary)
    im  : signed_vector; -- vector of imaginary values (same length as real)
    vld : std_logic := '1'; -- data valid
    rst : std_logic := '0' -- reset
  ) return cplx_vector;

  --! @brief Extract all real components of a CPLX vector and output as signed vector.
  function real (
    din : cplx_vector
  ) return signed_vector;

  --! @brief Extract all imaginary components of a CPLX vector and output as signed vector.
  function imag (
    din : cplx_vector
  ) return signed_vector;

  ------------------------------------------
  -- STD_LOGIC_VECTOR to CPLX
  ------------------------------------------

  --! @brief Convert SLV to cplx, L = SLV'length must be even.
  --! real = L/2 LSBs, imaginary = L/2 MSBs.
  --! Use swap() before conversion to have imaginary part in LSBs.
  function to_cplx (
    slv : std_logic_vector; -- data input
    vld : std_logic; -- data valid
    rst : std_logic := '0' -- reset
  ) return cplx;

  --! @brief Convert SLV to cplx_vector, L = SLV'length must be a multiple of 2*n .
  --! L/n bits per vector element : real = L/n/2 LSBs, imaginary = L/n/2 MSBs .
  --! Use swap() before conversion to have imaginary part in LSBs.
  function to_cplx_vector (
    slv : std_logic_vector; -- data input vector
    n   : positive; -- number of required vector elements
    vld : std_logic; -- data valid
    rst : std_logic := '0' -- reset
  ) return cplx_vector;

  ------------------------------------------
  -- CPLX to STD_LOGIC_VECTOR
  ------------------------------------------

  --! @brief Convert cplx to SLV, real=LSBs, imaginary=MSBs.
  --! Output length = din.re'length + din.im'length .
  --! Use swap() after conversion if imaginary part is in LSBs of SLV.
  --! Supported options: 'R'
  function to_slv(
    din : cplx;
    m   : cplx_mode:="-" -- mode, optional reset
  ) return std_logic_vector;

  --! @brief Convert cplx_vector to SLV (real=LSBs, imaginary=MSBs per vector element).
  --! Output length = din'length * (din.re'length + din.im'length).
  --! Use swap() after conversion if imaginary part is in LSBs of SLV.
  --! Supported options: 'R'
  function to_slv(
    din : cplx_vector;
    m   : cplx_mode:="-" -- mode, optional reset
  ) return std_logic_vector;

  ------------------------------------------
  -- Convert CPLX record into STD_LOGIC_VECTOR
  -- (useful for interfaces which do not support records)
  ------------------------------------------

  --! @brief Convert all elements of the cplx record to a single SLV.
  function record_to_slv(
    din : cplx
  ) return std_logic_vector;

  --! @brief Convert all elements of the cplx_vector record to a single SLV.
  function record_to_slv(
    din : cplx_vector
  ) return std_logic_vector;

  --! @brief Convert SLV to cplx record.
  function slv_to_record(
    slv : std_logic_vector
  ) return cplx;

  --! @brief Convert SLV to cplx_vector record.
  --! The number of expected vector elements N must be provided.
  function slv_to_record (
    slv : std_logic_vector;
    n   : positive
  ) return cplx_vector;

  --! @brief Convert SLV to cplx_vector record.
  --! The number of expected vector elements N is derived from the connected cplx_vector output length.
  procedure slv_to_record (
    din  : in  std_logic_vector;
    dout : out cplx_vector
  );

end package;

-------------------------------------------------------------------------------

package body cplx_pkg is

  ------------------------------------------
  -- local auxiliary
  ------------------------------------------
  
 -- if x/=0 then return x
 -- if x=0  then return dflt (default)
 function default_if_zero (x,dflt: integer) return integer is
 begin
   if x=0 then return dflt; else return x; end if;
 end function;

  ------------------------------------------
  -- auxiliary
  ------------------------------------------

  -- check if mode includes a specific option
  function "=" (l:cplx_mode; r:cplx_option) return boolean is
  begin
    for i in l'range loop
      if l(i)=r then return true; end if;
    end loop;
    return false;
  end function;

  function "/=" (l:cplx_mode; r:cplx_option) return boolean is
  begin
    return not(l=r);
  end function;

  ------------------------------------------
  -- RESET
  ------------------------------------------

  function cplx_reset (
    constant w : positive range 2 to integer'high; -- data RE/IM width in bits
    constant m : cplx_mode:="-" -- mode, supported options: 'R'
  ) return cplx is
    variable dout : cplx(re(w-1 downto 0),im(w-1 downto 0));
  begin
    dout.rst := '1'; dout.vld := '0'; dout.ovf := '0';
    if m='R' then
      dout.re := (others=>'0'); dout.im := (others=>'0');
--      dout := (rst=>'1', vld|ovf=>'0', re|im=>(others=>'0')); -- not supported by all tools
    else
      dout.re := (others=>'-'); dout.im := (others=>'-');
--      dout := (rst=>'1', vld|ovf=>'0', re|im=>(w-1 downto 0=>'-')); -- not supported by all tools
    end if;
    return dout;
  end function;

  function cplx_vector_reset (
    w : positive range 2 to integer'high; -- data RE/IM width in bits
    n : positive; -- number of vector elements
    m : cplx_mode:="-" -- mode, supported options: 'R'
  ) return cplx_vector is
    variable dout : cplx_vector(1 to n)(re(w-1 downto 0),im(w-1 downto 0));
  begin
    for i in dout'range loop dout(i):=cplx_reset(w=>w, m=>m); end loop;
    return dout;
  end function;

  function cplx_reset (din:cplx; m:cplx_mode:="-") return cplx is
    variable dout : cplx(re(din.re'range),im(din.im'range));
  begin
    dout := din; -- by default output = input
    if din.rst='1' then
      dout.vld:='0'; dout.ovf:='0'; -- always reset control signals
      -- reset data only when explicitly wanted
      if m='R' then dout.re:=(din.re'range=>'0'); dout.im:=(din.im'range=>'0'); end if;
    end if;
    return dout;
  end function;

  function cplx_vector_reset (
    din : cplx_vector; -- data input
    m   : cplx_mode:="-" -- mode, supported options: 'R'
  ) return cplx_vector is
    variable dout : cplx_vector(din'range)(re(din(din'left).re'range),im(din(din'left).im'range));
  begin
    for i in din'range loop dout(i):=cplx_reset(din=>din(i), m=>m); end loop; 
    return dout;
  end function;

  ------------------------------------------
  -- RESIZE
  ------------------------------------------

  function resize (
    din : cplx; -- data input
    w   : positive range 2 to integer'high; -- output bit width
    m   : cplx_mode:="-" -- mode, supported options: 'R','O', 'X' and/or 'S'
  ) return cplx is
    variable ovf_re, ovf_im : std_logic;
    variable dout : cplx(re(w-1 downto 0),im(w-1 downto 0));
  begin
    dout.rst:=din.rst; dout.vld:=din.vld; -- just forward signals
    if m='X' then dout.ovf:='0'; else dout.ovf:=din.ovf; end if; -- ignore input overflow ?
    RESIZE_CLIP(din=>din.re, dout=>dout.re, ovfl=>ovf_re, clip=>(m='S'));
    RESIZE_CLIP(din=>din.im, dout=>dout.im, ovfl=>ovf_im, clip=>(m='S'));
    -- If enabled this function reports overflows (only for valid data).
    if m='O' then dout.ovf := dout.ovf or (dout.vld and (ovf_re or ovf_im)); end if;
    dout := cplx_reset(din=>dout, m=>m);
    return dout;
  end function;

  procedure resize (
    din  : in  cplx; -- data input
    dout : out cplx; -- data output
    m    : in  cplx_mode:="-" -- mode, supported options: 'R','O', 'X' and/or 'S'
  ) is
    constant LOUT : positive := dout.re'length;
  begin
    dout := resize(din=>din, w=>LOUT, m=>m);
  end procedure;

  ------------------------------------------
  -- RESIZE VECTOR
  ------------------------------------------

  function resize (
    din : cplx_vector; -- data input vector
    w   : positive range 2 to integer'high; -- output bit width
    m   : cplx_mode:="-" -- mode, supported options: 'R','O', 'X' and/or 'S'
  ) return cplx_vector is
    variable dout : cplx_vector(din'range)(re(w-1 downto 0),im(w-1 downto 0));
  begin
    for i in din'range loop dout(i) := resize(din=>din(i), w=>w, m=>m); end loop;
    return dout;
  end function;

  ------------------------------------------
  -- Basic complex arithmetic
  ------------------------------------------

  -- complex negation
  function "-" (din:cplx) return cplx is
    variable ovf_re, ovf_im : std_logic;
    variable dout : cplx(re(din.re'length-1 downto 0),im(din.im'length-1 downto 0));
  begin
    -- by default copy input control signals
    dout.rst:=din.rst; dout.vld:=din.vld; dout.ovf:=din.ovf;
    -- wrap only occurs when input is most-negative number
    SUB(l=>to_signed(0,din.re'length), r=>din.re, dout=>dout.re, ovfl=>ovf_re, clip=>false);
    SUB(l=>to_signed(0,din.im'length), r=>din.im, dout=>dout.im, ovfl=>ovf_im, clip=>false);
    -- This function always reports overflows but only for valid data.
    dout.ovf := dout.ovf or (dout.vld and (ovf_re or ovf_im));
    dout := cplx_reset(din=>dout, m=>"-"); -- never reset data
    return dout;
  end function;

  -- complex negation (vector)
  function "-" (din:cplx_vector) return cplx_vector is
    constant LIN_RE : positive := din(din'left).re'length;
    constant LIN_IM : positive := din(din'left).im'length;
    variable dout : cplx_vector(din'range)(re(LIN_RE-1 downto 0),im(LIN_IM-1 downto 0));
  begin
    for i in din'range loop dout(i) := -din(i); end loop;
    return dout;
  end function;

  -- complex conjugate
  function conj (
    din  : cplx; -- data input
    w    : natural:=0; -- output bit width 
    m    : cplx_mode:="-" -- mode, supported options: 'R', 'O', 'X' and/or 'S'
  ) return cplx is
    variable ovf_re, ovf_im : std_logic;
    constant LIN_RE : positive := din.re'length;
    constant LIN_IM : positive := din.im'length;
    constant LOUT_RE : positive := default_if_zero(w, dflt=>LIN_RE); -- final output bit width
    constant LOUT_IM : positive := default_if_zero(w, dflt=>LIN_IM); -- final output bit width
    variable dout : cplx(re(LOUT_RE-1 downto 0),im(LOUT_IM-1 downto 0));
  begin
    dout.rst:=din.rst; dout.vld:=din.vld; -- just forward signals
    if (m='X') then dout.ovf:='0'; else dout.ovf:=din.ovf; end if; -- ignore input overflow ?
    -- overflow/underflow not possible when LOUT>LIN
    RESIZE_CLIP(din=>din.re, dout=>dout.re, ovfl=>ovf_re, clip=>(m='S'));
    SUB(l=>to_signed(0,LIN_IM), r=>din.im, dout=>dout.im, ovfl=>ovf_im, clip=>(m='S'));
    -- This function reports overflows only for valid data.
    if (m='O') then dout.ovf := dout.ovf or (dout.vld and (ovf_re or ovf_im)); end if;
    dout := cplx_reset(din=>dout, m=>m);
    return dout;
  end function;

  -- complex conjugate (vector)
  function conj (
    din : cplx_vector; -- data input vector
    w   : natural:=0; -- output bit width 
    m   : cplx_mode:="-" -- mode, supported options: 'R','O' and/or 'S'
  ) return cplx_vector is
    constant LIN_RE : positive := din(din'left).re'length;
    constant LIN_IM : positive := din(din'left).im'length;
    constant LOUT_RE : positive := default_if_zero(w, dflt=>LIN_RE); -- final output bit width
    constant LOUT_IM : positive := default_if_zero(w, dflt=>LIN_IM); -- final output bit width
    variable dout : cplx_vector(din'range)(re(LOUT_RE-1 downto 0),im(LOUT_IM-1 downto 0));
  begin
    for i in din'range loop dout(i) := conj(din=>din(i), w=>w, m=>m); end loop;
    return dout;
  end function;

  -- swap real and imaginary components
  function swap (din:cplx) return cplx is
    constant LIN : positive := din.re'length;
    variable dout : cplx(re(LIN-1 downto 0),im(LIN-1 downto 0));
  begin
    assert (din.re'length=din.im'length)
      report "ERROR: swap(cplx), real and imaginary component must have same size"
      severity failure;
    -- by default copy input control signals
    dout.rst:=din.rst; dout.vld:=din.vld; dout.ovf:=din.ovf;
    dout.re:=din.im; dout.im:=din.re; -- swap
    return dout;
  end function;

  -- swap real and imaginary components (vector)
  function swap (din:cplx_vector) return cplx_vector is
    constant LIN : positive := din(din'left).re'length;
    variable dout : cplx_vector(din'range)(re(LIN-1 downto 0),im(LIN-1 downto 0));
  begin
    for i in din'range loop dout(i) := swap(din=>din(i)); end loop;
    return dout;
  end function;

  ------------------------------------------
  -- ADDITION and ACCUMULATION
  ------------------------------------------

  procedure add (
    l,r  : in  cplx; -- left/right summand
    dout : out cplx; -- data output, sum
    m    : in  cplx_mode:="-" -- mode, supported options: 'R','O','X' and/or 'S'
  ) is
    variable ovf_re, ovf_im : std_logic;
  begin
    -- by default merge input control signals
    dout.rst := l.rst or r.rst;
    dout.vld := l.vld and r.vld;
    if (m='X') then dout.ovf:='0'; else dout.ovf := l.ovf or r.ovf; end if;
    ADD(l=>l.re, r=>r.re, dout=>dout.re, ovfl=>ovf_re, clip=>(m='S'));
    ADD(l=>l.im, r=>r.im, dout=>dout.im, ovfl=>ovf_im, clip=>(m='S'));
    -- This function reports overflows only for valid data.
    if (m='O') then dout.ovf := dout.ovf or (dout.vld and (ovf_re or ovf_im)); end if;
    dout := cplx_reset(din=>dout, m=>m);
  end procedure;

  function add (
    l,r  : cplx; -- left/right summand
    w    : natural:=0; -- output bit width
    m    : cplx_mode:="-" -- mode, supported options: 'R','O',X' and/or 'S'
  ) return cplx is
    constant LIN_RE : positive := MAXIMUM(l.re'length,r.re'length); -- default output length
    constant LIN_IM : positive := MAXIMUM(l.im'length,r.im'length); -- default output length
    constant LOUT_RE : positive := default_if_zero(w, dflt=>LIN_RE); -- final output length
    constant LOUT_IM : positive := default_if_zero(w, dflt=>LIN_IM); -- final output length
    variable dout : cplx(re(LOUT_RE-1 downto 0),im(LOUT_IM-1 downto 0));
  begin
    add(l=>l, r=>r, dout=>dout, m=>m);
    return dout;
  end function;

  function add (
    l,r  : cplx_vector; -- left/right summand
    w    : natural:=0; -- output bit width
    m    : cplx_mode:="-" -- mode, supported options: 'R','O','X' and/or 'S'
  ) return cplx_vector is
    constant WL_RE : positive := l(l'left).re'length; -- width left real
    constant WL_IM : positive := l(l'left).im'length; -- width left imaginary
    constant WR_RE : positive := r(r'left).re'length; -- width right real
    constant WR_IM : positive := r(r'left).im'length; -- width right imaginary
    alias xl : cplx_vector(1 to l'length)(re(WL_RE-1 downto 0),im(WL_IM-1 downto 0)) is l; -- default range
    alias xr : cplx_vector(1 to r'length)(re(WR_RE-1 downto 0),im(WR_IM-1 downto 0)) is r; -- default range
    constant LOUT_RE : positive := default_if_zero(w, dflt=>MAXIMUM(WL_RE,WR_RE)); -- final output length
    constant LOUT_IM : positive := default_if_zero(w, dflt=>MAXIMUM(WL_IM,WR_IM)); -- final output length
    variable dout : cplx_vector(1 to l'length)(re(LOUT_RE-1 downto 0),im(LOUT_IM-1 downto 0));
  begin
    assert (l'length=r'length)
      report "ERROR: add() cplx_vector, both summands must have same number of vector elements"
      severity failure;
    for i in 1 to l'length loop 
      add(l=>xl(i), r=>xr(i), dout=>dout(i), m=>m);
    end loop;
    return dout;
  end function;

  function "+" (l,r: cplx) return cplx is
  begin
    return add(l=>l, r=>r, w=>0, m=>"O"); -- just overflow detection!
  end function;

  function "+" (l,r: cplx_vector) return cplx_vector is
  begin
    return add(l=>l, r=>r, w=>0, m=>"O"); -- just overflow detection!
  end function;

  function sum (
    din  : cplx_vector; -- data input vector
    w    : natural:=0; -- output bit width
    m    : cplx_mode:="-" -- mode, supported options: 'R','O','X' and/or 'S'
  ) return cplx
  is
    constant LVEC : positive := din'length; -- vector length
    constant LIN : positive := MAXIMUM(din(din'left).re'length,din(din'left).im'length); -- default output bit width
    constant LOUT : positive := default_if_zero(w, dflt=>LIN); -- final output bit width
    alias xdin : cplx_vector(1 to LVEC)(re(LIN-1 downto 0),im(LIN-1 downto 0)) is din; -- default range
    constant T : positive := LIN + LOG2CEIL(LVEC); -- width including additional accumulation bits
    variable temp : cplx(re(T-1 downto 0),im(T-1 downto 0));
  begin
    temp := resize(din=>xdin(1), w=>LIN); -- mode irrelevant, do not set any options here! 
    if LVEC>1 then
      for i in 2 to LVEC loop temp:=temp+xdin(i); end loop;
    end if;
    return resize(din=>temp, w=>LOUT, m=>m);
  end function;

  procedure sum (
    din  : in  cplx_vector; -- data input vector
    dout : out cplx; -- data output, result of sum
    m    : in  cplx_mode:="-" -- mode, supported options: 'R','O','X' and/or 'S'
  ) is
    constant LOUT : positive := MAXIMUM(dout.re'length, dout.im'length);
  begin
    dout := sum(din=>din, w=>LOUT, m=>m);
  end procedure;

  ------------------------------------------
  -- SUBTRACTION
  ------------------------------------------

  -- complex subtraction with optional clipping and overflow detection
  -- d = l - r  (sum is resized to size of connected output)
  procedure sub (
    l,r  : in  cplx; -- data input, left minuend, right subtrahend
    dout : out cplx; -- data output, difference
    m    : in  cplx_mode:="-" -- mode, supported options: 'R','O','X' and/or 'S'
  ) is
    variable ovf_re, ovf_im : std_logic;
  begin
    -- by default merge input control signals
    dout.rst := l.rst or r.rst;
    dout.vld := l.vld and r.vld;
    if (m='X') then dout.ovf:='0'; else dout.ovf := l.ovf or r.ovf; end if;
    SUB(l=>l.re, r=>r.re, dout=>dout.re, ovfl=>ovf_re, clip=>(m='S'));
    SUB(l=>l.im, r=>r.im, dout=>dout.im, ovfl=>ovf_im, clip=>(m='S'));
    -- This function reports overflows only for valid data.
    if (m='O') then dout.ovf := dout.ovf or (dout.vld and (ovf_re or ovf_im)); end if;
    dout := cplx_reset(din=>dout, m=>m);
  end procedure;

  -- complex subtraction with optional clipping and overflow detection
  -- d = l - r  (sum is resized to given output bit width of sum)
  function sub (
    l,r  : cplx; -- data input, left minuend, right subtrahend
    w    : natural:=0; -- output bit width
    m    : cplx_mode:="-" -- mode, supported options: 'R','O','X' and/or 'S'
  ) return cplx is
    constant LIN_RE : positive := MAXIMUM(l.re'length,r.re'length); -- default output length
    constant LIN_IM : positive := MAXIMUM(l.im'length,r.im'length); -- default output length
    constant LOUT_RE : positive := default_if_zero(w, dflt=>LIN_RE); -- final output length
    constant LOUT_IM : positive := default_if_zero(w, dflt=>LIN_IM); -- final output length
    variable dout : cplx(re(LOUT_RE-1 downto 0),im(LOUT_IM-1 downto 0));
  begin
    sub(l=>l, r=>r, dout=>dout, m=>m);
    return dout;
  end function;

  function sub (
    l,r  : cplx_vector; -- data input, left minuend, right subtrahend
    w    : natural:=0; -- output bit width
    m    : cplx_mode:="-" -- mode, supported options: 'R','O','X' and/or 'S'
  ) return cplx_vector is
    constant WL_RE : positive := l(l'left).re'length; -- width left real
    constant WL_IM : positive := l(l'left).im'length; -- width left imaginary
    constant WR_RE : positive := r(r'left).re'length; -- width right real
    constant WR_IM : positive := r(r'left).im'length; -- width right imaginary
    alias xl : cplx_vector(1 to l'length)(re(WL_RE-1 downto 0),im(WL_IM-1 downto 0)) is l; -- default range
    alias xr : cplx_vector(1 to r'length)(re(WR_RE-1 downto 0),im(WR_IM-1 downto 0)) is r; -- default range
    constant LOUT_RE : positive := default_if_zero(w, dflt=>MAXIMUM(WL_RE,WR_RE)); -- final output length
    constant LOUT_IM : positive := default_if_zero(w, dflt=>MAXIMUM(WL_IM,WR_IM)); -- final output length
    variable dout : cplx_vector(1 to l'length)(re(LOUT_RE-1 downto 0),im(LOUT_IM-1 downto 0));
  begin
    assert (l'length=r'length)
      report "ERROR: sub() cplx_vector, left minuend and right subtrahend must have same number of vector elements"
      severity failure;
    for i in 1 to l'length loop 
      sub(l=>xl(i), r=>xr(i), dout=>dout(i), m=>m);
    end loop;
    return dout;
  end function;

  -- complex subtraction with wrap and overflow detection
  function "-" (l,r: cplx) return cplx is
  begin
    return sub(l=>l, r=>r, w=>0, m=>"O"); -- just overflow detection!
  end function;

  -- complex subtraction with wrap and overflow detection
  function "-" (l,r: cplx_vector) return cplx_vector is
  begin
    return sub(l=>l, r=>r, w=>0, m=>"O"); -- just overflow detection!
  end function;

  ------------------------------------------
  -- SHIFT LEFT AND SATURATE/CLIP
  ------------------------------------------

  -- complex signed shift left with optional clipping/saturation and overflow detection
  procedure shift_left (
    din  : in  cplx; -- data input
    n    : in  natural; -- number of left shifts
    dout : out cplx; -- data output
    m    : in  cplx_mode:="-" -- mode
  ) is
    variable ovf_re, ovf_im : std_logic;
  begin
    dout.rst:=din.rst; dout.vld:=din.vld; -- just forward signals
    if m='X' then dout.ovf:='0'; else dout.ovf:=din.ovf; end if; -- ignore input overflow ?
    SHIFT_LEFT_CLIP(din=>din.re, n=>n, dout=>dout.re, ovfl=>ovf_re, clip=>(m='S'));
    SHIFT_LEFT_CLIP(din=>din.im, n=>n, dout=>dout.im, ovfl=>ovf_im, clip=>(m='S'));
    -- This function reports overflows only for valid data.
    if m='O' then dout.ovf := dout.ovf or (dout.vld and (ovf_re or ovf_im)); end if;
    dout := cplx_reset(din=>dout, m=>m);
  end procedure;

  -- complex signed shift left with optional clipping/saturation and overflow detection
  function shift_left (
    din  : cplx; -- data input
    n    : natural; -- number of left shifts
    m    : cplx_mode:="-" -- mode
  ) return cplx is
    -- output size always equals input size
    constant LOUT_RE : positive := din.re'length;
    constant LOUT_IM : positive := din.im'length;
    variable dout : cplx(re(LOUT_RE-1 downto 0),im(LOUT_IM-1 downto 0));
  begin
    shift_left(din=>din, n=>n, dout=>dout, m=>m);
    return dout;
  end function;

  function shift_left (
    din  : cplx_vector; -- data input
    n    : natural; -- number of left shifts
    m    : cplx_mode:="-" -- mode
  ) return cplx_vector is
    -- output size always equals input size
    constant LOUT_RE : positive := din(din'left).re'length;
    constant LOUT_IM : positive := din(din'left).im'length;
    variable dout : cplx_vector(din'range)(re(LOUT_RE-1 downto 0),im(LOUT_IM-1 downto 0));
  begin
    for i in din'range loop 
      shift_left(din=>din(i), n=>n, dout=>dout(i), m=>m);
    end loop;
    return dout;
  end function;

  ------------------------------------------
  -- SHIFT RIGHT and ROUND
  ------------------------------------------

  function shift_right (
    din  : cplx; -- data input
    n    : natural; -- number of right shifts
    m    : cplx_mode:="-" -- mode
  ) return cplx is
    -- output size always equals input size
    constant LOUT_RE : positive := din.re'length;
    constant LOUT_IM : positive := din.im'length;
    variable dout : cplx(re(LOUT_RE-1 downto 0),im(LOUT_IM-1 downto 0));
  begin
    dout.rst:=din.rst; dout.vld:=din.vld; dout.ovf:=din.ovf; -- just forward
    if m='X' then dout.ovf:='0'; end if; -- ignore input overflow
    if m='N' then
      dout.re := SHIFT_RIGHT_ROUND(din=>din.re, n=>n, rnd=>nearest);
      dout.im := SHIFT_RIGHT_ROUND(din=>din.im, n=>n, rnd=>nearest);
    elsif m='U' then
      dout.re := SHIFT_RIGHT_ROUND(din=>din.re, n=>n, rnd=>ceil);
      dout.im := SHIFT_RIGHT_ROUND(din=>din.im, n=>n, rnd=>ceil);
    elsif m='Z' then
      dout.re := SHIFT_RIGHT_ROUND(din=>din.re, n=>n, rnd=>truncate);
      dout.im := SHIFT_RIGHT_ROUND(din=>din.im, n=>n, rnd=>truncate);
    elsif m='I' then
      dout.re := SHIFT_RIGHT_ROUND(din=>din.re, n=>n, rnd=>infinity);
      dout.im := SHIFT_RIGHT_ROUND(din=>din.im, n=>n, rnd=>infinity);
    else
      -- by default standard rounding, i.e. floor
      dout.re := SHIFT_RIGHT_ROUND(din=>din.re, n=>n, rnd=>floor);
      dout.im := SHIFT_RIGHT_ROUND(din=>din.im, n=>n, rnd=>floor);
    end if;
    return cplx_reset(din=>dout, m=>m);
  end function;

  function shift_right (
    din  : cplx_vector; -- data input
    n    : natural; -- number of right shifts
    m    : cplx_mode:="-" -- mode
  ) return cplx_vector is
    -- output size always equals input size
    constant LOUT_RE : positive := din(din'left).re'length;
    constant LOUT_IM : positive := din(din'left).im'length;
    variable dout : cplx_vector(din'range)(re(LOUT_RE-1 downto 0),im(LOUT_IM-1 downto 0));
  begin
    for i in din'range loop 
      dout(i) := shift_right(din=>din(i), n=>n, m=>m);
    end loop;
    return dout;
  end function;

  procedure shift_right (
    din  : in  cplx; -- data input
    n    : in  natural; -- number of right shifts
    dout : out cplx; -- data output
    m    : in  cplx_mode:="-" -- mode
  ) is
    constant LIN_RE : positive := din.re'length;
    constant LIN_IM : positive := din.im'length;
    constant LOUT : positive := dout.re'length;
    variable temp : cplx(re(LIN_RE-1 downto 0),im(LIN_IM-1 downto 0));
  begin
    temp := shift_right(din=>din, n=>n, m=>m);
    -- shift-right cannot cause overflow but only the following resize operation
    dout := resize(din=>temp, w=>LOUT, m=>m);
  end procedure;

  ------------------------------------------
  -- Conversion
  ------------------------------------------

  --! @brief Reverse order of vector elements without changing the index direction.
  --! To reverse the index direction (to<=>downto) use reverse_range attribute instead.
  function REVERSE(arg:cplx_vector) return cplx_vector is
    constant WRE : positive := arg(arg'low).re'length;
    constant WIM : positive := arg(arg'low).im'length;
    variable res : cplx_vector(arg'range)(re(WRE-1 downto 0),im(WIM-1 downto 0));
    alias xarg : cplx_vector(arg'reverse_range)(re(WRE-1 downto 0),im(WIM-1 downto 0)) is arg;
  begin
   for i in xarg'range loop res(i) := xarg(i); end loop;
   return res;
  end function;

  --! @brief Merge separate vectors of signed real and imaginary values into one CPLX vector.
  --! Input real and imaginary vectors must have same length.
  function to_cplx_vector (
    re  : signed_vector; -- vector of real values (same length as imaginary)
    im  : signed_vector; -- vector of imaginary values (same length as real)
    vld : std_logic := '1'; -- data valid
    rst : std_logic := '0' -- reset
  ) return cplx_vector is
    constant LRE : positive := re'length;
    constant LIM : positive := im'length;
    variable xre : signed_vector(0 to LRE-1)(re(re'left)'range);
    variable xim : signed_vector(0 to LIM-1)(im(im'left)'range);
    variable dout : cplx_vector(0 to LRE-1)(re(re(re'left)'length-1 downto 0),im(im(im'left)'length-1 downto 0));
--    variable dout : cplx_vector(0 to LRE-1)(re(re(re'left)'range),im(im(im'left)'range)); -- not working with Vivado 2019.1 !
  begin
    assert (LRE=LIM)
      report "ERROR: to_cplx_vector(), both input signed_vector must have same length."
      severity failure;
    xre := re; -- conversion to default range
    xim := im; -- conversion to default range
    for i in 0 to LRE-1 loop 
      dout(i).rst := rst;
      dout(i).vld := vld;
      dout(i).ovf := '0';
      dout(i).re := xre(i);
      dout(i).im := xim(i);
    end loop;
    return dout;
  end function;

  --! @brief Extract all real components of a CPLX vector and output as signed vector.
  function real (
    din : cplx_vector
  ) return signed_vector is
    variable dout : signed_vector(din'range)(din(din'left).re'range);
  begin
    for i in din'range loop dout(i):=din(i).re; end loop;
    return dout;
  end function;

  --! @brief Extract all imaginary components of a CPLX vector and output as signed vector.
  function imag (
    din : cplx_vector
  ) return signed_vector is
    variable dout : signed_vector(din'range)(din(din'left).im'range);
  begin
    for i in din'range loop dout(i):=din(i).im; end loop;
    return dout;
  end function;

  ------------------------------------------
  -- STD_LOGIC_VECTOR to CPLX
  ------------------------------------------

  function to_cplx (
    slv : std_logic_vector;
    vld : std_logic;
    rst : std_logic := '0'
  ) return cplx is
    constant BITS : positive := slv'length/2;
    alias x : std_logic_vector(2*BITS-1 downto 0) is slv; -- default range
    variable res : cplx(re(BITS-1 downto 0), im(BITS-1 downto 0));
  begin
    assert ((slv'length mod 2)=0)
      report "ERROR: to_cplx(), input std_logic_vector length must be even"
      severity failure;
    res.rst := rst;
    res.vld := vld;
    res.re  := signed(x(  BITS-1 downto    0));
    res.im  := signed(x(2*BITS-1 downto BITS));
    res.ovf := '0';
    return res;
  end function;

  function to_cplx_vector (
    slv : std_logic_vector;
    n   : positive;
    vld : std_logic;
    rst : std_logic := '0'
  ) return cplx_vector is
    constant BITS : integer := slv'length/n/2;
    variable res : cplx_vector(0 to n-1)(re(BITS-1 downto 0),im(BITS-1 downto 0));
  begin
    assert ((slv'length mod (2*n))=0)
      report "ERROR: to_cplx_vector(), input std_logic_vector length must be a multiple of 2*n"
      severity failure;
    for i in 0 to n-1 loop
      res(i) := to_cplx(slv(2*BITS*(i+1)-1 downto 2*BITS*i), vld=>vld, rst=>rst);
    end loop;
    return res;
  end function;

  ------------------------------------------
  -- CPLX to STD_LOGIC_VECTOR
  ------------------------------------------

  function to_slv(
    din : cplx;
    m   : cplx_mode:="-" -- mode
  ) return std_logic_vector is
    constant LRE : positive := din.re'length;
    constant LIM : positive := din.im'length;
    variable slv : std_logic_vector(LRE+LIM-1 downto 0);
  begin
    slv(    LRE-1 downto   0) := std_logic_vector(din.re);
    slv(LIM+LRE-1 downto LRE) := std_logic_vector(din.im);
    if m='R' and din.rst='1' then slv:=(others=>'0'); end if;
    return slv;
  end function;

  function to_slv(
    din : cplx_vector;
    m   : cplx_mode:="-" -- mode
  ) return std_logic_vector is
    constant N : positive := din'length;
    constant LRE : positive := din(din'left).re'length;
    constant LIM : positive := din(din'left).im'length;
    alias xdin : cplx_vector(0 to N-1)(re(LRE-1 downto 0),im(LIM-1 downto 0)) is din;
    variable slv : std_logic_vector(N*(LRE+LIM)-1 downto 0);
  begin
    for i in 0 to N-1 loop
      slv((i+1)*(LRE+LIM)-1 downto i*(LRE+LIM)) := to_slv(din=>xdin(i), m=>m);
    end loop;
    return slv;
  end function;

  ------------------------------------------
  -- Convert CPLX record into STD_LOGIC_VECTOR
  -- (useful for interfaces which do not support records)
  ------------------------------------------

  function record_to_slv(
    din : cplx
  ) return std_logic_vector is
    constant LRE : positive := din.re'length;
    constant LIM : positive := din.im'length;
    variable slv : std_logic_vector(3+LIM+LRE-1 downto 0);
  begin
    slv(3+LIM+LRE-1) := din.rst; 
    slv(2+LIM+LRE-1) := din.vld; 
    slv(1+LIM+LRE-1) := din.ovf; 
    slv(LIM+LRE-1 downto LRE) := std_logic_vector(din.im);
    slv(LRE-1 downto 0) := std_logic_vector(din.re);
    return slv;
  end function;

  function record_to_slv(
    din : cplx_vector
  ) return std_logic_vector is
    constant N : positive := din'length;
    constant LRE : positive := din(din'left).re'length;
    constant LIM : positive := din(din'left).im'length;
    alias xdin : cplx_vector(0 to N-1)(re(LRE-1 downto 0),im(LIM-1 downto 0)) is din;
    variable slv : std_logic_vector(N*(3+LRE+LIM)-1 downto 0);
  begin
    for i in 0 to N-1 loop
      slv((i+1)*(3+LRE+LIM)-1 downto i*(3+LRE+LIM)) := record_to_slv(din=>xdin(i));
    end loop;
    return slv;
  end function;

  function slv_to_record(
    slv : std_logic_vector
  ) return cplx is
    -- assume that RE and IM have same length BITS
    constant BITS : positive := (slv'length-3)/2;
    alias x : std_logic_vector(slv'length-1 downto 0) is slv; -- default range
    variable dout : cplx(re(BITS-1 downto 0),im(BITS-1 downto 0));
  begin
    assert ((slv'length mod 2)=1 and (slv'length>=7))
      report "ERROR: slv_to_record(cplx), input std_logic_vector length must be odd and 7 or greater."
      severity failure;
    dout.rst := x(3+2*BITS-1); 
    dout.vld := x(2+2*BITS-1); 
    dout.ovf := x(1+2*BITS-1); 
    dout.im  := signed(x(2*BITS-1 downto BITS));
    dout.re  := signed(x(BITS-1 downto 0));
    return dout;
  end function;

  function slv_to_record (
    slv : std_logic_vector;
    n   : positive
  ) return cplx_vector is
    -- assume that RE and IM have same length BITS
    constant BITS : integer := (slv'length/n-3)/2;
    variable res : cplx_vector(0 to n-1)(re(BITS-1 downto 0),im(BITS-1 downto 0));
  begin
    assert ((slv'length mod n)=0)
      report "ERROR: slv_to_record(cplx_vector), input std_logic_vector is not a multiple of given n."
      severity failure;
    for i in 0 to n-1 loop
      res(i) := slv_to_record(slv((i+1)*(3+2*BITS)-1 downto i*(3+2*BITS)));
    end loop;
    return res;
  end function;

  procedure slv_to_record (
    din  : in  std_logic_vector; -- data input
    dout : out cplx_vector -- data output
  ) is
    constant N : positive := dout'length;
  begin
    dout := slv_to_record(din,N);
  end procedure;

end package body;