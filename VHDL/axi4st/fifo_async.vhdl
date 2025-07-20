-------------------------------------------------------------------------------
-- @file       fifo_async.vhdl
-- @author     Fixitfetish
-- @note       VHDL-2008
-- @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library ramlib;

-- Generic asynchronous AXI4 Streaming FIFO which can be used as buffer and for clock domain crossings.
entity fifo_async is
  generic(
    -- FIFO depth in number of data words, only power of two allowed (mandatory!)
    FIFO_DEPTH  : positive;
    -- The FIFO PROG_FULL signal on master side might be useful non non-axi interface adaption.
    PROG_FULL_THRESHOLD : positive := FIFO_DEPTH/2;
    -- The FIFO PROG_EMPTY signal on slave side might be useful non non-axi interface adaption.
    PROG_EMPTY_THRESHOLD : positive := FIFO_DEPTH/2;
    -- RAM type for synthesis ("auto", "block", "dist")
    RAM_TYPE    : string  := "block"
  );
  port(
    -- Master Clock
    s_clk        : in  std_logic;
    -- Master Clock synchronous reset, preferably do not connect and use pipelined s_stream.treset instead!
    s_rst        : in  std_logic := '0';
    -- input stream from master
    s_stream     : in  work.pkg.axi4_s;
    -- ready signal towards master
    s_tready     : out std_logic;
    -- optional FIFO_PROG_FULL signal might be useful for non-axi interface adaption
    s_prog_full  : out std_logic;
    -- current FIFO fill level seen from master side
    s_level      : out integer range 0 to 2*FIFO_DEPTH - 1;
    -- Slave Clock
    m_clk        : in  std_logic;
    -- Slave Clock synchronous reset, preferably do not connect and use pipelined s_stream.treset instead!
    m_rst        : in  std_logic := '0';
    -- output stream towards slave
    m_stream     : out work.pkg.axi4_s;
    -- ready signal from slave
    m_tready     : in  std_logic;
    -- optional FIFO_PROG_EMTPY signal might be useful for non-axi interface adaption
    m_prog_empty : out std_logic;
    -- current FIFO fill level seen from slave side
    m_level      : out integer range 0 to 2*FIFO_DEPTH - 1
  );
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (m_stream.tdata'length=s_stream.tdata'length)
    report fifo_async'INSTANCE_NAME & " Input and output data must have the same width."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;

-------------------------------------------------------------------------------

architecture rtl of fifo_async is

  constant DATA_LENGTH : positive := work.pkg.length(s_stream);
  signal s_data : std_logic_vector(0 to DATA_LENGTH-1);
  signal m_data : std_logic_vector(0 to DATA_LENGTH-1);
  signal m_valid : std_logic;

  signal wr_ena : std_logic;
  signal rd_empty : std_logic;
  signal rd_ack : std_logic;
  signal fifo_wr_full : std_logic;
  signal rd_rst_busy : std_logic;
  signal m_reset : std_logic_vector(2 downto 0) := (others=>'1'); -- initially hold reset

begin

  s_tready <= not fifo_wr_full;
  wr_ena <= s_stream.tvalid and not fifo_wr_full;
  s_data <= work.pkg.to_slv(s_stream);

  fifo : entity ramlib.fifo_async
    generic map(
      FIFO_WIDTH           => DATA_LENGTH,
      FIFO_DEPTH           => FIFO_DEPTH,
      RAM_TYPE             => RAM_TYPE,
      ACKNOWLEDGE_MODE     => true,
      PROG_FULL_THRESHOLD  => PROG_FULL_THRESHOLD, -- useful for non-axi interface adaption
      PROG_EMPTY_THRESHOLD => PROG_EMPTY_THRESHOLD, -- useful for non-axi interface adaption
      READ_LATENCY         => 0, -- irrelevant because of acknowledge (FWFT) mode
      FULL_RESET_VALUE     => '1' -- show full during reset, hence FIFO is not ready to receive data from AXI master
    )
    port map(
      wr_rst        => s_stream.treset or s_rst,
      wr_clk        => s_clk, 
      wr_level      => s_level,
      wr_ena        => wr_ena,
      wr_din        => s_data, -- TODO: what if valid is part of data
      wr_full       => fifo_wr_full,
      wr_prog_full  => s_prog_full,
      wr_overflow   => open, -- cannot occur
      rd_rst        => m_rst,
      rd_rst_busy   => rd_rst_busy,
      rd_clk        => m_clk, 
      rd_level      => m_level,
      rd_req_ack    => rd_ack,
      rd_dout       => m_data,
      rd_valid      => open, -- use instead of rd_empty?
      rd_empty      => rd_empty,
      rd_prog_empty => m_prog_empty,
      rd_underflow  => open -- cannot occur
    );

  m_valid <= not rd_empty;
  rd_ack <= m_tready and m_valid;

  -- initially hold reset for a few cycles (especially relevant for simulation)
  m_reset <= m_reset(m_reset'high-1 downto 0) & rd_rst_busy when rising_edge(m_clk);

  process(all)
    variable stream : s_stream'subtype;
  begin
    stream := work.pkg.to_record(m_data, stream);
    stream.tvalid := m_valid; -- overwrite valid
    stream.treset := (or m_reset); -- overwrite reset
    m_stream <= stream; -- map to output
  end process;

end architecture;
