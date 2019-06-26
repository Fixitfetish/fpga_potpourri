-------------------------------------------------------------------------------
--! @file       noise_tb.vhdl
--! @author     Fixitfetish
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library siglib;

use std.textio.all;


entity noise_tb is
end entity;

architecture sim of noise_tb is

  file ofile : text; -- output file

  constant PERIOD : time := 1 ns;
  signal load : std_logic := '1';
  signal clk : std_logic := '1';
  signal finish : std_logic := '0';

  signal req_ack: std_logic := '1';

  constant OUTPUT_WIDTH : positive := 12;
  
  signal dout0 : signed(OUTPUT_WIDTH-1 downto 0);
  signal dout0_vld : std_logic;
  signal dout0_first : std_logic;

begin

  p_clk : process
  begin
    while finish='0' loop
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


  p_load: process
  begin
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    load <= '0'; 
    for n in 1 to 6 loop wait until rising_edge(clk); end loop;
    load <= '0'; 
    wait until rising_edge(clk);
    wait; -- end of process
  end process;


  i_noise : entity siglib.noise_normal
  generic map(
    RESOLUTION       => OUTPUT_WIDTH,
    ACKNOWLEDGE_MODE => false,
    INSTANCE_IDX     => 1
  )
  port map(
    clk        => clk,
    rst        => load,
    req_ack    => req_ack,
    dout       => dout0,
    dout_vld   => dout0_vld,
    dout_first => dout0_first
  );

  p_stimuli: process
  begin
    while load='1' loop
      wait until rising_edge(clk);
    end loop;

    -- time forward
    for m in 1 to 10 loop
     for n in 1 to 100000 loop
       req_ack <= '1'; 
       wait until rising_edge(clk);
--       req_ack <= '0'; 
--       wait until rising_edge(clk);
--       req_ack <= '1'; 
--       wait until rising_edge(clk);
--       req_ack <= '1'; 
--       wait until rising_edge(clk);
--       req_ack <= '1'; 
--       wait until rising_edge(clk);
--       req_ack <= '0'; 
--       wait until rising_edge(clk);
--       req_ack <= '0'; 
--       wait until rising_edge(clk);
--       req_ack <= '0'; 
--       wait until rising_edge(clk);
     end loop;
    end loop;
        
    wait until rising_edge(clk);
    req_ack <= '0'; 
    wait until rising_edge(clk);
    finish <= '1';
    wait until rising_edge(clk);
    wait; -- end of process
  end process;

  p_log: process
    variable l :line;
  begin
    file_open(ofile,"log.txt",WRITE_MODE);
      
    while finish='0' loop
      wait until rising_edge(clk);
      if dout0_vld='1' then
        write(l,integer'image(to_integer(dout0)),right,8);
        writeline(ofile,l);
      end if;
    end loop;

    file_close(ofile);
    wait; -- end of process
  end process;


end architecture;

