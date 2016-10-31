-------------------------------------------------------------------------------
-- FILE    : cplx_pkg_2008.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 31/Oct/2016
-- VERSION : 0.4
-- VHDL    : 2008
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
 use fixitfetish.ieee_extension.all;

package cplx_pkg is

  ------------------------------------------
  -- TYPES
  ------------------------------------------

  -- general unconstrained complex type
  type cplx is
  record
    rst : std_logic; -- reset
    vld : std_logic; -- data valid
    re  : signed; -- data real component (downto direction assumed)
    im  : signed; -- data imaginary component (downto direction assumed)
    ovf : std_logic; -- data overflow (or clipping)
  end record;

  subtype cplx16 is cplx(re(15 downto 0), im(15 downto 0));
  subtype cplx18 is cplx(re(17 downto 0), im(17 downto 0));
  subtype cplx20 is cplx(re(19 downto 0), im(19 downto 0));
  subtype cplx22 is cplx(re(21 downto 0), im(21 downto 0));

  -- general unconstrained complex vector type
  type cplx_vector is array(integer range <>) of cplx;

  subtype cplx16_vector is cplx_vector(open)(re(15 downto 0), im(15 downto 0));
  subtype cplx18_vector is cplx_vector(open)(re(17 downto 0), im(17 downto 0));
  subtype cplx20_vector is cplx_vector(open)(re(19 downto 0), im(19 downto 0));
  subtype cplx22_vector is cplx_vector(open)(re(21 downto 0), im(21 downto 0));

  type cplx_option is (
    '-', -- don't care, use defaults
    'R', -- use reset on RE/IM (set RE=0 and IM=0)
    'O', -- enable overflow/underflow detection (by default off)
    'S', -- enable saturation/clipping (by default off)
    'D', -- round down towards minus infinity, floor (default, just remove LSBs)
    'N', -- round to nearest (standard rounding, i.e. +0.5 and then remove LSBs)
    'U', -- round up towards plus infinity, ceil
    'Z', -- round towards zero, truncate
    'I'  -- round towards plus/minus infinity, i.e. away from zero
--  'F'  -- flush, required/needed ?
--  'C'  -- clear, required/needed ?
  );
  
  -- Complex operations can be used with one or more the following options.
  -- Note that some options can not be combined, e.g. different rounding options.
  -- '-' -- don't care, use defaults
  -- 'R' -- use reset on RE/IM (set RE=0 and IM=0)
  -- 'O' -- enable overflow/underflow detection (by default off)
  -- 'S' -- enable saturation/clipping (by default off)
  -- 'D' -- round down towards minus infinity, floor (default, just remove LSBs)
  -- 'N' -- round to nearest (standard rounding, i.e. +0.5 and then remove LSBs)
  -- 'U' -- round up towards plus infinity, ceil
  -- 'Z' -- round towards zero, truncate
  -- 'I' -- round towards plus/minus infinity, i.e. away from zero
  type cplx_mode is array(integer range <>) of cplx_option;
  
  ------------------------------------------
  -- RESIZE
  ------------------------------------------

  -- resize to given bit width (similar to NUMERIC_STD)
  function resize(
    din : cplx; -- data input
    n   : natural; -- output bit width
    m   : cplx_mode:="-" -- mode
  ) return cplx;

  -- resize to size of connected output
  procedure resize (
    din  : in  cplx; -- data input
    dout : out cplx; -- data output
    m    : in  cplx_mode:="-" -- mode
  );

  ------------------------------------------
  -- RESIZE VECTOR
  ------------------------------------------

  ------------------------------------------
  -- ADDITION and ACCUMULATION
  ------------------------------------------

  -- complex addition with optional clipping and overflow detection
  -- (sum is resized to given output bit width of sum)
  function add (
    l,r  : cplx; -- left/right summand
    w    : positive; -- output bit width
    m    : cplx_mode:="-"
  ) return cplx;

  -- complex addition with optional clipping and overflow detection
  -- (sum is resized to size of connected output)
  procedure add (
    l,r  : in  cplx; -- left/right summand
    dout : out cplx; -- data output, result of sum
    m    : in  cplx_mode:="-" -- mode
  );

  -- complex addition with wrap and overflow detection
  -- (bit width of sum equals the max bit width of summands)
  function "+" (l,r: cplx) return cplx;

  -- sum of vector elements with optional clipping and overflow detection
  -- (sum result is resized to given bit width of sum)
  function sum (
    din  : cplx_vector; -- data input vector
    w    : positive; -- output bit width
    m    : cplx_mode:="-" -- mode
  ) return cplx;

  -- sum of vector elements with optional clipping and overflow detection
  -- (sum result is resized to size of connected output)
  procedure sum (
    din  : in  cplx_vector; -- data input vector
    dout : out cplx; -- data output, result of sum
    m    : in  cplx_mode:="-" -- mode
  );

  ------------------------------------------
  -- SUBSTRACTION
  ------------------------------------------

  ------------------------------------------
  -- SHIFT RIGHT and ROUNDING
  ------------------------------------------

  -- complex signed shift right with optional rounding
  function shift_right (
    din  : cplx; -- data input
    n    : natural; -- number of right shifts
    m    : cplx_mode:="-" -- mode
  ) return cplx;

  -- complex signed shift right with optional rounding
  procedure shift_right (
    din  : in  cplx; -- data input
    n    : in  natural; -- number of right shifts
    dout : out cplx; -- data output
    ovfl : out std_logic; -- '1' if overflow occured
    m    : in  cplx_mode:="-" -- mode
  );

