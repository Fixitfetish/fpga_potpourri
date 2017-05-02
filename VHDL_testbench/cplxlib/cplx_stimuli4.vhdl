---------------------------------------------------------------------------------------------------
-- FILE    : cplx_stimuli4.vhdl   
-- AUTHOR  : Fixitfetish
-- DATE    : 01/May/2017
-- VERSION : 0.30
-- VHDL    : 1993
-- LICENSE : MIT License
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.string_conversion_pkg.all;
  use baselib.file_io_pkg.all;
library cplxlib;
  use cplxlib.cplx_pkg.all;

use std.textio.all;

entity cplx_stimuli4 is
generic(
  GEN_INVALID : boolean := true;
  GEN_FILE : string
);
port(
  clk    : in  std_logic;
  rst    : in  std_logic;
  dout1  : out cplx ;--:= cplx_reset(18,"R");
  dout2  : out cplx ;--:= cplx_reset(18,"R");
  dout3  : out cplx ;--:= cplx_reset(18,"R");
  dout4  : out cplx ;--:= cplx_reset(18,"R");
  finish : out std_logic := '0'
);
end entity;

-------------------------------------------------------------------------------

architecture sim of cplx_stimuli4 is

  file   ifile : text; -- input file

  signal finish_i : std_logic := '0';

  function to_01(i:integer) return std_logic is
  begin
    if i=0 then return '0'; else return '1'; end if;
  end function;

begin
  
  finish <= finish_i;
  
  p_stimuli: process
    variable in_line  : line;
    variable v_rst, v_vld, v_ovf : integer;
    variable v_re1, v_im1 : signed(dout1.re'length-1 downto 0);
    variable v_re2, v_im2 : signed(dout2.re'length-1 downto 0);
    variable v_re3, v_im3 : signed(dout3.re'length-1 downto 0);
    variable v_re4, v_im4 : signed(dout4.re'length-1 downto 0);
  begin
    dout1 <= cplx_reset(18,"R");
    dout2 <= cplx_reset(18,"R");
    dout3 <= cplx_reset(18,"R");
    dout4 <= cplx_reset(18,"R");
    file_open(ifile,GEN_FILE,READ_MODE);
    readline(ifile,in_line); -- ignore first line
    readline(ifile,in_line); -- ignore second line
    readline(ifile,in_line); -- ignore third line
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    loop
      -- evaluate line
      readline(ifile,in_line);
      -- 1st cplx
      read(in_line, v_rst);
      read(in_line, v_vld);
      read(in_line, v_ovf);
      hex_read(in_line, v_re1);
      hex_read(in_line, v_im1);
      dout1.rst <= to_01(v_rst);
      dout1.vld <= to_01(v_vld);
      dout1.ovf <= to_01(v_ovf);
      dout1.re <= v_re1;
      dout1.im <= v_im1;
      -- 2nd cplx
      read(in_line, v_rst);
      read(in_line, v_vld);
      read(in_line, v_ovf);
      hex_read(in_line, v_re2);
      hex_read(in_line, v_im2);
      dout2.rst <= to_01(v_rst);
      dout2.vld <= to_01(v_vld);
      dout2.ovf <= to_01(v_ovf);
      dout2.re <= v_re2;
      dout2.im <= v_im2;
      -- 3rd cplx
      read(in_line, v_rst);
      read(in_line, v_vld);
      read(in_line, v_ovf);
      hex_read(in_line, v_re3);
      hex_read(in_line, v_im3);
      dout3.rst <= to_01(v_rst);
      dout3.vld <= to_01(v_vld);
      dout3.ovf <= to_01(v_ovf);
      dout3.re <= v_re3;
      dout3.im <= v_im3;
      -- 4th cplx
      read(in_line, v_rst);
      read(in_line, v_vld);
      read(in_line, v_ovf);
      hex_read(in_line, v_re4);
      hex_read(in_line, v_im4);
      dout4.rst <= to_01(v_rst);
      dout4.vld <= to_01(v_vld);
      dout4.ovf <= to_01(v_ovf);
      dout4.re <= v_re4;
      dout4.im <= v_im4;
      wait until rising_edge(clk);
      exit when endfile(ifile);
    end loop; -- stimuli loop
    
    file_close(ifile);
    report "Finished: Read complete CPLX stimuli file." severity note;
    finish_i <= '1';
    wait until rising_edge(clk);

    wait; -- end of process
  end process;

end architecture;
