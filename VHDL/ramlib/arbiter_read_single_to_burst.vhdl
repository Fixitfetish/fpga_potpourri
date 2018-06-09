-------------------------------------------------------------------------------
--! @file       arbiter_read_single_to_burst.vhdl
--! @author     Fixitfetish
--! @date       07/Jun/2018
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
library baselib;
  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;
library ramlib;

--! @brief Arbiter that transforms single read requests from multiple input ports
--! to read request bursts.
--!
--! This arbiter has a definable number of input ports and one output port.
--! The output port provides sequential bursts of data words for each input port.
--! The burst size is configurable but the same for all.
--! 
--! * Completion read data must be returned in same order as requested.
--! 
--!
--! @image html arbiter_read_single_to_burst.svg "" width=500px
--!


--! NOTES: 
--! * Input port 0 has the highest priority and input port NUM_PORTS-1 has the lowest priority.
--! * The data width of each input port, the output port and the RAM is DATA_WIDTH.
--! * The overall used RAM depth is NUM_PORTS x 2^FIFO_DEPTH_LOG2 .
--! * If only one input port is open/active then continuous streaming is possible.
--! * The arbiter intentionally excludes RAM address handling or similar to keep it more flexible. 
--! 
--! This arbiter is a slightly simplified version of a general arbiter that efficiently uses FPGA
--! RAM resources. Instead of having seperate independent FIFOs per input port a shared RAM
--! is used to hold the FIFOs of all input ports. Hence, FPGA memory blocks can be used more
--! efficiently when FIFOs with small depth but large data width are required.
--!
--! As a drawback the following limitations need to be considered
--! * This is a synchronous design. Input and output must run with the same clock.
--! * If N input ports are active only every Nth cycle can have valid data at each input port.
--!   For N>1 input data valid bursts of consecutive cycles are not allowed and cause input overflows.
--! * The overall input data valid rate (all ports) cannot exceed the maximum supported output rate.
--!   FIFO overflows will occur when the dout_rdy goes low for too long.
--!
--! USAGE:
--! * Setting din_frame(N)='1' opens the port N. The FIFO is reset and dout_frame(N)='1'. 
--! * Data can be written using the din(N) and din_vld(N) considering the limitations.
--!   If limitations are not considered din_ovf(N) or fifo_ovf(N) might be set.
--! * Bursts will be output as soon as BURST_SIZE+1 data words have been provided.
--! * Setting din_frame(N)='0' closes the port N. Input data is not accepted anymore and
--!   the FIFO is flushed. A final burst smaller than BURST_SIZE might be generated.
--! * FIFO flushing is completed when dout_frame(N)='0'. 

