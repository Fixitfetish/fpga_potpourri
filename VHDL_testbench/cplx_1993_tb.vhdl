-------------------------------------------------------------------------------
-- FILE    : cplx_1993_tb.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 12/Nov/2016
-- VERSION : 0.2
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
 use fixitfetish.cplx_pkg.all;

use std.textio.all;

entity cplx_1993_tb is
end entity;

architecture sim of cplx_1993_tb is

  -- Input A
  constant WIDTH_RE_A : positive := 16;
  constant WIDTH_IM_A : positive := 16;
  constant MIN_RE_A : integer := -2**(WIDTH_RE_A-1);
  constant MAX_RE_A : integer := 2**(WIDTH_RE_A-1)-1;
  constant MIN_IM_A : integer := -2**(WIDTH_IM_A-1);
  constant MAX_IM_A : integer := 2**(WIDTH_IM_A-1)-1;
  alias cplx_a is cplx16;
  alias cplx_a_vector is cplx16_vector;
  constant stimuli_a : cplx_a_vector(0 to 25) := (
    ( rst=>'1', vld=>'0', ovf=>'0', re=>(WIDTH_RE_A-1 downto 0 =>'-'), im=>(WIDTH_IM_A-1 downto 0 =>'-')),
    ( rst=>'0', vld=>'0', ovf=>'0', re=>(WIDTH_RE_A-1 downto 0 =>'-'), im=>(WIDTH_IM_A-1 downto 0 =>'-')),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(MAX_RE_A  ,WIDTH_RE_A), im=>to_signed(MAX_IM_A  ,WIDTH_IM_A) ),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(MAX_RE_A-1,WIDTH_RE_A), im=>to_signed(MAX_IM_A-1,WIDTH_IM_A) ),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(         9,WIDTH_RE_A), im=>to_signed(         9,WIDTH_IM_A) ),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(         8,WIDTH_RE_A), im=>to_signed(         8,WIDTH_IM_A) ),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(         7,WIDTH_RE_A), im=>to_signed(         7,WIDTH_IM_A) ),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(         6,WIDTH_RE_A), im=>to_signed(         6,WIDTH_IM_A) ),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(         5,WIDTH_RE_A), im=>to_signed(         5,WIDTH_IM_A) ),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(         4,WIDTH_RE_A), im=>to_signed(         4,WIDTH_IM_A) ),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(         3,WIDTH_RE_A), im=>to_signed(         3,WIDTH_IM_A) ),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(         2,WIDTH_RE_A), im=>to_signed(         2,WIDTH_IM_A) ),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(         1,WIDTH_RE_A), im=>to_signed(         1,WIDTH_IM_A) ),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(         0,WIDTH_RE_A), im=>to_signed(         0,WIDTH_IM_A) ),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(        -1,WIDTH_RE_A), im=>to_signed(        -1,WIDTH_IM_A) ),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(        -2,WIDTH_RE_A), im=>to_signed(        -2,WIDTH_IM_A) ),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(        -3,WIDTH_RE_A), im=>to_signed(        -3,WIDTH_IM_A) ),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(        -4,WIDTH_RE_A), im=>to_signed(        -4,WIDTH_IM_A) ),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(        -5,WIDTH_RE_A), im=>to_signed(        -5,WIDTH_IM_A) ),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(        -6,WIDTH_RE_A), im=>to_signed(        -6,WIDTH_IM_A) ),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(        -7,WIDTH_RE_A), im=>to_signed(        -7,WIDTH_IM_A) ),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(        -8,WIDTH_RE_A), im=>to_signed(        -8,WIDTH_IM_A) ),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(        -9,WIDTH_RE_A), im=>to_signed(        -9,WIDTH_IM_A) ),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(MIN_RE_A+1,WIDTH_RE_A), im=>to_signed(MIN_IM_A+1,WIDTH_IM_A) ),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(MIN_RE_A  ,WIDTH_RE_A), im=>to_signed(MIN_IM_A  ,WIDTH_IM_A) ),
    ( rst=>'0', vld=>'0', ovf=>'0', re=>to_signed(         0,WIDTH_RE_A), im=>to_signed(         0,WIDTH_IM_A) )
  );
  signal A : cplx_a := cplx_reset(16,"R");

  -- Input B
  constant WIDTH_RE_B : positive := 16;
  constant WIDTH_IM_B : positive := 16;
  constant MIN_RE_B : integer := -2**(WIDTH_RE_B-1);
  constant MAX_RE_B : integer := 2**(WIDTH_RE_B-1)-1;
  constant MIN_IM_B : integer := -2**(WIDTH_IM_B-1);
  constant MAX_IM_B : integer := 2**(WIDTH_IM_B-1)-1;
  subtype cplx_b is cplx16;
  subtype cplx_b_vector is cplx16_vector;
  constant stimuli_b : cplx_b_vector(0 to 9) := (
    ( rst=>'1', vld=>'0', ovf=>'0', re=>(WIDTH_RE_B-1 downto 0 =>'-'), im=>(WIDTH_IM_B-1 downto 0 =>'-')),
    ( rst=>'0', vld=>'0', ovf=>'0', re=>(WIDTH_RE_B-1 downto 0 =>'-'), im=>(WIDTH_IM_B-1 downto 0 =>'-')),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(MAX_RE_B  ,WIDTH_RE_B), im=>to_signed(MAX_IM_B  ,WIDTH_IM_B) ),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(MAX_RE_B-1,WIDTH_RE_B), im=>to_signed(MAX_IM_B-1,WIDTH_IM_B) ),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(         1,WIDTH_RE_B), im=>to_signed(         1,WIDTH_IM_B) ),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(         0,WIDTH_RE_B), im=>to_signed(         0,WIDTH_IM_B) ),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(        -1,WIDTH_RE_B), im=>to_signed(        -1,WIDTH_IM_B) ),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(MIN_RE_B+1,WIDTH_RE_B), im=>to_signed(MIN_IM_B+1,WIDTH_IM_B) ),
    ( rst=>'0', vld=>'1', ovf=>'0', re=>to_signed(MIN_RE_B  ,WIDTH_RE_B), im=>to_signed(MIN_IM_B  ,WIDTH_IM_B) ),
    ( rst=>'0', vld=>'0', ovf=>'0', re=>to_signed(         0,WIDTH_RE_B), im=>to_signed(         0,WIDTH_IM_B) )
  );

  -- Output R
  constant WIDTH_RE_R : positive := 16;
  constant WIDTH_IM_R : positive := 16;
  subtype cplx_r is cplx16;
  subtype cplx_r_vector is cplx16_vector;
  signal R1 : cplx_r;
  signal R2 : cplx_r;

  file SLC : text open WRITE_MODE IS "output/shift_left_clip_cplx.log";

  signal clk : std_logic := '1';
  
  -- for GTKWave convert to basic types
  signal A_rst : std_logic;
  signal A_vld : std_logic;
  signal A_ovf : std_logic;
  signal A_re  : signed(WIDTH_RE_A-1 downto 0);
  signal A_im  : signed(WIDTH_IM_A-1 downto 0);
  signal R1_rst : std_logic;
  signal R1_vld : std_logic;
  signal R1_ovf : std_logic;
  signal R1_re  : signed(WIDTH_RE_R-1 downto 0);
  signal R1_im  : signed(WIDTH_IM_R-1 downto 0);
  signal R2_rst : std_logic;
  signal R2_vld : std_logic;
  signal R2_ovf : std_logic;
  signal R2_re  : signed(WIDTH_RE_R-1 downto 0);
  signal R2_im  : signed(WIDTH_IM_R-1 downto 0);

