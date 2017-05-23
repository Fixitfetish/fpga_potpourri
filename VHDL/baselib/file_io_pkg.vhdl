-------------------------------------------------------------------------------
--! @file       file_io_pkg.vhdl
--! @author     Fixitfetish
--! @date       04/Jun/2016
--! @version    0.10
--! @copyright  MIT License
--! @note       VHDL-1993
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

  -- decimal read
  procedure dec_read(l:inout line; val:out unsigned);
  procedure dec_read(l:inout line; val:out signed);

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



  procedure dec_read(l:inout line; val:out unsigned) is
    variable str : string(1 to 16); -- max 16 characters
    variable c : integer range 1 to 16 := 1;
  begin
    loop -- skip preceding white spaces
      read(l,str(c));
      exit when ((str(c)/=' ') and (str(c)/=CR) and (str(c)/=HT));
    end loop;
    loop -- read until next white space
      c := c + 1;
      read(l,str(c));
      exit when ((str(c)=' ') or (str(c)=CR) or (str(c)=HT));
    end loop;
    decstr_to_unsigned(str(1 to c-1),val);
  end procedure;

  procedure dec_read(l:inout line; val:out signed) is
    variable str : string(1 to 16); -- max 16 characters
    variable c : integer range 1 to 16 := 1;
  begin
    loop -- skip preceding white spaces
      read(l,str(c));
      exit when ((str(c)/=' ') and (str(c)/=CR) and (str(c)/=HT));
    end loop;
    loop -- read until next white space
      c := c + 1;
      read(l,str(c));
      exit when ((str(c)=' ') or (str(c)=LF) or (str(c)=CR) or (str(c)=HT));
    end loop;
    decstr_to_signed(str(1 to c-1),val);
  end procedure;


 end package body;