end package;

-------------------------------------------------------------------------------

package body cplx_pkg is

  ------------------------------------------
  -- local auxiliary
  ------------------------------------------

  function "=" (l:cplx_mode; r:cplx_option) return boolean is
    variable res : boolean := false;
  begin
    for i in l'range loop
      res := res or (l(i)=r);
    end loop;
    return res;
  end function;

  function max (l,r: integer) return integer is
  begin
    if l > r then return l; else return r; end if;
  end function;

--  function min (l,r: integer) return integer is
--  begin
--    if l < r then return l; else return r; end if;
--  end function;

  function log2ceil (n:positive) return natural is
    variable n_bit : unsigned(31 downto 0);
  begin
    n_bit := to_unsigned(n-1,32);
    for i in 31 downto 0 loop
      if n_bit(i) = '1' then
        return i+1;
      end if;
    end loop;
    return 1;
  end function;

  ------------------------------------------
  -- RESIZE
  ------------------------------------------

  function resize(
    din : cplx; -- data input
    n   : natural; -- output bit width
    m   : cplx_mode:="-" -- mode
  ) return cplx is
    variable ovfl_re, ovfl_im : std_logic;
    variable dout : cplx(re(n-1 downto 0),im(n-1 downto 0));
  begin
    -- data signals
    if m='R' and din.rst='1' then
      dout.re := (n-1 downto 0 => '0');
      dout.im := (n-1 downto 0 => '0');
    else
      RESIZE_CLIP(din=>din.re, dout=>dout.re, ovfl=>ovfl_re, clip=>(m='S'));
      RESIZE_CLIP(din=>din.im, dout=>dout.im, ovfl=>ovfl_im, clip=>(m='S'));
    end if;
    -- control signals
    dout.rst := din.rst;
    if m='R' and din.rst='1' then
      dout.vld := '0';
      dout.ovf := '0';
    else
      dout.vld := din.vld; 
      dout.ovf := din.ovf;
      if m='O' then dout.ovf := din.ovf or ovfl_re or ovfl_im; end if;
    end if;  
    return dout;
  end function;

  procedure resize (
    din  : in  cplx; -- data input
    dout : out cplx; -- data output
    m    : in  cplx_mode:="-" -- mode
  ) is
    constant LOUT : positive := dout.re'length;
  begin
    dout := resize(din=>din, n=>LOUT, m=>m);
  end procedure;

  ------------------------------------------
  -- RESIZE VECTOR
  ------------------------------------------

  ------------------------------------------
  -- ADDITION and ACCUMULATION
  ------------------------------------------

