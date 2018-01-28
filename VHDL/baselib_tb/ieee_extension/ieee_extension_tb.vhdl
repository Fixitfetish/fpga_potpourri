-------------------------------------------------------------------------------
-- FILE    : ieee_extension_tb.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 02/Nov/2016
-- VERSION : 0.3
-- VHDL    : 1993
-- LICENSE : MIT License
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library baselib;
 use baselib.ieee_extension.all;

use std.textio.all;

entity ieee_extension_tb is
end entity;

architecture sim of ieee_extension_tb is

  file SLCU : text open WRITE_MODE IS "output/shift_left_clip_unsigned.log";
  file SLCS : text open WRITE_MODE IS "output/shift_left_clip_signed.log";
  file SRRU : text open WRITE_MODE IS "output/shift_right_round_unsigned.log";
  file SRRS : text open WRITE_MODE IS "output/shift_right_round_signed.log";
  file ADDU : text open WRITE_MODE IS "output/addition_unsigned.log";
  file ADDS : text open WRITE_MODE IS "output/addition_signed.log";
  file SUBU : text open WRITE_MODE IS "output/subtraction_unsigned.log";
  file SUBS : text open WRITE_MODE IS "output/subtraction_signed.log";

  type TL is (t_slcu, t_slcs, t_srru, t_srrs, t_addu, t_adds, t_subu, t_subs);
  
  signal finish : std_logic_vector(0 to TL'pos(TL'right)) := (others=>'0');

  constant PERIOD : time := 1 us; -- 1 MHz
  signal clk : std_logic := '1';
   