begin

 clk <= not clk after 0.5 ns; -- 1000MHz

 -- for GTKWave convert to basic types
 A_rst  <= A.rst;
 A_vld  <= A.vld;
 A_ovf  <= A.ovf;
 A_re   <= A.re;
 A_im   <= A.im;
 R1_rst <= R1.rst;
 R1_vld <= R1.vld;
 R1_ovf <= R1.ovf;
 R1_re  <= R1.re;
 R1_im  <= R1.im;
 R2_rst <= R2.rst;
 R2_vld <= R2.vld;
 R2_ovf <= R2.ovf;
 R2_re  <= R2.re;
 R2_im  <= R2.im;

 -- shift left clip
 p_slc : process
   variable v_a : cplx_a := cplx_reset(16); -- input A
   variable v_r1, v_r2 : cplx_r; -- result
   variable v_r : integer;
   variable wline : line;
 begin
   wait until rising_edge(clk);
   for n in 0 to WIDTH_RE_A loop
     write(wline,string'("n=") & integer'image(n), left,6);
     write(wline,string'("  wrap,ovf  clip,ovf"));
     writeline(SLC,wline);
     for i in stimuli_a'range loop
       v_a := stimuli_a(i);
       write(wline, integer'image(i),right, 3); write(wline,string'(" "),right, 3);
       v_r1 := shift_left(din=>v_a, n=>n, m=>"O");
       v_r := to_integer(v_r1.re);
       write(wline, integer'image(v_r) & ',' & std_logic'image(v_r1.ovf),right, 10);
       v_r2 := shift_left(din=>v_a, n=>n, m=>"OS");
       v_r := to_integer(v_r2.re);
       write(wline, integer'image(v_r) & ',' & std_logic'image(v_r2.ovf),right, 10);
       writeline(SLC,wline);
       A <= v_a;
       wait until rising_edge(clk);
       R1 <= v_r1;
       R2 <= v_r2;
     end loop;
     writeline(SLC,wline);
   end loop;
   report "End shift left clip" severity note;
   while true loop
     wait until rising_edge(clk);
   end loop;
 end process;


end architecture;
