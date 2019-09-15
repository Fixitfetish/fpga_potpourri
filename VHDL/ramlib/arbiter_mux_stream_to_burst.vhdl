-------------------------------------------------------------------------------
--! @file       arbiter_mux_stream_to_burst.vhdl
--! @author     Fixitfetish
--! @date       15/Sep/2019
--! @version    0.96
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

--! @brief Arbiter that transforms single write requests from multiple input ports
--! to write request bursts at the single output port.
--!
--! This arbiter has a definable number of input ports and one output port.
--! The output port provides sequential bursts of data words for each input port.
--! The burst size is configurable but the same for all.
--! 
--! NOTES: 
--! * Input port 0 has the highest priority and input port NUM_PORTS-1 has the lowest priority.
--! * The data width of each input port, the output port and the RAM is DATA_WIDTH.
--! * The overall used RAM depth is NUM_PORTS x 2^FIFO_DEPTH_LOG2 .
--! * If only one input port is open/active then continuous streaming is possible.
--! * The arbiter intentionally excludes RAM address handling or similar to keep it more flexible.
--!   Address handling can be implemented easily on top of this arbiter. 
--! 
--! This arbiter is a slightly simplified version of a general arbiter that efficiently uses FPGA
--! RAM resources. Instead of having separate independent FIFOs per input port a shared RAM
--! is used to hold the FIFOs of all input ports. Hence, FPGA memory blocks can be used more
--! efficiently when FIFOs with small depth but large data width are required.
--!
--! As a drawback the following limitations need to be considered
--! * This is a synchronous design. Input and output must run with the same clock.
--! * If N input ports are active only every Nth cycle can have valid data at each input port.
--!   For N>1 input data valid bursts of consecutive cycles are not allowed and cause input overflows.
--! * The overall input data valid rate (all ports) cannot exceed the maximum supported output rate.
--!   FIFO overflows will occur when the bus_out_req_rdy goes low for too long.
--!
--! Signal Prefix Naming (also useful for record mapping):
--! * usr_out : user output port, signals that the user generate (e.g. requests)
--! * usr_in : user input port, signals that the user receives (e.g. status)
--! * bus_out : bus output port, signals that are originated by the bus (e.g. status or answers)
--! * bus_in : bus input port, signals that feed the bus (e.g. write/read requests)
--!
--! USAGE:
--! * Setting usr_out_req_frame(N)='1' opens the port N. The FIFO is reset and bus_in_req_usr_frame(N)='1'. 
--! * Data can be written using the usr_out_req_wr_data(N) and usr_out_req_ena(N) considering the limitations.
--!   If limitations are not considered usr_in_req_ovfl(N) or usr_in_req_fifo_ovfl(N) might flag errors.
--! * Bursts will be output as soon as BURST_SIZE+1 data words have been provided.
--! * Setting usr_out_req_frame(N)='0' closes the port N. Input data is not accepted anymore and
--!   the FIFO is flushed. A final burst smaller than BURST_SIZE might be generated.
--! * FIFO flushing is completed when bus_in_req_usr_frame(N)='0'. 
--!
--! Further ideas for future development
--! * do different priority modes like e.g. round-robin or first-come-first-serve make sense?
--!     
--! @image html arbiter_mux_stream_to_burst.svg "" width=500px
--!
entity arbiter_mux_stream_to_burst is
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
  --! @brief Write request enable. If disabled then usr_out_req_wr_data is ignored and
  --! only read requests without data are allowed.
  --! If enabled then usr_out_req_wr_data is stored in the FIFO and more RAM resources are needed.
  WRITE_ENABLE : boolean := true;
  --! RAM primitive type ("block" or "ultra")
  RAM_TYPE : string := "block";
  --! @brief Add an idle gap of a few cycles after each burst, e.g. to allow header insertion in front of each burst.
  --! Note that additional gap cycles reduce the maximum possible arbiter throughput.
  POST_BURST_GAP_CYCLES : integer range 0 to 3 := 0
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
--  usr_out_req_wr_data     : in  slv_array(0 to NUM_PORTS-1)(DATA_WIDTH-1 downto 0);
  usr_out_req_wr_data     : in  slv32_array(0 to NUM_PORTS-1);
  --! @brief Request overflow.
  --! Occurs when overall usr_out_req_ena rate is too high and requests cannot be written into FIFO on-time.
  --! These output bits are NOT sticky, hence they could also be used as error IRQ source.
  usr_in_req_ovfl         : out std_logic_vector(NUM_PORTS-1 downto 0);
  --! FIFO is ready to accept input data. User must stop writing to FIFO when ready flag is '0'.
  usr_in_req_fifo_rdy     : out std_logic_vector(NUM_PORTS-1 downto 0);
  --! @brief FIFO overflow (one per input port)
  --! Occurs when requests cannot be transmitted on the bus fast enough. 
  --! These output bits are NOT sticky, hence they could also be used as error IRQ source.
  usr_in_req_fifo_ovfl    : out std_logic_vector(NUM_PORTS-1 downto 0);
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
  --! User ID of corresponding user request port (0 .. NUM_PORTS-1). Width must be at least 2 bits.
  bus_in_req_usr_id       : out unsigned;
  --! Data output frame (one bit per input port)
  bus_in_req_usr_frame    : out std_logic_vector(NUM_PORTS-1 downto 0);
  --! Write request data output, optional
  bus_in_req_data         : out std_logic_vector(DATA_WIDTH-1 downto 0) := (others=>'0');
  --! Write request data output valid, optional
  bus_in_req_data_vld     : out std_logic := '0'
);
begin
  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (2*BURST_SIZE)<=(2**FIFO_DEPTH_LOG2)
    report "ERROR in " & arbiter_mux_stream_to_burst'INSTANCE_NAME & 
           " FIFO depth must be at least double the burst size."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)
