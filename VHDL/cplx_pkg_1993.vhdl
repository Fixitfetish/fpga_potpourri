-------------------------------------------------------------------------------
-- FILE    : cplx_pkg_1993.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 31/Oct/2016
-- VERSION : 0.5
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
library fixitfetish;
 use fixitfetish.ieee_extension.all;

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
  constant CPLX16_RESET_ALL : cplx16 := (rst=>'1', vld|ovf=>'0', re|im=>(others=>'0'));
  constant CPLX16_RESET_DO_NOT_CARE_DATA : cplx16 := (rst=>'1', vld|ovf=>'0', re|im=>(others=>'-'));

  -- complex 2x18 type
  type cplx18 is
  record
    rst : std_logic; -- reset
    vld : std_logic; -- data valid
    re  : signed(17 downto 0); -- data real component
    im  : signed(17 downto 0); -- data imaginary component 
    ovf : std_logic; -- data overflow (or clipping)
  end record;
  constant CPLX18_RESET_ALL : cplx16 := (rst=>'1', vld|ovf=>'0', re|im=>(others=>'0'));
  constant CPLX18_RESET_DO_NOT_CARE_DATA : cplx16 := (rst=>'1', vld|ovf=>'0', re|im=>(others=>'-'));

  -- complex 2x20 type
  type cplx20 is
  record
    rst : std_logic; -- reset
    vld : std_logic; -- data valid
    re  : signed(19 downto 0); -- data real component
    im  : signed(19 downto 0); -- data imaginary component 
    ovf : std_logic; -- data overflow (or clipping)
  end record;
  constant CPLX20_RESET_ALL : cplx16 := (rst=>'1', vld|ovf=>'0', re|im=>(others=>'0'));
  constant CPLX20_RESET_DO_NOT_CARE_DATA : cplx16 := (rst=>'1', vld|ovf=>'0', re|im=>(others=>'-'));

  -- complex 2x22 type
  type cplx22 is
  record
    rst : std_logic; -- reset
    vld : std_logic; -- data valid
    re  : signed(21 downto 0); -- data real component
    im  : signed(21 downto 0); -- data imaginary component 
    ovf : std_logic; -- data overflow (or clipping)
  end record;
  constant CPLX22_RESET_ALL : cplx16 := (rst=>'1', vld|ovf=>'0', re|im=>(others=>'0'));
  constant CPLX22_RESET_DO_NOT_CARE_DATA : cplx16 := (rst=>'1', vld|ovf=>'0', re|im=>(others=>'-'));

  -- complex 2x16 vector type
  type cplx16_vector is array(integer range <>) of cplx16;

  -- complex 2x18 vector type
  type cplx18_vector is array(integer range <>) of cplx18;

  -- complex 2x20 vector type
  type cplx20_vector is array(integer range <>) of cplx20;

  -- complex 2x20 vector type
  type cplx22_vector is array(integer range <>) of cplx22;

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
  
  ------------------------------------------
  -- RESIZE DOWN AND SATURATE/CLIP
  ------------------------------------------

  -- resize from CPLX18 down to CPLX16 with optional saturation/clipping and overflow detection
  function resize (arg:cplx18; m:cplx_switch:="-") return cplx16;
  -- resize from CPLX20 down to CPLX16 with optional saturation/clipping and overflow detection
  function resize (arg:cplx20; m:cplx_switch:="-") return cplx16;
  -- resize from CPLX20 down to CPLX18 with optional saturation/clipping and overflow detection
  function resize (arg:cplx20; m:cplx_switch:="-") return cplx18;

  ------------------------------------------
  -- RESIZE DOWN VECTOR AND SATURATE/CLIP
  ------------------------------------------

  -- vector resize from CPLX18 down to CPLX16 with optional saturation/clipping and overflow detection
  function resize (arg:cplx18_vector; m:cplx_switch:="-") return cplx16_vector;
  -- vector resize from CPLX20 down to CPLX16 with optional saturation/clipping and overflow detection
  function resize (arg:cplx20_vector; m:cplx_switch:="-") return cplx16_vector;
  -- vector resize from CPLX20 down to CPLX18 with optional saturation/clipping and overflow detection
  function resize (arg:cplx20_vector; m:cplx_switch:="-") return cplx18_vector;

  ------------------------------------------
  -- RESIZE UP
  ------------------------------------------

  -- resize from CPLX16 up to CPLX18 
  function resize (arg:cplx16) return cplx18;
  -- resize from CPLX16 up to CPLX20 
  function resize (arg:cplx16) return cplx20;
  -- resize from CPLX16 up to CPLX22 
  function resize (arg:cplx16) return cplx22;
  -- resize from CPLX18 up to CPLX20 
  function resize (arg:cplx18) return cplx20;
  -- resize from CPLX18 up to CPLX22 
  function resize (arg:cplx18) return cplx22;
  -- resize from CPLX20 up to CPLX22 
  function resize (arg:cplx20) return cplx22;

  ------------------------------------------
  -- RESIZE UP VECTOR
  ------------------------------------------

  -- vector resize from CPLX16 up to CPLX18 
  function resize (arg:cplx16_vector) return cplx18_vector;
  -- vector resize from CPLX16 up to CPLX20 
  function resize (arg:cplx16_vector) return cplx20_vector;
  -- vector resize from CPLX16 up to CPLX22 
  function resize (arg:cplx16_vector) return cplx22_vector;
  -- vector resize from CPLX18 up to CPLX20 
  function resize (arg:cplx18_vector) return cplx20_vector;
  -- vector resize from CPLX18 up to CPLX22 
  function resize (arg:cplx18_vector) return cplx22_vector;
  -- vector resize from CPLX20 up to CPLX22 
  function resize (arg:cplx20_vector) return cplx22_vector;

  ------------------------------------------
  -- ADDITION and ACCUMULATION
  ------------------------------------------

  -- complex addition with optional clipping and overflow detection
  function add (l,r: cplx16; m:cplx_switch:="-") return cplx16;
  -- complex addition with optional clipping and overflow detection
  function add (l,r: cplx18; m:cplx_switch:="-") return cplx18;
  -- complex addition with optional clipping and overflow detection
  function add (l,r: cplx20; m:cplx_switch:="-") return cplx20;
  -- complex addition with optional clipping and overflow detection
  function add (l,r: cplx22; m:cplx_switch:="-") return cplx22;

  -- complex addition with wrap and overflow detection
  function "+" (l,r: cplx16) return cplx16;
  -- complex addition with wrap and overflow detection
  function "+" (l,r: cplx18) return cplx18;
  -- complex addition with wrap and overflow detection
  function "+" (l,r: cplx20) return cplx20;
  -- complex addition with wrap and overflow detection
  function "+" (l,r: cplx22) return cplx22;

  -- sum of vector elements (max 4 elements for timing closure reasons)
  function sum (arg: cplx16_vector) return cplx18;
  -- sum of vector elements (max 4 elements for timing closure reasons)
  function sum (arg: cplx18_vector) return cplx20;
  -- sum of vector elements (max 4 elements for timing closure reasons)
  function sum (arg: cplx20_vector) return cplx22;

  ------------------------------------------
  -- SUBSTRACTION
  ------------------------------------------

  -- complex subtraction with optional clipping and overflow detection
  function sub (l,r: cplx16; m:cplx_switch:="-") return cplx16;
  -- complex subtraction with optional clipping and overflow detection
  function sub (l,r: cplx18; m:cplx_switch:="-") return cplx18;
  -- complex subtraction with optional clipping and overflow detection
  function sub (l,r: cplx20; m:cplx_switch:="-") return cplx20;
  -- complex subtraction with optional clipping and overflow detection
  function sub (l,r: cplx22; m:cplx_switch:="-") return cplx22;

  function "-" (l,r: cplx16) return cplx16;
  function "-" (l,r: cplx18) return cplx18;
  function "-" (l,r: cplx20) return cplx20;
  function "-" (l,r: cplx22) return cplx22;

  ------------------------------------------
  -- SHIFT LEFT AND CLIP/SATURATE
  ------------------------------------------

  -- complex signed shift left with optional clipping/saturation and overflow detection
  function shift_left (arg:cplx16 ; n:natural; m:cplx_switch:="-") return cplx16;
  -- complex signed shift left with optional clipping/saturation and overflow detection
  function shift_left (arg:cplx18 ; n:natural; m:cplx_switch:="-") return cplx18;
  -- complex signed shift left with optional clipping/saturation and overflow detection
  function shift_left (arg:cplx20 ; n:natural; m:cplx_switch:="-") return cplx20;

  ------------------------------------------
  -- SHIFT RIGHT and ROUND
  ------------------------------------------

  -- complex signed shift right with optional rounding
  function shift_right (arg:cplx16 ; n:natural; m:cplx_switch:="-") return cplx16;
  -- complex signed shift right with optional rounding
  function shift_right (arg:cplx18 ; n:natural; m:cplx_switch:="-") return cplx18;
  -- complex signed shift right with optional rounding
  function shift_right (arg:cplx20 ; n:natural; m:cplx_switch:="-") return cplx20;

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
  -- convert cplx20 to SLV (real = 20 LSBs, imaginary = 20 MSBs)
  function to_slv (arg:cplx20) return std_logic_vector;
  -- convert cplx22 to SLV (real = 22 LSBs, imaginary = 22 MSBs)
  function to_slv (arg:cplx22) return std_logic_vector;

  ------------------------------------------
  -- CPLX VECTOR to STD_LOGIC_VECTOR
  ------------------------------------------

  -- convert cplx16 array to SLV (output is multiple of 32 bits)
  function to_slv (arg:cplx16_vector) return std_logic_vector;
  -- convert cplx18 array to SLV (output is multiple of 36 bits)
  function to_slv (arg:cplx18_vector) return std_logic_vector;
  -- convert cplx20 array to SLV (output is multiple of 40 bits)
  function to_slv (arg:cplx20_vector) return std_logic_vector;
  -- convert cplx22 array to SLV (output is multiple of 44 bits)
  function to_slv (arg:cplx22_vector) return std_logic_vector;

