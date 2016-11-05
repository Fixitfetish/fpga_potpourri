-------------------------------------------------------------------------------
-- FILE    : fifo_sync.vhdl   
-- AUTHOR  : Fixitfetish
-- DATE    : 07/May/2016
-- VERSION : 1.0
-- VHDL    : 1993
-- LICENSE : MIT License
-------------------------------------------------------------------------------
-- Copyright (c) 2016 Fixitfetish
-- 
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
-- 
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
-- IN THE SOFTWARE.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

---------------------------------------------------------------------------------------------------
-- The synchronous FIFO supports two modes:
--   REQUEST MODE = If the FIFO is not empty data can be requested and appears at the data output
--     port one cycles after the request. 
--   ACKNOWLEDGE MODE = If the FIFO is not empty valid data is present at the data output port
--     and must be acknowledged before the next data is passed to the output. This mode is also
--     known First-Word-Fall-Through (FWFT).
---------------------------------------------------------------------------------------------------
entity fifo_sync is
generic (
  FIFO_WIDTH : positive; -- data width in bits (mandatory!)
  FIFO_DEPTH : positive; -- FIFO depth in number of data words (mandatory!)
  USE_BLOCK_RAM : boolean := false; -- true=use vendor specific block ram type, false=don't use block ram but logic
  ACKNOWLEDGE_MODE : boolean := false; -- false=read request, true=read acknowledge (fall-through, show-ahead)
  ALMOST_FULL_THRESHOLD : natural := 0; -- 0(unused) < almost full threshold < FIFO_DEPTH
  ALMOST_EMPTY_THRESHOLD : natural := 0  -- 0(unused) < almost empty threshold < FIFO_DEPTH
);
port (
  clock        : in  std_logic; -- read/write clock
  reset        : in  std_logic; -- synchrounous reset
  level        : out integer range 0 to FIFO_DEPTH; -- FIFO fill level
  -- write port
  wr_ena       : in  std_logic; -- write data enable
  wr_din       : in  std_logic_vector(FIFO_WIDTH-1 downto 0); -- write data input
  wr_full      : out std_logic; -- FIFO full
  wr_alm_full  : out std_logic; -- FIFO almost full
  wr_overflow  : out std_logic; -- FIFO overflow (wr_ena=1 and wr_full=1)
  -- read port
  rd_req_ack   : in  std_logic; -- read request/acknowledge
  rd_dout      : out std_logic_vector(FIFO_WIDTH-1 downto 0); -- read data output
  rd_empty     : out std_logic; -- FIFO empty
  rd_alm_empty : out std_logic; -- FIFO almost empty
  rd_underflow : out std_logic  -- FIFO underflow (rd_req_ack=1 and rd_empty=1)
);
begin
  ASSERT ALMOST_FULL_THRESHOLD<FIFO_DEPTH
    REPORT "Almost full threshold must be smaller than FIFO depth."
    SEVERITY Error;
  ASSERT ALMOST_EMPTY_THRESHOLD<FIFO_DEPTH
    REPORT "Almost empty threshold must be smaller than FIFO depth."
    SEVERITY Error;
end entity;
