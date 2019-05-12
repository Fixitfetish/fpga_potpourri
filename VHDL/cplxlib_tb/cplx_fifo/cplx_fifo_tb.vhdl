-------------------------------------------------------------------------------
-- FILE    : cplx_fifo_tb.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 11/May/2019
-- VERSION : 0.10
-- VHDL    : 2008
-- LICENSE : MIT License
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library cplxlib;
  use cplxlib.cplx_pkg.all;

entity cplx_fifo_tb is
end entity;

architecture sim of cplx_fifo_tb is
  
  constant PERIOD : time := 1 ns; -- 1000MHz
  signal rst : std_logic := '1';
  signal clk : std_logic := '1';
  signal finish : std_logic := '0';

  constant RESOLUTION : integer := 16;
  constant FIFO_DEPTH : integer := 16;

  signal level : integer range 0 to FIFO_DEPTH; -- FIFO fill level
  signal wr_ack        : std_logic := '0';
  signal wr_ena        : std_logic := '1';
  signal wr_din        : cplx(re(RESOLUTION-1 downto 0),im(RESOLUTION-1 downto 0));
  signal wr_full       : std_logic; -- FIFO full
  signal wr_prog_full  : std_logic; -- FIFO prog full
  signal wr_overflow   : std_logic; -- FIFO overflow (wr_ena=1 and wr_full=1)
  signal rd_req_ack    : std_logic := '0';
  signal rd_dout       : cplx(re(RESOLUTION-1 downto 0),im(RESOLUTION-1 downto 0));
  signal rd_empty      : std_logic; -- FIFO empty
  signal rd_prog_empty : std_logic; -- FIFO prog empty
  signal rd_underflow  : std_logic; -- FIFO underflow (rd_req_ack=1 and rd_empty=1)

  -- GTKWAVE debug
  signal wr_din_rst  : std_logic;
  signal wr_din_vld  : std_logic;
  signal wr_din_ovf  : std_logic;
  signal wr_din_re   : signed(RESOLUTION-1 downto 0);
  signal wr_din_im   : signed(RESOLUTION-1 downto 0);
  signal rd_dout_rst : std_logic;
  signal rd_dout_vld : std_logic;
  signal rd_dout_ovf : std_logic;
  signal rd_dout_re  : signed(RESOLUTION-1 downto 0);
  signal rd_dout_im  : signed(RESOLUTION-1 downto 0);

begin

  -- GTKWAVE debug
  wr_din_rst  <= wr_din.rst;
  wr_din_vld  <= wr_din.vld;
  wr_din_ovf  <= wr_din.ovf;
  wr_din_re   <= wr_din.re;
  wr_din_im   <= wr_din.im;
  rd_dout_rst <= rd_dout.rst;
  rd_dout_vld <= rd_dout.vld;
  rd_dout_ovf <= rd_dout.ovf;
  rd_dout_re  <= rd_dout.re;
  rd_dout_im  <= rd_dout.im;


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
  rst <= '0' after 3*PERIOD;

  finish <= '1' after 500 ns;
  
  p_start : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        rd_req_ack <= '0';
      else
        rd_req_ack <= not rd_req_ack;
      end if;
    end if;
  end process;

  i_noise : entity cplxlib.cplx_noise_uniform
  generic map (
    RESOLUTION => RESOLUTION,
    ACKNOWLEDGE_MODE => false,
    INSTANCE_IDX => open
  )
  port map (
    clk        => clk, -- clock
    rst        => rst, -- synchronous reset
    req_ack    => wr_ack, 
    dout       => wr_din,
    PIPESTAGES => open
  );

  wr_ack <= not wr_prog_full;

  i_fifo_sync : entity cplxlib.cplx_fifo_sync
  generic map (
    FIFO_DEPTH => FIFO_DEPTH,
    USE_BLOCK_RAM => false,
    ACKNOWLEDGE_MODE => false,
    PROG_FULL_THRESHOLD => FIFO_DEPTH/2,
    PROG_EMPTY_THRESHOLD => 0
  )
  port map (
    clock         => clk, -- clock
    reset         => rst, -- synchronous reset
    level         => level,
    -- write port
    wr_ena        => wr_ena, 
    wr_din        => wr_din, 
    wr_full       => wr_full, 
    wr_prog_full  => wr_prog_full, 
    wr_overflow   => wr_overflow, 
    -- read port
    rd_req_ack    => rd_req_ack, 
    rd_dout       => rd_dout, 
    rd_empty      => rd_empty, 
    rd_prog_empty => rd_prog_empty, 
    rd_underflow  => rd_underflow 
  );

end architecture;
