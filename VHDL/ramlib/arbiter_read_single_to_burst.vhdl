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

  -----------------------
  -- Completion FIFO/RAM
  -----------------------

  type r_cpl_fifo is
  record
    rst          : std_logic;
    wr_ena       : std_logic;
    wr_ptr       : unsigned(FIFO_DEPTH_LOG2-1 downto 0);
    wr_full      : std_logic;
    wr_overflow  : std_logic;
    rd_ena       : std_logic;
    rd_ptr       : unsigned(FIFO_DEPTH_LOG2-1 downto 0);
    rd_empty     : std_logic;
    rd_underflow : std_logic;
    level        : unsigned(FIFO_DEPTH_LOG2 downto 0);
  end record;
  type a_cpl_fifo is array(integer range <>) of r_cpl_fifo;
  signal cpl_fifo : a_cpl_fifo(0 to NUM_PORTS-1);

  -- Data width of the completion FIFO/RAM (data + EOF flag)
  constant CPL_RAM_DATA_WIDTH : positive := DATA_WIDTH + 1;

  -- Address width of the completion FIFO/RAM
  constant CPL_RAM_ADDR_WIDTH : positive := FIFO_SEL_WIDTH + FIFO_DEPTH_LOG2;

  -- CPL RAM read delay can be adjusted if another RAM/FIFO with more pipeline stages is used.
  constant CPL_RAM_READ_DELAY : natural := 2;

  type r_cpl_ram is
  record
    addr     : unsigned(CPL_RAM_ADDR_WIDTH-1 downto 0);
    addr_vld : std_logic;
    data     : std_logic_vector(CPL_RAM_DATA_WIDTH-1 downto 0);
    data_vld : std_logic;
  end record;
  signal cpl_ram_wr : r_cpl_ram;
  signal cpl_ram_rd : r_cpl_ram;

  type a_cpl_ram_rd_ena is array(integer range <>) of std_logic_vector(NUM_PORTS-1 downto 0);
  signal cpl_ram_rd_ena : a_cpl_ram_rd_ena(0 to CPL_RAM_READ_DELAY);


  function get_next(pending:std_logic_vector) return std_logic_vector is
    variable res : std_logic_vector(NUM_PORTS-1 downto 0);
  begin
    res := (others=>'0');
    -- lowest index = highest priority
    for n in pending'low to pending'high loop
      if pending(n)='1' then
        res(n):='1'; return res;
      end if;
    end loop;
    return res;
  end function;

  function get_next(pending:std_logic_vector) return unsigned is
    variable sel : unsigned(FIFO_SEL_WIDTH-1 downto 0);
  begin
    sel := (others=>'0');
    -- lowest index = highest priority
    for n in pending'low to pending'high loop
      if pending(n)='1' then
        sel := to_unsigned(n-pending'low,sel'length); return sel;
      end if;
    end loop;
    return sel;
  end function;


  -- GTKWave work-around
  signal seq_fifo_level : integer;
  signal cpl_ram_wr_addr     : unsigned(CPL_RAM_ADDR_WIDTH-1 downto 0);
  signal cpl_ram_wr_addr_vld : std_logic;
  signal cpl_ram_wr_data     : std_logic_vector(CPL_RAM_DATA_WIDTH-1 downto 0);
  signal cpl_ram_wr_data_vld : std_logic;
  signal cpl_ram_rd_addr     : unsigned(CPL_RAM_ADDR_WIDTH-1 downto 0);
  signal cpl_ram_rd_addr_vld : std_logic;
  signal cpl_ram_rd_data     : std_logic_vector(CPL_RAM_DATA_WIDTH-1 downto 0);
  signal cpl_ram_rd_data_vld : std_logic;

