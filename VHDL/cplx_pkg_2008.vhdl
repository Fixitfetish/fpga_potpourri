-------------------------------------------------------------------------------
-- FILE    : cplx_pkg_2008.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 31/Oct/2016
-- VERSION : 0.3
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
  type cplx_switch is array(integer range <>) of cplx_option;
  
  type cplx_mode is (
    STD     , -- standard (truncate, wrap, no overflow detection)
    OVF     , -- just overflow/underflow detection
    CLP     , -- just clipping/saturation
    RND     , -- rounding
    CLP_OVF   -- clipping including overflow/underflow detection
  );

  ------------------------------------------
  -- RESIZE
  ------------------------------------------

  -- resize to given bit width
  function resize (din:cplx; n:natural; m:cplx_mode:=STD) return cplx;

  -- resize to size of connected output
  procedure resize (
    din  : in  cplx; -- data input
    dout : out cplx; -- data output
    m    : in  cplx_mode:=STD -- mode
  );

  ------------------------------------------
  -- RESIZE VECTOR
  ------------------------------------------

  ------------------------------------------
  -- ADDITION and ACCUMULATION
  ------------------------------------------

  -- complex addition with optional clipping and overflow detection
  -- (sum is resized to given bit width of sum)
  function add (l,r:cplx; width_sum:positive; m:cplx_mode:=STD) return cplx;

  -- complex addition with optional clipping and overflow detection
  -- (sum is resized to size of connected output)
  procedure add (
    l,r : in  cplx; -- left/right summand
    s   : out cplx; -- result sum
    m   : in  cplx_mode:=STD -- mode
  );

  -- complex addition with wrap and overflow detection
  -- (bit width of sum equals the max bit width of summands)
  function "+" (l,r: cplx) return cplx;

  -- sum of vector elements with optional clipping and overflow detection
  -- (sum result is resized to given bit width of sum)
  function sum (arg:cplx_vector; width_sum:positive; m:cplx_mode:=STD) return cplx;

  -- sum of vector elements with optional clipping and overflow detection
  -- (sum result is resized to size of connected output)
  procedure sum (
    arg : in  cplx_vector; -- input vector
    s   : out cplx; -- result sum
    m   : in  cplx_mode:=STD -- mode
  );

  ------------------------------------------
  -- SUBSTRACTION
  ------------------------------------------

  ------------------------------------------
  -- SHIFT RIGHT and ROUNDING
  ------------------------------------------

  -- complex signed shift right with optional rounding
  function shift_right (arg:cplx ; n:natural; m:cplx_switch:="-") return cplx;

end package;

-------------------------------------------------------------------------------