--  function add (l,r:cplx; width_sum:positive; m:cplx_mode:=STD) return cplx
  function add (
    l,r  : cplx; -- left/right summand
    w    : positive; -- output bit width
    m    : cplx_mode:="-"
  ) return cplx is
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx(re(w-1 downto 0),im(w-1 downto 0));
  begin
    res.rst := l.rst or r.rst;
    -- data signals
    if m='R' and res.rst='1' then
      res.re := (w-1 downto 0 => '0');
      res.im := (w-1 downto 0 => '0');
    else
      ADD_CLIP(l=>l.re, r=>r.re, dout=>res.re, ovfl=>ovfl_re, clip=>(m="S"));
      ADD_CLIP(l=>l.im, r=>r.im, dout=>res.im, ovfl=>ovfl_im, clip=>(m="S"));
    end if;
    -- control signals
    if m='R' and res.rst='1' then
      res.vld := '0';
      res.ovf := '0';
    else
      res.vld := l.vld and r.vld;
      res.ovf := l.ovf or r.ovf;
      if m='O' then res.ovf := res.ovf or ovfl_re or ovfl_im; end if;
    end if;  
    return res;
  end function;

  procedure add (
    l,r  : in  cplx; -- left/right summand
    dout : out cplx; -- data output, result of sum
    m    : in  cplx_mode:="-" -- mode
  ) is
    constant LOUT : positive := dout.re'length;
  begin
    dout := add(l=>l, r=>r, w=>LOUT, m=>m);
  end procedure;

  function "+" (l,r: cplx) return cplx is
    constant w : positive := max(l.re'length,r.re'length);
  begin
    return add(l=>l, r=>r, w=>w, m=>"O");
  end function;

  function sum (
    din  : cplx_vector; -- data input vector
    w    : positive; -- output bit width
    m    : cplx_mode:="-" -- mode
  ) return cplx
  is
    constant LVEC : positive := din'length; -- vector length
    alias xdin : cplx_vector(0 to LVEC-1) is din; -- default range
    constant LIN : positive := xdin(0).re'length; -- input bit width
    constant T : positive := LIN+log2ceil(LVEC); -- width including additional accumulation bits
    variable temp : cplx(re(T-1 downto 0),im(T-1 downto 0));
  begin
    temp := resize(din=>xdin(0),n=>LIN);
    if LVEC>1 then
      for i in 1 to LVEC-1 loop temp:=temp+xdin(i); end loop;
    end if;
    return resize(din=>temp, n=>w, m=>m);
  end function;

  procedure sum (
    din  : in  cplx_vector; -- data input vector
    dout : out cplx; -- data output, result of sum
    m    : in  cplx_mode:="-" -- mode
  ) is
    constant LOUT : positive := dout.re'length;
  begin
    dout := sum(din=>din, w=>LOUT, m=>m);
  end procedure;

  ------------------------------------------
  -- SUBSTRACTION
  ------------------------------------------

  ------------------------------------------
  -- SHIFT RIGHT and ROUND
  ------------------------------------------

  function shift_right (
    din  : cplx; -- data input
    n    : natural; -- number of right shifts
    m    : cplx_mode:="-" -- mode
  ) return cplx is
    constant SIZE_RE : positive := din.re'length;
    constant SIZE_IM : positive := din.im'length;
    variable dout : cplx(re(SIZE_RE-1 downto 0),im(SIZE_IM-1 downto 0));
  begin
    -- data signals
    if m='R' and din.rst='1' then
      dout.re := (SIZE_RE-1 downto 0 => '0');
      dout.im := (SIZE_IM-1 downto 0 => '0');
    elsif m='N' then
      dout.re := SHIFT_RIGHT_ROUND(din.re, n, nearest); -- real part
      dout.im := SHIFT_RIGHT_ROUND(din.im, n, nearest); -- imaginary part
    elsif m='U' then
      dout.re := SHIFT_RIGHT_ROUND(din.re, n, ceil); -- real part
      dout.im := SHIFT_RIGHT_ROUND(din.im, n, ceil); -- imaginary part
    elsif m='Z' then
      dout.re := SHIFT_RIGHT_ROUND(din.re, n, truncate); -- real part
      dout.im := SHIFT_RIGHT_ROUND(din.im, n, truncate); -- imaginary part
    elsif m='I' then
      dout.re := SHIFT_RIGHT_ROUND(din.re, n, infinity); -- real part
      dout.im := SHIFT_RIGHT_ROUND(din.im, n, infinity); -- imaginary part
    else
      -- by default standard rounding, i.e. floor
      dout.re := shift_right(din.re, n); -- real part
      dout.im := shift_right(din.im, n); -- imaginary part
    end if;
    -- control signals
    dout.rst := din.rst;
    if m='R' and din.rst='1' then
      dout.vld := '0';
      dout.ovf := '0';
    else
      dout.vld := din.vld;
      dout.ovf := din.ovf; -- shift right cannot cause overflow
    end if;  
    return dout;
  end function;

  procedure shift_right (
    din  : in  cplx; -- data input
    n    : in  natural; -- number of right shifts
    dout : out cplx; -- data output
    ovfl : out std_logic; -- '1' if overflow occured
    m    : in  cplx_mode:="-" -- mode
  ) is
    constant LIN_RE : positive := din.re'length;
    constant LIN_IM : positive := din.im'length;
    variable temp : cplx(re(LIN_RE-1 downto 0),im(LIN_IM-1 downto 0));
  begin
    temp := shift_right(din=>din, n=>n, m=>m);
    resize(din=>temp, dout=>dout, m=>m);
  end procedure;
  
end package body;
