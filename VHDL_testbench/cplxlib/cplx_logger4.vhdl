---------------------------------------------------------------------------------------------------
-- FILE    : cplx_logger4.vhdl   
-- AUTHOR  : Fixitfetish
-- DATE    : 01/May/2017
-- VERSION : 0.30
-- VHDL    : 1993
-- LICENSE : MIT License
-------------------------------------------------------------------------------
-- Copyright (c) 2016-2017 Fixitfetish
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.string_conversion_pkg.all;
library cplxlib;
  use cplxlib.cplx_pkg.all;

use std.textio.all;


entity cplx_logger4 is
generic(
  LOG_DECIMAL : boolean := false;
  LOG_INVALID : boolean := false;
  LOG_FILE : string := "log.txt";
  TITLE1 : string := "FIRST";
  TITLE2 : string := "SECOND";
  TITLE3 : string := "THIRD";
  TITLE4 : string := "FOURTH"
);
port(
  clk    : in  std_logic;
  rst    : in  std_logic;
  din1   : in  cplx := cplx_reset(18,"R"); -- default when open
  din2   : in  cplx := cplx_reset(18,"R"); -- default when open
  din3   : in  cplx := cplx_reset(18,"R"); -- default when open
  din4   : in  cplx := cplx_reset(18,"R"); -- default when open
  finish : in  std_logic := '0'
);
end entity;

---------------------------------------------------------------------------------------------------

architecture sim of cplx_logger4 is

  file ofile : text; -- output file

  -- avoid problems with resolving overload for "write" procedure call
  procedure write_str
  ( l : inout line;
    value : in string; 
    justified : in side := RIGHT;
    field : in width := 0) is
  begin
    write(l,value,justified,field);
  end procedure;

begin

  p_file: process
    variable v_oline : line;
  begin
    file_open(ofile,log_file,WRITE_MODE);
    -- File header
    write_str(v_oline,TITLE1,left,34);
    write_str(v_oline,TITLE2,left,34);
    write_str(v_oline,TITLE3,left,34);
    write_str(v_oline,TITLE4,left,34);
    writeline(ofile,v_oline);
    write_str(v_oline,"RST VLD OVF    REAL    IMAG",left,34);
    write_str(v_oline,"RST VLD OVF    REAL    IMAG",left,34);
    write_str(v_oline,"RST VLD OVF    REAL    IMAG",left,34);
    write_str(v_oline,"RST VLD OVF    REAL    IMAG",left,34);
    writeline(ofile,v_oline);
    write_str(v_oline,"===========================",left,34);
    write_str(v_oline,"===========================",left,34);
    write_str(v_oline,"===========================",left,34);
    write_str(v_oline,"===========================",left,34);
    writeline(ofile,v_oline);
    loop
      wait until rising_edge(clk);
      exit when (finish='1');
    end loop;
    file_close(ofile);
	wait;
  end process;

g_hex : if not LOG_DECIMAL generate
  p_log: process(clk)
    variable v_oline : line;
  begin
    if rising_edge(clk) then
      if rst='0' and (LOG_INVALID or din1.vld='1' or din2.vld='1') then
        -- 1st cplx
        write(v_oline,hexstr_from_slv(l(0)=>din1.rst),right,3);
        write(v_oline,hexstr_from_slv(l(0)=>din1.vld),right,4);
        write(v_oline,hexstr_from_slv(l(0)=>din1.ovf),right,4);
        write_str(v_oline,hexstr_from_signed(din1.re),right,8);
        write_str(v_oline,hexstr_from_signed(din1.im),right,8);
        -- 2nd cplx
        write(v_oline,hexstr_from_slv(l(0)=>din2.rst),right,10);
        write(v_oline,hexstr_from_slv(l(0)=>din2.vld),right,4);
        write(v_oline,hexstr_from_slv(l(0)=>din2.ovf),right,4);
        write_str(v_oline,hexstr_from_signed(din2.re),right,8);
        write_str(v_oline,hexstr_from_signed(din2.im),right,8);
        -- 3rd cplx
        write(v_oline,hexstr_from_slv(l(0)=>din3.rst),right,10);
        write(v_oline,hexstr_from_slv(l(0)=>din3.vld),right,4);
        write(v_oline,hexstr_from_slv(l(0)=>din3.ovf),right,4);
        write_str(v_oline,hexstr_from_signed(din3.re),right,8);
        write_str(v_oline,hexstr_from_signed(din3.im),right,8);
        -- 4th cplx
        write(v_oline,hexstr_from_slv(l(0)=>din4.rst),right,10);
        write(v_oline,hexstr_from_slv(l(0)=>din4.vld),right,4);
        write(v_oline,hexstr_from_slv(l(0)=>din4.ovf),right,4);
        write_str(v_oline,hexstr_from_signed(din4.re),right,8);
        write_str(v_oline,hexstr_from_signed(din4.im),right,8);
        -- line to file
        if finish='0' then
         writeline(ofile,v_oline);
        end if;
      end if; -- valid  
    end if; -- clock
  end process;
end generate;

g_dec : if LOG_DECIMAL generate
  p_log: process(clk)
    variable v_oline : line;
    variable v_val : integer;
  begin
    if rising_edge(clk) then
      if rst='0' and (LOG_INVALID or din1.vld='1' or din2.vld='1') then
        -- 1st cplx
        write(v_oline,hexstr_from_slv(l(0)=>din1.rst),right,3);
        write(v_oline,hexstr_from_slv(l(0)=>din1.vld),right,4);
        write(v_oline,hexstr_from_slv(l(0)=>din1.ovf),right,4);
        v_val := to_integer(din1.re);
        write_str(v_oline,integer'image(v_val),right,8);
        v_val := to_integer(din1.im);
        write_str(v_oline,integer'image(v_val),right,8);
        -- 2nd cplx
        write(v_oline,hexstr_from_slv(l(0)=>din2.rst),right,10);
        write(v_oline,hexstr_from_slv(l(0)=>din2.vld),right,4);
        write(v_oline,hexstr_from_slv(l(0)=>din2.ovf),right,4);
        v_val := to_integer(din2.re);
        write_str(v_oline,integer'image(v_val),right,8);
        v_val := to_integer(din2.im);
        write_str(v_oline,integer'image(v_val),right,8);
        -- 3rd cplx
        write(v_oline,hexstr_from_slv(l(0)=>din3.rst),right,10);
        write(v_oline,hexstr_from_slv(l(0)=>din3.vld),right,4);
        write(v_oline,hexstr_from_slv(l(0)=>din3.ovf),right,4);
        v_val := to_integer(din3.re);
        write_str(v_oline,integer'image(v_val),right,8);
        v_val := to_integer(din3.im);
        write_str(v_oline,integer'image(v_val),right,8);
        -- 4th cplx
        write(v_oline,hexstr_from_slv(l(0)=>din4.rst),right,10);
        write(v_oline,hexstr_from_slv(l(0)=>din4.vld),right,4);
        write(v_oline,hexstr_from_slv(l(0)=>din4.ovf),right,4);
        v_val := to_integer(din4.re);
        write_str(v_oline,integer'image(v_val),right,8);
        v_val := to_integer(din4.im);
        write_str(v_oline,integer'image(v_val),right,8);
        -- line to file
        if finish='0' then
         writeline(ofile,v_oline);
        end if;
      end if; -- valid  
    end if; -- clock
  end process;
end generate;


end architecture;