package body cplx_pkg is

  ------------------------------------------
  -- local auxiliary
  ------------------------------------------

  function "=" (l:cplx_switch; r:cplx_option) return boolean is
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

  function ALL_HIGH (arg: std_logic_vector) return std_logic is
    constant L : positive := arg'length;
    alias x : std_logic_vector(arg'length-1 downto 0) is arg; -- default range
    variable res : std_logic := '1';
  begin
    for i in 0 to L-1 loop  res := res and x(i); end loop;
    return res; 
  end function;
  
  function ALL_LOW (arg: std_logic_vector) return std_logic is
    constant L : positive := arg'length;
    alias x : std_logic_vector(arg'length-1 downto 0) is arg; -- default range
    variable res : std_logic := '0';
  begin
    for i in 0 to L-1 loop  res := res or x(i); end loop;
    return (not res); 
  end function;

  -- signed resize with optional clipping and overflow detection
  procedure RESIZE (din:in signed; dout:out signed; ovfl:out std_logic; m:in cplx_mode:=STD) is
    constant LIN : positive := din'length;
    constant LOUT : positive := dout'length;
    alias xdin : signed(LIN-1 downto 0) is din; -- default range
    alias xdout : signed(LOUT-1 downto 0) is dout; -- default range
    variable ov,ud : std_logic;
  begin
    xdout := resize(xdin,LOUT);
    ovfl := '0';
    if LIN>LOUT then
      -- if resized down then check for overflow/underflow  
      ov := (not xdin(LIN-1)) and (not ALL_LOW (std_logic_vector(xdin(LIN-2 downto LOUT-1))));
      ud :=      xdin(LIN-1)  and (not ALL_HIGH(std_logic_vector(xdin(LIN-2 downto LOUT-1))));
      -- clipping if required
      if (m=CLP) or (m=CLP_OVF) then
        if ov='1' then
          xdout(LOUT-1):='0'; xdout(LOUT-2 downto 0):=(others=>'1'); -- positive clipping
        elsif ud='1' then
          xdout(LOUT-1):='1'; xdout(LOUT-2 downto 0):=(others=>'0'); -- negative clipping
        end if;
      end if;
      -- overflow/underflow detection if required
      if (m=OVF) or (m=CLP_OVF) then
        ovfl := ov or ud;
      end if;
    end if;
  end procedure;

  -- signed addition with optional clipping and overflow detection
  procedure ADD_CLP_OVF(l,r:in signed; s:out signed; ovfl:out std_logic; m:in cplx_mode:=STD) is
    constant SIZE : positive := max(l'length,r'length);
    alias xl : signed(l'length-1 downto 0) is l; -- default range
    alias xr : signed(r'length-1 downto 0) is r; -- default range
    alias xs : signed(s'length-1 downto 0) is s; -- default range
    variable t : signed(SIZE downto 0);
  begin
    t := RESIZE(xl,SIZE+1) + RESIZE(xr,SIZE+1);
    RESIZE(din=>t, dout=>xs, ovfl=>ovfl, m=>m);
  end procedure;

  ------------------------------------------
  -- RESIZE
  ------------------------------------------

  function resize (din:cplx; n:natural; m:cplx_mode:=STD) return cplx
  is
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx(re(n-1 downto 0),im(n-1 downto 0));
  begin
    res.rst := din.rst;
    res.vld := din.vld;
    RESIZE(din=>din.re, dout=>res.re, ovfl=>ovfl_re, m=>m);
    RESIZE(din=>din.im, dout=>res.im, ovfl=>ovfl_im, m=>m);
    if m=OVF or m=CLP_OVF then
      res.ovf := din.ovf or ovfl_re or ovfl_im;
    else
      res.ovf := din.ovf; -- overflow detection disabled
    end if;
    return res;
  end function;

  procedure resize (
    din  : in  cplx; -- data input
    dout : out cplx; -- data output
    m    : in  cplx_mode:=STD -- mode
  ) is
    constant WOUT : positive := dout.re'length;
  begin
    dout := resize(din=>din, n=>WOUT, m=>m);
  end procedure;

  ------------------------------------------
  -- RESIZE VECTOR
  ------------------------------------------

  ------------------------------------------
  -- ADDITION and ACCUMULATION
  ------------------------------------------

  function add (l,r:cplx; width_sum:positive; m:cplx_mode:=STD) return cplx
  is
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx(re(width_sum-1 downto 0),im(width_sum-1 downto 0));
  begin
    res.rst := l.rst or r.rst;
    res.vld := l.vld and r.vld;
    ADD_CLP_OVF(l=>l.re, r=>r.re, s=>res.re, ovfl=>ovfl_re, m=>m);
    ADD_CLP_OVF(l=>l.im, r=>r.im, s=>res.im, ovfl=>ovfl_im, m=>m);
    res.ovf := l.ovf or r.ovf or ovfl_re or ovfl_im;
    return res;
  end function;

  procedure add (
    l,r : in  cplx; -- left/right summand
    s   : out cplx; -- result sum
    m   : in  cplx_mode:=STD -- mode
  ) is
    constant width_sum : positive := s.re'length;
  begin
    s := add(l, r, width_sum, m=>m);
  end procedure;

  function "+" (l,r: cplx) return cplx is
    constant width_sum : positive := max(l.re'length,r.re'length);
  begin
    return add(l, r, width_sum, m=>OVF);
  end function;

  function sum (arg:cplx_vector; width_sum:positive; m:cplx_mode:=STD) return cplx
  is
    constant L : positive := arg'length; -- vector length
    alias xarg : cplx_vector(0 to L-1) is arg; -- default range
    constant W : positive := xarg(0).re'length; -- input bit width
    constant T : positive := W+log2ceil(L); -- width including additional accumulation bits
    variable temp : cplx(re(T-1 downto 0),im(T-1 downto 0));
  begin
    temp := resize(din=>xarg(0),n=>W);
    if L>1 then
      for i in 1 to L-1 loop temp:=temp+xarg(i); end loop;
    end if;
    return resize(din=>temp, n=>width_sum, m=>m);
  end function;

  procedure sum (
    arg : in  cplx_vector; -- input vector
    s   : out cplx; -- result sum
    m   : in  cplx_mode:=STD -- mode
  ) is
    constant width_sum : positive := s.re'length;
  begin
    s := sum(arg, width_sum, m=>m);
  end procedure;

  ------------------------------------------
  -- SUBSTRACTION
  ------------------------------------------

  ------------------------------------------
  -- SHIFT RIGHT and ROUNDING
  ------------------------------------------

  function shift_right (arg:cplx; n:natural; m:cplx_switch:="-") return cplx
  is
    constant SIZE_RE : positive := arg.re'length;
    constant SIZE_IM : positive := arg.im'length;
    variable res : cplx(re(SIZE_RE-1 downto 0),im(SIZE_IM-1 downto 0));
  begin
    -- data signals
    if m='R' and arg.rst='1' then
      res.re := (SIZE_RE-1 downto 0 =>'0');
      res.im := (SIZE_IM-1 downto 0 =>'0');
    elsif m='N' then
      res.re := SHIFT_RIGHT_ROUND(arg.re, n, nearest); -- real part
      res.im := SHIFT_RIGHT_ROUND(arg.im, n, nearest); -- imaginary part
    elsif m='U' then
      res.re := SHIFT_RIGHT_ROUND(arg.re, n, ceil); -- real part
      res.im := SHIFT_RIGHT_ROUND(arg.im, n, ceil); -- imaginary part
    elsif m='Z' then
      res.re := SHIFT_RIGHT_ROUND(arg.re, n, truncate); -- real part
      res.im := SHIFT_RIGHT_ROUND(arg.im, n, truncate); -- imaginary part
    elsif m='I' then
      res.re := SHIFT_RIGHT_ROUND(arg.re, n, infinity); -- real part
      res.im := SHIFT_RIGHT_ROUND(arg.im, n, infinity); -- imaginary part
    else
      -- by default standard rounding, i.e. floor
      res.re := shift_right(arg.re, n); -- real part
      res.im := shift_right(arg.im, n); -- imaginary part
    end if;
    -- control signals
    res.rst := arg.rst;
    if m='R' and arg.rst='1' then
      res.vld := '0';
      res.ovf := '0';
    else
      res.vld := arg.vld;
      res.ovf := arg.ovf; -- shift right cannot cause overflow
    end if;  
    return res;
  end function;


end package body;
