-------------------------------------------------------------------------------
-- FILE    : file_io_pkg.vhdl
-- DATE    : 04/Jun/2016
-- VERSION : 0.10
-- VHDL    : 1993
-- LICENSE : MIT License
-------------------------------------------------------------------------------
-- Copyright (c) 2016 Fixitfetish
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.string_conversion_pkg.all;
  
use std.textio.all;
  
package file_io_pkg is

  -- hexadecimal read
  procedure hex_read(l:inout line; val:out std_logic_vector; field:in width:=0);
  procedure hex_read(l:inout line; val:out unsigned);
  procedure hex_read(l:inout line; val:out signed);

  -- hexadecimal write
  procedure hex_write(l:inout line; val:in std_logic_vector; justified:in side:=right; field:in width:=0);
  procedure hex_write(l:inout line; val:in unsigned; justified:in side:=right; field:in width:=0);
  procedure hex_write(l:inout line; val:in signed; justified:in side:=right; field:in width:=0);

end package;

-------------------------------------------------------------------------------

package body file_io_pkg is

 -- local auxiliary functions

 -- integer maximum of x and y
 function IMAX(x,y:integer) return integer is
 begin
   if y>x then return y;
   else        return x; end if;
 end function;

  procedure hex_read(l:inout line; val:out std_logic_vector; field:in width:=0) is
    constant W : natural := (val'length+3)/4;
    constant N : natural := IMAX(W,field);
    variable str : string(1 to N);
  begin
    str := (others=>' ');
    loop -- skip preceding white spaces
      read(l,str(1));
      exit when ((str(1)/=' ') and (str(1)/=CR) and (str(1)/=HT));
    end loop;
    read(l,str(2 to N));
    hexstr_to_slv(str,val);
  end procedure;

  procedure hex_read(l:inout line; val:out unsigned) is
    constant N : integer := (val'length+3)/4;
    variable str : string(1 to N);
  begin
    loop -- skip white space
      read(l,str(1));
      exit when ((str(1)/=' ') and (str(1)/=CR) and (str(1)/=HT));
    end loop;
    read(l,str(2 to N));
    hexstr_to_unsigned(str,val);
  end procedure;

  procedure hex_read(l:inout line; val:out signed) is
    constant N : integer := (val'length+3)/4;
    variable str : string(1 to N);
  begin
    loop -- skip white space
      read(l,str(1));
      exit when ((str(1)/=' ') and (str(1)/=CR) and (str(1)/=HT));
    end loop;
    read(l,str(2 to N));
    hexstr_to_signed(str,val);
  end procedure;

  procedure hex_write(l:inout line; val:in std_logic_vector; justified:in side:=right; field:in width:=0) is
    constant N : natural := (val'length-1)/4+1; -- number of nibbles
    variable str : string(1 to N);
  begin
    hexstr_from_slv(val,str);
    write(l,str,justified,field);
  end procedure;

  procedure hex_write(l:inout line; val:in unsigned; justified:in side:=right; field:in width:=0) is
    constant N : natural := (val'length-1)/4+1; -- number of nibbles
    variable str : string(1 to N);
  begin
    hexstr_from_unsigned(val,str);
    write(l,str,justified,field);
  end procedure;

  procedure hex_write(l:inout line; val:in signed; justified:in side:=right; field:in width:=0) is
    constant N : natural := (val'length-1)/4+1; -- number of nibbles
    variable str : string(1 to N);
  begin
    hexstr_from_signed(val,str);
    write(l,str,justified,field);
  end procedure;

 end package body;
