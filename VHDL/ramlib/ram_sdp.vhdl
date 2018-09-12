-------------------------------------------------------------------------------
--! @file       ram_sdp.vhdl
--! @author     Fixitfetish
--! @date       12/Sep/2018
--! @version    0.20
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
    --! RAM data width
    DATA_WIDTH     : positive;
    --! Write port input pipeline registers (at least one required!)
    WR_INPUT_REGS  : positive := 1;
    --! Read port input pipeline registers (at least one required!)
    RD_INPUT_REGS  : positive := 1;
    --! Read port output pipeline registers
    RD_OUTPUT_REGS : natural := 1
  );
  port(
    --! Write port clock
    wr_clk     : in  std_logic;
    --! Write port clock reset. Resets all input pipeline registers.
    wr_rst     : in  std_logic;
    --! Write port clock enable
    wr_clk_en  : in  std_logic := '1';
    --! Write port enable
    wr_en      : in  std_logic := '0';
    --! Write port address
    wr_addr    : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    --! Write port data
    wr_data    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    --! Read port clock
    rd_clk     : in  std_logic;
    --! Read port clock reset. Resets all input and output pipeline registers.
    rd_rst     : in  std_logic;
    --! Read port clock enable
    rd_clk_en  : in  std_logic := '1';
    --! Read port (address) enable
    rd_en      : in  std_logic := '0';
    --! Read port address
    rd_addr    : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    --! Read port data
    rd_data    : out std_logic_vector(DATA_WIDTH-1 downto 0);
    --! Read port data enable
    rd_data_en : out std_logic
  );
end entity;
