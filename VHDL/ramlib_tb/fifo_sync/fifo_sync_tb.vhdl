-------------------------------------------------------------------------------
-- FILE    : fifo_sync_tb.vhdl   
-- AUTHOR  : Fixitfetish
-- DATE    : 08/May/2016
-- VERSION : 1.0
-- VHDL    : 1993
-- LICENSE : MIT License
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library ramlib;

entity fifo_sync_tb is
end entity;

architecture rtl of fifo_sync_tb is

  constant PERIOD : time := 10 ns; -- 100 MHz
  signal rst : std_logic := '1';
  signal clk : std_logic := '1';
  signal finish : std_logic := '0';

  constant CYCLES : natural := 32;
  constant rd : std_logic_vector(0 to CYCLES-1) := "01100000000000001111111111111111";
  constant wr : std_logic_vector(0 to CYCLES-1) := "00011111111111110000111100000000";
  signal cycle : integer range 0 to CYCLES-1;  

  constant FIFO_WIDTH : natural := 8;
  constant FIFO_DEPTH : natural := 11;

  signal level : integer range 0 to FIFO_DEPTH; -- FIFO fill level
  signal data : unsigned(FIFO_WIDTH-1 downto 0) := (others=>'0');

  signal wr_ena       : std_logic := '0';
  signal wr_din       : std_logic_vector(FIFO_WIDTH-1 downto 0) := (others=>'1');
  signal wr_full      : std_logic; -- FIFO full
  signal wr_alm_full  : std_logic; -- FIFO almost full
  signal wr_overflow  : std_logic; -- FIFO overflow (wr_ena=1 and wr_full=1)

  signal rd_req_ack   : std_logic := '0';
  signal rd_dout      : std_logic_vector(FIFO_WIDTH-1 downto 0); -- read data output
  signal rd_empty     : std_logic; -- FIFO empty
  signal rd_alm_empty : std_logic; -- FIFO almost empty
  signal rd_underflow : std_logic; -- FIFO underflow (rd_req_ack=1 and rd_empty=1)

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

  -- release reset
  rst <= '0' after 21 ns;

  finish <= '1' after 500 ns;

  p : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        wr_ena <= '0';
        rd_req_ack <= '0';
        data <= (others=>'0');
        cycle <= 0;
      else
        if wr(cycle)='1' then
          data <= data + 1;
        end if;
        wr_ena <= wr(cycle);
        rd_req_ack <= rd(cycle);
        if cycle/=(CYCLES-1) then
          cycle <= cycle + 1;
        else
          cycle <= 0;
        end if;
      end if;  
    end if;
  end process;  

  wr_din <= std_logic_vector(data);

  i_fifo_sync : entity ramlib.fifo_sync
  generic map (
    FIFO_WIDTH => FIFO_WIDTH,
    FIFO_DEPTH => FIFO_DEPTH,
    USE_BLOCK_RAM => false,
    ACKNOWLEDGE_MODE => false,
    ALMOST_FULL_THRESHOLD => FIFO_DEPTH-2,
    ALMOST_EMPTY_THRESHOLD => 2
  )
  port map (
    clock        => clk, -- clock
    reset        => rst, -- synchronous reset
    level        => level,
    -- write port
    wr_ena       => wr_ena, 
    wr_din       => wr_din, 
    wr_full      => wr_full, 
    wr_alm_full  => wr_alm_full, 
    wr_overflow  => wr_overflow, 
    -- read port
    rd_req_ack   => rd_req_ack, 
    rd_dout      => rd_dout, 
    rd_empty     => rd_empty, 
    rd_alm_empty => rd_alm_empty, 
    rd_underflow => rd_underflow 
  );

end architecture;
