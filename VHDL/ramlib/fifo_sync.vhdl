-------------------------------------------------------------------------------
--! @file       fifo_sync.vhdl
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

--! @brief Synchronous FIFO that supports request mode and acknowledge mode.
--!
--! * REQUEST MODE = If the FIFO is not empty then data can be requested and
--!   appears at the data output port one cycle after the request. 
--! * ACKNOWLEDGE MODE = If the FIFO is not empty then valid data is present at
--!   the data output port and must be acknowledged before the next data is passed
--!   to the output. This mode is also known First-Word-Fall-Through (FWFT).

entity fifo_sync is
generic (
  --! Data width in bits (mandatory!)
  FIFO_WIDTH : positive;
  --! FIFO depth in number of data words (mandatory!)
  FIFO_DEPTH : positive;
  --! true=use vendor specific block ram type, false=don't use block ram but logic
  USE_BLOCK_RAM : boolean := false;
  --! false=read request, true=read acknowledge (fall-through, show-ahead)
  ACKNOWLEDGE_MODE : boolean := false;
  --! 0(unused) < almost full threshold < FIFO_DEPTH
  ALMOST_FULL_THRESHOLD : natural := 0;
  --! 0(unused) < almost empty threshold < FIFO_DEPTH
  ALMOST_EMPTY_THRESHOLD : natural := 0
);
port (
  --! Clock for read and write port
  clock        : in  std_logic;
  --! Synchronous reset
  reset        : in  std_logic;
  --! FIFO fill level
  level        : out integer range 0 to FIFO_DEPTH;
  --! Write data enable
  wr_ena       : in  std_logic;
  --! Write data input
  wr_din       : in  std_logic_vector(FIFO_WIDTH-1 downto 0);
  --! FIFO full
  wr_full      : out std_logic;
  --! FIFO almost full
  wr_alm_full  : out std_logic;
  --! FIFO overflow (wr_ena=1 and wr_full=1)
  wr_overflow  : out std_logic;
  --! Read request/acknowledge
  rd_req_ack   : in  std_logic;
  --! Read data output
  rd_dout      : out std_logic_vector(FIFO_WIDTH-1 downto 0);
  --! FIFO empty
  rd_empty     : out std_logic;
  --! FIFO almost empty
  rd_alm_empty : out std_logic;
  --! FIFO underflow (rd_req_ack=1 and rd_empty=1)
  rd_underflow : out std_logic
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  ASSERT ALMOST_FULL_THRESHOLD<FIFO_DEPTH
    REPORT "Almost full threshold must be smaller than FIFO depth."
    SEVERITY Error;
  ASSERT ALMOST_EMPTY_THRESHOLD<FIFO_DEPTH
    REPORT "Almost empty threshold must be smaller than FIFO depth."
    SEVERITY Error;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;
