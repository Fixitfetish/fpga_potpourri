-------------------------------------------------------------------------------
--! @file       fifo_sync.behave.vhdl
--! @author     Fixitfetish
--! @date       13/May/2019
--! @version    1.20
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
--! 
--! For synthesis please use a FPGA specific implementation which is typically
--! more efficient in terms of resources and timing.
--!
architecture behave of fifo_sync is

  -- FIFO
  type ramtype is array (1 to FIFO_DEPTH) of std_logic_vector(FIFO_WIDTH-1 downto 0);
  signal fifo : ramtype := (others=>(others=>'0'));
  signal fifo_dout : std_logic_vector(FIFO_WIDTH-1 downto 0);
  signal level_i : integer range 0 to FIFO_DEPTH;
  
  -- write
  signal wr_ptr : integer range 1 to FIFO_DEPTH; -- write pointer
  signal full : std_logic;
  signal fifo_wr : std_logic;

  -- read
  signal rd_ptr : integer range 1 to FIFO_DEPTH; -- read pointer
  signal empty : std_logic;
  signal fifo_rd : std_logic;

begin

  full <= '1' when (level_i=FIFO_DEPTH or reset='1') else '0';
  fifo_wr <= wr_ena and (not full);

  empty <= '1' when (level_i=0) else '0'; 
  fifo_rd <= rd_req_ack and (not empty);

  p_level : process(clock)
  begin
    if rising_edge(clock) then
      if reset='1' then
        level_i <= 0;
      else
        if fifo_wr='1' and fifo_rd='0' then 
          -- increase level only when not read in same cycle
          level_i <= level_i + 1;
        elsif fifo_wr='0' and fifo_rd='1' then 
          -- decrease level only when not written in same cycle
          level_i <= level_i - 1;
        end if; 
      end if;
    end if;  
  end process;

  level <= level_i;
  
  p_write : process(clock)
  begin
    if rising_edge(clock) then
      if reset='1' then
        wr_ptr <= 1; 
        fifo <= (others=>(others=>'0'));
      elsif fifo_wr='1' then
        -- write to FIFO
        fifo(wr_ptr) <= wr_din;
        if wr_ptr=FIFO_DEPTH then 
          wr_ptr <= 1; -- cyclic RAM wrap-around
        else
          wr_ptr <= wr_ptr + 1;
        end if;
      end if;
      -- overflow detection
      wr_overflow <= full and wr_ena;
    end if;  
  end process;

  wr_full <= FULL_RESET_VALUE when (reset='1') else full;
  wr_prog_full <= '0' when (PROG_FULL_THRESHOLD=0) else
                  '1' when (level_i>=PROG_FULL_THRESHOLD or reset='1') else '0';
  
  ----------------------------------------------------------
  
  p_read : process(clock)
  begin
    if rising_edge(clock) then
      if reset='1' then
        rd_ptr <= 1; 
      elsif fifo_rd='1' then
        -- read FIFO
        if rd_ptr=FIFO_DEPTH then 
          rd_ptr <= 1; -- cyclic RAM wrap-around
        else
          rd_ptr <= rd_ptr + 1;
        end if;
      end if;  
      -- underflow detection  
      rd_underflow <= empty and rd_req_ack;
    end if;
  end process;

  fifo_dout <= fifo(rd_ptr);

  rd_empty <= empty;
  rd_prog_empty <= '0' when (PROG_EMPTY_THRESHOLD=0) else
                   '1' when (level_i<=PROG_EMPTY_THRESHOLD) else '0';
  
  ----------------------------------------------------------
  
  g_ack : if ACKNOWLEDGE_MODE generate
    rd_dout <= fifo_dout;
  end generate;
  
  g_req : if not ACKNOWLEDGE_MODE generate
  begin
   p_out : process(clock)
   begin
     if rising_edge(clock) then
       if reset='1' then
         rd_dout <= (others=>'0'); 
       elsif fifo_rd='1' then
         rd_dout <= fifo_dout;
       end if;  
     end if;
   end process;
  end generate;
  
end architecture;