end package;

-------------------------------------------------------------------------------

package body cplx_pkg is

  ------------------------------------------
  -- local auxiliary
  ------------------------------------------

  function "=" (l:cplx_switch; r:cplx_option) return boolean is
    variable res : boolean := false;
  begin
    for i in l'range loop res := res or (l(i)=r); end loop;
    return res;
  end function;

  ------------------------------------------
  -- RESIZE DOWN AND SATURATE/CLIP
  ------------------------------------------

  function resize (arg:cplx18; m:cplx_switch:="-") return cplx16 is
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx16;
  begin
    -- data signals
    if m='R' and arg.rst='1' then
      res.re := (others=>'0');
      res.im := (others=>'0');
    else
      RESIZE_CLIP(din=>arg.re, dout=>res.re, ovfl=>ovfl_re, clip=>(m='S'));
      RESIZE_CLIP(din=>arg.im, dout=>res.im, ovfl=>ovfl_im, clip=>(m='S'));
    end if;
    res.rst := arg.rst;
    res.vld := arg.vld;
    -- control signals
    res.rst := arg.rst;
    if m='R' and arg.rst='1' then
      res.vld := '0';
      res.ovf := '0';
    else
      res.vld := arg.vld; 
      res.ovf := arg.ovf;
      if m='O' then res.ovf := arg.ovf or ovfl_re or ovfl_im; end if;
    end if;  
    return res;
  end function;

  function resize (arg:cplx20; m:cplx_switch:="-") return cplx16 is
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx16;
  begin
    -- data signals
    if m='R' and arg.rst='1' then
      res.re := (others=>'0');
      res.im := (others=>'0');
    else
      RESIZE_CLIP(din=>arg.re, dout=>res.re, ovfl=>ovfl_re, clip=>(m='S'));
      RESIZE_CLIP(din=>arg.im, dout=>res.im, ovfl=>ovfl_im, clip=>(m='S'));
    end if;
    res.rst := arg.rst;
    res.vld := arg.vld;
    -- control signals
    res.rst := arg.rst;
    if m='R' and arg.rst='1' then
      res.vld := '0';
      res.ovf := '0';
    else
      res.vld := arg.vld; 
      res.ovf := arg.ovf;
      if m='O' then res.ovf := arg.ovf or ovfl_re or ovfl_im; end if;
    end if;  
    return res;
  end function;

  function resize (arg:cplx20; m:cplx_switch:="-") return cplx18 is
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx18;
  begin
    -- data signals
    if m='R' and arg.rst='1' then
      res.re := (others=>'0');
      res.im := (others=>'0');
    else
      RESIZE_CLIP(din=>arg.re, dout=>res.re, ovfl=>ovfl_re, clip=>(m='S'));
      RESIZE_CLIP(din=>arg.im, dout=>res.im, ovfl=>ovfl_im, clip=>(m='S'));
    end if;
    res.rst := arg.rst;
    res.vld := arg.vld;
    -- control signals
    res.rst := arg.rst;
    if m='R' and arg.rst='1' then
      res.vld := '0';
      res.ovf := '0';
    else
      res.vld := arg.vld; 
      res.ovf := arg.ovf;
      if m='O' then res.ovf := arg.ovf or ovfl_re or ovfl_im; end if;
    end if;  
    return res;
  end function;

  ------------------------------------------
  -- RESIZE DOWN VECTOR AND SATURATE/CLIP
  ------------------------------------------

  function resize (arg:cplx18_vector; m:cplx_switch:="-") return cplx16_vector is
    variable res : cplx16_vector(arg'range);
  begin
    for i in arg'range loop res(i) := resize(arg=>arg(i), m=>m); end loop;
    return res;
  end function;

  function resize (arg:cplx20_vector; m:cplx_switch:="-") return cplx16_vector is
    variable res : cplx16_vector(arg'range);
  begin
    for i in arg'range loop res(i) := resize(arg=>arg(i), m=>m); end loop;
    return res;
  end function;

  function resize (arg:cplx20_vector; m:cplx_switch:="-") return cplx18_vector is
    variable res : cplx18_vector(arg'range);
  begin
    for i in arg'range loop res(i) := resize(arg=>arg(i), m=>m); end loop;
    return res;
  end function;

  ------------------------------------------
  -- RESIZE UP
  ------------------------------------------

  function resize (arg:cplx16) return cplx18 is
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

  function resize (arg:cplx16) return cplx20 is
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

  function resize (arg:cplx16) return cplx22 is
    constant LOUT : positive := 22;
    variable res : cplx22;
  begin
    res.rst := arg.rst;
    res.vld := arg.vld;
    res.re  := RESIZE(arg.re,LOUT);
    res.im  := RESIZE(arg.im,LOUT);
    res.ovf := arg.ovf; -- increasing size cannot cause overflow 
    return res;
  end function;

  function resize (arg:cplx18) return cplx20 is
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

  function resize (arg:cplx18) return cplx22 is
    constant LOUT : positive := 22;
    variable res : cplx22;
  begin
    res.rst := arg.rst;
    res.vld := arg.vld;
    res.re  := RESIZE(arg.re,LOUT);
    res.im  := RESIZE(arg.im,LOUT);
    res.ovf := arg.ovf; -- increasing size cannot cause overflow 
    return res;
  end function;

  function resize (arg:cplx20) return cplx22 is
    constant LOUT : positive := 22;
    variable res : cplx22;
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

  function resize (arg:cplx16_vector) return cplx18_vector is
    variable res : cplx18_vector(arg'range);
  begin
    for i in arg'range loop res(i) := resize(arg(i)); end loop;
    return res;
  end function;

  function resize (arg:cplx16_vector) return cplx20_vector is
    variable res : cplx20_vector(arg'range);
  begin
    for i in arg'range loop res(i) := resize(arg(i)); end loop;
    return res;
  end function;

  function resize (arg:cplx16_vector) return cplx22_vector is
    variable res : cplx22_vector(arg'range);
  begin
    for i in arg'range loop res(i) := resize(arg(i)); end loop;
    return res;
  end function;

  function resize (arg:cplx18_vector) return cplx20_vector is
    variable res : cplx20_vector(arg'range);
  begin
    for i in arg'range loop res(i) := resize(arg(i)); end loop;
    return res;
  end function;

  function resize (arg:cplx18_vector) return cplx22_vector is
    variable res : cplx22_vector(arg'range);
  begin
    for i in arg'range loop res(i) := resize(arg(i)); end loop;
    return res;
  end function;

  function resize (arg:cplx20_vector) return cplx22_vector is
    variable res : cplx22_vector(arg'range);
  begin
    for i in arg'range loop res(i) := resize(arg(i)); end loop;
    return res;
  end function;

  ------------------------------------------
  -- ADDITION and ACCUMULATION
  ------------------------------------------

  function add (l,r: cplx16; m:cplx_switch:="-") return cplx16 is 
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx16;
  begin
    res.rst := l.rst or r.rst;
    -- data signals
    if m='R' and res.rst='1' then
      res.re := (others=>'0');
      res.im := (others=>'0');
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

  function add (l,r: cplx18; m:cplx_switch:="-") return cplx18 is 
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx18;
  begin
    res.rst := l.rst or r.rst;
    -- data signals
    if m='R' and res.rst='1' then
      res.re := (others=>'0');
      res.im := (others=>'0');
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

  function add (l,r: cplx20; m:cplx_switch:="-") return cplx20 is 
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx20;
  begin
    res.rst := l.rst or r.rst;
    -- data signals
    if m='R' and res.rst='1' then
      res.re := (others=>'0');
      res.im := (others=>'0');
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

  function add (l,r: cplx22; m:cplx_switch:="-") return cplx22 is 
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx22;
  begin
    res.rst := l.rst or r.rst;
    -- data signals
    if m='R' and res.rst='1' then
      res.re := (others=>'0');
      res.im := (others=>'0');
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

  function "+" (l,r: cplx16) return cplx16 is
  begin
    return add(l, r, m=>"O");
  end function;

  function "+" (l,r: cplx18) return cplx18 is
  begin
    return add(l, r, m=>"O");
  end function;

  function "+" (l,r: cplx20) return cplx20 is
  begin
    return add(l, r, m=>"O");
  end function;

  function "+" (l,r: cplx22) return cplx22 is
  begin
    return add(l, r, m=>"O");
  end function;

  function sum (arg: cplx16_vector) return cplx18 is
    constant L : positive := arg'length;
    alias xarg : cplx16_vector(0 to L-1) is arg; -- default range
    variable res : cplx18;
  begin
    assert L<=4
      report "ERROR: Only up to 4 vector elements can be summed up."
      severity error;
    res := resize(xarg(0));
    if L>1 then
      for i in 1 to L-1 loop res:=res+resize(xarg(i)); end loop;
    end if;
    return res;
  end function;

  function sum (arg: cplx18_vector) return cplx20 is
    constant L : positive := arg'length;
    alias xarg : cplx18_vector(0 to L-1) is arg; -- default range
    variable res : cplx20;
  begin
    assert L<=4
      report "ERROR: Only up to 4 vector elements can be summed up."
      severity error;
    res := resize(xarg(0));
    if L>1 then
      for i in 1 to L-1 loop res:=res+resize(xarg(i)); end loop;
    end if;
    return res;
  end function;

  function sum (arg: cplx20_vector) return cplx22 is
    constant L : positive := arg'length;
    alias xarg : cplx20_vector(0 to L-1) is arg; -- default range
    variable res : cplx22;
  begin
    assert L<=4
      report "ERROR: Only up to 4 vector elements can be summed up."
      severity error;
    res := resize(xarg(0));
    if L>1 then
      for i in 1 to L-1 loop res:=res+resize(xarg(i)); end loop;
    end if;
    return res;
  end function;

  ------------------------------------------
  -- SUBSTRACTION
  ------------------------------------------

  function sub (l,r: cplx16; m:cplx_switch:="-") return cplx16 is 
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx16;
  begin
    res.rst := l.rst or r.rst;
    -- data signals
    if m='R' and res.rst='1' then
      res.re := (others=>'0');
      res.im := (others=>'0');
    else
      SUB_CLIP(l=>l.re, r=>r.re, dout=>res.re, ovfl=>ovfl_re, clip=>(m="S"));
      SUB_CLIP(l=>l.im, r=>r.im, dout=>res.im, ovfl=>ovfl_im, clip=>(m="S"));
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

  function sub (l,r: cplx18; m:cplx_switch:="-") return cplx18 is 
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx18;
  begin
    res.rst := l.rst or r.rst;
    -- data signals
    if m='R' and res.rst='1' then
      res.re := (others=>'0');
      res.im := (others=>'0');
    else
      SUB_CLIP(l=>l.re, r=>r.re, dout=>res.re, ovfl=>ovfl_re, clip=>(m="S"));
      SUB_CLIP(l=>l.im, r=>r.im, dout=>res.im, ovfl=>ovfl_im, clip=>(m="S"));
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

  function sub (l,r: cplx20; m:cplx_switch:="-") return cplx20 is 
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx20;
  begin
    res.rst := l.rst or r.rst;
    -- data signals
    if m='R' and res.rst='1' then
      res.re := (others=>'0');
      res.im := (others=>'0');
    else
      SUB_CLIP(l=>l.re, r=>r.re, dout=>res.re, ovfl=>ovfl_re, clip=>(m="S"));
      SUB_CLIP(l=>l.im, r=>r.im, dout=>res.im, ovfl=>ovfl_im, clip=>(m="S"));
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

  function sub (l,r: cplx22; m:cplx_switch:="-") return cplx22 is 
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx22;
  begin
    res.rst := l.rst or r.rst;
    -- data signals
    if m='R' and res.rst='1' then
      res.re := (others=>'0');
      res.im := (others=>'0');
    else
      SUB_CLIP(l=>l.re, r=>r.re, dout=>res.re, ovfl=>ovfl_re, clip=>(m="S"));
      SUB_CLIP(l=>l.im, r=>r.im, dout=>res.im, ovfl=>ovfl_im, clip=>(m="S"));
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

  function "-" (l,r: cplx16) return cplx16 is
  begin
    return sub(l, r, m=>"O");
  end function;

  function "-" (l,r: cplx18) return cplx18 is
  begin
    return sub(l, r, m=>"O");
  end function;

  function "-" (l,r: cplx20) return cplx20 is
  begin
    return sub(l, r, m=>"O");
  end function;

  function "-" (l,r: cplx22) return cplx22 is
  begin
    return sub(l, r, m=>"O");
  end function;

  ------------------------------------------
 -- SHIFT LEFT AND SATURATE/CLIP
  ------------------------------------------

  function shift_left (arg:cplx16 ; n:natural; m:cplx_switch:="-") return cplx16 is
    variable ovf_re, ovf_im : std_logic;
    variable res : cplx16;
  begin
    -- data signals
    if m='R' and arg.rst='1' then
      res.re := (others=>'0');
      res.im := (others=>'0');
    else
      SHIFT_LEFT_CLIP(din=>arg.re, n=>n, dout=>res.re, ovfl=>ovf_re, clip=>(m='S'));
      SHIFT_LEFT_CLIP(din=>arg.im, n=>n, dout=>res.im, ovfl=>ovf_im, clip=>(m='S'));
    end if;
    -- control signals
    res.rst := arg.rst;
    if m='R' and arg.rst='1' then
      res.vld := '0';
      res.ovf := '0';
    else
      res.vld := arg.vld; 
      res.ovf := arg.ovf;
      if m='O' then res.ovf := arg.ovf or ovf_re or ovf_im; end if;
    end if;  
    return res;
  end function;

  function shift_left (arg:cplx18 ; n:natural; m:cplx_switch:="-") return cplx18 is
    variable ovf_re, ovf_im : std_logic;
    variable res : cplx18;
  begin
    -- data signals
    if m='R' and arg.rst='1' then
      res.re := (others=>'0');
      res.im := (others=>'0');
    else
      SHIFT_LEFT_CLIP(din=>arg.re, n=>n, dout=>res.re, ovfl=>ovf_re, clip=>(m='S'));
      SHIFT_LEFT_CLIP(din=>arg.im, n=>n, dout=>res.im, ovfl=>ovf_im, clip=>(m='S'));
    end if;
    -- control signals
    res.rst := arg.rst;
    if m='R' and arg.rst='1' then
      res.vld := '0';
      res.ovf := '0';
    else
      res.vld := arg.vld; 
      res.ovf := arg.ovf;
      if m='O' then res.ovf := arg.ovf or ovf_re or ovf_im; end if;
    end if;  
    return res;
  end function;

  function shift_left (arg:cplx20 ; n:natural; m:cplx_switch:="-") return cplx20 is
    variable ovf_re, ovf_im : std_logic;
    variable res : cplx20;
  begin
    -- data signals
    if m='R' and arg.rst='1' then
      res.re := (others=>'0');
      res.im := (others=>'0');
    else
      SHIFT_LEFT_CLIP(din=>arg.re, n=>n, dout=>res.re, ovfl=>ovf_re, clip=>(m='S'));
      SHIFT_LEFT_CLIP(din=>arg.im, n=>n, dout=>res.im, ovfl=>ovf_im, clip=>(m='S'));
    end if;
    -- control signals
    res.rst := arg.rst;
    if m='R' and arg.rst='1' then
      res.vld := '0';
      res.ovf := '0';
    else
      res.vld := arg.vld; 
      res.ovf := arg.ovf;
      if m='O' then res.ovf := arg.ovf or ovf_re or ovf_im; end if;
    end if;  
    return res;
  end function;

  ------------------------------------------
  -- SHIFT RIGHT and ROUND
  ------------------------------------------

  function shift_right (arg:cplx16; n:natural; m:cplx_switch:="-") return cplx16 is
    variable res : cplx16;
  begin
    -- data signals
    if m='R' and arg.rst='1' then
      res.re := (others=>'0');
      res.im := (others=>'0');
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

  function shift_right (arg:cplx18 ; n:natural; m:cplx_switch:="-") return cplx18 is
    variable res : cplx18;
  begin
    -- data signals
    if m='R' and arg.rst='1' then
      res.re := (others=>'0');
      res.im := (others=>'0');
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

  function shift_right (arg:cplx20 ; n:natural; m:cplx_switch:="-") return cplx20 is
    variable res : cplx20;
  begin
    -- data signals
    if m='R' and arg.rst='1' then
      res.re := (others=>'0');
      res.im := (others=>'0');
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

  ------------------------------------------
  -- STD_LOGIC_VECTOR to CPLX
  ------------------------------------------

  function to_cplx16 (
    slv : std_logic_vector(31 downto 0);
    vld : std_logic;
    rst : std_logic := '0'
  ) return cplx16 is
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
  ) return cplx18 is
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
  ) return cplx16_vector is
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
  ) return cplx18_vector is
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

  function to_slv (arg : cplx16) return std_logic_vector is
    constant BITS : integer := 16;
    variable slv : std_logic_vector(2*BITS-1 downto 0);
  begin
    slv(  BITS-1 downto    0) := std_logic_vector(arg.re);
    slv(2*BITS-1 downto BITS) := std_logic_vector(arg.im);
    return slv;
  end function;

  function to_slv (arg : cplx18) return std_logic_vector is
    constant BITS : integer := 18;
    variable slv : std_logic_vector(2*BITS-1 downto 0);
  begin
    slv(  BITS-1 downto    0) := std_logic_vector(arg.re);
    slv(2*BITS-1 downto BITS) := std_logic_vector(arg.im);
    return slv;
  end function;

  function to_slv (arg : cplx20) return std_logic_vector is
    constant BITS : integer := 20;
    variable slv : std_logic_vector(2*BITS-1 downto 0);
  begin
    slv(  BITS-1 downto    0) := std_logic_vector(arg.re);
    slv(2*BITS-1 downto BITS) := std_logic_vector(arg.im);
    return slv;
  end function;

  function to_slv (arg : cplx22) return std_logic_vector is
    constant BITS : integer := 22;
    variable slv : std_logic_vector(2*BITS-1 downto 0);
  begin
    slv(  BITS-1 downto    0) := std_logic_vector(arg.re);
    slv(2*BITS-1 downto BITS) := std_logic_vector(arg.im);
    return slv;
  end function;

  ------------------------------------------
  -- CPLX VECTOR to STD_LOGIC_VECTOR
  ------------------------------------------

  function to_slv (arg : cplx16_vector) return std_logic_vector is
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

  function to_slv (arg : cplx18_vector) return std_logic_vector is
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

  function to_slv (arg : cplx20_vector) return std_logic_vector is
    constant BITS : integer := 20;
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

  function to_slv (arg : cplx22_vector) return std_logic_vector is
    constant BITS : integer := 22;
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

end package body;
