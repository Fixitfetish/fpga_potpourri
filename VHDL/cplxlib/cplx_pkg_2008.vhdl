-------------------------------------------------------------------------------
--! @file       cplx_pkg_2008.vhdl
--! @author     Fixitfetish
--! @date       14/Mar/2017
--! @version    0.99
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension.all;

-- This package provides types, functions and procedures that allow basic
-- operations with complex integer numbers. Only the most common signals are
-- taken into account. The functions and procedures are designed in a way to
-- use as few logic elements as possible. 
-- Please note that multiplications, divisions and so on are not part of this
-- package since they typically make use of hardware specific DSP cells and
-- require registers in addition. Corresponding entities have been (can be)
-- developed based on this package.

package cplx_pkg is

  ------------------------------------------
  -- TYPES
  ------------------------------------------

  -- general unconstrained complex type
  type cplx is
  record
    rst : std_logic; -- reset
    vld : std_logic; -- data valid
    ovf : std_logic; -- data overflow (or clipping)
    re  : signed; -- data real component ("downto" direction assumed)
    im  : signed; -- data imaginary component ("downto" direction assumed)
  end record;

  subtype cplx16 is cplx(re(15 downto 0), im(15 downto 0));
  subtype cplx18 is cplx(re(17 downto 0), im(17 downto 0));
  subtype cplx20 is cplx(re(19 downto 0), im(19 downto 0));
  subtype cplx22 is cplx(re(21 downto 0), im(21 downto 0));

  -- general unconstrained complex vector type (preferably "to" direction)
  type cplx_vector is array(integer range <>) of cplx;

  subtype cplx16_vector is cplx_vector(open)(re(15 downto 0), im(15 downto 0));
  subtype cplx18_vector is cplx_vector(open)(re(17 downto 0), im(17 downto 0));
  subtype cplx20_vector is cplx_vector(open)(re(19 downto 0), im(19 downto 0));
  subtype cplx22_vector is cplx_vector(open)(re(21 downto 0), im(21 downto 0));

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
  
  -- Complex operations can be used with one or more the following options.
  -- Note that some options can not be combined, e.g. different rounding options.
  -- Use options carefully and only when really required. Some options can have
  -- a negative influence on logic consumption and timing.
  -- '-' -- don't care, use defaults
  -- 'D' -- round down towards minus infinity, floor (default, just remove LSBs)
  -- 'I' -- round towards plus/minus infinity, i.e. away from zero
  -- 'N' -- round to nearest (standard rounding, i.e. +0.5 and then remove LSBs)
  -- 'O' -- enable overflow/underflow detection (by default off)
  -- 'R' -- use reset on RE/IM (set RE=0 and IM=0)
  -- 'S' -- enable saturation/clipping (by default off)
  -- 'U' -- round up towards plus infinity, ceil
  -- 'X' -- ignore/discard input overflow flag
  -- 'Z' -- round towards zero, truncate
  -- 
  -- Option X : By default the overflow flags of the inputs are propagated
  -- to the output to not loose the overflow flags in processing chains.
  -- If the input overflow flags are ignored then output overflow flags only
  -- report overflows within this entity. Note that ignoring the input
  -- overflows can save a little bit of logic.
  type cplx_mode is array(integer range <>) of cplx_option;

  ------------------------------------------
  -- auxiliary
  ------------------------------------------

  -- check if a certain option is enabled
  function "=" (l:cplx_mode; r:cplx_option) return boolean;

  -- check if a certain option is disabled
  function "/=" (l:cplx_mode; r:cplx_option) return boolean;

  ------------------------------------------
  -- RESET
  ------------------------------------------

  -- get cplx reset value 
  -- RE/IM data will be 0 with option 'R', otherwise data is do-not-care
  function cplx_reset (
    w : positive range 2 to integer'high; -- RE/IM data width in bits
    m : cplx_mode:="-" -- mode, supported options: 'R'
  ) return cplx;

  -- get cplx_vector reset value 
  -- RE/IM data will be 0 with option 'R', otherwise data is do-not-care
  function cplx_vector_reset (
    w : positive range 2 to integer'high; -- RE/IM data width in bits
    n : positive; -- number of vector elements
    m : cplx_mode:="-" -- mode, supported options: 'R'
  ) return cplx_vector;

  -- Complex data reset on demand - to be placed into the data path
  -- supported options: 'R'
  function reset_on_demand (
    din : cplx; -- data input
    m   : cplx_mode:="-" -- mode, supported options: 'R'
  ) return cplx;

  function reset_on_demand (
    din : cplx_vector; -- data input
    m   : cplx_mode:="-" -- mode, supported options: 'R'
  ) return cplx_vector;

  ------------------------------------------
  -- RESIZE
  ------------------------------------------

  -- resize to given bit width (similar to NUMERIC_STD)
  -- supported options: 'R', 'O' and/or 'S'
  function resize(
    din : cplx; -- data input
    w   : positive range 2 to integer'high; -- output bit width
    m   : cplx_mode:="-" -- mode, supported options: 'R', 'O' and/or 'S'
  ) return cplx;

  -- resize to size of connected output
  -- supported options: 'R', 'O' and/or 'S'
  procedure resize (
    din  : in  cplx; -- data input
    dout : out cplx; -- data output
    m    : in  cplx_mode:="-" -- mode, supported options: 'R', 'O' and/or 'S'
  );

  -- resize each vector element to given bit width
  -- supported options: 'R', 'O' and/or 'S'
  function resize (
    din : cplx_vector; -- data input vector
    w   : positive range 2 to integer'high; -- output bit width
    m   : cplx_mode:="-" -- mode, supported options: 'R','O' and/or 'S'
  ) return cplx_vector;

  ------------------------------------------
  -- Basic complex arithmetic
  ------------------------------------------

  -- complex minus with overflow detection
  -- wrap only occurs when input is most-negative number
  -- (bit width of output equals the bit width of input)
  function "-" (din:cplx) return cplx;

  function "-" (din:cplx_vector) return cplx_vector;

  -- complex conjugate
  -- w=0 : output bit width is equal to the maximum input bit width
  -- w>0 : output bit width is w (includes resize)
  -- supported options: 'R', 'O' and/or 'S'
  function conj (
    din  : cplx; -- data input
    w    : natural:=0; -- output bit width
    m    : cplx_mode:="-" -- mode, supported options: 'R', 'O' and/or 'S'
  ) return cplx;

  function conj (
    din  : cplx_vector; -- data input
    w    : natural:=0; -- output bit width
    m    : cplx_mode:="-" -- mode, supported options: 'R', 'O' and/or 'S'
  ) return cplx_vector;

  -- swap real and imaginary components
  -- (bit width of output equals the bit width of input)
  function swap (din:cplx) return cplx;
    
  function swap (din:cplx_vector) return cplx_vector;

  ------------------------------------------
  -- ADDITION and ACCUMULATION
  ------------------------------------------

  -- complex addition with optional clipping and overflow detection
  -- dout = l + r  (result sum is resized to size of connected output)
  -- supported options: 'R', 'O' and/or 'S'
  procedure add (
    l,r  : in  cplx; -- left/right summand
    dout : out cplx; -- data output, sum
    m    : in  cplx_mode:="-" -- mode, supported options: 'R', 'O' and/or 'S'
  );

  -- complex addition with optional clipping and overflow detection
  -- w=0 : output bit width is equal to the maximum input bit width
  -- w>0 : output bit width is w (includes resize)
  -- supported options: 'R', 'O' and/or 'S'
  function add (
    l,r  : cplx; -- left/right summand
    w    : natural:=0; -- output bit width
    m    : cplx_mode:="-" -- mode, supported options: 'R', 'O' and/or 'S'
  ) return cplx;

  function add (
    l,r  : cplx_vector; -- left/right summand
    w    : natural:=0; -- output bit width
    m    : cplx_mode:="-" -- mode, supported options: 'R', 'O' and/or 'S'
  ) return cplx_vector;

  -- complex addition with wrap and overflow detection
  -- The output width of sum equals the max width of summands.
  -- Alternatively use function ADD() for more options.
  function "+" (l,r: cplx) return cplx;

  function "+" (l,r: cplx_vector) return cplx_vector;

  -- sum of vector elements with optional clipping and overflow detection
  -- w=0 : output bit width is equal to input bit width
  -- w>0 : output bit width is w (includes resize)
  -- supported options: 'R', 'O' and/or 'S'
  function sum (
    din  : cplx_vector; -- data input vector
    w    : natural:=0; -- output bit width
    m    : cplx_mode:="-" -- mode, supported options: 'R', 'O' and/or 'S'
  ) return cplx;

  -- sum of vector elements with optional clipping and overflow detection
  -- (sum result is resized to size of connected output)
  -- supported options: 'R', 'O' and/or 'S'
  procedure sum (
    din  : in  cplx_vector; -- data input vector
    dout : out cplx; -- data output, sum
    m    : in  cplx_mode:="-" -- mode, supported options: 'R', 'O' and/or 'S'
  );

  ------------------------------------------
  -- SUBTRACTION
  ------------------------------------------

  -- complex subtraction with optional clipping and overflow detection
  -- dout = l - r  (difference result is resized to size of connected output)
  -- supported options: 'R', 'O' and/or 'S'
  procedure sub (
    l,r  : in  cplx; -- data input, left minuend, right subtrahend
    dout : out cplx; -- data output, difference
    m    : in  cplx_mode:="-" -- mode, supported options: 'R', 'O' and/or 'S'
  );

  -- complex subtraction with optional clipping and overflow detection
  -- w=0 : output bit width is equal to the maximum input bit width
  -- w>0 : output bit width is w (includes resize)
  -- supported options: 'R', 'O' and/or 'S'
  function sub (
    l,r  : cplx; -- data input, left minuend, right subtrahend
    w    : natural:=0; -- output bit width
    m    : cplx_mode:="-" -- mode, supported options: 'R', 'O' and/or 'S'
  ) return cplx;

  function sub (
    l,r  : cplx_vector; -- data input, left minuend, right subtrahend
    w    : natural:=0; -- output bit width
    m    : cplx_mode:="-" -- mode, supported options: 'R', 'O' and/or 'S'
  ) return cplx_vector;

  -- complex subtraction with wrap and overflow detection
  -- The output width of difference equals the max width of left minuend and right subtrahend.
  -- Alternatively use function SUB() for more options.
  function "-" (l,r: cplx) return cplx;

  function "-" (l,r: cplx_vector) return cplx_vector;

  ------------------------------------------
  -- SHIFT LEFT AND SATURATE/CLIP
  ------------------------------------------

  -- complex signed shift left by n bits with optional clipping/saturation and overflow detection
  -- Result dout is resized to size of connected output.
  -- supported options: 'R', 'O' and/or 'S'
  procedure shift_left (
    din  : in  cplx; -- data input
    n    : in  natural; -- number of left shifts
    dout : out cplx; -- data output
    m    : in  cplx_mode:="-" -- mode
  );

  -- complex signed shift left by n bits with optional clipping/saturation and overflow detection
  -- The output bit width equals the input bit width.
  -- supported options: 'R', 'O' and/or 'S'
  function shift_left (
    din  : cplx; -- data input
    n    : natural; -- number of left shifts
    m    : cplx_mode:="-" -- mode
  ) return cplx;

  -- complex signed shift left by n bits with optional clipping/saturation and overflow detection
  -- The output bit width equals the input bit width.
  -- supported options: 'R', 'O' and/or 'S'
  function shift_left (
    din  : cplx_vector; -- data input
    n    : natural; -- number of left shifts
    m    : cplx_mode:="-" -- mode
  ) return cplx_vector;

  ------------------------------------------
  -- SHIFT RIGHT and ROUND
  ------------------------------------------

  -- complex signed shift right by n bits with optional rounding
  -- Result dout is resized to size of connected output.
  -- supported options: 'R' and/or ('D','N','U','Z' or 'I')
  procedure shift_right (
    din  : in  cplx; -- data input
    n    : in  natural; -- number of right shifts
    dout : out cplx; -- data output
    m    : in  cplx_mode:="-" -- mode
  );

  -- complex signed shift right by n bits with optional rounding
  -- The output bit width equals the input bit width.
  -- supported options: 'R' and/or ('D','N','U','Z' or 'I')
  function shift_right (
    din  : cplx; -- data input
    n    : natural; -- number of right shifts
    m    : cplx_mode:="-" -- mode
  ) return cplx;

  -- complex signed shift right by n bits with optional rounding
  -- The output bit width equals the input bit width.
  -- supported options: 'R' and/or ('D','N','U','Z' or 'I')
  function shift_right (
    din  : cplx_vector; -- data input
    n    : natural; -- number of right shifts
    m    : cplx_mode:="-" -- mode
  ) return cplx_vector;

  ------------------------------------------
  -- STD_LOGIC_VECTOR to CPLX
  ------------------------------------------

  -- convert SLV to cplx, L = SLV'length must be even
  -- (real = L/2 LSBs, imaginary = L/2 MSBs)
  function to_cplx (
    slv : std_logic_vector; -- data input
    vld : std_logic; -- data valid
    rst : std_logic := '0' -- reset
  ) return cplx;

  -- convert SLV to cplx_vector, L = SLV'length must be a multiple of 2*n 
  -- (L/n bits per vector element : real = L/n/2 LSBs, imaginary = L/n/2 MSBs)
  function to_cplx_vector (
    slv : std_logic_vector; -- data input vector
    n   : positive; -- number of required vector elements
    vld : std_logic; -- data valid
    rst : std_logic := '0' -- reset
  ) return cplx_vector;

  ------------------------------------------
  -- CPLX to STD_LOGIC_VECTOR
  ------------------------------------------

  -- convert cplx to SLV, real=LSBs, imaginary=MSBs
  -- (output length = din.re'length + din.im'length)
  -- supported options: 'R'
  function to_slv(
    din : cplx;
    m   : cplx_mode:="-" -- mode, optional reset
  ) return std_logic_vector;

  -- convert cplx_vector to SLV (real=LSBs, imaginary=MSBs per vector element)
  -- output length = din'length * (din.re'length + din.im'length)
  -- supported options: 'R'
  function to_slv(
    din : cplx_vector;
    m   : cplx_mode:="-" -- mode, optional reset
  ) return std_logic_vector;

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
    w : positive range 2 to integer'high; -- data RE/IM width in bits
    m : cplx_mode:="-" -- mode, supported options: 'R'
  ) return cplx is
    variable dout : cplx(re(w-1 downto 0),im(w-1 downto 0));
  begin
    if m='R' then
      dout := (rst=>'1', vld|ovf=>'0', re|im=>(w-1 downto 0=>'0'));
    else
      dout := (rst=>'1', vld|ovf=>'0', re|im=>(w-1 downto 0=>'-'));
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

  function reset_on_demand (din:cplx; m:cplx_mode:="-") return cplx is
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

  function reset_on_demand (
    din : cplx_vector; -- data input
    m   : cplx_mode:="-" -- mode, supported options: 'R'
  ) return cplx_vector is
    variable dout : cplx_vector(din'range)(re(din(din'left).re'range),im(din(din'left).im'range));
  begin
    for i in din'range loop dout(i):=reset_on_demand(din=>din(i), m=>m); end loop; 
    return dout;
  end function;

  ------------------------------------------
  -- RESIZE
  ------------------------------------------

  function resize (
    din : cplx; -- data input
    w   : positive range 2 to integer'high; -- output bit width
    m   : cplx_mode:="-" -- mode, supported options: 'R','O' and/or 'S'
  ) return cplx is
    variable ovf_re, ovf_im : std_logic;
    variable dout : cplx(re(w-1 downto 0),im(w-1 downto 0));
  begin
    -- by default copy input control signals
    dout.rst:=din.rst; dout.vld:=din.vld; dout.ovf:=din.ovf;
    RESIZE_CLIP(din=>din.re, dout=>dout.re, ovfl=>ovf_re, clip=>(m='S'));
    RESIZE_CLIP(din=>din.im, dout=>dout.im, ovfl=>ovf_im, clip=>(m='S'));
    if m='O' then dout.ovf := din.ovf or ovf_re or ovf_im; end if;
    dout := reset_on_demand(din=>dout, m=>m);
    return dout;
  end function;

  procedure resize (
    din  : in  cplx; -- data input
    dout : out cplx; -- data output
    m    : in  cplx_mode:="-" -- mode, supported options: 'R','O' and/or 'S'
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
    m   : cplx_mode:="-" -- mode, supported options: 'R','O' and/or 'S'
  ) return cplx_vector is
    variable dout : cplx_vector(din'range)(re(w-1 downto 0),im(w-1 downto 0));
  begin
    for i in din'range loop dout(i) := resize(din=>din(i), w=>w, m=>m); end loop;
    return dout;
  end function;

  ------------------------------------------
  -- Basic complex arithmetic
  ------------------------------------------

  -- complex minus
  function "-" (din:cplx) return cplx is
    variable ovf_re, ovf_im : std_logic;
    variable dout : cplx(re(din.re'length-1 downto 0),im(din.im'length-1 downto 0));
  begin
    -- by default copy input control signals
    dout.rst:=din.rst; dout.vld:=din.vld; dout.ovf:=din.ovf;
    -- wrap only occurs when input is most-negative number
    SUB(l=>to_signed(0,din.re'length), r=>din.re, dout=>dout.re, ovfl=>ovf_re, clip=>false);
    SUB(l=>to_signed(0,din.im'length), r=>din.im, dout=>dout.im, ovfl=>ovf_im, clip=>false);
    dout.ovf := dout.ovf or ovf_re or ovf_im; -- always with overflow detection
    dout := reset_on_demand(din=>dout, m=>"-"); -- never reset data
    return dout;
  end function;

  -- complex minus (vector)
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
    m    : cplx_mode:="-" -- mode, supported options: 'R', 'O' and/or 'S'
  ) return cplx is
    variable ovf_re, ovf_im : std_logic;
    constant LIN_RE : positive := din.re'length;
    constant LIN_IM : positive := din.im'length;
    constant LOUT_RE : positive := default_if_zero(w, dflt=>LIN_RE); -- final output bit width
    constant LOUT_IM : positive := default_if_zero(w, dflt=>LIN_IM); -- final output bit width
    variable dout : cplx(re(LOUT_RE-1 downto 0),im(LOUT_IM-1 downto 0));
  begin
    -- by default copy input control signals
    dout.rst:=din.rst; dout.vld:=din.vld; dout.ovf:=din.ovf;
    -- overflow/underflow not possible when LOUT>LIN
    RESIZE_CLIP(din=>din.re, dout=>dout.re, ovfl=>ovf_re, clip=>(m='S'));
    SUB(l=>to_signed(0,LIN_IM), r=>din.im, dout=>dout.im, ovfl=>ovf_im, clip=>(m='S'));
    if (m='O') then dout.ovf := dout.ovf or ovf_re or ovf_im; end if;
    dout := reset_on_demand(din=>dout, m=>m);
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
    m    : in  cplx_mode:="-" -- mode, supported options: 'R','O' and/or 'S'
  ) is
    variable ovf_re, ovf_im : std_logic;
  begin
    -- by default merge input control signals
    dout.rst := l.rst or r.rst;
    dout.vld := l.vld and r.vld;
    dout.ovf := l.ovf or r.ovf;
    ADD(l=>l.re, r=>r.re, dout=>dout.re, ovfl=>ovf_re, clip=>(m='S'));
    ADD(l=>l.im, r=>r.im, dout=>dout.im, ovfl=>ovf_im, clip=>(m='S'));
    if (m='O') then dout.ovf := dout.ovf or ovf_re or ovf_im; end if;
    dout := reset_on_demand(din=>dout, m=>m);
  end procedure;

  function add (
    l,r  : cplx; -- left/right summand
    w    : natural:=0; -- output bit width
    m    : cplx_mode:="-" -- mode, supported options: 'R','O' and/or 'S'
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
    m    : cplx_mode:="-" -- mode, supported options: 'R','O' and/or 'S'
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
    m    : cplx_mode:="-" -- mode, supported options: 'R','O' and/or 'S'
  ) return cplx
  is
    constant LVEC : positive := din'length; -- vector length
    constant LIN : positive := MAXIMUM(din(din'left).re'length,din(din'left).im'length); -- default output bit width
    constant LOUT : positive := default_if_zero(w, dflt=>LIN); -- final output bit width
    alias xdin : cplx_vector(1 to LVEC) is din; -- default range
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
    m    : in  cplx_mode:="-" -- mode, supported options: 'R','O' and/or 'S'
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
    m    : in  cplx_mode:="-" -- mode, supported options: 'R','O' and/or 'S'
  ) is
    variable ovf_re, ovf_im : std_logic;
  begin
    -- by default merge input control signals
    dout.rst := l.rst or r.rst;
    dout.vld := l.vld and r.vld;
    dout.ovf := l.ovf or r.ovf;
    SUB(l=>l.re, r=>r.re, dout=>dout.re, ovfl=>ovf_re, clip=>(m='S'));
    SUB(l=>l.im, r=>r.im, dout=>dout.im, ovfl=>ovf_im, clip=>(m='S'));
    if (m='O') then dout.ovf := dout.ovf or ovf_re or ovf_im; end if;
    dout := reset_on_demand(din=>dout, m=>m);
  end procedure;

  -- complex subtraction with optional clipping and overflow detection
  -- d = l - r  (sum is resized to given output bit width of sum)
  function sub (
    l,r  : cplx; -- data input, left minuend, right subtrahend
    w    : natural:=0; -- output bit width
    m    : cplx_mode:="-" -- mode, supported options: 'R','O' and/or 'S'
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
    m    : cplx_mode:="-" -- mode, supported options: 'R','O' and/or 'S'
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
    -- by default copy input control signals
    dout.rst:=din.rst; dout.vld:=din.vld; dout.ovf:=din.ovf;
    SHIFT_LEFT_CLIP(din=>din.re, n=>n, dout=>dout.re, ovfl=>ovf_re, clip=>(m='S'));
    SHIFT_LEFT_CLIP(din=>din.im, n=>n, dout=>dout.im, ovfl=>ovf_im, clip=>(m='S'));
    if m='O' then dout.ovf := din.ovf or ovf_re or ovf_im; end if;
    dout := reset_on_demand(din=>dout, m=>m);
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

  procedure shift_right (
    din  : in  cplx; -- data input
    n    : in  natural; -- number of right shifts
    dout : out cplx; -- data output
    m    : in  cplx_mode:="-" -- mode
  ) is
    variable ovf_re, ovf_im : std_logic;
  begin
    -- by default copy input control signals
    dout.rst:=din.rst; dout.vld:=din.vld; dout.ovf:=din.ovf;
    if m='N' then
      SHIFT_RIGHT_ROUND(din=>din.re, n=>n, dout=>dout.re, ovfl=>ovf_re, rnd=>nearest, clip=>(m='S'));
      SHIFT_RIGHT_ROUND(din=>din.im, n=>n, dout=>dout.im, ovfl=>ovf_im, rnd=>nearest, clip=>(m='S'));
    elsif m='U' then
      SHIFT_RIGHT_ROUND(din=>din.re, n=>n, dout=>dout.re, ovfl=>ovf_re, rnd=>ceil, clip=>(m='S'));
      SHIFT_RIGHT_ROUND(din=>din.im, n=>n, dout=>dout.im, ovfl=>ovf_im, rnd=>ceil, clip=>(m='S'));
    elsif m='Z' then
      SHIFT_RIGHT_ROUND(din=>din.re, n=>n, dout=>dout.re, ovfl=>ovf_re, rnd=>truncate, clip=>(m='S'));
      SHIFT_RIGHT_ROUND(din=>din.im, n=>n, dout=>dout.im, ovfl=>ovf_im, rnd=>truncate, clip=>(m='S'));
    elsif m='I' then
      SHIFT_RIGHT_ROUND(din=>din.re, n=>n, dout=>dout.re, ovfl=>ovf_re, rnd=>infinity, clip=>(m='S'));
      SHIFT_RIGHT_ROUND(din=>din.im, n=>n, dout=>dout.im, ovfl=>ovf_im, rnd=>infinity, clip=>(m='S'));
    else
      -- by default standard rounding, i.e. floor
      SHIFT_RIGHT_ROUND(din=>din.re, n=>n, dout=>dout.re, ovfl=>ovf_re, rnd=>floor, clip=>(m='S'));
      SHIFT_RIGHT_ROUND(din=>din.im, n=>n, dout=>dout.im, ovfl=>ovf_im, rnd=>floor, clip=>(m='S'));
    end if;
    if m='O' then dout.ovf := din.ovf or ovf_re or ovf_im; end if;
    dout := reset_on_demand(din=>dout, m=>m);
  end procedure;

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
    shift_right(din=>din, n=>n, dout=>dout, m=>m);
    return dout;
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
      shift_right(din=>din(i), n=>n, dout=>dout(i), m=>m);
    end loop;
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
    variable res : cplx(re(BITS-1 downto 0), im(BITS-1 downto 0));
  begin
    assert ((slv'length mod 2)=0)
      report "ERROR: to_cplx(), input std_logic_vector length must be even"
      severity failure;
    res.rst := rst;
    res.vld := vld;
    res.re  := signed(slv(  BITS-1 downto    0));
    res.im  := signed(slv(2*BITS-1 downto BITS));
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

end package body;
