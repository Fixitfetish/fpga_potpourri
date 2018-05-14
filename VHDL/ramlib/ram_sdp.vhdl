-------------------------------------------------------------------------------
--! @file       ram_sdp.vhdl
--! @author     Fixitfetish
--! @date       14/May/2016
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

--! @brief Simple Dual Port RAM 

entity ram_sdp is
  generic(
    ADDR_WIDTH     : positive;
    DATA_WIDTH     : positive;
    RD_OUTPUT_REGS : natural range 0 to 1 := 1
  );
  port(
    clk        : in  std_logic;
    rst        : in  std_logic;
    wr_clk_en  : in  std_logic := '1';
    wr_addr_en : in  std_logic;
    wr_addr    : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    wr_data    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    rd_clk_en  : in  std_logic := '1';
    rd_addr_en : in  std_logic;
    rd_addr    : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    rd_data    : out std_logic_vector(DATA_WIDTH-1 downto 0);
    rd_data_en : out std_logic
  );
end entity;
