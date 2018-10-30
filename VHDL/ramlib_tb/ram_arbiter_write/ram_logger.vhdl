library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;

use std.textio.all;

entity ram_logger is
generic(
  LOG_FILE : string := "log.txt";
  TITLE : string := ""
);
port(
  clk      : in  std_logic;
  rst      : in  std_logic;
  addr     : in  std_logic_vector;
  din      : in  std_logic_vector;
  wren     : in  std_logic;
  sob      : in  std_logic;
  eob      : in  std_logic;
  finish   : in  std_logic := '0'
);
end entity;

architecture sim of ram_logger is

  constant ADDR_WIDTH : positive := addr'length;
  constant DATA_WIDTH : positive := din'length;

  constant ADDR_DIGIT : positive := (ADDR_WIDTH+3)/4;
  constant DATA_DIGIT : positive := (DATA_WIDTH+3)/4;
  
  signal cycle : natural := 0;

  type r_ram_wr is
  record
    cycle : integer;
    addr  : std_logic_vector(ADDR_WIDTH-1 downto 0);
    din   : std_logic_vector(DATA_WIDTH-1 downto 0);
    wren  : std_logic;
    sob   : std_logic;
    eob   : std_logic;
  end record;

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

  procedure ram_line(
    variable l : inout line;
    variable x : in r_ram_wr
  ) is
  begin
    write(l,integer'image(x.cycle),right,4);
    write(l,x.sob,right,2);
    write(l,x.eob,right,2);
    write(l,to_hstring(x.addr),right,ADDR_DIGIT+1);
    write(l,to_hstring(x.din),right,DATA_DIGIT+1);
  end procedure;

begin

  p_file: process
    variable v_oline : line;
  begin
    file_open(ofile,LOG_FILE,WRITE_MODE);
    -- File header
    if TITLE/="" then
      write_str(v_oline,TITLE,left,30);
      writeline(ofile,v_oline);
    end if;
    loop
      wait until rising_edge(clk);
      exit when (finish='1');
    end loop;
    file_close(ofile);
    wait; -- end of process
  end process;

  p_cycle: process(clk)
  begin
    if rising_edge(clk) and rst='0' then
      cycle <= cycle + 1;
    end if;
  end process;

  p_log: process(clk)
    variable v_oline : line;
    variable v_din : r_ram_wr;
  begin
    if rising_edge(clk) then
      if rst='0' then
        v_din.cycle := cycle;
        v_din.addr := addr;
        v_din.din := din;
        v_din.wren := wren;
        v_din.sob := sob;
        v_din.eob := eob;
        -- line to file
        if wren='1' and finish='0' then
          ram_line(v_oline,v_din);
          writeline(ofile,v_oline);
        end if;
      end if; -- valid  
    end if; -- clock
  end process;

  
end architecture;
