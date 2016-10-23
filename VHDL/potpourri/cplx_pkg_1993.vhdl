-------------------------------------------------------------------------------
-- FILE    : cplx_pkg_1993.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 23/Oct/2016
-- VERSION : 0.3
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

package cplx_pkg is

  ------------------------------------------
  -- TYPES
  ------------------------------------------

  -- complex 2x16
  type cplx16 is
  record
    rst : std_logic; -- reset
    vld : std_logic; -- data valid
    re  : signed(15 downto 0); -- data real component
    im  : signed(15 downto 0); -- data imaginary component 
    ovf : std_logic; -- data overflow (or clipping)
  end record;

  -- complex 2x18 type
  type cplx18 is
  record
    rst : std_logic; -- reset
    vld : std_logic; -- data valid
    re  : signed(17 downto 0); -- data real component
    im  : signed(17 downto 0); -- data imaginary component 
    ovf : std_logic; -- data overflow (or clipping)
  end record;

  -- complex 2x20 type
  type cplx20 is
  record
    rst : std_logic; -- reset
    vld : std_logic; -- data valid
    re  : signed(19 downto 0); -- data real component
    im  : signed(19 downto 0); -- data imaginary component 
    ovf : std_logic; -- data overflow (or clipping)
  end record;

  -- complex 2x16 vector type
  type cplx16_vector is array(integer range <>) of cplx16;

  -- complex 2x18 vector type
  type cplx18_vector is array(integer range <>) of cplx18;

  -- complex 2x20 vector type
  type cplx20_vector is array(integer range <>) of cplx20;

  type cplx_mode is (
    STD     , -- standard (truncate, wrap, no overflow detection)
    OVF     , -- just overflow/underflow detection
    CLP     , -- just clipping
    RND     , -- rounding
    CLP_OVF   -- clipping including overflow/underflow detection
  );

  ------------------------------------------
  -- ADDITION
  ------------------------------------------

  -- complex addition with optional clipping and overflow detection
  function add (l,r: cplx16; m:cplx_mode:=STD) return cplx16;
  -- complex addition with optional clipping and overflow detection
  function add (l,r: cplx18; m:cplx_mode:=STD) return cplx18;
  -- complex addition with optional clipping and overflow detection
  function add (l,r: cplx20; m:cplx_mode:=STD) return cplx20;

  function "+" (l,r: cplx16) return cplx16;
  function "+" (l,r: cplx18) return cplx18;
  function "+" (l,r: cplx20) return cplx20;
    
  ------------------------------------------
  -- SUBSTRACTION
  ------------------------------------------

  -- complex subtraction with optional clipping and overflow detection
  function sub (l,r: cplx16; m:cplx_mode:=STD) return cplx16;
  -- complex subtraction with optional clipping and overflow detection
  function sub (l,r: cplx18; m:cplx_mode:=STD) return cplx18;
  -- complex subtraction with optional clipping and overflow detection
  function sub (l,r: cplx20; m:cplx_mode:=STD) return cplx20;

  function "-" (l,r: cplx16) return cplx16;
  function "-" (l,r: cplx18) return cplx18;
  function "-" (l,r: cplx20) return cplx20;

  ------------------------------------------
  -- SHIFT RIGHT (similar to NUMERIC_STD)
  ------------------------------------------

  -- complex signed shift right with optional rounding
  function shift_right (arg:cplx16 ; n:natural; m:cplx_mode:=STD) return cplx16;
  -- complex signed shift right with optional rounding
  function shift_right (arg:cplx18 ; n:natural; m:cplx_mode:=STD) return cplx18;
  -- complex signed shift right with optional rounding
  function shift_right (arg:cplx20 ; n:natural; m:cplx_mode:=STD) return cplx20;

  ------------------------------------------
  -- SHIFT LEFT (similar to NUMERIC_STD)
  ------------------------------------------

  -- complex signed shift left with optional clipping and overflow detection
  function shift_left (arg:cplx16 ; n:natural; m:cplx_mode:=STD) return cplx16;
  -- complex signed shift left with optional clipping and overflow detection
  function shift_left (arg:cplx18 ; n:natural; m:cplx_mode:=STD) return cplx18;
  -- complex signed shift left with optional clipping and overflow detection
  function shift_left (arg:cplx20 ; n:natural; m:cplx_mode:=STD) return cplx20;

  ------------------------------------------
  -- STD_LOGIC_VECTOR to CPLX
  ------------------------------------------

  -- convert SLV to cplx16 (real = 16 LSBs, imaginary = 16 MSBs)
  function to_cplx16 (
    slv : std_logic_vector(31 downto 0);
    vld : std_logic;
    rst : std_logic := '0'
  ) return cplx16;

  -- convert SLV to cplx18 (real = 18 LSBs, imaginary = 18 MSBs)
  function to_cplx18 (
    slv : std_logic_vector(35 downto 0);
    vld : std_logic;
    rst : std_logic := '0'
  ) return cplx18;

  ------------------------------------------
  -- STD_LOGIC_VECTOR to CPLX VECTOR
  ------------------------------------------

  -- convert SLV to cplx16 array (input must be multiple of 32 bits)
  function to_cplx16_vector (
    slv : std_logic_vector;
    vld : std_logic;
    rst : std_logic := '0'
  ) return cplx16_vector;

  -- convert SLV to cplx18 array (input must be multiple of 36 bits)
  function to_cplx18_vector (
    slv : std_logic_vector;
    vld : std_logic;
    rst : std_logic := '0'
  ) return cplx18_vector;

  ------------------------------------------
  -- CPLX to STD_LOGIC_VECTOR
  ------------------------------------------
 
  -- convert cplx16 to SLV (real = 16 LSBs, imaginary = 16 MSBs)
  function to_slv (arg:cplx16) return std_logic_vector;

  -- convert cplx18 to SLV (real = 18 LSBs, imaginary = 18 MSBs)
  function to_slv (arg:cplx18) return std_logic_vector;

  ------------------------------------------
  -- CPLX VECTOR to STD_LOGIC_VECTOR
  ------------------------------------------

  -- convert cplx16 array to SLV (output is multiple of 32 bits)
  function to_slv (arg:cplx16_vector) return std_logic_vector;
  
  -- convert cplx18 array to SLV (output is multiple of 36 bits)
  function to_slv (arg:cplx18_vector) return std_logic_vector;

  ------------------------------------------
  -- RESIZE DOWN
  ------------------------------------------

  -- resize from CPLX18 down to CPLX16
  function resize (arg:cplx18; m:cplx_mode:=STD) return cplx16;
  -- resize from CPLX20 down to CPLX16
  function resize (arg:cplx20; m:cplx_mode:=STD) return cplx16;
  -- resize from CPLX20 down to CPLX18
  function resize (arg:cplx20; m:cplx_mode:=STD) return cplx18;

  ------------------------------------------
  -- RESIZE DOWN VECTOR
  ------------------------------------------

  -- vector resize from CPLX18 down to CPLX16
  function resize (arg:cplx18_vector; m:cplx_mode:=STD) return cplx16_vector;

  ------------------------------------------
  -- RESIZE UP
  ------------------------------------------

  -- resize from CPLX16 up to CPLX18 
  function resize (arg:cplx16) return cplx18;
  -- resize from CPLX16 up to CPLX20 
  function resize (arg:cplx16) return cplx20;
  -- resize from CPLX18 up to CPLX20 
  function resize (arg:cplx18) return cplx20;

  ------------------------------------------
  -- RESIZE UP VECTOR
  ------------------------------------------

  -- vector resize from CPLX16 up to CPLX18 
  function resize (arg:cplx16_vector) return cplx18_vector;

