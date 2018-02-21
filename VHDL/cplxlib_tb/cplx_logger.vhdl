---------------------------------------------------------------------------------------------------
-- FILE    : cplx_logger.vhdl   
-- AUTHOR  : Fixitfetish
-- DATE    : 26/May/2017
-- VERSION : 0.40
-- VHDL    : 1993
-- LICENSE : MIT License
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.string_conversion_pkg.all;
library cplxlib;
  use cplxlib.cplx_pkg.all;

use std.textio.all;


entity cplx_logger is
generic(
  NUM_CPLX : natural := 1; -- number of parallel CPLX inputs 
  LOG_FILE : string := "log.txt";
  LOG_DECIMAL : boolean := false; -- TODO
  LOG_INVALID : boolean := false;
  STR_INVALID : string := "nan"; -- string for invalid values
  TITLE : string := ""
);
port(
  clk    : in  std_logic;
  rst    : in  std_logic;
  din    : in  cplx_vector(0 to NUM_CPLX-1) := cplx_vector_reset(18,NUM_CPLX,"R"); -- default when open
  finish : in  std_logic := '0'
);
end entity;

---------------------------------------------------------------------------------------------------

architecture sim of cplx_logger is

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

  procedure cplx_write(
    constant DEC : in boolean;
    variable l : inout line;
    variable din : in cplx
  ) is
    variable v_val : integer;
  begin
    write(l,hexstr_validate(hexstr_from_sl(din.rst),STR_INVALID),right,3);
    write(l,hexstr_validate(hexstr_from_sl(din.vld),STR_INVALID),right,4);
    write(l,hexstr_validate(hexstr_from_sl(din.ovf),STR_INVALID),right,4);
    if DEC then
      v_val := to_integer(din.re);
      write_str(l,integer'image(v_val),right,8);
      v_val := to_integer(din.im);
      write_str(l,integer'image(v_val),right,8);
    else
      write_str(l,hexstr_from_signed(din.re),right,8);
      write_str(l,hexstr_from_signed(din.im),right,8);
    end if;
    write_str(l," ",right,3); -- trailing spaces
  end procedure;

begin

  p_file: process
    variable v_oline : line;
  begin
    file_open(ofile,LOG_FILE,WRITE_MODE);
    -- File header
    if TITLE/="" then
      for n in 0 to (NUM_CPLX-1) loop
        write_str(v_oline,TITLE,left,30);
      end loop;
      writeline(ofile,v_oline);
      for n in 0 to (NUM_CPLX-1) loop
        write_str(v_oline,"RST VLD OVF    REAL    IMAG",left,30);
      end loop;
      writeline(ofile,v_oline);
    end if;
    loop
      wait until rising_edge(clk);
      exit when (finish='1');
    end loop;
    file_close(ofile);
    
	  wait; -- end of process
  end process;

  p_log: process(clk)
    variable v_oline : line;
    variable v_din : cplx18;
  begin
    if rising_edge(clk) then
      if rst='0' and (LOG_INVALID or din(0).vld='1') then
        for n in 0 to (NUM_CPLX-1) loop
          v_din := din(n);
          cplx_write(LOG_DECIMAL,v_oline,v_din);
        end loop;
        -- line to file
        if finish='0' then
         writeline(ofile,v_oline);
        end if;
      end if; -- valid  
    end if; -- clock
  end process;

end architecture;
