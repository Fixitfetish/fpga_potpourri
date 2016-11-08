-------------------------------------------------------------------------------
-- FILE    : cplx_pkg_1993.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 08/Nov/2016
-- VERSION : 0.8
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
    ovf : std_logic; -- data overflow (or clipping)
    re  : signed(15 downto 0); -- data real component
    im  : signed(15 downto 0); -- data imaginary component 
  end record;
  constant CPLX16_RESET_ALL : cplx16 := (rst=>'1', vld|ovf=>'0', re|im=>(others=>'0'));
  constant CPLX16_RESET_DO_NOT_CARE_DATA : cplx16 := (rst=>'1', vld|ovf=>'0', re|im=>(others=>'-'));

  -- complex 2x18 type
  type cplx18 is
  record
    rst : std_logic; -- reset
    vld : std_logic; -- data valid
    ovf : std_logic; -- data overflow (or clipping)
    re  : signed(17 downto 0); -- data real component
    im  : signed(17 downto 0); -- data imaginary component 
  end record;
  constant CPLX18_RESET_ALL : cplx16 := (rst=>'1', vld|ovf=>'0', re|im=>(others=>'0'));
  constant CPLX18_RESET_DO_NOT_CARE_DATA : cplx16 := (rst=>'1', vld|ovf=>'0', re|im=>(others=>'-'));

  -- complex 2x20 type
  type cplx20 is
  record
    rst : std_logic; -- reset
    vld : std_logic; -- data valid
    ovf : std_logic; -- data overflow (or clipping)
    re  : signed(19 downto 0); -- data real component
    im  : signed(19 downto 0); -- data imaginary component 
  end record;
  constant CPLX20_RESET_ALL : cplx16 := (rst=>'1', vld|ovf=>'0', re|im=>(others=>'0'));
  constant CPLX20_RESET_DO_NOT_CARE_DATA : cplx16 := (rst=>'1', vld|ovf=>'0', re|im=>(others=>'-'));

  -- complex 2x22 type
  type cplx22 is
  record
    rst : std_logic; -- reset
    vld : std_logic; -- data valid
    ovf : std_logic; -- data overflow (or clipping)
    re  : signed(21 downto 0); -- data real component
    im  : signed(21 downto 0); -- data imaginary component 
  end record;
  constant CPLX22_RESET_ALL : cplx16 := (rst=>'1', vld|ovf=>'0', re|im=>(others=>'0'));
  constant CPLX22_RESET_DO_NOT_CARE_DATA : cplx16 := (rst=>'1', vld|ovf=>'0', re|im=>(others=>'-'));

  -- complex 2x16 vector type (preferably "to" direction)
  type cplx16_vector is array(integer range <>) of cplx16;

  -- complex 2x18 vector type (preferably "to" direction)
  type cplx18_vector is array(integer range <>) of cplx18;

  -- complex 2x20 vector type (preferably "to" direction)
  type cplx20_vector is array(integer range <>) of cplx20;

  -- complex 2x20 vector type (preferably "to" direction)
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
  type cplx_mode is array(integer range <>) of cplx_option;
  
  ------------------------------------------
  -- RESIZE DOWN AND SATURATE/CLIP
  ------------------------------------------

  -- resize from CPLX18 down to CPLX16 with optional saturation/clipping and overflow detection
  -- To be compatible with the VHDL-2008 version of this package the output size is fixed: n=16
  function resize (din:cplx18; n:positive; m:cplx_mode:="-") return cplx16;

  -- resize from CPLX20 down to CPLX16 with optional saturation/clipping and overflow detection
  -- To be compatible with the VHDL-2008 version of this package the output size is fixed: n=16
  function resize (din:cplx20; n:positive; m:cplx_mode:="-") return cplx16;

  -- resize from CPLX22 down to CPLX16 with optional saturation/clipping and overflow detection
  -- To be compatible with the VHDL-2008 version of this package the output size is fixed: n=16
  function resize (din:cplx22; n:positive; m:cplx_mode:="-") return cplx16;

  -- resize from CPLX20 down to CPLX18 with optional saturation/clipping and overflow detection
  -- To be compatible with the VHDL-2008 version of this package the output size is fixed: n=18
  function resize (din:cplx20; n:positive; m:cplx_mode:="-") return cplx18;

  -- resize from CPLX22 down to CPLX18 with optional saturation/clipping and overflow detection
  -- To be compatible with the VHDL-2008 version of this package the output size is fixed: n=18
  function resize (din:cplx22; n:positive; m:cplx_mode:="-") return cplx18;

  -- resize from CPLX22 down to CPLX20 with optional saturation/clipping and overflow detection
  -- To be compatible with the VHDL-2008 version of this package the output size is fixed: n=20
  function resize (din:cplx22; n:positive; m:cplx_mode:="-") return cplx20;

  ------------------------------------------
  -- RESIZE DOWN VECTOR AND SATURATE/CLIP
  ------------------------------------------

  -- vector resize from CPLX18 down to CPLX16 with optional saturation/clipping and overflow detection
  -- To be compatible with the VHDL-2008 version of this package the output size is fixed: n=16
  function resize (din:cplx18_vector; n:positive; m:cplx_mode:="-") return cplx16_vector;

  -- vector resize from CPLX20 down to CPLX16 with optional saturation/clipping and overflow detection
  -- To be compatible with the VHDL-2008 version of this package the output size is fixed: n=16
  function resize (din:cplx20_vector; n:positive; m:cplx_mode:="-") return cplx16_vector;

  -- vector resize from CPLX22 down to CPLX16 with optional saturation/clipping and overflow detection
  -- To be compatible with the VHDL-2008 version of this package the output size is fixed: n=16
  function resize (din:cplx22_vector; n:positive; m:cplx_mode:="-") return cplx16_vector;

  -- vector resize from CPLX20 down to CPLX18 with optional saturation/clipping and overflow detection
  -- To be compatible with the VHDL-2008 version of this package the output size is fixed: n=18
  function resize (din:cplx20_vector; n:positive; m:cplx_mode:="-") return cplx18_vector;

  -- vector resize from CPLX22 down to CPLX18 with optional saturation/clipping and overflow detection
  -- To be compatible with the VHDL-2008 version of this package the output size is fixed: n=18
  function resize (din:cplx22_vector; n:positive; m:cplx_mode:="-") return cplx18_vector;

  -- vector resize from CPLX22 down to CPLX20 with optional saturation/clipping and overflow detection
  -- To be compatible with the VHDL-2008 version of this package the output size is fixed: n=20
  function resize (din:cplx22_vector; n:positive; m:cplx_mode:="-") return cplx20_vector;

  ------------------------------------------
  -- RESIZE UP
  ------------------------------------------

  -- resize from CPLX16 up to CPLX18 
  -- To be compatible with the VHDL-2008 version of this package the output size is fixed: n=18
  function resize (din:cplx16; n:positive) return cplx18;

  -- resize from CPLX16 up to CPLX20 
  -- To be compatible with the VHDL-2008 version of this package the output size is fixed: n=20
  function resize (din:cplx16; n:positive) return cplx20;

  -- resize from CPLX18 up to CPLX20 
  -- To be compatible with the VHDL-2008 version of this package the output size is fixed: n=20
  function resize (din:cplx18; n:positive) return cplx20;

  -- resize from CPLX16 up to CPLX22 
  -- To be compatible with the VHDL-2008 version of this package the output size is fixed: n=22
  function resize (din:cplx16; n:positive) return cplx22;

  -- resize from CPLX18 up to CPLX22 
  -- To be compatible with the VHDL-2008 version of this package the output size is fixed: n=22
  function resize (din:cplx18; n:positive) return cplx22;

  -- resize from CPLX20 up to CPLX22 
  -- To be compatible with the VHDL-2008 version of this package the output size is fixed: n=22
  function resize (din:cplx20; n:positive) return cplx22;

  ------------------------------------------
  -- RESIZE UP VECTOR
  ------------------------------------------

  -- vector resize from CPLX16 up to CPLX18 
  -- To be compatible with the VHDL-2008 version of this package the output size is fixed: n=18
  function resize (din:cplx16_vector; n:positive) return cplx18_vector;

  -- vector resize from CPLX16 up to CPLX20 
  -- To be compatible with the VHDL-2008 version of this package the output size is fixed: n=20
  function resize (din:cplx16_vector; n:positive) return cplx20_vector;

  -- vector resize from CPLX18 up to CPLX20 
  -- To be compatible with the VHDL-2008 version of this package the output size is fixed: n=20
  function resize (din:cplx18_vector; n:positive) return cplx20_vector;

  -- vector resize from CPLX16 up to CPLX22 
  -- To be compatible with the VHDL-2008 version of this package the output size is fixed: n=22
  function resize (din:cplx16_vector; n:positive) return cplx22_vector;

  -- vector resize from CPLX18 up to CPLX22 
  -- To be compatible with the VHDL-2008 version of this package the output size is fixed: n=22
  function resize (din:cplx18_vector; n:positive) return cplx22_vector;

  -- vector resize from CPLX20 up to CPLX22 
  -- To be compatible with the VHDL-2008 version of this package the output size is fixed: n=22
  function resize (din:cplx20_vector; n:positive) return cplx22_vector;

  ------------------------------------------
  -- ADDITION and ACCUMULATION
  ------------------------------------------

  -- complex addition with optional clipping and overflow detection
  -- Both inputs must have the same bit width.
  -- To be compatible with the VHDL-2008 version of this package the output
  -- bit width w must be equal to the input bit width, i.e. w=0 or w=16.
  function add (l,r: cplx16; w:natural:=16; m:cplx_mode:="-") return cplx16;

  -- complex addition with optional clipping and overflow detection
  -- Both inputs must have the same bit width.
  -- To be compatible with the VHDL-2008 version of this package the output
  -- bit width w must be equal to the input bit width, i.e. w=0 or w=18.
  function add (l,r: cplx18; w:natural:=18; m:cplx_mode:="-") return cplx18;

  -- complex addition with optional clipping and overflow detection
  -- Both inputs must have the same bit width.
  -- To be compatible with the VHDL-2008 version of this package the output
  -- bit width w must be equal to the input bit width, i.e. w=0 or w=20.
  function add (l,r: cplx20; w:natural:=20; m:cplx_mode:="-") return cplx20;

  -- complex addition with optional clipping and overflow detection
  -- Both inputs must have the same bit width.
  -- To be compatible with the VHDL-2008 version of this package the output
  -- bit width w must be equal to the input bit width, i.e. w=0 or w=22.
  function add (l,r: cplx22; w:natural:=22; m:cplx_mode:="-") return cplx22;

  -- complex addition with wrap and overflow detection
  function "+" (l,r: cplx16) return cplx16;
  -- complex addition with wrap and overflow detection
  function "+" (l,r: cplx18) return cplx18;
  -- complex addition with wrap and overflow detection
  function "+" (l,r: cplx20) return cplx20;
  -- complex addition with wrap and overflow detection
  function "+" (l,r: cplx22) return cplx22;

  -- sum of vector elements (max 4 elements for simplicity reasons)
  -- All inputs (i.e. vector elements) have the same bit width.
  -- The output bit width is 2 bits wider than the input bit width, i.e. w=18.
  function sum (din: cplx16_vector; w:natural:=18; m:cplx_mode:="-") return cplx18;

  -- sum of vector elements (max 4 elements for simplicity reasons)
  -- All inputs (i.e. vector elements) have the same bit width.
  -- The output bit width is 2 bits wider than the input bit width, i.e. w=20.
  function sum (din: cplx18_vector; w:natural:=20; m:cplx_mode:="-") return cplx20;

  -- sum of vector elements (max 4 elements for simplicity reasons)
  -- All inputs (i.e. vector elements) have the same bit width.
  -- The output bit width is 2 bits wider than the input bit width, i.e. w=22.
  function sum (din: cplx20_vector; w:natural:=22; m:cplx_mode:="-") return cplx22;

  ------------------------------------------
  -- SUBSTRACTION
  ------------------------------------------

  -- complex subtraction with optional clipping and overflow detection
  -- Both inputs must have the same bit width.
  -- To be compatible with the VHDL-2008 version of this package the output
  -- bit width w must be equal to the input bit width, i.e. w=0 or w=16.
  function sub (l,r: cplx16; w:natural:=16; m:cplx_mode:="-") return cplx16;

  -- complex subtraction with optional clipping and overflow detection
  -- Both inputs must have the same bit width.
  -- To be compatible with the VHDL-2008 version of this package the output
  -- bit width w must be equal to the input bit width, i.e. w=0 or w=18.
  function sub (l,r: cplx18; w:natural:=18; m:cplx_mode:="-") return cplx18;

  -- complex subtraction with optional clipping and overflow detection
  -- Both inputs must have the same bit width.
  -- To be compatible with the VHDL-2008 version of this package the output
  -- bit width w must be equal to the input bit width, i.e. w=0 or w=20.
  function sub (l,r: cplx20; w:natural:=20; m:cplx_mode:="-") return cplx20;

  -- complex subtraction with optional clipping and overflow detection
  -- Both inputs must have the same bit width.
  -- To be compatible with the VHDL-2008 version of this package the output
  -- bit width w must be equal to the input bit width, i.e. w=0 or w=22.
  function sub (l,r: cplx22; w:natural:=22; m:cplx_mode:="-") return cplx22;

  -- complex subtraction with wrap and overflow detection
  function "-" (l,r: cplx16) return cplx16;
  -- complex subtraction with wrap and overflow detection
  function "-" (l,r: cplx18) return cplx18;
  -- complex subtraction with wrap and overflow detection
  function "-" (l,r: cplx20) return cplx20;
  -- complex subtraction with wrap and overflow detection
  function "-" (l,r: cplx22) return cplx22;

  ------------------------------------------
  -- SHIFT LEFT AND CLIP/SATURATE
  ------------------------------------------

  -- complex signed shift left with optional clipping/saturation and overflow detection
  -- The output bit width equals the input bit width.
  function shift_left (din:cplx16 ; n:natural; m:cplx_mode:="-") return cplx16;

  -- complex signed shift left with optional clipping/saturation and overflow detection
  -- The output bit width equals the input bit width.
  function shift_left (din:cplx18 ; n:natural; m:cplx_mode:="-") return cplx18;

  -- complex signed shift left with optional clipping/saturation and overflow detection
  -- The output bit width equals the input bit width.
  function shift_left (din:cplx20 ; n:natural; m:cplx_mode:="-") return cplx20;

  -- complex signed shift left with optional clipping/saturation and overflow detection
  -- The output bit width equals the input bit width.
  function shift_left (din:cplx22 ; n:natural; m:cplx_mode:="-") return cplx22;

  ------------------------------------------
  -- SHIFT RIGHT and ROUND
  ------------------------------------------

  -- complex signed shift right with optional rounding
  -- The output bit width equals the input bit width.
  function shift_right (din:cplx16 ; n:natural; m:cplx_mode:="-") return cplx16;

  -- complex signed shift right with optional rounding
  -- The output bit width equals the input bit width.
  function shift_right (din:cplx18 ; n:natural; m:cplx_mode:="-") return cplx18;

  -- complex signed shift right with optional rounding
  -- The output bit width equals the input bit width.
  function shift_right (din:cplx20 ; n:natural; m:cplx_mode:="-") return cplx20;

  -- complex signed shift right with optional rounding
  -- The output bit width equals the input bit width.
  function shift_right (din:cplx22 ; n:natural; m:cplx_mode:="-") return cplx22;

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

  function "=" (l:cplx_mode; r:cplx_option) return boolean is
    variable res : boolean := false;
  begin
    for i in l'range loop res := res or (l(i)=r); end loop;
    return res;
  end function;

  ------------------------------------------
  -- RESIZE DOWN AND SATURATE/CLIP
  ------------------------------------------

  -- local auxiliary procedure to avoid massive code duplication
  procedure help_resize_down (
    rst  : in  std_logic;
    din  : in  signed;
    ovfi : in  std_logic;
    dout : out signed;
    ovfo : out std_logic;
    m    : in  cplx_mode
  ) is
    variable ovfl : std_logic;
  begin
    if m='R' and rst='1' then
      dout := (dout'range =>'0');
      ovfo := '0';
    else
      RESIZE_CLIP(din=>din, dout=>dout, ovfl=>ovfl, clip=>(m='S'));
      if m='O' then ovfo := ovfi or ovfl; else ovfo := ovfi; end if;
    end if;
  end procedure;

  function resize (din:cplx18; n:positive; m:cplx_mode:="-") return cplx16 is
    variable ovf_re, ovf_im : std_logic;
    variable dout : cplx16; -- default
  begin
    assert n=16
      report "ERROR in resize cplx18->cplx16 : Output resolution must be always n=16"
      severity failure;
    dout.rst := din.rst;
    if m='R' and din.rst='1' then dout.vld:='0'; else dout.vld:=din.vld; end if;
    help_resize_down(din.rst, din.re, din.ovf, dout.re, ovf_re, m);
    help_resize_down(din.rst, din.im, din.ovf, dout.im, ovf_im, m);
    dout.ovf := ovf_re or ovf_im; -- overflow handling in help procedure
    return dout;
  end function;

  function resize (din:cplx20; n:positive; m:cplx_mode:="-") return cplx16 is
    variable ovf_re, ovf_im : std_logic;
    variable dout : cplx16; -- default
  begin
    assert n=16
      report "ERROR in resize cplx20->cplx16 : Output resolution must be always n=16"
      severity failure;
    dout.rst := din.rst;
    if m='R' and din.rst='1' then dout.vld:='0'; else dout.vld:=din.vld; end if;
    help_resize_down(din.rst, din.re, din.ovf, dout.re, ovf_re, m);
    help_resize_down(din.rst, din.im, din.ovf, dout.im, ovf_im, m);
    dout.ovf := ovf_re or ovf_im; -- overflow handling in help procedure
    return dout;
  end function;

  function resize (din:cplx22; n:positive; m:cplx_mode:="-") return cplx16 is
    variable ovf_re, ovf_im : std_logic;
    variable dout : cplx16; -- default
  begin
    assert n=16
      report "ERROR in resize cplx22->cplx16 : Output resolution must be always n=16"
      severity failure;
    dout.rst := din.rst;
    if m='R' and din.rst='1' then dout.vld:='0'; else dout.vld:=din.vld; end if;
    help_resize_down(din.rst, din.re, din.ovf, dout.re, ovf_re, m);
    help_resize_down(din.rst, din.im, din.ovf, dout.im, ovf_im, m);
    dout.ovf := ovf_re or ovf_im; -- overflow handling in help procedure
    return dout;
  end function;

  function resize (din:cplx20; n:positive; m:cplx_mode:="-") return cplx18 is
    variable ovf_re, ovf_im : std_logic;
    variable dout : cplx18; -- default
  begin
    assert n=18
      report "ERROR in resize cplx20->cplx18 : Output resolution must be always n=18"
      severity failure;
    dout.rst := din.rst;
    if m='R' and din.rst='1' then dout.vld:='0'; else dout.vld:=din.vld; end if;
    help_resize_down(din.rst, din.re, din.ovf, dout.re, ovf_re, m);
    help_resize_down(din.rst, din.im, din.ovf, dout.im, ovf_im, m);
    dout.ovf := ovf_re or ovf_im; -- overflow handling in help procedure
    return dout;
  end function;

  function resize (din:cplx22; n:positive; m:cplx_mode:="-") return cplx18 is
    variable ovf_re, ovf_im : std_logic;
    variable dout : cplx18; -- default
  begin
    assert n=18
      report "ERROR in resize cplx22->cplx18 : Output resolution must be always n=18"
      severity failure;
    dout.rst := din.rst;
    if m='R' and din.rst='1' then dout.vld:='0'; else dout.vld:=din.vld; end if;
    help_resize_down(din.rst, din.re, din.ovf, dout.re, ovf_re, m);
    help_resize_down(din.rst, din.im, din.ovf, dout.im, ovf_im, m);
    dout.ovf := ovf_re or ovf_im; -- overflow handling in help procedure
    return dout;
  end function;

  function resize (din:cplx22; n:positive; m:cplx_mode:="-") return cplx20 is
    variable ovf_re, ovf_im : std_logic;
    variable dout : cplx20; -- default
  begin
    assert n=20
      report "ERROR in resize cplx22->cplx20 : Output resolution must be always n=20"
      severity failure;
    dout.rst := din.rst;
    if m='R' and din.rst='1' then dout.vld:='0'; else dout.vld:=din.vld; end if;
    help_resize_down(din.rst, din.re, din.ovf, dout.re, ovf_re, m);
    help_resize_down(din.rst, din.im, din.ovf, dout.im, ovf_im, m);
    dout.ovf := ovf_re or ovf_im; -- overflow handling in help procedure
    return dout;
  end function;

  ------------------------------------------
  -- RESIZE DOWN VECTOR AND SATURATE/CLIP
  ------------------------------------------

  function resize (din:cplx18_vector; n:positive; m:cplx_mode:="-") return cplx16_vector is
    variable res : cplx16_vector(din'range);
  begin
    for i in din'range loop res(i) := resize(din=>din(i), n=>n, m=>m); end loop;
    return res;
  end function;

  function resize (din:cplx20_vector; n:positive; m:cplx_mode:="-") return cplx16_vector is
    variable res : cplx16_vector(din'range);
  begin
    for i in din'range loop res(i) := resize(din=>din(i), n=>n, m=>m); end loop;
    return res;
  end function;

  function resize (din:cplx22_vector; n:positive; m:cplx_mode:="-") return cplx16_vector is
    variable res : cplx16_vector(din'range);
  begin
    for i in din'range loop res(i) := resize(din=>din(i), n=>n, m=>m); end loop;
    return res;
  end function;

  function resize (din:cplx20_vector; n:positive; m:cplx_mode:="-") return cplx18_vector is
    variable res : cplx18_vector(din'range);
  begin
    for i in din'range loop res(i) := resize(din=>din(i), n=>n, m=>m); end loop;
    return res;
  end function;

  function resize (din:cplx22_vector; n:positive; m:cplx_mode:="-") return cplx18_vector is
    variable res : cplx18_vector(din'range);
  begin
    for i in din'range loop res(i) := resize(din=>din(i), n=>n, m=>m); end loop;
    return res;
  end function;

  function resize (din:cplx22_vector; n:positive; m:cplx_mode:="-") return cplx20_vector is
    variable res : cplx20_vector(din'range);
  begin
    for i in din'range loop res(i) := resize(din=>din(i), n=>n, m=>m); end loop;
    return res;
  end function;

  ------------------------------------------
  -- RESIZE UP
  ------------------------------------------

  function resize (din:cplx16; n:positive) return cplx18 is
    constant LOUT : positive := 18;
    variable dout : cplx18;
  begin
    assert n=LOUT
      report "ERROR in resize cplx16->cplx18 : Output resolution must be always n=" & integer'image(LOUT)
      severity failure;
    dout.rst := din.rst;
    dout.vld := din.vld;
    dout.re  := RESIZE(din.re,LOUT);
    dout.im  := RESIZE(din.im,LOUT);
    dout.ovf := din.ovf; -- increasing size cannot cause overflow 
    return dout;
  end function;

  function resize (din:cplx16; n:positive) return cplx20 is
    constant LOUT : positive := 20;
    variable dout : cplx20;
  begin
    assert n=LOUT
      report "ERROR in resize cplx16->cplx20 : Output resolution must be always n=" & integer'image(LOUT)
      severity failure;
    dout.rst := din.rst;
    dout.vld := din.vld;
    dout.re  := RESIZE(din.re,LOUT);
    dout.im  := RESIZE(din.im,LOUT);
    dout.ovf := din.ovf; -- increasing size cannot cause overflow 
    return dout;
  end function;

  function resize (din:cplx18; n:positive) return cplx20 is
    constant LOUT : positive := 20;
    variable dout : cplx20;
  begin
    assert n=LOUT
      report "ERROR in resize cplx18->cplx20 : Output resolution must be always n=" & integer'image(LOUT)
      severity failure;
    dout.rst := din.rst;
    dout.vld := din.vld;
    dout.re  := RESIZE(din.re,LOUT);
    dout.im  := RESIZE(din.im,LOUT);
    dout.ovf := din.ovf; -- increasing size cannot cause overflow 
    return dout;
  end function;

  function resize (din:cplx16; n:positive) return cplx22 is
    constant LOUT : positive := 22;
    variable dout : cplx22;
  begin
    assert n=LOUT
      report "ERROR in resize cplx16->cplx22 : Output resolution must be always n=" & integer'image(LOUT)
      severity failure;
    dout.rst := din.rst;
    dout.vld := din.vld;
    dout.re  := RESIZE(din.re,LOUT);
    dout.im  := RESIZE(din.im,LOUT);
    dout.ovf := din.ovf; -- increasing size cannot cause overflow 
    return dout;
  end function;

  function resize (din:cplx18; n:positive) return cplx22 is
    constant LOUT : positive := 22;
    variable dout : cplx22;
  begin
    assert n=LOUT
      report "ERROR in resize cplx18->cplx22 : Output resolution must be always n=" & integer'image(LOUT)
      severity failure;
    dout.rst := din.rst;
    dout.vld := din.vld;
    dout.re  := RESIZE(din.re,LOUT);
    dout.im  := RESIZE(din.im,LOUT);
    dout.ovf := din.ovf; -- increasing size cannot cause overflow 
    return dout;
  end function;

  function resize (din:cplx20; n:positive) return cplx22 is
    constant LOUT : positive := 22;
    variable dout : cplx22;
  begin
    assert n=LOUT
      report "ERROR in resize cplx20->cplx22 : Output resolution must be always n=" & integer'image(LOUT)
      severity failure;
    dout.rst := din.rst;
    dout.vld := din.vld;
    dout.re  := RESIZE(din.re,LOUT);
    dout.im  := RESIZE(din.im,LOUT);
    dout.ovf := din.ovf; -- increasing size cannot cause overflow 
    return dout;
  end function;

  ------------------------------------------
  -- RESIZE UP VECTOR
  ------------------------------------------

  function resize (din:cplx16_vector; n:positive) return cplx18_vector is
    variable res : cplx18_vector(din'range);
  begin
    for i in din'range loop res(i) := resize(din(i), n=>n); end loop;
    return res;
  end function;

  function resize (din:cplx16_vector; n:positive) return cplx20_vector is
    variable res : cplx20_vector(din'range);
  begin
    for i in din'range loop res(i) := resize(din(i), n=>n); end loop;
    return res;
  end function;

  function resize (din:cplx18_vector; n:positive) return cplx20_vector is
    variable res : cplx20_vector(din'range);
  begin
    for i in din'range loop res(i) := resize(din(i), n=>n); end loop;
    return res;
  end function;

  function resize (din:cplx16_vector; n:positive) return cplx22_vector is
    variable res : cplx22_vector(din'range);
  begin
    for i in din'range loop res(i) := resize(din(i), n=>n); end loop;
    return res;
  end function;

  function resize (din:cplx18_vector; n:positive) return cplx22_vector is
    variable res : cplx22_vector(din'range);
  begin
    for i in din'range loop res(i) := resize(din(i), n=>n); end loop;
    return res;
  end function;

  function resize (din:cplx20_vector; n:positive) return cplx22_vector is
    variable res : cplx22_vector(din'range);
  begin
    for i in din'range loop res(i) := resize(din(i), n=>n); end loop;
    return res;
  end function;

  ------------------------------------------
  -- ADDITION and ACCUMULATION
  ------------------------------------------

  -- local auxiliary procedure to avoid massive code duplication
  procedure help_add (
    rst  : in  std_logic;
    l,r  : in  signed;
    ovfi : in  std_logic;
    dout : out signed;
    ovfo : out std_logic;
    m    : in  cplx_mode
  ) is
    variable ovfl : std_logic;
  begin
    if m='R' and rst='1' then
      dout := (dout'range =>'0');
      ovfo := '0';
    else
      ADD(l=>l, r=>r, dout=>dout, ovfl=>ovfl, clip=>(m='S'));
      if m='O' then ovfo := ovfi or ovfl; else ovfo := ovfi; end if;
    end if;
  end procedure;

  function add (l,r: cplx16; w:natural:=16; m:cplx_mode:="-") return cplx16 is 
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx16;
  begin
    assert (w=0 or w=16)
      report "ERROR in add cplx16 : Output bit width must be w=0 or w=16"
      severity failure;
    res.rst := l.rst or r.rst;
    res.vld := l.vld and r.vld; -- input before reset
    res.ovf := l.ovf or r.ovf; -- input before reset
    if m='R' and res.rst='1' then res.vld:='0'; else end if;
    help_add(res.rst, l.re, r.re, res.ovf, res.re, ovfl_re, m);
    help_add(res.rst, l.im, r.im, res.ovf, res.im, ovfl_im, m);
    res.ovf := ovfl_re or ovfl_im; -- overflow handling in help procedure
    return res;
  end function;

  function add (l,r: cplx18; w:natural:=18; m:cplx_mode:="-") return cplx18 is 
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx18;
  begin
    assert (w=0 or w=18)
      report "ERROR in add cplx18 : Output bit width must be w=0 or w=18"
      severity failure;
    res.rst := l.rst or r.rst;
    res.vld := l.vld and r.vld; -- input before reset
    res.ovf := l.ovf or r.ovf; -- input before reset
    if m='R' and res.rst='1' then res.vld:='0'; else end if;
    help_add(res.rst, l.re, r.re, res.ovf, res.re, ovfl_re, m);
    help_add(res.rst, l.im, r.im, res.ovf, res.im, ovfl_im, m);
    res.ovf := ovfl_re or ovfl_im; -- overflow handling in help procedure
    return res;
  end function;

  function add (l,r: cplx20; w:natural:=20; m:cplx_mode:="-") return cplx20 is 
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx20;
  begin
    assert (w=0 or w=20)
      report "ERROR in add cplx20 : Output bit width must be w=0 or w=20"
      severity failure;
    res.rst := l.rst or r.rst;
    res.vld := l.vld and r.vld;
    res.ovf := l.ovf or r.ovf;
    if m='R' and res.rst='1' then res.vld:='0'; else end if;
    help_add(res.rst, l.re, r.re, res.ovf, res.re, ovfl_re, m);
    help_add(res.rst, l.im, r.im, res.ovf, res.im, ovfl_im, m);
    res.ovf := ovfl_re or ovfl_im; -- overflow handling in help procedure
    return res;
  end function;

  function add (l,r: cplx22; w:natural:=22; m:cplx_mode:="-") return cplx22 is 
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx22;
  begin
    assert (w=0 or w=22)
      report "ERROR in add cplx22 : Output bit width must be w=0 or w=22"
      severity failure;
    res.rst := l.rst or r.rst;
    res.vld := l.vld and r.vld;
    res.ovf := l.ovf or r.ovf;
    if m='R' and res.rst='1' then res.vld:='0'; else end if;
    help_add(res.rst, l.re, r.re, res.ovf, res.re, ovfl_re, m);
    help_add(res.rst, l.im, r.im, res.ovf, res.im, ovfl_im, m);
    res.ovf := ovfl_re or ovfl_im; -- overflow handling in help procedure
    return res;
  end function;

  function "+" (l,r: cplx16) return cplx16 is
  begin
    return add(l, r, m=>"O"); -- always with overflow detection
  end function;

  function "+" (l,r: cplx18) return cplx18 is
  begin
    return add(l, r, m=>"O"); -- always with overflow detection
  end function;

  function "+" (l,r: cplx20) return cplx20 is
  begin
    return add(l, r, m=>"O"); -- always with overflow detection
  end function;

  function "+" (l,r: cplx22) return cplx22 is
  begin
    return add(l, r, m=>"O"); -- always with overflow detection
  end function;

  function sum (din: cplx16_vector; w:natural:=18; m:cplx_mode:="-") return cplx18 is
    constant LVEC : positive := din'length; -- vector length
    constant LOUT : positive := 18;
    alias d : cplx16_vector(0 to LVEC-1) is din; -- default range
    variable res : cplx18;
  begin
    assert (w=LOUT)
      report "ERROR in sum cplx16->cplx18 : Output bit width must be w=" & integer'image(LOUT)
      severity failure;
    assert LVEC<=4
      report "WARNING: Only up to 4 vector elements should be summed up."
      severity warning;
    res := resize(d(0),LOUT);
    if LVEC>1 then
      for i in 1 to LVEC-1 loop res:=res+resize(d(i),LOUT); end loop;
    end if;
    return res;
  end function;

  function sum (din: cplx18_vector; w:natural:=20; m:cplx_mode:="-") return cplx20 is
    constant LVEC : positive := din'length; -- vector length
    constant LOUT : positive := 20;
    alias d : cplx18_vector(0 to LVEC-1) is din; -- default range
    variable res : cplx20;
  begin
    assert (w=LOUT)
      report "ERROR in sum cplx18->cplx20 : Output bit width must be w=" & integer'image(LOUT)
      severity failure;
    assert LVEC<=4
      report "WARNING: Only up to 4 vector elements should be summed up."
      severity warning;
    res := resize(d(0),LOUT);
    if LVEC>1 then
      for i in 1 to LVEC-1 loop res:=res+resize(d(i),LOUT); end loop;
    end if;
    return res;
  end function;

  function sum (din: cplx20_vector; w:natural:=22; m:cplx_mode:="-") return cplx22 is
    constant LVEC : positive := din'length; -- vector length
    constant LOUT : positive := 22;
    alias d : cplx20_vector(0 to LVEC-1) is din; -- default range
    variable res : cplx22;
  begin
    assert (w=LOUT)
      report "ERROR in sum cplx20->cplx22 : Output bit width must be w=" & integer'image(LOUT)
      severity failure;
    assert LVEC<=4
      report "WARNING: Only up to 4 vector elements should be summed up."
      severity warning;
    res := resize(d(0),LOUT);
    if LVEC>1 then
      for i in 1 to LVEC-1 loop res:=res+resize(d(i),LOUT); end loop;
    end if;
    return res;
  end function;

  ------------------------------------------
  -- SUBSTRACTION
  ------------------------------------------

  -- local auxiliary procedure to avoid massive code duplication
  procedure help_sub (
    rst  : in  std_logic;
    l,r  : in  signed;
    ovfi : in  std_logic;
    dout : out signed;
    ovfo : out std_logic;
    m    : in  cplx_mode
  ) is
    variable ovfl : std_logic;
  begin
    if m='R' and rst='1' then
      dout := (dout'range =>'0');
      ovfo := '0';
    else
      SUB(l=>l, r=>r, dout=>dout, ovfl=>ovfl, clip=>(m='S'));
      if m='O' then ovfo := ovfi or ovfl; else ovfo := ovfi; end if;
    end if;
  end procedure;

  function sub (l,r: cplx16; w:natural:=16; m:cplx_mode:="-") return cplx16 is 
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx16;
  begin
    assert (w=0 or w=16)
      report "ERROR in sub cplx16 : Output bit width must be w=0 or w=16"
      severity failure;
    res.rst := l.rst or r.rst;
    res.vld := l.vld and r.vld; -- input before reset
    res.ovf := l.ovf or r.ovf; -- input before reset
    if m='R' and res.rst='1' then res.vld:='0'; else end if;
    help_sub(res.rst, l.re, r.re, res.ovf, res.re, ovfl_re, m);
    help_sub(res.rst, l.im, r.im, res.ovf, res.im, ovfl_im, m);
    res.ovf := ovfl_re or ovfl_im; -- overflow handling in help procedure
    return res;
  end function;

  function sub (l,r: cplx18; w:natural:=18; m:cplx_mode:="-") return cplx18 is 
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx18;
  begin
    assert (w=0 or w=18)
      report "ERROR in sub cplx18 : Output bit width must be w=0 or w=18"
      severity failure;
    res.rst := l.rst or r.rst;
    res.vld := l.vld and r.vld; -- input before reset
    res.ovf := l.ovf or r.ovf; -- input before reset
    if m='R' and res.rst='1' then res.vld:='0'; else end if;
    help_sub(res.rst, l.re, r.re, res.ovf, res.re, ovfl_re, m);
    help_sub(res.rst, l.im, r.im, res.ovf, res.im, ovfl_im, m);
    res.ovf := ovfl_re or ovfl_im; -- overflow handling in help procedure
    return res;
  end function;

  function sub (l,r: cplx20; w:natural:=20; m:cplx_mode:="-") return cplx20 is 
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx20;
  begin
    assert (w=0 or w=20)
      report "ERROR in sub cplx20 : Output bit width must be w=0 or w=20"
      severity failure;
    res.rst := l.rst or r.rst;
    res.vld := l.vld and r.vld; -- input before reset
    res.ovf := l.ovf or r.ovf; -- input before reset
    if m='R' and res.rst='1' then res.vld:='0'; else end if;
    help_sub(res.rst, l.re, r.re, res.ovf, res.re, ovfl_re, m);
    help_sub(res.rst, l.im, r.im, res.ovf, res.im, ovfl_im, m);
    res.ovf := ovfl_re or ovfl_im; -- overflow handling in help procedure
    return res;
  end function;

  function sub (l,r: cplx22; w:natural:=22; m:cplx_mode:="-") return cplx22 is 
    variable ovfl_re, ovfl_im : std_logic;
    variable res : cplx22;
  begin
    assert (w=0 or w=22)
      report "ERROR in sub cplx22 : Output bit width must be w=0 or w=22"
      severity failure;
    res.rst := l.rst or r.rst;
    res.vld := l.vld and r.vld; -- input before reset
    res.ovf := l.ovf or r.ovf; -- input before reset
    if m='R' and res.rst='1' then res.vld:='0'; else end if;
    help_sub(res.rst, l.re, r.re, res.ovf, res.re, ovfl_re, m);
    help_sub(res.rst, l.im, r.im, res.ovf, res.im, ovfl_im, m);
    res.ovf := ovfl_re or ovfl_im; -- overflow handling in help procedure
    return res;
  end function;

  function "-" (l,r: cplx16) return cplx16 is
  begin
    return sub(l, r, m=>"O"); -- always with overflow detection
  end function;

  function "-" (l,r: cplx18) return cplx18 is
  begin
    return sub(l, r, m=>"O"); -- always with overflow detection
  end function;

  function "-" (l,r: cplx20) return cplx20 is
  begin
    return sub(l, r, m=>"O"); -- always with overflow detection
  end function;

  function "-" (l,r: cplx22) return cplx22 is
  begin
    return sub(l, r, m=>"O"); -- always with overflow detection
  end function;

  ------------------------------------------
 -- SHIFT LEFT AND SATURATE/CLIP
  ------------------------------------------

  -- local auxiliary procedure to avoid massive code duplication
  procedure help_shift_left (
    rst  : in  std_logic;
    din  : in  signed;
    ovfi : in  std_logic;
    n    : in  natural;
    dout : out signed;
    ovfo : out std_logic;
    m    : in  cplx_mode
  ) is
    variable ovfl : std_logic;
  begin
    if m='R' and rst='1' then
      dout := (dout'range =>'0');
      ovfo := '0';
    else
      SHIFT_LEFT_CLIP(din=>din, n=>n, dout=>dout, ovfl=>ovfl, clip=>(m='S'));
      if m='O' then ovfo := ovfi or ovfl; else ovfo := ovfi; end if;
    end if;
  end procedure;

  function shift_left (din:cplx16 ; n:natural; m:cplx_mode:="-") return cplx16 is
    variable ovf_re, ovf_im : std_logic;
    variable res : cplx16 := din; -- default
  begin
    if m='R' and din.rst='1' then res.vld:='0'; end if;
    help_shift_left(din.rst, din.re, din.ovf, n, res.re, ovf_re, m);
    help_shift_left(din.rst, din.im, din.ovf, n, res.im, ovf_im, m);
    res.ovf := ovf_re or ovf_im;
    return res;
  end function;

  function shift_left (din:cplx18 ; n:natural; m:cplx_mode:="-") return cplx18 is
    variable ovf_re, ovf_im : std_logic;
    variable res : cplx18 := din; -- default
  begin
    if m='R' and din.rst='1' then res.vld:='0'; end if;
    help_shift_left(din.rst, din.re, din.ovf, n, res.re, ovf_re, m);
    help_shift_left(din.rst, din.im, din.ovf, n, res.im, ovf_im, m);
    res.ovf := ovf_re or ovf_im;
    return res;
  end function;

  function shift_left (din:cplx20 ; n:natural; m:cplx_mode:="-") return cplx20 is
    variable ovf_re, ovf_im : std_logic;
    variable res : cplx20 := din; -- default
  begin
    if m='R' and din.rst='1' then res.vld:='0'; end if;
    help_shift_left(din.rst, din.re, din.ovf, n, res.re, ovf_re, m);
    help_shift_left(din.rst, din.im, din.ovf, n, res.im, ovf_im, m);
    res.ovf := ovf_re or ovf_im;
    return res;
  end function;

  function shift_left (din:cplx22 ; n:natural; m:cplx_mode:="-") return cplx22 is
    variable ovf_re, ovf_im : std_logic;
    variable res : cplx22 := din; -- default
  begin
    if m='R' and din.rst='1' then res.vld:='0'; end if;
    help_shift_left(din.rst, din.re, din.ovf, n, res.re, ovf_re, m);
    help_shift_left(din.rst, din.im, din.ovf, n, res.im, ovf_im, m);
    res.ovf := ovf_re or ovf_im;
    return res;
  end function;

  ------------------------------------------
  -- SHIFT RIGHT and ROUND
  ------------------------------------------

  -- local auxiliary procedure to avoid massive code duplication
  procedure help_shift_right (
    rst  : in  std_logic;
    din  : in  signed;
    n    : in  natural;
    dout : out signed;
    m    : in  cplx_mode
  ) is
  begin
    if m='R' and rst='1' then
      dout := (dout'range =>'0');
    elsif m='N' then
      dout := SHIFT_RIGHT_ROUND(din, n, nearest);
    elsif m='U' then
      dout := SHIFT_RIGHT_ROUND(din, n, ceil); -- real part
    elsif m='Z' then
      dout := SHIFT_RIGHT_ROUND(din, n, truncate); -- real part
    elsif m='I' then
      dout := SHIFT_RIGHT_ROUND(din, n, infinity); -- real part
    else
      -- by default standard rounding, i.e. floor
      dout := shift_right(din, n); -- real part
    end if;
  end procedure;

  function shift_right (din:cplx16; n:natural; m:cplx_mode:="-") return cplx16 is
    variable res : cplx16 := din; -- default
  begin
    if m='R' and din.rst='1' then res.vld:='0'; res.ovf:='0'; end if;
    help_shift_right(din.rst, din.re, n, res.re, m);
    help_shift_right(din.rst, din.im, n, res.im, m);
    return res;
  end function;

  function shift_right (din:cplx18; n:natural; m:cplx_mode:="-") return cplx18 is
    variable res : cplx18 := din; -- default
  begin
    if m='R' and din.rst='1' then res.vld:='0'; res.ovf:='0'; end if;
    help_shift_right(din.rst, din.re, n, res.re, m);
    help_shift_right(din.rst, din.im, n, res.im, m);
    return res;
  end function;

  function shift_right (din:cplx20; n:natural; m:cplx_mode:="-") return cplx20 is
    variable res : cplx20 := din; -- default
  begin
    if m='R' and din.rst='1' then res.vld:='0'; res.ovf:='0'; end if;
    help_shift_right(din.rst, din.re, n, res.re, m);
    help_shift_right(din.rst, din.im, n, res.im, m);
    return res;
  end function;

  function shift_right (din:cplx22; n:natural; m:cplx_mode:="-") return cplx22 is
    variable res : cplx22 := din; -- default
  begin
    if m='R' and din.rst='1' then res.vld:='0'; res.ovf:='0'; end if;
    help_shift_right(din.rst, din.re, n, res.re, m);
    help_shift_right(din.rst, din.im, n, res.im, m);
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