entity arbiter_read_single_to_burst is
generic(
  --! Number of user ports
  NUM_PORTS  : positive;
  --! Input, output and FIFO/RAM data width. 
  DATA_WIDTH : positive;
  --! Output burst length (minimum length is 2)
  BURST_SIZE : positive;
  --! @brief FIFO depth per input port. LOG2(depth) ensures that the depth is a power of 2.
  --! The depth must be at least double the burst size.
  --! (Example: if BURST_SIZE=7 then FIFO_DEPTH_LOG2>=4 is required)
  FIFO_DEPTH_LOG2 : positive;
  --! Maximum completion (RAM read) delay from bus_in_req to bus_out_cpl.
  MAX_CPL_DELAY : positive
);
port(
  --! System clock
  clk                     : in  std_logic;
  --! Synchronous reset
  rst                     : in  std_logic;
  --! Request frame, rising_edge opens a port, falling edge closes a port
  usr_out_req_frame       : in  std_logic_vector(NUM_PORTS-1 downto 0);
  --! Request enable, only considered when usr_out_req_frame='1'
  usr_out_req_ena         : in  std_logic_vector(NUM_PORTS-1 downto 0);
  --! @brief Request overflow.
  --! Occurs when overall usr_out_req_ena rate is too high and requests cannot be written into FIFO on-time.
  --! These output bits are NOT sticky, hence they could also be used as error IRQ source.
  usr_in_req_ovfl         : out std_logic_vector(NUM_PORTS-1 downto 0);
  --! @brief FIFO overflow (one per input port)
  --! Occurs when requests cannot be transmitted on the bus fast enough. 
  --! These output bits are NOT sticky, hence they could also be used as error IRQ source.
  usr_in_req_fifo_ovfl    : out std_logic_vector(NUM_PORTS-1 downto 0);

  --! User ready to accept read data
  usr_in_cpl_rdy          : out std_logic_vector(NUM_PORTS-1 downto 0);
  usr_out_cpl_ack         : in  std_logic_vector(NUM_PORTS-1 downto 0) := (others=>'1');
  usr_in_cpl_ack_ovfl     : out std_logic_vector(NUM_PORTS-1 downto 0);
  --! Read completiton data
  usr_in_cpl_data         : out std_logic_vector(DATA_WIDTH-1 downto 0);
  --! Read completiton data valid
  usr_in_cpl_data_vld     : out std_logic_vector(NUM_PORTS-1 downto 0);
  --! End/last data of frame
  usr_in_cpl_data_eof     : out std_logic_vector(NUM_PORTS-1 downto 0);
  --! @brief FIFO overflow (one per input port)
  --! These output bits are NOT sticky, hence they could also be used as error IRQ source.
  usr_in_cpl_fifo_ovfl    : out std_logic_vector(NUM_PORTS-1 downto 0);

  --! Bus is ready to accept requests, default is '1', set '0' to pause bus_in_req_ena
  bus_out_req_rdy         : in  std_logic := '1';
  --! Data output valid (one per input port)
  bus_in_req_ena          : out std_logic;
  --! Start of burst, first request of burst
  bus_in_req_sob          : out std_logic;
  --! End of burst, last request of burst
  bus_in_req_eob          : out std_logic;
  --! End of frame, last request of frame (current user ID)
  bus_in_req_eof          : out std_logic;
  --! User ID of corresponding user request port
  bus_in_req_usr_id       : out unsigned(log2ceil(NUM_PORTS)-1 downto 0);
  --! Data output frame (one bit per input port)
  bus_in_req_usr_frame    : out std_logic_vector(NUM_PORTS-1 downto 0);
  --! Write request data output, optional
  bus_in_req_data         : out std_logic_vector(DATA_WIDTH-1 downto 0) := (others=>'0');
  --! Write request data output valid, optional
  bus_in_req_data_vld     : out std_logic := '0';
  --! Completiton data input
  bus_out_cpl_data        : in  std_logic_vector(DATA_WIDTH-1 downto 0);
  --! Competition data input valid
  bus_out_cpl_data_vld    : in  std_logic
);
begin
  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (2*BURST_SIZE)<=(2**FIFO_DEPTH_LOG2)
    report "ERROR in " & arbiter_read_single_to_burst'INSTANCE_NAME & 
           " FIFO depth must be at least double the burst size."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)
end entity;

-------------------------------------------------------------------------------

architecture rtl of arbiter_read_single_to_burst is

  -- Width of FIFO/Port select signal
  constant FIFO_SEL_WIDTH : positive := log2ceil(NUM_PORTS);

  signal bus_in_req_ena_i    : std_logic;
  signal bus_in_req_eof_i    : std_logic;
  signal bus_in_req_usr_id_i : unsigned(log2ceil(NUM_PORTS)-1 downto 0);

  -----------------------
  -- Sequence FIFO
  -----------------------

  -- Data width of the request sequence FIFO (port index + EOF flag)
  constant SEQ_FIFO_WIDTH : positive := FIFO_SEL_WIDTH + 1;

  -- Depth of the request sequence FIFO
  constant SEQ_FIFO_DEPTH : positive := MAX_CPL_DELAY;

  type r_seq_fifo is
  record
    wr_ena       : std_logic;
    wr_data      : std_logic_vector(SEQ_FIFO_WIDTH-1 downto 0);
    wr_full      : std_logic;
    wr_overflow  : std_logic;
    rd_ack       : std_logic;
    rd_data      : std_logic_vector(SEQ_FIFO_WIDTH-1 downto 0);
    rd_empty     : std_logic;
    rd_underflow : std_logic;
    level        : integer;
  end record;
  signal seq_fifo : r_seq_fifo;
  signal seq_fifo_cpl_id : unsigned(FIFO_SEL_WIDTH-1 downto 0);
  signal seq_fifo_cpl_eof : std_logic;


  -- GTKWave work-around
  signal seq_fifo_level : integer;

