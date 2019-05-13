-------------------------------------------------------------------------------
--! @file       fifo_async.behave.vhdl
--! @author     Fixitfetish
--! @date       07/May/2016
--! @version    1.00
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

--! @brief The behavioral model shall only be used in simulations.
--! THIS IS ONLY A NON-WORKING FIRST DRAFT VERSION !!!
--! 
--! For synthesis please use a FPGA specific implementation which is typically
--! more efficient in terms of resources and timing.
--!
architecture behave of fifo_async is

  type ram_type is array (1 to FIFO_DEPTH) of std_logic_vector(FIFO_WIDTH-1 downto 0);
  signal fifo : ram_type := (others=>(others=>'0'));
  signal async_rst : std_logic; -- asynchronous reset (read and write port) 
  
  -- write clock
  signal wr_rst : std_logic; -- write port synchronous reset 
  signal wr_pointer : integer range 1 to FIFO_DEPTH;
  signal wr_level : integer range 0 to FIFO_DEPTH;
  signal wr_read : std_logic;
  signal full : std_logic;
  signal fifo_wr : std_logic;

  -- read clock
  signal rd_rst : std_logic; -- read port synchronous reset 
  signal rd_pointer : integer range 1 to FIFO_DEPTH;
  signal rd_level : integer range 0 to FIFO_DEPTH;
  signal rd_write : std_logic;
  signal empty : std_logic;
  signal fifo_rd : std_logic;

begin

  -- reset
  g_arst : if USE_ASYNC_RESET generate
    async_rst <= reset;
    wr_rst <= '0';
    rd_rst <= '0';
  end generate;
  g_srst : if not USE_ASYNC_RESET generate
    signal wr_srst : std_logic_vector(1 to 2);
    signal rd_srst : std_logic_vector(1 to 2);
  begin
    async_rst <= '0';
    -- synchronizer chain for write port reset
    process(wr_clk) begin if rising_edge(wr_clk) then
      wr_srst(1)<=reset; wr_srst(2)<=wr_srst(1); wr_rst<=wr_srst(2); 
    end if; end process; 
    -- synchronizer chain for read port reset
    process(rd_clk) begin if rising_edge(rd_clk) then
      rd_srst(1)<=reset; rd_srst(2)<=rd_srst(1); rd_rst<=rd_srst(2); 
    end if; end process; 
  end generate;

  full <= '1' when (wr_level=FIFO_DEPTH) else '0';
  
  p_write : process(wr_clk, async_rst)
  begin
    if async_rst='1' then
      wr_pointer <= 1; 
      wr_level <= 0;
      fifo_wr <= '0';
      fifo <= (others=>(others=>'0'));
    elsif rising_edge(wr_clk) then
      fifo_wr <= '0'; -- by default no FIFO write
      if wr_rst='1' then
        wr_pointer <= 1; 
        wr_level <= 0;
        fifo <= (others=>(others=>'0'));
      else
        if wr_ena='1' and (full='0' or wr_read='1') then
          -- write to FIFO
          fifo_wr <= '1';
          fifo(wr_pointer) <= wr_din;
          if wr_pointer=FIFO_DEPTH then 
            wr_pointer <= 1; -- cyclic RAM wrap-around
          else
            wr_pointer <= wr_pointer + 1;
          end if;
          -- increase write level only when not read in same cycle
          if wr_read='0' then 
            wr_level <= wr_level + 1;
          end if; 
        elsif wr_ena='0' and wr_read='1' then
          -- just read
          wr_level <= wr_level - 1;
        end if;
      end if;
      -- synchronizer
      wr_read <= fifo_rd;
    end if;  
  end process;

  wr_full <= full;
  wr_alm_full <= '0' when (ALMOST_FULL_THRESHOLD=0) else
                 '1' when (wr_level>=ALMOST_FULL_THRESHOLD) else '0';
  wr_overflow <= full and wr_ena;
  
  ----------------------------------------------------------
  
  empty <= '1' when (rd_level=0) else '0';
 
  p_read : process(rd_clk, async_rst)
  begin
    if async_rst='1' then
      rd_pointer <= 1; 
      rd_level <= 0;
      fifo_rd <= '0';
    elsif rising_edge(rd_clk) then
      rd_rst <= wr_rst; -- synchronizer
      fifo_rd <= '0'; -- by default no FIFO read
      if rd_rst='1' then
        rd_pointer <= 1; 
        rd_level <= 0;
      else
      end if;  
      -- synchronizer
      rd_rst <= wr_rst;
      rd_write <= fifo_wr;
    end if;  
  end process;

  rd_empty <= empty;
  rd_alm_empty <= '0' when (ALMOST_EMPTY_THRESHOLD=0) else
                  '1' when (rd_level<=ALMOST_EMPTY_THRESHOLD) else '0';
  rd_underflow <= empty and rd_req_ack;
  
end architecture;