begin

  p_clk : process
  begin
    while ALL_ONES(finish)='0' loop
      wait for PERIOD/2;
      clk <= not clk;
    end loop;
    -- epilog, 5 cycles
    for n in 1 to 10 loop
      wait for PERIOD/2;
      clk <= not clk;
    end loop;
    report "INFO: Clock stopped. End of simulation." severity note;
    wait; -- stop clock
  end process;

 -- shift left clip unsigned
 p_slcu : process
   constant LIN : positive := 5;
   constant LOUT : positive := 5;
   constant LIN_MIN : integer := 0;
   constant LIN_MAX : integer := 2**LIN-1;
   variable din : unsigned(LIN-1 downto 0);
   variable dout : unsigned(LOUT-1 downto 0);
   variable ovfl : std_logic;
   variable r : integer;
   variable wline : line;
 begin
   for n in 0 to LIN loop
     write(wline,string'("n=") & integer'image(n), left,6);
     write(wline,string'("  wrap,ovf  clip,ovf"));
     writeline(SLCU,wline);
     for i in LIN_MIN to LIN_MAX loop
       din := to_unsigned(i,LIN);
       write(wline, integer'image(i),right, 3); write(wline,string'(" "),right, 3);
       shift_left_clip(din=>din, n=>n, dout=>dout, ovfl=>ovfl, clip=>false);
       r := to_integer(dout);
       write(wline, integer'image(r) & ',' & std_logic'image(ovfl),right, 10);
       shift_left_clip(din=>din, n=>n, dout=>dout, ovfl=>ovfl, clip=>true);
       r := to_integer(dout);
       write(wline, integer'image(r) & ',' & std_logic'image(ovfl),right, 10);
       writeline(SLCU,wline);
       wait until rising_edge(clk);
     end loop;
     writeline(SLCU,wline);
   end loop;
   report "End shift left clip unsigned" severity note;
   wait until rising_edge(clk);
   
   finish(TL'pos(t_slcu)) <= '1';
   wait until rising_edge(clk);
   wait;   
 end process;

 -- shift left clip signed
 p_slcs : process
   constant LIN : positive := 5;
   constant LOUT : positive := 5;
   constant LIN_MIN : integer := -2**(LIN-1);
   constant LIN_MAX : integer := 2**(LIN-1)-1;
   variable din : signed(LIN-1 downto 0);
   variable dout : signed(LOUT-1 downto 0);
   variable ovfl : std_logic;
   variable r : integer;
   variable wline : line;
 begin
   for n in 0 to LIN loop
     write(wline,string'("n=") & integer'image(n), left,6);
     write(wline,string'("  wrap,ovf  clip,ovf"));
     writeline(SLCS,wline);
     for i in LIN_MIN to LIN_MAX loop
       din := to_signed(i,LIN);
       write(wline, integer'image(i),right, 3); write(wline,string'(" "),right, 3);
       shift_left_clip(din=>din, n=>n, dout=>dout, ovfl=>ovfl, clip=>false);
       r := to_integer(dout);
       write(wline, integer'image(r) & ',' & std_logic'image(ovfl),right, 10);
       shift_left_clip(din=>din, n=>n, dout=>dout, ovfl=>ovfl, clip=>true);
       r := to_integer(dout);
       write(wline, integer'image(r) & ',' & std_logic'image(ovfl),right, 10);
       writeline(SLCS,wline);
       wait until rising_edge(clk);
     end loop;
     writeline(SLCS,wline);
   end loop;
   report "End shift left clip signed" severity note;
   wait until rising_edge(clk);
   
   finish(TL'pos(t_slcs)) <= '1';
   wait until rising_edge(clk);
   wait;   
 end process;

 -- shift right round unsigned
 p_srru : process
   constant LIN : positive := 5;
   constant LOUT : positive := 5;
   constant LIN_MIN : integer := 0;
   constant LIN_MAX : integer := 2**LIN-1;
   variable din : unsigned(LIN-1 downto 0);
   variable dout : unsigned(LOUT-1 downto 0);
   variable ovfl : std_logic;
   variable clip : boolean := false;
   variable r : integer;
   variable wline : line;
 begin
   for n in 0 to LIN loop
     write(wline,string'("n=") & integer'image(n), left,6);
     write(wline,string'(" floor  near  ceil trunc infin"));
     writeline(SRRU,wline);
     for i in LIN_MIN to LIN_MAX loop
       din := to_unsigned(i,LIN);
       write(wline, integer'image(i),right, 3); write(wline,string'(" "),right, 3);
       shift_right_round(din=>din, n=>n, dout=>dout, ovfl=>ovfl, clip=>clip, rnd=>floor);
       r := to_integer(dout);
       write(wline, integer'image(r),right, 6);
       shift_right_round(din=>din, n=>n, dout=>dout, ovfl=>ovfl, clip=>clip, rnd=>nearest);
       r := to_integer(dout);
       write(wline, integer'image(r),right, 6);
       shift_right_round(din=>din, n=>n, dout=>dout, ovfl=>ovfl, clip=>clip, rnd=>ceil);
       r := to_integer(dout);
       write(wline, integer'image(r),right, 6);
       shift_right_round(din=>din, n=>n, dout=>dout, ovfl=>ovfl, clip=>clip, rnd=>truncate);
       r := to_integer(dout);
       write(wline, integer'image(r),right, 6);
       shift_right_round(din=>din, n=>n, dout=>dout, ovfl=>ovfl, clip=>clip, rnd=>infinity);
       r := to_integer(dout);
       write(wline, integer'image(r),right, 6);
       writeline(SRRU,wline);
       wait until rising_edge(clk);
     end loop;
     writeline(SRRU,wline);
   end loop;
   report "End shift right round unsigned" severity note;
   wait until rising_edge(clk);
   
   finish(TL'pos(t_srru)) <= '1';
   wait until rising_edge(clk);
   wait;   
 end process;

 -- shift right round signed
 p_srrs : process
   constant LIN : positive := 5;
   constant LOUT : positive := 5;
   constant LIN_MIN : integer := -2**(LIN-1);
   constant LIN_MAX : integer := 2**(LIN-1)-1;
   variable din : signed(LIN-1 downto 0);
   variable dout : signed(LOUT-1 downto 0);
   variable ovfl : std_logic;
   variable clip : boolean := false;
   variable r : integer;
   variable wline : line;
 begin
   for n in 0 to LIN loop
     write(wline,string'("n=") & integer'image(n), left,6);
     write(wline,string'(" floor  near  ceil trunc infin"));
     writeline(SRRS,wline);
     for i in LIN_MIN to LIN_MAX loop
       din := to_signed(i,LIN);
       write(wline, integer'image(i),right, 3); write(wline,string'(" "),right, 3);
       shift_right_round(din=>din, n=>n, dout=>dout, ovfl=>ovfl, clip=>clip, rnd=>floor);
       r := to_integer(dout);
       write(wline, integer'image(r),right, 6);
       shift_right_round(din=>din, n=>n, dout=>dout, ovfl=>ovfl, clip=>clip, rnd=>nearest);
       r := to_integer(dout);
       write(wline, integer'image(r),right, 6);
       shift_right_round(din=>din, n=>n, dout=>dout, ovfl=>ovfl, clip=>clip, rnd=>ceil);
       r := to_integer(dout);
       write(wline, integer'image(r),right, 6);
       shift_right_round(din=>din, n=>n, dout=>dout, ovfl=>ovfl, clip=>clip, rnd=>truncate);
       r := to_integer(dout);
       write(wline, integer'image(r),right, 6);
       shift_right_round(din=>din, n=>n, dout=>dout, ovfl=>ovfl, clip=>clip, rnd=>infinity);
       r := to_integer(dout);
       write(wline, integer'image(r),right, 6);
       writeline(SRRS,wline);
       wait until rising_edge(clk);
     end loop;
     writeline(SRRS,wline);
   end loop;
   report "End shift right round signed" severity note;
   wait until rising_edge(clk);
   
   finish(TL'pos(t_srrs)) <= '1';
   wait until rising_edge(clk);
   wait;   
 end process;

 -- addition unsigned
 p_addu : process
   constant LINL : positive := 4; -- length left input
   constant LINR : positive := 5; -- length right input
   constant LOUT : positive := 5; -- length output
   constant LINL_MIN : integer := 0;
   constant LINL_MAX : integer := 2**LINL-1;
   constant LINR_MIN : integer := 0;
   constant LINR_MAX : integer := 2**LINR-1;
   variable l : unsigned(LINL-1 downto 0);
   variable r : unsigned(LINR-1 downto 0);
   variable dout : unsigned(LOUT-1 downto 0);
   variable ovfl : std_logic;
   variable d : integer;
   variable wline : line;
 begin
   write(wline,string'("              wrap,ovf  clip,ovf"));
   writeline(ADDU,wline);
   for li in LINL_MIN to LINL_MAX loop
     l := to_unsigned(li,LINL);
     for ri in LINR_MIN to LINR_MAX loop
       r := to_unsigned(ri,LINR);
       write(wline, integer'image(li),right,3);
       write(wline,string'(" + "),right,3);
       write(wline, integer'image(ri),right,3);
       write(wline,string'(" = "),right,3);
       -- wrap
       add(l=>l, r=>r, dout=>dout, ovfl=>ovfl, clip=>false);
       d := to_integer(dout);
       write(wline, integer'image(d) & ',' & std_logic'image(ovfl),right, 10);
       -- clip
       add(l=>l, r=>r, dout=>dout, ovfl=>ovfl, clip=>true);
       d := to_integer(dout);
       write(wline, integer'image(d) & ',' & std_logic'image(ovfl),right, 10);
       writeline(ADDU,wline);
     end loop;
     writeline(ADDU,wline);
   end loop;
   report "End addition unsigned" severity note;
   file_close(ADDU);
   wait until rising_edge(clk);
   
   finish(TL'pos(t_addu)) <= '1';
   wait until rising_edge(clk);
   wait;   
 end process;

 -- addition signed
 p_adds : process
   constant LINL : positive := 4; -- length left input
   constant LINR : positive := 5; -- length right input
   constant LOUT : positive := 5; -- length output
   constant LINL_MIN : integer := -2**(LINL-1);
   constant LINL_MAX : integer := 2**(LINL-1)-1;
   constant LINR_MIN : integer := -2**(LINR-1);
   constant LINR_MAX : integer := 2**(LINR-1)-1;
   variable l : signed(LINL-1 downto 0);
   variable r : signed(LINR-1 downto 0);
   variable dout : signed(LOUT-1 downto 0);
   variable ovfl : std_logic;
   variable d : integer;
   variable wline : line;
 begin
   write(wline,string'("              wrap,ovf  clip,ovf"));
   writeline(ADDS,wline);
   for li in LINL_MIN to LINL_MAX loop
     l := to_signed(li,LINL);
     for ri in LINR_MIN to LINR_MAX loop
       r := to_signed(ri,LINR);
       write(wline, integer'image(li),right,3);
       write(wline,string'(" + "),right,3);
       write(wline, integer'image(ri),right,3);
       write(wline,string'(" = "),right,3);
       -- wrap
       add(l=>l, r=>r, dout=>dout, ovfl=>ovfl, clip=>false);
       d := to_integer(dout);
       write(wline, integer'image(d) & ',' & std_logic'image(ovfl),right, 10);
       -- clip
       add(l=>l, r=>r, dout=>dout, ovfl=>ovfl, clip=>true);
       d := to_integer(dout);
       write(wline, integer'image(d) & ',' & std_logic'image(ovfl),right, 10);
       writeline(ADDS,wline);
     end loop;
     writeline(ADDS,wline);
   end loop;
   report "End addition signed" severity note;
   wait until rising_edge(clk);
   
   finish(TL'pos(t_adds)) <= '1';
   wait until rising_edge(clk);
   wait;   
 end process;

 -- subtraction unsigned
 p_subu : process
   constant LINL : positive := 4; -- length left input
   constant LINR : positive := 4; -- length right input
   constant LOUT : positive := 4; -- length output
   constant LINL_MIN : integer := 0;
   constant LINL_MAX : integer := 2**LINL-1;
   constant LINR_MIN : integer := 0;
   constant LINR_MAX : integer := 2**LINR-1;
   variable l : unsigned(LINL-1 downto 0);
   variable r : unsigned(LINR-1 downto 0);
   variable dout : unsigned(LOUT-1 downto 0);
   variable ovfl : std_logic;
   variable d : integer;
   variable wline : line;
 begin
   write(wline,string'("              wrap,ovf  clip,ovf"));
   writeline(SUBU,wline);
   for li in LINL_MIN to LINL_MAX loop
     l := to_unsigned(li,LINL);
     for ri in LINR_MIN to LINR_MAX loop
       r := to_unsigned(ri,LINR);
       write(wline, integer'image(li),right,3);
       write(wline,string'(" - "),right,3);
       write(wline, integer'image(ri),right,3);
       write(wline,string'(" = "),right,3);
       -- wrap
       sub(l=>l, r=>r, dout=>dout, ovfl=>ovfl, clip=>false);
       d := to_integer(dout);
       write(wline, integer'image(d) & ',' & std_logic'image(ovfl),right, 10);
       -- clip
       sub(l=>l, r=>r, dout=>dout, ovfl=>ovfl, clip=>true);
       d := to_integer(dout);
       write(wline, integer'image(d) & ',' & std_logic'image(ovfl),right, 10);
       writeline(SUBU,wline);
     end loop;
     writeline(SUBU,wline);
   end loop;
   report "End subtraction unsigned" severity note;
   file_close(SUBU);
   wait until rising_edge(clk);
   
   finish(TL'pos(t_subu)) <= '1';
   wait until rising_edge(clk);
   wait;   
 end process;

 -- subtraction signed
 p_subs : process
   constant LINL : positive := 4; -- length left input
   constant LINR : positive := 5; -- length right input
   constant LOUT : positive := 5; -- length output
   constant LINL_MIN : integer := -2**(LINL-1);
   constant LINL_MAX : integer := 2**(LINL-1)-1;
   constant LINR_MIN : integer := -2**(LINR-1);
   constant LINR_MAX : integer := 2**(LINR-1)-1;
   variable l : signed(LINL-1 downto 0);
   variable r : signed(LINR-1 downto 0);
   variable dout : signed(LOUT-1 downto 0);
   variable ovfl : std_logic;
   variable d : integer;
   variable wline : line;
 begin
   write(wline,string'("              wrap,ovf  clip,ovf"));
   writeline(SUBS,wline);
   for li in LINL_MIN to LINL_MAX loop
     l := to_signed(li,LINL);
     for ri in LINR_MIN to LINR_MAX loop
       r := to_signed(ri,LINR);
       write(wline, integer'image(li),right,3);
       write(wline,string'(" - "),right,3);
       write(wline, integer'image(ri),right,3);
       write(wline,string'(" = "),right,3);
       -- wrap
       sub(l=>l, r=>r, dout=>dout, ovfl=>ovfl, clip=>false);
       d := to_integer(dout);
       write(wline, integer'image(d) & ',' & std_logic'image(ovfl),right, 10);
       -- clip
       sub(l=>l, r=>r, dout=>dout, ovfl=>ovfl, clip=>true);
       d := to_integer(dout);
       write(wline, integer'image(d) & ',' & std_logic'image(ovfl),right, 10);
       writeline(SUBS,wline);
     end loop;
     writeline(SUBS,wline);
   end loop;
   report "End subtraction signed" severity note;
   wait until rising_edge(clk);
   
   finish(TL'pos(t_subs)) <= '1';
   wait until rising_edge(clk);
   wait;   
 end process;


end architecture;