begin

  -- GTKWave work-around
  seq_fifo_level <= seq_fifo.level;
  cpl_ram_wr_addr     <= cpl_ram_wr.addr;
  cpl_ram_wr_addr_vld <= cpl_ram_wr.addr_vld;
  cpl_ram_wr_data     <= cpl_ram_wr.data;
  cpl_ram_wr_data_vld <= cpl_ram_wr.data_vld;
  cpl_ram_rd_addr     <= cpl_ram_rd.addr;
  cpl_ram_rd_addr_vld <= cpl_ram_rd.addr_vld;
  cpl_ram_rd_data     <= cpl_ram_rd.data;
  cpl_ram_rd_data_vld <= cpl_ram_rd.data_vld;

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

  p_cpl : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        cpl_ram_wr.addr_vld <= '0';
        cpl_ram_wr.data_vld <= '0';
        cpl_ram_wr.addr <= (others=>'-');
        cpl_ram_wr.data <= (others=>'-');
      else
        cpl_ram_wr.addr_vld <= bus_out_cpl_data_vld;
        cpl_ram_wr.data_vld <= bus_out_cpl_data_vld;
        cpl_ram_wr.addr(CPL_RAM_ADDR_WIDTH-1 downto FIFO_DEPTH_LOG2) <= seq_fifo_cpl_id;
        cpl_ram_wr.addr(FIFO_DEPTH_LOG2-1 downto 0) <= cpl_fifo(to_integer(seq_fifo_cpl_id)).wr_ptr;
        cpl_ram_wr.data <= seq_fifo_cpl_eof & bus_out_cpl_data;
      end if; --reset
    end if; --clock
  end process;

  g_cpl_fifo : for n in 0 to (NUM_PORTS-1) generate
  begin

    -- reset FIFO 
    cpl_fifo(n).rst <= rst; -- TODO also after frame when FIFO is empty
    cpl_fifo(n).wr_ena <= bus_out_cpl_data_vld when seq_fifo_cpl_id=n else '0'; 
    
    i_logic : entity ramlib.fifo_logic_sync
    generic map(
      FIFO_DEPTH => 2**FIFO_DEPTH_LOG2,
      PROG_FULL_THRESHOLD => 0,
      PROG_EMPTY_THRESHOLD => 0
    )
    port map(
      clk           => clk,
      rst           => cpl_fifo(n).rst,
      wr_ena        => cpl_fifo(n).wr_ena,
      wr_ptr        => cpl_fifo(n).wr_ptr,
      wr_full       => cpl_fifo(n).wr_full,
      wr_prog_full  => open,
      wr_overflow   => cpl_fifo(n).wr_overflow,
      rd_ena        => cpl_fifo(n).rd_ena,
      rd_ptr        => cpl_fifo(n).rd_ptr,
      rd_empty      => cpl_fifo(n).rd_empty,
      rd_prog_empty => open,
      rd_underflow  => cpl_fifo(n).rd_underflow,
      level         => cpl_fifo(n).level
    );

    usr_in_cpl_fifo_ovfl(n) <= cpl_fifo(n).wr_overflow;
    usr_in_cpl_rdy(n) <= not cpl_fifo(n).rd_empty;
    cpl_fifo(n).rd_ena <= usr_out_cpl_ack(n);

  end generate;

  i_cpl_ram : entity ramlib.ram_sdp
  generic map(
    ADDR_WIDTH => CPL_RAM_ADDR_WIDTH,
    DATA_WIDTH => CPL_RAM_DATA_WIDTH,
    RD_OUTPUT_REGS => 1
  )
  port map(
    clk        => clk,
    rst        => rst,
    wr_clk_en  => '1',
    wr_addr_en => cpl_ram_wr.addr_vld,
    wr_addr    => std_logic_vector(cpl_ram_wr.addr),
    wr_data    => cpl_ram_wr.data,
    rd_clk_en  => '1',
    rd_addr_en => cpl_ram_rd.addr_vld,
    rd_addr    => std_logic_vector(cpl_ram_rd.addr),
    rd_data    => cpl_ram_rd.data,
    rd_data_en => cpl_ram_rd.data_vld
  );


  p_output_arbiter : process(clk)
    type a_rd_ptr is array(integer range <>) of unsigned(FIFO_DEPTH_LOG2-1 downto 0);
    variable v_cpl_rd_ptr : a_rd_ptr(NUM_PORTS-1 downto 0) := (others=>(others=>'-'));
    variable v_cpl_ack : std_logic_vector(NUM_PORTS-1 downto 0);
    variable v_cpl_rd_pending : std_logic_vector(NUM_PORTS-1 downto 0);
    variable v_cpl_rd_pending_new : std_logic_vector(NUM_PORTS-1 downto 0);
    variable v_cpl_rd_ena : std_logic_vector(NUM_PORTS-1 downto 0);
    variable v_cpl_rd_id : unsigned(FIFO_SEL_WIDTH-1 downto 0);
  begin
    if rising_edge(clk) then

      for n in 0 to (NUM_PORTS-1) loop
        v_cpl_ack(n) := usr_out_cpl_ack(n); -- TODO allow only when frame active
        if usr_out_cpl_ack(n)='1' then
          v_cpl_rd_ptr(n) := cpl_fifo(n).rd_ptr;
        end if;  
      end loop;

      v_cpl_rd_pending_new := v_cpl_ack or v_cpl_rd_pending;
      v_cpl_rd_ena := get_next(v_cpl_rd_pending_new);
      v_cpl_rd_id := get_next(v_cpl_rd_pending_new);

      if rst='1' then
        cpl_ram_rd.addr_vld <= '0';
        cpl_ram_rd.addr <= (others=>'-');

        usr_in_cpl_ack_ovfl <= (others=>'0');
        v_cpl_rd_pending := (others=>'0');

      else
        cpl_ram_rd.addr_vld <= slv_or(v_cpl_rd_ena);
        cpl_ram_rd.addr(CPL_RAM_ADDR_WIDTH-1 downto FIFO_DEPTH_LOG2) <= v_cpl_rd_id;
        cpl_ram_rd.addr(FIFO_DEPTH_LOG2-1 downto 0) <= v_cpl_rd_ptr(to_integer(v_cpl_rd_id));

        -- handling of pending bits and overflow errors
        usr_in_cpl_ack_ovfl <= v_cpl_rd_pending and v_cpl_ack;
        v_cpl_rd_pending := v_cpl_rd_pending_new and (not v_cpl_rd_ena);

      end if; 

      -- compensate CPL RAM delay
      cpl_ram_rd_ena(0) <= v_cpl_rd_ena;
      for n in 1 to CPL_RAM_READ_DELAY loop
        cpl_ram_rd_ena(n) <= cpl_ram_rd_ena(n-1);
      end loop;

    end if; --clock
  end process;

  -- all users directly connect to CPL RAM data output register
  usr_in_cpl_data <= cpl_ram_rd.data(usr_in_cpl_data'length-1 downto 0); -- without EOF flag!

  -- one data valid per user, only one user per cycle
  usr_in_cpl_data_vld <= cpl_ram_rd_ena(CPL_RAM_READ_DELAY);
  
  -- completion data end of frame (EOF)
  g_cpl_eof : for n in 0 to NUM_PORTS-1 generate 
    usr_in_cpl_data_eof(n) <= cpl_ram_rd_ena(CPL_RAM_READ_DELAY)(n) and cpl_ram_rd.data(cpl_ram_rd.data'high);
  end generate;

end architecture;