begin

  -- GTKWave work-around
  seq_fifo_level <= seq_fifo.level;

  -----------------------------------------------------------------------------
  -- Request FIFO
  -----------------------------------------------------------------------------

  i_req : entity ramlib.arbiter_mux_stream_to_burst
  generic map(
    NUM_PORTS  => NUM_PORTS,
    DATA_WIDTH => DATA_WIDTH,
    BURST_SIZE => BURST_SIZE,
    FIFO_DEPTH_LOG2 => FIFO_DEPTH_LOG2,
    WRITE_ENABLE => false -- read only!
  )
  port map (
    clk                     => clk,
    rst                     => rst,
    usr_out_req_frame       => usr_out_req_frame,
    usr_out_req_ena         => usr_out_req_ena,
    usr_out_req_wr_data     => (others=>(others=>'0')), -- read only!
    usr_in_req_ovfl         => usr_in_req_ovfl,
    usr_in_req_fifo_ovfl    => usr_in_req_fifo_ovfl,
    bus_out_req_rdy         => bus_out_req_rdy,
    bus_in_req_ena          => bus_in_req_ena_i,
    bus_in_req_sob          => bus_in_req_sob,
    bus_in_req_eob          => bus_in_req_eob,
    bus_in_req_eof          => bus_in_req_eof_i,
    bus_in_req_usr_id       => bus_in_req_usr_id_i,
    bus_in_req_usr_frame    => bus_in_req_usr_frame,
    bus_in_req_data         => bus_in_req_data, -- read only!
    bus_in_req_data_vld     => bus_in_req_data_vld  -- read only!
  );

  bus_in_req_ena <= bus_in_req_ena_i;
  bus_in_req_eof <= bus_in_req_eof_i;
  bus_in_req_usr_id <= bus_in_req_usr_id_i;

  -----------------------------------------------------------------------------
  -- Sequence FIFO
  -----------------------------------------------------------------------------

  seq_fifo.wr_data(seq_fifo.wr_data'high) <= bus_in_req_eof_i;
  seq_fifo.wr_data(bus_in_req_usr_id_i'length-1 downto 0) <= std_logic_vector(bus_in_req_usr_id_i);
  seq_fifo.wr_ena <= bus_in_req_ena_i;

  i_seq_fifo : entity ramlib.fifo_sync
  generic map (
    FIFO_WIDTH => SEQ_FIFO_WIDTH,
    FIFO_DEPTH => SEQ_FIFO_DEPTH,
    USE_BLOCK_RAM => true,
    ACKNOWLEDGE_MODE => true,
    PROG_FULL_THRESHOLD => 0,
    PROG_EMPTY_THRESHOLD => 0
  )
  port map (
    clock         => clk, -- clock
    reset         => rst, -- synchronous reset
    level         => seq_fifo.level,
    -- write port
    wr_ena        => seq_fifo.wr_ena, 
    wr_din        => seq_fifo.wr_data, 
    wr_full       => seq_fifo.wr_full, 
    wr_prog_full  => open, 
    wr_overflow   => seq_fifo.wr_overflow, 
    -- read port
    rd_req_ack    => seq_fifo.rd_ack, 
    rd_dout       => seq_fifo.rd_data, 
    rd_empty      => seq_fifo.rd_empty, 
    rd_prog_empty => open, 
    rd_underflow  => seq_fifo.rd_underflow 
  );

  seq_fifo.rd_ack <= bus_out_cpl_data_vld;
  seq_fifo_cpl_id <= unsigned(seq_fifo.rd_data(seq_fifo_cpl_id'length-1 downto 0));
  seq_fifo_cpl_eof <= seq_fifo.rd_data(seq_fifo.rd_data'high);

  -----------------------------------------------------------------------------
  -- Completion FIFO
  -----------------------------------------------------------------------------

  i_cpl : entity ramlib.arbiter_demux_single_to_stream
  generic map(
    NUM_PORTS  => NUM_PORTS,
    DATA_WIDTH => DATA_WIDTH,
    FIFO_DEPTH_LOG2 => FIFO_DEPTH_LOG2
  )
  port map (
    clk                     => clk,
    rst                     => rst,
    bus_out_cpl_eof         => seq_fifo_cpl_eof, 
    bus_out_cpl_usr_id      => seq_fifo_cpl_id, 
    bus_out_cpl_data        => bus_out_cpl_data, 
    bus_out_cpl_data_vld    => bus_out_cpl_data_vld, 
    usr_in_cpl_rdy          => usr_in_cpl_rdy, 
    usr_out_cpl_ack         => usr_out_cpl_ack, 
    usr_in_cpl_ack_ovfl     => usr_in_cpl_ack_ovfl, 
    usr_in_cpl_data         => usr_in_cpl_data, 
    usr_in_cpl_data_vld     => usr_in_cpl_data_vld, 
    usr_in_cpl_data_eof     => usr_in_cpl_data_eof, 
    usr_in_cpl_fifo_ovfl    => usr_in_cpl_fifo_ovfl
  );

end architecture;