end entity;

-------------------------------------------------------------------------------

architecture shared_ram of arbiter_mux_stream_to_burst is

  -- Width of FIFO/Port select signal
  constant FIFO_SEL_WIDTH : positive := log2ceil(NUM_PORTS);

  function REQ_RAM_INPUT_REGS return natural is
    variable res : natural := 0; -- no RAM required/implemented => no extra pipeline registers
  begin
    if WRITE_ENABLE then
      if RAM_TYPE="ultra" then 
        res := 2; -- Xilinx Ultra-RAM
      else
        res := 1; -- standard Block-RAM
      end if;
    end if;
    return res;
  end function;

  function REQ_RAM_OUTPUT_REGS return natural is
    variable res : natural := 0; -- no RAM required/implemented => no extra pipeline registers
  begin
    if WRITE_ENABLE then
      if RAM_TYPE="ultra" then 
        res := 2; -- Xilinx Ultra-RAM
      else
        res := 1; -- standard Block-RAM
      end if;
    end if;
    return res;
  end function;

  -- RAM read delay can be adjusted if another RAM/FIFO with more pipeline stages is used.
  -- Note that the RAM is only implemented when write request support is needed.
  constant REQ_RAM_READ_DELAY : natural := REQ_RAM_INPUT_REGS + REQ_RAM_OUTPUT_REGS;

  constant REQ_RAM_ADDR_WIDTH : positive := FIFO_SEL_WIDTH + FIFO_DEPTH_LOG2;
  constant REQ_RAM_DATA_WIDTH : positive := DATA_WIDTH;

  -- input arbiter
  type r_arbiter is
  record
    request      : std_logic_vector(NUM_PORTS-1 downto 0);
    request_ovfl : std_logic_vector(NUM_PORTS-1 downto 0);
    pending      : std_logic_vector(NUM_PORTS-1 downto 0);
    grant        : std_logic_vector(NUM_PORTS-1 downto 0);
    grant_idx    : integer range 0 to NUM_PORTS-1;
    grant_vld    : std_logic;
  end record;
  signal arb_usr : r_arbiter;
  signal arb_burst : r_arbiter;
  signal arb_flush : r_arbiter;

  -- user port
  type r_usr_out is
  record
    frame : std_logic; -- frame input
    sof   : std_logic; -- start of frame
    eof   : std_logic; -- end of frame
    ena   : std_logic; -- request enable
    data  : std_logic_vector(DATA_WIDTH-1 downto 0);
  end record;
  constant DEFAULT_USR_OUT : r_usr_out := (
    frame => '0',
    sof   => '0',
    eof   => '0',
    ena   => '0',
    data  => (others=>'-')
  );
  type a_usr_out is array(integer range <>) of r_usr_out;
  signal usr_out : a_usr_out(0 to NUM_PORTS-1);

  signal usr_out_sel : unsigned(FIFO_SEL_WIDTH-1 downto 0);

  type t_req_fifo is
  record
    rst          : std_logic;
    wr_ena       : std_logic;
    wr_ptr       : unsigned(FIFO_DEPTH_LOG2-1 downto 0);
    wr_full      : std_logic;
    wr_prog_full : std_logic;
    wr_overflow  : std_logic;
    rd_ena       : std_logic;
    rd_ptr       : unsigned(FIFO_DEPTH_LOG2-1 downto 0);
    rd_empty     : std_logic;
    rd_prog_empty: std_logic;
    rd_data_vld  : std_logic;
    rd_data_last : std_logic;
    level        : unsigned(FIFO_DEPTH_LOG2 downto 0);
    active       : std_logic; -- FIFO active
    flush_trig   : std_logic; -- flush triggered
    flushing     : std_logic; -- flushing active
  end record;
  type a_req_fifo is array(integer range <>) of t_req_fifo;
  signal req_fifo : a_req_fifo(0 to NUM_PORTS-1);

  -- request FIFO read
  type t_rd is
  record
    frame : std_logic_vector(NUM_PORTS-1 downto 0);
    ena   : std_logic_vector(NUM_PORTS-1 downto 0);
    sel   : unsigned(FIFO_SEL_WIDTH-1 downto 0);
    sob   : std_logic; -- start/first of burst
    eob   : std_logic; -- end/last of burst
    eof   : std_logic; -- end/last of frame
  end record;
  type a_rd is array(integer range <>) of t_rd;
  signal rd : a_rd(0 to REQ_RAM_READ_DELAY);

  -- burst cycle counter
  signal burst_cnt : unsigned(FIFO_DEPTH_LOG2 downto 0);

  -- gap cycle counter
  signal gap_cnt : unsigned(1 downto 0) := (others=>'-');

  type t_state is (
    WAITING, -- wait until next burst is available
    BURST,   -- burst transmission is active
    GAP      -- gap insertion after burst
  );
  signal state : t_state;


  type t_req_ram is
  record
    addr : unsigned(REQ_RAM_ADDR_WIDTH-1 downto 0);
    addr_vld : std_logic;
    data : std_logic_vector(DATA_WIDTH-1 downto 0);
    data_vld : std_logic;
  end record;
  signal req_ram_wr : t_req_ram;
  signal req_ram_rd : t_req_ram;
  signal req_ram_wr_addr : std_logic_vector(REQ_RAM_ADDR_WIDTH-1 downto 0); -- GHDL work-around
  signal req_ram_rd_addr : std_logic_vector(REQ_RAM_ADDR_WIDTH-1 downto 0); -- GHDL work-around
  
  -- GTKWave work-around
  signal level0 : unsigned(FIFO_DEPTH_LOG2 downto 0);
  signal level1 : unsigned(FIFO_DEPTH_LOG2 downto 0);
  signal level2 : unsigned(FIFO_DEPTH_LOG2 downto 0);
  signal level3 : unsigned(FIFO_DEPTH_LOG2 downto 0);
  signal ptr0 : unsigned(FIFO_DEPTH_LOG2-1 downto 0);
  signal ptr1 : unsigned(FIFO_DEPTH_LOG2-1 downto 0);
  signal ptr2 : unsigned(FIFO_DEPTH_LOG2-1 downto 0);
  signal ptr3 : unsigned(FIFO_DEPTH_LOG2-1 downto 0);
  signal fifo_active : std_logic_vector(NUM_PORTS-1 downto 0);
  signal fifo_empty : std_logic_vector(NUM_PORTS-1 downto 0);
  signal fifo_rd_data_vld : std_logic_vector(NUM_PORTS-1 downto 0);
  signal fifo_rd_data_last : std_logic_vector(NUM_PORTS-1 downto 0);
  signal fifo_full : std_logic_vector(NUM_PORTS-1 downto 0);
  signal fifo_filled : std_logic_vector(NUM_PORTS-1 downto 0);
  signal fifo_flush_triggered : std_logic_vector(NUM_PORTS-1 downto 0);
  signal fifo_flush : std_logic_vector(NUM_PORTS-1 downto 0);
  signal wr_frame : std_logic_vector(NUM_PORTS-1 downto 0);
  signal wr_sof : std_logic_vector(NUM_PORTS-1 downto 0);
  signal wr_eof : std_logic_vector(NUM_PORTS-1 downto 0);
  signal wr_ena : std_logic_vector(NUM_PORTS-1 downto 0);
  signal wr_addr : unsigned(REQ_RAM_ADDR_WIDTH-1 downto 0);
  signal wr_sel : unsigned(FIFO_SEL_WIDTH-1 downto 0);
  signal wr_addr_vld : std_logic;
  signal wr_data : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal rd_ena : std_logic_vector(NUM_PORTS-1 downto 0);
  signal rd_addr : unsigned(REQ_RAM_ADDR_WIDTH-1 downto 0);
  signal rd_addr_vld : std_logic;
  signal rd_sob : std_logic;
  signal rd_eob : std_logic;
  signal rd_eof : std_logic;
  signal rd_sel : unsigned(FIFO_SEL_WIDTH-1 downto 0);
  signal rd_data_en : std_logic;
  signal rd_data : std_logic_vector(DATA_WIDTH-1 downto 0);
  
  signal request : std_logic_vector(NUM_PORTS-1 downto 0) := (others=>'0');
  signal request_ovfl : std_logic_vector(request'range);
  signal pending : std_logic_vector(request'range);
  signal grant : std_logic_vector(request'range);
  signal grant_idx : integer;
  signal grant_vld : std_logic;

begin

  -- GTKWave work-around
  level0 <= req_fifo(0).level;
  level1 <= req_fifo(1).level;
  level2 <= req_fifo(2).level;
  level3 <= req_fifo(3).level;
  ptr0 <= req_fifo(0).wr_ptr;
  ptr1 <= req_fifo(1).wr_ptr;
  ptr2 <= req_fifo(2).wr_ptr;
  ptr3 <= req_fifo(3).wr_ptr;
  g_gtkwave : for n in 0 to (NUM_PORTS-1) generate
    fifo_active(n) <= req_fifo(n).active;
    fifo_empty(n) <= req_fifo(n).rd_empty;
    fifo_rd_data_vld(n) <= req_fifo(n).rd_data_vld;
    fifo_rd_data_last(n) <= req_fifo(n).rd_data_last;
    fifo_full(n) <= req_fifo(n).wr_full;
    fifo_filled(n) <= not req_fifo(n).rd_prog_empty;
    fifo_flush_triggered(n) <= req_fifo(n).flush_trig;
    fifo_flush(n) <= req_fifo(n).flushing;
    wr_ena(n) <= usr_out(n).ena;
    wr_frame(n) <= usr_out(n).frame;
    wr_sof(n) <= usr_out(n).sof;
    wr_eof(n) <= usr_out(n).eof;
  end generate;
  wr_sel <= usr_out_sel;
  wr_addr <= req_ram_wr.addr;
  wr_addr_vld <= req_ram_wr.addr_vld;
  wr_data <= req_ram_wr.data;

  rd_ena <= rd(0).ena;
  rd_sel <= rd(0).sel;
  rd_sob <= rd(0).sob;
  rd_eob <= rd(0).eob;
  rd_eof <= rd(0).eof;

  rd_addr <= req_ram_rd.addr;
  rd_addr_vld <= req_ram_rd.addr_vld;
  rd_data <= req_ram_rd.data;
  rd_data_en <= req_ram_rd.data_vld;

  request <= arb_usr.request;
  request_ovfl <= arb_usr.request_ovfl;
  pending <= arb_usr.pending;
  grant <= arb_usr.grant;
  grant_idx <= arb_usr.grant_idx;
  grant_vld <= arb_usr.grant_vld;


  -- input arbiter
  arb_usr.request <= usr_out_req_ena and usr_out_req_frame;

  i_arbiter : entity ramlib.arbiter(prio)
  generic map(
    RIGHTMOST_REQUEST_FIRST => true,
    REQUEST_PULSE => true,
    OUTPUT_REG => false
  )
  port map(
    clk              => clk,
    rst              => rst,
    clk_ena          => '1',
    request          => arb_usr.request,
    request_ovfl     => arb_usr.request_ovfl,
    pending          => arb_usr.pending,
    grant            => arb_usr.grant,
    grant_idx        => arb_usr.grant_idx,
    grant_vld        => arb_usr.grant_vld
  );

  p_input_arbiter : process(clk)
    variable v_usr_out_frame_q : std_logic_vector(NUM_PORTS-1 downto 0);
  begin
    if rising_edge(clk) then
      if rst='1' then
        usr_in_req_ovfl <= (others=>'0');
        usr_out_sel <= (others=>'0');
        usr_out <= (others=>DEFAULT_USR_OUT);
        v_usr_out_frame_q := (others=>'0');
      else
        for n in 0 to (NUM_PORTS-1) loop
          usr_out(n).frame <= arb_usr.request(n) or arb_usr.pending(n) or usr_out_req_frame(n);
          usr_out(n).sof <= usr_out_req_frame(n) and (not usr_out(n).frame); -- rising edge
          usr_out(n).eof <= v_usr_out_frame_q(n) and (not usr_out(n).frame); -- falling edge
          usr_out(n).ena <= arb_usr.grant(n);
          if arb_usr.request(n)='1' then
            usr_out(n).data <= usr_out_req_wr_data(n); 
          end if;
          v_usr_out_frame_q(n) := usr_out(n).frame; -- for edge detection
        end loop;
        -- index of granted request
        usr_out_sel <= to_unsigned(arb_usr.grant_idx,usr_out_sel'length);
        -- handling of overflow errors
        usr_in_req_ovfl <= arb_usr.request_ovfl;
      end if; --reset 
    end if; --clock
  end process;

  -- For the (read) request FIFO only the level logic is needed to count the requests.
  -- Since the user does not provide any data write/read pointers and a FIFO/RAM are not required. 
  g_req_fifo : for n in 0 to (NUM_PORTS-1) generate
  begin

    -- reset FIFO also when flushing is completed 
    req_fifo(n).rst <= rst or (req_fifo(n).flushing and req_fifo(n).rd_empty);
    
    req_fifo(n).wr_ena <= usr_out(n).ena;
    
--    i_logic : entity ramlib.fifo_logic_sync
--    generic map(
--      FIFO_DEPTH => 2**FIFO_DEPTH_LOG2,
--      PROG_FULL_THRESHOLD => 2**FIFO_DEPTH_LOG2-2, -- TODO : some margin to give user time to react 
--      PROG_EMPTY_THRESHOLD => BURST_SIZE -- ensures that at least one element remains for final flushing
--    )
--    port map(
--      clk           => clk,
--      rst           => req_fifo(n).rst,
--      wr_ena        => req_fifo(n).wr_ena,
--      wr_ptr        => req_fifo(n).wr_ptr,
--      wr_full       => req_fifo(n).wr_full,
--      wr_prog_full  => req_fifo(n).wr_prog_full,
--      wr_overflow   => req_fifo(n).wr_overflow,
--      rd_ena        => req_fifo(n).rd_ena,
--      rd_ptr        => req_fifo(n).rd_ptr,
--      rd_empty      => req_fifo(n).rd_empty,
--      rd_prog_empty => req_fifo(n).rd_prog_empty,
--      rd_underflow  => open,
--      level         => req_fifo(n).level
--    );
--
    i_logic : entity ramlib.fifo_logic_sync2
    generic map(
      MAX_FIFO_DEPTH_LOG2 => FIFO_DEPTH_LOG2,
      FULL_RESET_VALUE => '0'
    )
    port map(
      clk                      => clk,
      rst                      => req_fifo(n).rst,
      cfg_fifo_depth_minus1    => to_unsigned(2**FIFO_DEPTH_LOG2-1, FIFO_DEPTH_LOG2),
      cfg_prog_full_threshold  => to_unsigned(2**FIFO_DEPTH_LOG2-2, FIFO_DEPTH_LOG2), -- TODO : some margin to give user time to react
      cfg_prog_empty_threshold => to_unsigned(BURST_SIZE, FIFO_DEPTH_LOG2), -- ensures that at least one element remains for final flushing
      wr_ena                   => req_fifo(n).wr_ena,
      wr_ptr                   => req_fifo(n).wr_ptr,
      wr_full                  => req_fifo(n).wr_full,
      wr_prog_full             => req_fifo(n).wr_prog_full,
      wr_overflow              => req_fifo(n).wr_overflow,
      rd_ena                   => req_fifo(n).rd_ena,
      rd_ptr                   => req_fifo(n).rd_ptr,
      rd_empty                 => req_fifo(n).rd_empty,
      rd_prog_empty            => req_fifo(n).rd_prog_empty,
      rd_underflow             => open,
      level                    => req_fifo(n).level
    );

    i_last : entity ramlib.fifo_read_valid_last_logic
    generic map(
      FIFO_DELAY => REQ_RAM_READ_DELAY
    )
    port map(
      rst        => rst,
      clk        => clk,
      clk_ena    => '1',
      rd_ena     => req_fifo(n).rd_ena,
      rd_empty   => req_fifo(n).rd_empty,
      data_vld   => req_fifo(n).rd_data_vld,
      data_last  => req_fifo(n).rd_data_last
    );

    req_fifo(n).rd_ena <= rd(0).ena(n);
    usr_in_req_fifo_ovfl(n) <= req_fifo(n).wr_overflow;
    usr_in_req_fifo_rdy(n) <= not req_fifo(n).wr_prog_full;

    p_flush : process(clk)
    begin
      if rising_edge(clk) then
        if req_fifo(n).rst='1' then
          req_fifo(n).active <= '0';
          req_fifo(n).flush_trig <= '0';
          req_fifo(n).flushing <= '0';
        else
          -- FIFO becomes active with rising edge of frame signal
          req_fifo(n).active <= req_fifo(n).active or usr_out(n).sof;
          -- FIFO flush is triggered with falling edge of frame signal but only when the FIFO is already active
          req_fifo(n).flush_trig <= req_fifo(n).flush_trig or (req_fifo(n).active and usr_out(n).eof);
          -- FIFO flushing starts after the trigger when no more full bursts are are active or pending
          req_fifo(n).flushing <= req_fifo(n).flushing or
                                 (req_fifo(n).flush_trig and req_fifo(n).rd_prog_empty and (not req_fifo(n).rd_ena));
        end if; --reset
      end if; --clock
    end process;

    arb_burst.request(n) <= not req_fifo(n).rd_prog_empty;

    -- Full pending bursts have priority before flush.
    -- In case of a flush the FIFO filling stopped already and overflows can't occur anymore.
    -- Flushing starts after one idle cycle to ensure a stable FIFO level.  
    arb_flush.request(n) <= '0' when unsigned(rd(0).ena)/=0 else
                            req_fifo(n).flushing and (not req_fifo(n).rd_empty);

  end generate;

  i_burst_grant : entity ramlib.arbiter(prio)
  generic map(
    RIGHTMOST_REQUEST_FIRST => true,
    REQUEST_PULSE => false,
    OUTPUT_REG => false
  )
  port map(
    clk              => clk,
    rst              => rst,
    clk_ena          => '1',
    request          => arb_burst.request,
    request_ovfl     => arb_burst.request_ovfl,
    pending          => arb_burst.pending,
    grant            => arb_burst.grant,
    grant_idx        => arb_burst.grant_idx,
    grant_vld        => arb_burst.grant_vld
  );

  i_flush_grant : entity ramlib.arbiter(prio)
  generic map(
    RIGHTMOST_REQUEST_FIRST => true,
    REQUEST_PULSE => false,
    OUTPUT_REG => false
  )
  port map(
    clk              => clk,
    rst              => rst,
    clk_ena          => '1',
    request          => arb_flush.request,
    request_ovfl     => arb_flush.request_ovfl,
    pending          => arb_flush.pending,
    grant            => arb_flush.grant,
    grant_idx        => arb_flush.grant_idx,
    grant_vld        => arb_flush.grant_vld
  );


  p_output : process(clk)
    variable v_burst_size : unsigned(FIFO_DEPTH_LOG2 downto 0);
  begin
    if rising_edge(clk) then

      for n in 0 to (NUM_PORTS-1) loop
        rd(0).frame(n) <= req_fifo(n).active;
      end loop;

      rd(0).sob <= '0'; -- default
      rd(0).eob <= '0'; -- default
      rd(0).eof <= '0'; -- default

      if rst='1' then
        rd(0).ena <= (others=>'0');
        rd(0).sel <= (others=>'0');
        burst_cnt <= (others=>'-');
        state <= WAITING;

      elsif bus_out_req_rdy='1' then
          
        case state is
          when WAITING =>
            burst_cnt <= (others=>'0');
            rd(0).ena <= (others=>'0');

            if arb_burst.grant_vld='1' then
              rd(0).sob <= '1';
              rd(0).sel <= to_unsigned(arb_burst.grant_idx,FIFO_SEL_WIDTH);
              rd(0).ena <= arb_burst.grant;
              burst_cnt <= to_unsigned(BURST_SIZE,burst_cnt'length);
              state <= BURST;
            elsif arb_flush.grant_vld='1' then
              rd(0).sob <= '1';
              rd(0).sel <= to_unsigned(arb_flush.grant_idx,FIFO_SEL_WIDTH);
              rd(0).ena <= arb_flush.grant;
              v_burst_size := req_fifo(arb_flush.grant_idx).level;
              burst_cnt <= v_burst_size;
              if v_burst_size=1 then
                rd(0).eob <= '1';
                rd(0).eof <= '1';
              else
                state <= BURST;
              end if;
            end if;

          when BURST =>
            rd(0).ena(to_integer(rd(0).sel)) <= '1';
            if burst_cnt=2 then 
              rd(0).eob <= '1';
              rd(0).eof <= req_fifo(to_integer(rd(0).sel)).flushing;
              if POST_BURST_GAP_CYCLES/=0 then
                gap_cnt <= to_unsigned(POST_BURST_GAP_CYCLES,gap_cnt'length);
                state <= GAP;
              else
                state <= WAITING; -- gap not needed
              end if;
            end if;
            burst_cnt <= burst_cnt - 1;

          when GAP =>
            rd(0).ena <= (others=>'0');
            if gap_cnt=1 then
              state <= WAITING;
            else
              gap_cnt <= gap_cnt - 1;
            end if;
        
        end case;  

      else
        rd(0).ena <= (others=>'0');
        
      end if; --reset 

      -- handle RAM read delay
      if REQ_RAM_READ_DELAY>=1 then
        for d in 1 to REQ_RAM_READ_DELAY loop
          rd(d) <= rd(d-1);
        end loop;
      end if;
      
    end if; --clock
  end process;

  g_write_true : if WRITE_ENABLE generate

    -- write port mux before RAM input register
    req_ram_wr.addr_vld <= usr_out(to_integer(usr_out_sel)).ena and (not req_fifo(to_integer(usr_out_sel)).wr_full);
    req_ram_wr.addr(REQ_RAM_ADDR_WIDTH-1 downto FIFO_DEPTH_LOG2) <= usr_out_sel;
    req_ram_wr.addr(FIFO_DEPTH_LOG2-1 downto 0) <= req_fifo(to_integer(usr_out_sel)).wr_ptr;
    req_ram_wr.data <= usr_out(to_integer(usr_out_sel)).data;
    req_ram_wr.data_vld <= req_ram_wr.addr_vld;

    -- read port mux before RAM input register
    req_ram_rd.addr_vld <= rd(0).ena(to_integer(rd(0).sel));
    req_ram_rd.addr(REQ_RAM_ADDR_WIDTH-1 downto FIFO_DEPTH_LOG2) <= rd(0).sel;
    req_ram_rd.addr(FIFO_DEPTH_LOG2-1 downto 0) <= req_fifo(to_integer(rd(0).sel)).rd_ptr;

    req_ram_wr_addr <= std_logic_vector(req_ram_wr.addr); -- GHDL work-around
    req_ram_rd_addr <= std_logic_vector(req_ram_rd.addr); -- GHDL work-around

    i_req_ram : entity ramlib.ram_sdp
    generic map(
      WR_DATA_WIDTH => REQ_RAM_DATA_WIDTH,
      RD_DATA_WIDTH => REQ_RAM_DATA_WIDTH,
      WR_DEPTH => 2**REQ_RAM_ADDR_WIDTH,
      WR_USE_BYTE_ENABLE => false,
      WR_INPUT_REGS => REQ_RAM_INPUT_REGS,
      RD_INPUT_REGS => REQ_RAM_INPUT_REGS,
      RD_OUTPUT_REGS => REQ_RAM_OUTPUT_REGS,
      RAM_TYPE => RAM_TYPE,
      INIT_FILE => open
    )
    port map(
      wr_clk     => clk,
      wr_rst     => rst,
      wr_clk_en  => '1',
      wr_en      => req_ram_wr.addr_vld,
  --    wr_addr    => std_logic_vector(req_ram_wr.addr),
      wr_addr    => req_ram_wr_addr, -- GHDL work-around
      wr_be      => open, -- unused
      wr_data    => req_ram_wr.data,
      rd_clk     => clk,
      rd_rst     => rst,
      rd_clk_en  => '1',
      rd_en      => req_ram_rd.addr_vld,
  --    rd_addr    => std_logic_vector(req_ram_rd.addr),
      rd_addr    => req_ram_rd_addr, -- GHDL work-around
      rd_data    => req_ram_rd.data,
      rd_data_en => req_ram_rd.data_vld
    );

    bus_in_req_data <= req_ram_rd.data;
    bus_in_req_data_vld <= req_ram_rd.data_vld;

  end generate;

  g_write_false : if not WRITE_ENABLE generate
    bus_in_req_data <= (others=>'0');
    bus_in_req_data_vld <= '0';
  end generate;

  -- map requests to bus 
  bus_in_req_ena <= rd(REQ_RAM_READ_DELAY).ena(to_integer(rd(REQ_RAM_READ_DELAY).sel));
  bus_in_req_sob <= rd(REQ_RAM_READ_DELAY).sob;
  bus_in_req_eob <= rd(REQ_RAM_READ_DELAY).eob;
  bus_in_req_eof <= rd(REQ_RAM_READ_DELAY).eof;
  bus_in_req_usr_id <= resize(rd(REQ_RAM_READ_DELAY).sel, bus_in_req_usr_id'length);
  bus_in_req_usr_frame <= rd(REQ_RAM_READ_DELAY).frame;

end architecture;

-------------------------------------------------------------------------------

--architecture fifo_sync of arbiter_mux_stream_to_burst is
--
--  -- Width of FIFO/Port select signal
--  constant FIFO_SEL_WIDTH : positive := log2ceil(NUM_PORTS);
--
--  signal sof : std_logic_vector(NUM_PORTS-1 downto 0);
--  signal eof : std_logic_vector(NUM_PORTS-1 downto 0);
--
--  type t_req_fifo is
--  record
--    rst          : std_logic;
--    wr_ena       : std_logic;
--    wr_din       : std_logic_vector(DATA_WIDTH-1 downto 0);
--    wr_full      : std_logic;
--    wr_prog_full : std_logic;
--    wr_overflow  : std_logic;
--    rd_ena       : std_logic;
--    rd_dout      : std_logic_vector(DATA_WIDTH-1 downto 0);
--    rd_empty     : std_logic;
--    rd_prog_empty: std_logic;
--    level        : unsigned(FIFO_DEPTH_LOG2 downto 0);
--    active       : std_logic; -- FIFO active
--    flush_trig   : std_logic; -- flush triggered
--    flushing     : std_logic; -- flushing active
--  end record;
--  type a_req_fifo is array(integer range <>) of t_req_fifo;
--  signal req_fifo : a_req_fifo(0 to NUM_PORTS-1);
--
--
--begin
--
--
--  g_req_fifo : for n in 0 to (NUM_PORTS-1) generate
--  begin
--
--    -- reset FIFO also when flushing is completed 
--    req_fifo(n).rst <= rst or (req_fifo(n).flushing and req_fifo(n).rd_empty);
--
--    req_fifo(n).wr_ena <= usr_out_req_ena(n) and usr_out_req_frame(n);
--    req_fifo(n).wr_din <= usr_out_req_wr_data(n);
--    
--    usr_in_req_ovfl <= (others=>'0'); -- request overflow can never occur, just FIFO overflow
--    usr_in_req_fifo_ovfl(n) <= req_fifo(n).wr_overflow;
--    usr_in_req_fifo_rdy(n) <= not req_fifo(n).wr_prog_full;
--
--    i_fifo : entity ramlib.fifo_sync
--    generic map(
--      FIFO_WIDTH => DATA_WIDTH,
--      FIFO_DEPTH => 2**FIFO_DEPTH_LOG2,
--      USE_BLOCK_RAM => true,
--      ACKNOWLEDGE_MODE => false,
--      PROG_FULL_THRESHOLD => 2**FIFO_DEPTH_LOG2-2, -- TODO : some margin to give user time to react 
--      PROG_EMPTY_THRESHOLD => BURST_SIZE -- ensures that at least one element remains for final flushing
--    )
--    port map(
--      clock         => clk,
--      reset         => req_fifo(n).rst,
--      wr_ena        => req_fifo(n).wr_ena,
--      wr_din        => req_fifo(n).wr_din,
--      wr_full       => req_fifo(n).wr_full,
--      wr_prog_full  => req_fifo(n).wr_prog_full,
--      wr_overflow   => req_fifo(n).wr_overflow,
--      rd_req_ack    => req_fifo(n).rd_ena,
--      rd_dout       => req_fifo(n).rd_dout,
--      rd_empty      => req_fifo(n).rd_empty,
--      rd_prog_empty => req_fifo(n).rd_prog_empty,
--      rd_underflow  => open
--    );
--
----    req_fifo(n).rd_ena <= rd(0).ena(n);
--
--    p_flush : process(clk)
--    begin
--      if rising_edge(clk) then
--        if req_fifo(n).rst='1' then
--          req_fifo(n).active <= '0';
--          req_fifo(n).flush_trig <= '0';
--          req_fifo(n).flushing <= '0';
--        else
--          -- FIFO becomes active with rising edge of frame signal
--          req_fifo(n).active <= req_fifo(n).active or sof(n);
--          -- FIFO flush is triggered with falling edge of frame signal but only when the FIFO is already active
--          req_fifo(n).flush_trig <= req_fifo(n).flush_trig or (req_fifo(n).active and eof(n));
--          -- FIFO flushing starts after the trigger when no more full bursts are are active or pending
--          req_fifo(n).flushing <= req_fifo(n).flushing or
--                                 (req_fifo(n).flush_trig and req_fifo(n).rd_prog_empty and (not req_fifo(n).rd_ena));
--        end if; --reset
--      end if; --clock
--    end process;
--
--  end generate;
--
--
--end architecture;