end package;

-------------------------------------------------------------------------------

package body cplx_pkg is

  --------------------
  -- local auxiliary
  --------------------

  function max (l,r: integer) return integer is
  begin
    if l > r then return l; else return r; end if;
  end function;

--  function min (l,r: integer) return integer is
--  begin
--    if l < r then return l; else return r; end if;
--  end function;

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

  -- check N number of MSB bits are identical 
  function SIGN_EXTENSION_CHECK (arg: signed; n:natural) return std_logic is
    constant L : positive := arg'length;
    variable x : std_logic_vector(arg'length-1 downto 0);
    variable ok : std_logic := '0'; -- default result
  begin
    if n<L then
      x := std_logic_vector(arg);
      ok := ALL_HIGH(x(L-1 downto L-1-n)) or ALL_HIGH(x(L-1 downto L-1-n));
    end if; 
    return ok; 
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

  -- signed subtraction with optional clipping and overflow detection
  procedure SUB_CLP_OVF(l,r:in signed; s:out signed; ovfl:out std_logic; m:in cplx_mode:=STD) is
    constant SIZE : positive := max(l'length,r'length);
    alias xl : signed(l'length-1 downto 0) is l; -- default range
    alias xr : signed(r'length-1 downto 0) is r; -- default range
    alias xs : signed(s'length-1 downto 0) is s; -- default range
    variable t : signed(SIZE downto 0);
  begin
    t := RESIZE(xl,SIZE+1) - RESIZE(xr,SIZE+1);
    RESIZE(din=>t, dout=>xs, ovfl=>ovfl, m=>m);
  end procedure;

  function SHIFT_RIGHT_ROUND(din:signed; N:natural) return signed is
    constant L : positive := din'length;
    alias d : signed(L-1 downto 0) is din; -- default range
    variable t : signed(L downto 0) := (others=>din(din'left)); -- sign extension bits
    variable dout : signed(L-1 downto 0) := (others=>'0'); -- default when N>=L
  begin
    if N=0 then
      dout := din;
    elsif N<L then
      t(L-N downto 0) := d(L-1 downto N-1);
      t := t + 1;
      dout := t(L downto 1); -- remove rounding LSB
    end if;  
    return dout;
  end function;

  procedure SHIFT_LEFT_CLIP(
    din  : in  signed;
    n    : in  natural;
    dout : out signed;
    ovf  : out std_logic
  ) is
    constant LIN : positive := din'length-1;
    alias d : signed(LIN downto 0) is din; -- default range
    variable r_dout : signed(LIN downto 0) := (others=>'0'); -- default output
  begin
    if (LIN<1) then
      r_dout := (others=>'X');
      ovf := 'X';
    elsif (n<=LIN) then
      if d(LIN)='0' and d(LIN-1 downto LIN-n)/=(LIN-1 downto LIN-n=>'0') then
        -- positive clipping
        r_dout(LIN-1 downto 0):=(others=>'1'); -- sign remains default '0'
        ovf := '1';
      elsif d(LIN)='1' and d(LIN-1 downto LIN-n)/=(LIN-1 downto LIN-n=>'1') then
        -- negative clipping
        r_dout(LIN):='1'; -- LSBs remain default '0'
        ovf := '1';
      else
        -- standard left shift
        r_dout(LIN downto n) := d(LIN-n downto 0); -- LSBs remain default '0'
        ovf := '0';
      end if;
    end if;
    dout := r_dout;
  end procedure;

  ---------------------------
  -- ADDITION
  ---------------------------
  function add (l,r: cplx16; m:cplx_mode:=STD) return cplx16
  is 
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx16;
  begin
    res.rst := l.rst or r.rst;
    res.vld := l.vld and r.vld;
    ADD_CLP_OVF(l=>l.re, r=>r.re, s=>res.re, ovfl=>ovfl_re, m=>m);
    ADD_CLP_OVF(l=>l.im, r=>r.im, s=>res.im, ovfl=>ovfl_im, m=>m);
    res.ovf := l.ovf or r.ovf or ovfl_re or ovfl_im;
    return res;
  end function;

  function add (l,r: cplx18; m:cplx_mode:=STD) return cplx18
  is 
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx18;
  begin
    res.rst := l.rst or r.rst;
    res.vld := l.vld and r.vld;
    ADD_CLP_OVF(l=>l.re, r=>r.re, s=>res.re, ovfl=>ovfl_re, m=>m);
    ADD_CLP_OVF(l=>l.im, r=>r.im, s=>res.im, ovfl=>ovfl_im, m=>m);
    res.ovf := l.ovf or r.ovf or ovfl_re or ovfl_im;
    return res;
  end function;

  function add (l,r: cplx20; m:cplx_mode:=STD) return cplx20
  is 
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx20;
  begin
    res.rst := l.rst or r.rst;
    res.vld := l.vld and r.vld;
    ADD_CLP_OVF(l=>l.re, r=>r.re, s=>res.re, ovfl=>ovfl_re, m=>m);
    ADD_CLP_OVF(l=>l.im, r=>r.im, s=>res.im, ovfl=>ovfl_im, m=>m);
    res.ovf := l.ovf or r.ovf or ovfl_re or ovfl_im;
    return res;
  end function;

  function "+" (l,r: cplx16) return cplx16 is
  begin
    return add(l, r, m=>STD);
  end function;

  function "+" (l,r: cplx18) return cplx18 is
  begin
    return add(l, r, m=>STD);
  end function;

  function "+" (l,r: cplx20) return cplx20 is
  begin
    return add(l, r, m=>STD);
  end function;

  ---------------------------
  -- SUBSTRACTION
  ---------------------------
  function sub (l,r: cplx16; m:cplx_mode:=STD) return cplx16
  is 
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx16;
  begin
    res.rst := l.rst or r.rst;
    res.vld := l.vld and r.vld;
    SUB_CLP_OVF(l=>l.re, r=>r.re, s=>res.re, ovfl=>ovfl_re, m=>m);
    SUB_CLP_OVF(l=>l.im, r=>r.im, s=>res.im, ovfl=>ovfl_im, m=>m);
    res.ovf := l.ovf or r.ovf or ovfl_re or ovfl_im;
    return res;
  end function;

  function sub (l,r: cplx18; m:cplx_mode:=STD) return cplx18
  is 
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx18;
  begin
    res.rst := l.rst or r.rst;
    res.vld := l.vld and r.vld;
    SUB_CLP_OVF(l=>l.re, r=>r.re, s=>res.re, ovfl=>ovfl_re, m=>m);
    SUB_CLP_OVF(l=>l.im, r=>r.im, s=>res.im, ovfl=>ovfl_im, m=>m);
    res.ovf := l.ovf or r.ovf or ovfl_re or ovfl_im;
    return res;
  end function;

  function sub (l,r: cplx20; m:cplx_mode:=STD) return cplx20
  is 
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx20;
  begin
    res.rst := l.rst or r.rst;
    res.vld := l.vld and r.vld;
    SUB_CLP_OVF(l=>l.re, r=>r.re, s=>res.re, ovfl=>ovfl_re, m=>m);
    SUB_CLP_OVF(l=>l.im, r=>r.im, s=>res.im, ovfl=>ovfl_im, m=>m);
    res.ovf := l.ovf or r.ovf or ovfl_re or ovfl_im;
    return res;
  end function;

  function "-" (l,r: cplx16) return cplx16 is
  begin
    return sub(l, r, m=>STD);
  end function;

  function "-" (l,r: cplx18) return cplx18 is
  begin
    return sub(l, r, m=>STD);
  end function;

  function "-" (l,r: cplx20) return cplx20 is
  begin
    return sub(l, r, m=>STD);
  end function;

  ---------------------------
  -- SHIFT RIGHT
  ---------------------------

  function shift_right (arg:cplx16 ; n:natural; m:cplx_mode:=STD) return cplx16
  is
    variable res : cplx16;
  begin
    res.rst := arg.rst;
    res.vld := arg.vld;
    if m=RND then
      res.re := SHIFT_RIGHT_ROUND(arg.re, n); -- real part
      res.im := SHIFT_RIGHT_ROUND(arg.im, n); -- imaginary part
    else
      res.re := shift_right(arg.re, n); -- real part
      res.im := shift_right(arg.im, n); -- imaginary part
    end if;
    res.ovf := arg.ovf; -- shift right cannot cause overflow 
    return res;
  end function;

  function shift_right (arg:cplx18 ; n:natural; m:cplx_mode:=STD) return cplx18
  is
    variable res : cplx18;
  begin
    res.rst := arg.rst;
    res.vld := arg.vld;
    if m=RND then
      res.re := SHIFT_RIGHT_ROUND(arg.re, n); -- real part
      res.im := SHIFT_RIGHT_ROUND(arg.im, n); -- imaginary part
    else
      res.re := shift_right(arg.re, n); -- real part
      res.im := shift_right(arg.im, n); -- imaginary part
    end if;
    res.ovf := arg.ovf; -- shift right cannot cause overflow 
    return res;
  end function;

  function shift_right (arg:cplx20 ; n:natural; m:cplx_mode:=STD) return cplx20
  is
    variable res : cplx20;
  begin
    res.rst := arg.rst;
    res.vld := arg.vld;
    if m=RND then
      res.re := SHIFT_RIGHT_ROUND(arg.re, n); -- real part
      res.im := SHIFT_RIGHT_ROUND(arg.im, n); -- imaginary part
    else
      res.re := shift_right(arg.re, n); -- real part
      res.im := shift_right(arg.im, n); -- imaginary part
    end if;
    res.ovf := arg.ovf; -- shift right cannot cause overflow 
    return res;
  end function;

  ---------------------------
  -- SHIFT LEFT
  ---------------------------

  function shift_left (arg:cplx16 ; n:natural; m:cplx_mode:=STD) return cplx16
  is
    variable ovf_re, ovf_im : std_logic;
    variable res : cplx16;
  begin
    if n=0 then
      res := arg; -- nothing to do
    else
      res.rst := arg.rst;
      res.vld := arg.vld;
      if m=CLP or m=CLP_OVF then
        SHIFT_LEFT_CLIP(din=>arg.re, n=>n, dout=>res.re, ovf=>ovf_re);
        SHIFT_LEFT_CLIP(din=>arg.im, n=>n, dout=>res.im, ovf=>ovf_im);
      else
        res.re := shift_left(arg.re, n); -- real part
        res.im := shift_left(arg.im, n); -- imaginary part
        ovf_re := not SIGN_EXTENSION_CHECK(arg.re,n);
        ovf_im := not SIGN_EXTENSION_CHECK(arg.im,n);
      end if;
      if m=OVF or m=CLP_OVF then
        res.ovf := arg.ovf or ovf_re or ovf_im;
      else
        res.ovf := arg.ovf; -- overflow detection disabled
      end if;
    end if;
    return res;
  end function;

  function shift_left (arg:cplx18 ; n:natural; m:cplx_mode:=STD) return cplx18
  is
    variable ovf_re, ovf_im : std_logic;
    variable res : cplx18;
  begin
    if n=0 then
      res := arg; -- nothing to do
    else
      res.rst := arg.rst;
      res.vld := arg.vld;
      if m=CLP or m=CLP_OVF then
        SHIFT_LEFT_CLIP(din=>arg.re, n=>n, dout=>res.re, ovf=>ovf_re);
        SHIFT_LEFT_CLIP(din=>arg.im, n=>n, dout=>res.im, ovf=>ovf_im);
      else
        res.re := shift_left(arg.re, n); -- real part
        res.im := shift_left(arg.im, n); -- imaginary part
        ovf_re := not SIGN_EXTENSION_CHECK(arg.re,n);
        ovf_im := not SIGN_EXTENSION_CHECK(arg.im,n);
      end if;
      if m=OVF or m=CLP_OVF then
        res.ovf := arg.ovf or ovf_re or ovf_im;
      else
        res.ovf := arg.ovf; -- overflow detection disabled
      end if;
    end if;
    return res;
  end function;

  function shift_left (arg:cplx20 ; n:natural; m:cplx_mode:=STD) return cplx20
  is
    variable ovf_re, ovf_im : std_logic;
    variable res : cplx20;
  begin
    if n=0 then
      res := arg; -- nothing to do
    else
      res.rst := arg.rst;
      res.vld := arg.vld;
      if m=CLP or m=CLP_OVF then
        SHIFT_LEFT_CLIP(din=>arg.re, n=>n, dout=>res.re, ovf=>ovf_re);
        SHIFT_LEFT_CLIP(din=>arg.im, n=>n, dout=>res.im, ovf=>ovf_im);
      else
        res.re := shift_left(arg.re, n); -- real part
        res.im := shift_left(arg.im, n); -- imaginary part
        ovf_re := not SIGN_EXTENSION_CHECK(arg.re,n);
        ovf_im := not SIGN_EXTENSION_CHECK(arg.im,n);
      end if;
      if m=OVF or m=CLP_OVF then
        res.ovf := arg.ovf or ovf_re or ovf_im;
      else
        res.ovf := arg.ovf; -- overflow detection disabled
      end if;
    end if;
    return res;
  end function;

  ------------------------------------------
  -- STD_LOGIC_VECTOR to CPLX
  ------------------------------------------

  function to_cplx16 (
    slv : std_logic_vector(31 downto 0);
    vld : std_logic;
    rst : std_logic := '0'
  ) return cplx16
  is
    constant BITS : integer := 16;
    variable res : cplx16;
  begin
    res.rst := rst;
    res.vld := vld;
    res.re  := signed( slv(  BITS-1 downto    0) );
    res.im  := signed( slv(2*BITS-1 downto BITS) );
    res.ovf := '0';
    return res;
  end function;

  function to_cplx18 (
    slv : std_logic_vector(35 downto 0);
    vld : std_logic;
    rst : std_logic := '0'
  ) return cplx18
  is
    constant BITS : integer := 18;
    variable res : cplx18;
  begin
    res.rst := rst;
    res.vld := vld;
    res.re := signed( slv(  BITS-1 downto    0) );
    res.im := signed( slv(2*BITS-1 downto BITS) );
    res.ovf := '0';
    return res;
  end function;

  ------------------------------------------
  -- STD_LOGIC_VECTOR to CPLX VECTOR
  ------------------------------------------

  function to_cplx16_vector (
    slv : std_logic_vector;
    vld : std_logic;
    rst : std_logic := '0'
  ) return cplx16_vector
  is
    constant BITS : integer := 16;
    constant N : integer := slv'length/BITS/2;
    variable res : cplx16_vector(0 to N-1);
  begin
    for i in 0 to N-1 loop
      res(i) := to_cplx16(slv=>slv(2*BITS*(i+1)-1 downto 2*BITS*i), vld=>vld, rst=>rst);
    end loop;
    return res;
  end function;

  function to_cplx18_vector (
    slv : std_logic_vector;
    vld : std_logic;
    rst : std_logic := '0'
  ) return cplx18_vector
  is
    constant BITS : integer := 18;
    constant N : integer := slv'length/BITS/2;
    variable res : cplx18_vector(0 to N-1);
  begin
    for i in 0 to N-1 loop 
      res(i) := to_cplx18(slv(2*BITS*(i+1)-1 downto 2*BITS*i), vld=>vld, rst=>rst);
    end loop;
    return res;
  end function;

  ------------------------------------------
  -- CPLX to STD_LOGIC_VECTOR
  ------------------------------------------

  function to_slv (arg : cplx16) return std_logic_vector
  is
    constant BITS : integer := 16;
    variable slv : std_logic_vector(2*BITS-1 downto 0);
  begin
    slv(  BITS-1 downto    0) := std_logic_vector(arg.re);
    slv(2*BITS-1 downto BITS) := std_logic_vector(arg.im);
    return slv;
  end function;

  function to_slv (arg : cplx18) return std_logic_vector
  is
    constant BITS : integer := 18;
    variable slv : std_logic_vector(2*BITS-1 downto 0);
  begin
    slv(  BITS-1 downto    0) := std_logic_vector(arg.re);
    slv(2*BITS-1 downto BITS) := std_logic_vector(arg.im);
    return slv;
  end function;

  ------------------------------------------
  -- CPLX VECTOR to STD_LOGIC_VECTOR
  ------------------------------------------

  function to_slv (arg : cplx16_vector) return std_logic_vector
  is
    constant BITS : integer := 16;
    constant N : integer := arg'length;
    variable slv : std_logic_vector(2*BITS*N-1 downto 0);
    variable i : integer range 0 to N := 0;
  begin
    for e in arg'range loop
      slv(2*BITS*(i+1)-1 downto 2*BITS*i) := to_slv(arg(e));
      i := i+1;
    end loop;
    return slv;
  end function;

  function to_slv (arg : cplx18_vector) return std_logic_vector
  is
    constant BITS : integer := 18;
    constant N : integer := arg'length;
    variable slv : std_logic_vector(2*BITS*N-1 downto 0);
    variable i : integer range 0 to N := 0;
  begin
    for e in arg'range loop 
      slv(2*BITS*(i+1)-1 downto 2*BITS*i) := to_slv(arg(e));
      i := i+1;
    end loop;
    return slv;
  end function;


  ------------------------------------------
  -- RESIZE DOWN
  ------------------------------------------

  function resize (arg:cplx18; m:cplx_mode:=STD) return cplx16
  is
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx16;
  begin
    res.rst := arg.rst;
    res.vld := arg.vld;
    RESIZE(din=>arg.re, dout=>res.re, ovfl=>ovfl_re, m=>m);
    RESIZE(din=>arg.im, dout=>res.im, ovfl=>ovfl_im, m=>m);
    if m=OVF or m=CLP_OVF then
      res.ovf := arg.ovf or ovfl_re or ovfl_im;
    else
      res.ovf := arg.ovf; -- overflow detection disabled
    end if;
    return res;
  end function;

  function resize (arg:cplx20; m:cplx_mode:=STD) return cplx16
  is
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx16;
  begin
    res.rst := arg.rst;
    res.vld := arg.vld;
    RESIZE(din=>arg.re, dout=>res.re, ovfl=>ovfl_re, m=>m);
    RESIZE(din=>arg.im, dout=>res.im, ovfl=>ovfl_im, m=>m);
    if m=OVF or m=CLP_OVF then
      res.ovf := arg.ovf or ovfl_re or ovfl_im;
    else
      res.ovf := arg.ovf; -- overflow detection disabled
    end if;
    return res;
  end function;

  function resize (arg:cplx20; m:cplx_mode:=STD) return cplx18
  is
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx18;
  begin
    res.rst := arg.rst;
    res.vld := arg.vld;
    RESIZE(din=>arg.re, dout=>res.re, ovfl=>ovfl_re, m=>m);
    RESIZE(din=>arg.im, dout=>res.im, ovfl=>ovfl_im, m=>m);
    if m=OVF or m=CLP_OVF then
      res.ovf := arg.ovf or ovfl_re or ovfl_im;
    else
      res.ovf := arg.ovf; -- overflow detection disabled
    end if;
    return res;
  end function;

  ------------------------------------------
  -- RESIZE DOWN VECTOR
  ------------------------------------------

  function resize (arg:cplx18_vector; m:cplx_mode:=STD) return cplx16_vector
  is
    variable res : cplx16_vector(arg'range);
  begin
    for i in arg'range loop res(i) := resize(arg=>arg(i), m=>m); end loop;
    return res;
  end function;

  ------------------------------------------
  -- RESIZE UP
  ------------------------------------------

  function resize (arg:cplx16) return cplx18
  is
    constant LOUT : positive := 18;
    variable res : cplx18;
  begin
    res.rst := arg.rst;
    res.vld := arg.vld;
    res.re  := RESIZE(arg.re,LOUT);
    res.im  := RESIZE(arg.im,LOUT);
    res.ovf := arg.ovf; -- increasing size cannot cause overflow 
    return res;
  end function;

  function resize (arg:cplx16) return cplx20
  is
    constant LOUT : positive := 20;
    variable res : cplx20;
  begin
    res.rst := arg.rst;
    res.vld := arg.vld;
    res.re  := RESIZE(arg.re,LOUT);
    res.im  := RESIZE(arg.im,LOUT);
    res.ovf := arg.ovf; -- increasing size cannot cause overflow 
    return res;
  end function;

  function resize (arg:cplx18) return cplx20
  is
    constant LOUT : positive := 20;
    variable res : cplx20;
  begin
    res.rst := arg.rst;
    res.vld := arg.vld;
    res.re  := RESIZE(arg.re,LOUT);
    res.im  := RESIZE(arg.im,LOUT);
    res.ovf := arg.ovf; -- increasing size cannot cause overflow 
    return res;
  end function;

  ------------------------------------------
  -- RESIZE UP VECTOR
  ------------------------------------------

  function resize (arg:cplx16_vector) return cplx18_vector
  is
    variable res : cplx18_vector(arg'range);
  begin
    for i in arg'range loop res(i) := resize(arg(i)); end loop;
    return res;
  end function;

end package body;
