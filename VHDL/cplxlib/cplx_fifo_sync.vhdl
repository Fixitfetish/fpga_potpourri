-------------------------------------------------------------------------------
--! @file       cplx_fifo_sync.vhdl
--! @author     Fixitfetish
--! @date       11/May/2019
--! @version    0.10
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library ramlib;
library cplxlib;
  use cplxlib.cplx_pkg.all;

--! @brief Synchronous FIFO that supports request mode and acknowledge mode.
--!
--! * REQUEST MODE = If the FIFO is not empty then data can be requested and
--!   appears at the data output port one cycle after the request. 
--! * ACKNOWLEDGE MODE = If the FIFO is not empty then valid data is present at
--!   the data output port and must be acknowledged before the next data is passed
--!   to the output. This mode is also known First-Word-Fall-Through (FWFT).
--! * WRITE FIFO : only when wr_din.vld='1' and wr_ena='1' .
--!   Optional wr_ena can be used as additional write (clock) enable.
--! 
--! VHDL Instantiation Template:
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
--! I1 : cplx_fifo_sync
--! generic map (
--!   FIFO_DEPTH           => positive, -- FIFO depth in number of data words
--!   USE_BLOCK_RAM        => boolean,  -- block ram or logic
--!   ACKNOWLEDGE_MODE     => boolean,  -- read request or acknowledge
--!   PROG_FULL_THRESHOLD  => natural,
--!   PROG_EMPTY_THRESHOLD => natural,
--!   MODE                 => cplx_mode -- options
--! )
--! port map (
--!   clock         => in  std_logic, -- clock
--!   reset         => in  std_logic, -- synchronous reset
--!   level         => out integer,
--!   wr_ena        => in  std_logic, 
--!   wr_din        => in  cplx, 
--!   wr_full       => out std_logic, 
--!   wr_prog_full  => out std_logic, 
--!   wr_overflow   => out std_logic, 
--!   rd_req_ack    => in  std_logic, 
--!   rd_dout       => out cplx, 
--!   rd_empty      => out std_logic, 
--!   rd_prog_empty => out std_logic, 
--!   rd_underflow  => out std_logic
--! );
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--!
entity cplx_fifo_sync is
generic (
  --! FIFO depth in number of data words (mandatory!)
  FIFO_DEPTH : positive;
  --! true=use vendor specific block ram type, false=don't use block ram but logic
  USE_BLOCK_RAM : boolean := false;
  --! false=read request, true=read acknowledge (fall-through, show-ahead)
  ACKNOWLEDGE_MODE : boolean := false;
   --! 0(unused) < prog full threshold < FIFO_DEPTH
  PROG_FULL_THRESHOLD : natural := FIFO_DEPTH/2;
  --! 0(unused) < prog empty threshold < FIFO_DEPTH
  PROG_EMPTY_THRESHOLD : natural := FIFO_DEPTH/2;
  --! Supported operation modes 'R' and 'X'
  MODE : cplx_mode := "-"
);
port (
  --! Clock for read and write port
  clock         : in  std_logic;
  --! Synchronous reset
  reset         : in  std_logic := '0';
  --! FIFO fill level
  level         : out integer range 0 to 2*FIFO_DEPTH-1;
  --! Write enable, optional, by default '1'
  wr_ena        : in  std_logic := '1';
  --! Write CPLX data input.
  wr_din        : in  cplx;
  --! FIFO full
  wr_full       : out std_logic;
  --! FIFO programmable full
  wr_prog_full  : out std_logic;
  --! FIFO overflow (wr_ena=1 and wr_full=1)
  wr_overflow   : out std_logic;
  --! Read request/acknowledge
  rd_req_ack    : in  std_logic;
  --! @brief Read CPLX data output.
  --! Includes the read valid flag rd_dout.vld which is the negated FIFO empty signal.
  rd_dout       : out cplx;
  --! FIFO empty
  rd_empty      : out std_logic;
  --! FIFO programmable empty
  rd_prog_empty : out std_logic;
  --! FIFO underflow (rd_req_ack=1 and rd_empty=1)
  rd_underflow  : out std_logic
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  ASSERT PROG_FULL_THRESHOLD<FIFO_DEPTH
    REPORT "Prog full threshold must be smaller than FIFO depth."
    SEVERITY Error;
  ASSERT PROG_EMPTY_THRESHOLD<FIFO_DEPTH
    REPORT "Prog empty threshold must be smaller than FIFO depth."
    SEVERITY Error;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;

-------------------------------------------------------------------------------

architecture rtl of cplx_fifo_sync is

  constant WRE : positive := wr_din.re'length;
  constant WIM : positive := wr_din.im'length;

  -- real / imaginary and optional overflow flag
  function FIFO_WIDTH return positive is
  begin
    if MODE='X' then return (WRE+WIM); else return (WRE+WIM+1); end if;
  end function;

  signal rst_i : std_logic;
  signal wr_ena_i : std_logic;

  signal wr_slv, rd_slv : std_logic_vector(FIFO_WIDTH-1 downto 0);
  signal rd_dout_i : cplx(re(WRE-1 downto 0),im(WIM-1 downto 0));
  signal rd_empty_i : std_logic;

begin

  rst_i <= reset or wr_din.rst;

  wr_ena_i <= wr_ena and wr_din.vld;

  wr_slv(WRE-1 downto 0) <= std_logic_vector(wr_din.re);
  wr_slv(WRE+WIM-1 downto WRE) <= std_logic_vector(wr_din.im);
  g_ovf_in : if MODE/='X' generate
    wr_slv(WRE+WIM) <= wr_din.ovf;
  end generate;

  --! Instantiation of FIFO
  i_fifo : entity ramlib.fifo_sync
    generic map(
      FIFO_WIDTH           => FIFO_WIDTH,
      FIFO_DEPTH           => FIFO_DEPTH,
      USE_BLOCK_RAM        => USE_BLOCK_RAM,
      ACKNOWLEDGE_MODE     => ACKNOWLEDGE_MODE,
      PROG_FULL_THRESHOLD  => PROG_FULL_THRESHOLD,
      PROG_EMPTY_THRESHOLD => PROG_EMPTY_THRESHOLD
    )
    port map(
      clock         => clock,
      reset         => rst_i,
      level         => level,
      wr_ena        => wr_ena_i,
      wr_din        => wr_slv,
      wr_full       => wr_full,
      wr_prog_full  => wr_prog_full,
      wr_overflow   => wr_overflow,
      rd_req_ack    => rd_req_ack,
      rd_dout       => rd_slv,
      rd_empty      => rd_empty_i,
      rd_prog_empty => rd_prog_empty,
      rd_underflow  => rd_underflow
    );

  rd_dout_i.rst <= rst_i;
  rd_dout_i.vld <= not rd_empty_i;
  rd_dout_i.re  <= signed(rd_slv(WRE-1 downto 0));
  rd_dout_i.im  <= signed(rd_slv(WRE+WIM-1 downto WRE));

  -- ignore/discard overflow flag
  g_ovf_out : if MODE='X' generate
    rd_dout_i.ovf <= '0';
  else generate
    rd_dout_i.ovf <= rd_slv(WRE+WIM);
  end generate;

  -- final output
  rd_empty <= rd_empty_i;
  rd_dout <= cplx_reset(rd_dout_i,MODE); 

end architecture;
