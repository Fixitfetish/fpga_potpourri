-------------------------------------------------------------------------------
--! @file       fifo_read_valid_last_logic.vhdl
--! @author     Fixitfetish
--! @date       30/Oct/2018
--! @version    0.10
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

--! @brief Additional FIFO read port logic to generate data valid and last signal.
--!
--! TODO : Acknowledge Mode
--!
entity fifo_read_valid_last_logic is
generic (
  --! FIFO delay from read request to data output
  FIFO_DELAY : positive
);
port (
  --! Synchronous reset
  rst        : in  std_logic;
  --! Clock 
  clk        : in  std_logic;
  --! Clock enable (optional)
  clk_ena    : in  std_logic := '1';
  --! Read data enable
  rd_ena     : in  std_logic;
  --! FIFO empty
  rd_empty   : in  std_logic;
  --! Data valid
  data_vld   : out std_logic;
  --! Last data from FIFO
  data_last  : out std_logic
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of fifo_read_valid_last_logic is

  signal valid : std_logic_vector(0 to FIFO_DELAY);
  signal empty : std_logic_vector(0 to FIFO_DELAY);

begin

  valid(0) <= rd_ena and (not rd_empty);
  empty(0) <= rd_empty;

  p_pipe : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        valid(1 to FIFO_DELAY) <= (others=>'0');
        empty(1 to FIFO_DELAY) <= (others=>'1');
      elsif clk_ena='1' then
        valid(1 to FIFO_DELAY) <= valid(0 to FIFO_DELAY-1);
        empty(1 to FIFO_DELAY) <= empty(0 to FIFO_DELAY-1);
      end if;
    end if;
  end process;

  data_vld <= valid(FIFO_DELAY);
  
  data_last <= empty(FIFO_DELAY-1) and (not empty(FIFO_DELAY));
  
end architecture;
