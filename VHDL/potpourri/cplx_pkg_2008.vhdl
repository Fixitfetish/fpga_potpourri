-------------------------------------------------------------------------------
-- FILE    : cplx_pkg_2008.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 23/Oct/2016
-- VERSION : 0.1
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

  type cplx_mode is (
    STD     , -- standard (truncate, wrap, no overflow detection)
    OVF     , -- just overflow/underflow detection
    CLP     , -- just clipping
    RND     , -- rounding
    CLP_OVF   -- clipping including overflow/underflow detection
  );

  function resize (arg:cplx; n:natural; m:cplx_mode:=STD) return cplx;

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

  ------------------------------------------
  -- RESIZE
  ------------------------------------------

  function resize (arg:cplx; n:natural; m:cplx_mode:=STD) return cplx
  is
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx(re(n-1 downto 0),im(n-1 downto 0));
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


end package body;
