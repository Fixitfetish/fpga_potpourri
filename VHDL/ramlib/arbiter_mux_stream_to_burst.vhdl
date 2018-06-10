-------------------------------------------------------------------------------
--! @file       arbiter_mux_stream_to_burst.vhdl
--! @author     Fixitfetish
--! @date       07/Jun/2018
--! @version    0.60
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
--! RAM resources. Instead of having seperate independent FIFOs per input port a shared RAM
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
--! * bus_out : bus output port, signals that are orginated by the bus (e.g. status or answers)
--! * bus_in : bus input port, signals that feed the bus (e.g. write/read requests)
--!
--! USAGE:
--! * Setting usr_out_req_frame(N)='1' opens the port N. The FIFO is reset and bus_in_req_usr_frame(N)='1'. 
--! * Data can be written using the usr_out_req_wr_data(N) and usr_out_req_ena(N) considering the limitations.
--!   If limitations are not considered usr_in_req_ovfl(N) or usr_in_req_fifo_ovfl(N) might be set.
--! * Bursts will be output as soon as BURST_SIZE+1 data words have been provided.
--! * Setting usr_out_req_frame(N)='0' closes the port N. Input data is not accepted anymore and
--!   the FIFO is flushed. A final burst smaller than BURST_SIZE might be generated.
--! * FIFO flushing is completed when bus_in_req_usr_frame(N)='0'. 
--!
--! Further ideas for future development
--! * Generic POST_BURST_GAP : add idle gap of X cycles after each burst,
--!   allow adding of a header infront of each burst.
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
  WRITE_ENABLE : boolean := true
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
--  din         : in  slv_array(0 to NUM_PORTS-1)(DATA_WIDTH-1 downto 0);
  usr_out_req_wr_data     : in  slv32_array(0 to NUM_PORTS-1);
  --! @brief Request overflow.
  --! Occurs when overall usr_out_req_ena rate is too high and requests cannot be written into FIFO on-time.
  --! These output bits are NOT sticky, hence they could also be used as error IRQ source.
  usr_in_req_ovfl         : out std_logic_vector(NUM_PORTS-1 downto 0);
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
  --! User ID of corresponding user request port
  bus_in_req_usr_id       : out unsigned(log2ceil(NUM_PORTS)-1 downto 0);
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

architecture rtl of arbiter_mux_stream_to_burst is

  -- Width of FIFO/Port select signal
  constant FIFO_SEL_WIDTH : positive := log2ceil(NUM_PORTS);

  -- RAM read delay can be adjusted if another RAM/FIFO with more pipeline stages is used.
  -- Note that the RAM is only implemented when write request support is needed.
  function REQ_RAM_READ_DELAY return natural is
  begin
    if WRITE_ENABLE then
      return 2; -- configure RAM delay here!
    else
      return 0; -- no RAM required => no extra delay
    end if;
  end function;
  
  constant REQ_RAM_ADDR_WIDTH : positive := FIFO_SEL_WIDTH + FIFO_DEPTH_LOG2;
  constant REQ_RAM_DATA_WIDTH : positive := DATA_WIDTH;

  signal din_pending : std_logic_vector(NUM_PORTS-1 downto 0);

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

--  type t_fifo_wr is
--  record
--    ena        : std_logic;
--    ptr        : unsigned(FIFO_DEPTH_LOG2-1 downto 0);
--    full       : std_logic;
--    prog_full  : std_logic;
--    overflow   : std_logic;
--  end record;
--  
--  type t_fifo_rd is
--  record
--    ena        : std_logic;
--    ptr        : unsigned(FIFO_DEPTH_LOG2-1 downto 0);
--    empty      : std_logic;
--    prog_empty : std_logic;
--    underflow  : std_logic;
--  end record;
  
  type t_req_fifo is
  record
    rst          : std_logic;
    wr_ena       : std_logic;
    wr_ptr       : unsigned(FIFO_DEPTH_LOG2-1 downto 0);
    wr_full      : std_logic;
    wr_overflow  : std_logic;
    rd_ena       : std_logic;
    rd_ptr       : unsigned(FIFO_DEPTH_LOG2-1 downto 0);
    rd_empty     : std_logic;
    rd_prog_empty: std_logic;
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

  signal burst_cnt : unsigned(FIFO_DEPTH_LOG2 downto 0);

  type t_state is (WAITING, BURST);
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

  type t_fifo_ptr is array(integer range <>) of unsigned(FIFO_DEPTH_LOG2-1 downto 0);

  
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


  p_input_arbiter : process(clk)
    variable v_din_vld : std_logic_vector(NUM_PORTS-1 downto 0);
    variable v_din_pending_new : std_logic_vector(NUM_PORTS-1 downto 0);
    variable v_din_ack : std_logic_vector(NUM_PORTS-1 downto 0);
    variable v_usr_out_frame_q : std_logic_vector(NUM_PORTS-1 downto 0);
  begin
    if rising_edge(clk) then

      v_din_vld := usr_out_req_ena and usr_out_req_frame;
      v_din_pending_new := v_din_vld or din_pending;
      v_din_ack := get_next(v_din_pending_new);

      if rst='1' then
        din_pending <= (others=>'0');
        usr_in_req_ovfl <= (others=>'0');
        usr_out_sel <= (others=>'0');
        usr_out <= (others=>DEFAULT_USR_OUT);
        v_usr_out_frame_q := (others=>'0');

      else

        for n in 0 to (NUM_PORTS-1) loop
          usr_out(n).frame <= v_din_pending_new(n) or usr_out_req_frame(n);
          usr_out(n).sof <= usr_out_req_frame(n) and (not usr_out(n).frame); -- rising edge
          usr_out(n).eof <= v_usr_out_frame_q(n) and (not usr_out(n).frame); -- falling edge
          usr_out(n).ena <= v_din_ack(n);
          if v_din_vld(n)='1' then
            usr_out(n).data <= usr_out_req_wr_data(n); 
          end if;
          
          v_usr_out_frame_q(n) := usr_out(n).frame; -- for edge detection
        end loop;

        usr_out_sel <= get_next(v_din_pending_new);

        -- handling of pending bits and overflow errors
        din_pending <= v_din_pending_new and (not v_din_ack);
        usr_in_req_ovfl <= din_pending and v_din_vld;

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
    
    i_logic : entity ramlib.fifo_logic_sync
    generic map(
      FIFO_DEPTH => 2**FIFO_DEPTH_LOG2,
      PROG_FULL_THRESHOLD => 0,
      PROG_EMPTY_THRESHOLD => BURST_SIZE -- ensures that at least one element remains for final flushing
    )
    port map(
      clk           => clk,
      rst           => req_fifo(n).rst,
      wr_ena        => req_fifo(n).wr_ena,
      wr_ptr        => req_fifo(n).wr_ptr,
      wr_full       => req_fifo(n).wr_full,
      wr_prog_full  => open,
      wr_overflow   => req_fifo(n).wr_overflow,
      rd_ena        => req_fifo(n).rd_ena,
      rd_ptr        => req_fifo(n).rd_ptr,
      rd_empty      => req_fifo(n).rd_empty,
      rd_prog_empty => req_fifo(n).rd_prog_empty,
      rd_underflow  => open,
      level         => req_fifo(n).level
    );

    req_fifo(n).rd_ena <= rd(0).ena(n);
    usr_in_req_fifo_ovfl(n) <= req_fifo(n).wr_overflow;

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

  end generate;


  p_output : process(clk)
    variable v_burst_full_pending : std_logic_vector(NUM_PORTS-1 downto 0);
    variable v_burst_flush_pending : std_logic_vector(NUM_PORTS-1 downto 0);
    variable v_burst_size : unsigned(FIFO_DEPTH_LOG2 downto 0);
    variable v_full_sel : unsigned(FIFO_SEL_WIDTH-1 downto 0);
    variable v_full_sel_vld : std_logic;
    variable v_flush_sel : unsigned(FIFO_SEL_WIDTH-1 downto 0);
    variable v_flush_sel_vld : std_logic;
  begin
    if rising_edge(clk) then

      for n in 0 to (NUM_PORTS-1) loop
        v_burst_full_pending(n) := not req_fifo(n).rd_prog_empty;
        v_burst_flush_pending(n) := req_fifo(n).flushing and (not req_fifo(n).rd_empty);
        rd(0).frame(n) <= req_fifo(n).active;
      end loop;

      v_full_sel := get_next(v_burst_full_pending);
      v_full_sel_vld := slv_or(v_burst_full_pending);

      -- Full pending bursts have priority before flush.
      -- In case of a flush the FIFO filling stopped already and overflows can't occur anymore.
      -- Flushing starts after one idle cycle to ensure a stable FIFO level.  
      if unsigned(rd(0).ena)/=0 then
        v_burst_flush_pending := (others=>'0');
      end if;
      v_flush_sel := get_next(v_burst_flush_pending);
      v_flush_sel_vld := slv_or(v_burst_flush_pending);

      rd(0).sob <= '0';
      rd(0).eob <= '0';
      rd(0).eof <= '0';

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

            if v_full_sel_vld='1' then
              rd(0).sob <= '1';
              rd(0).sel <= v_full_sel;
              rd(0).ena(to_integer(v_full_sel)) <= '1';
              burst_cnt <= to_unsigned(BURST_SIZE,burst_cnt'length);
              state <= BURST;
            elsif v_flush_sel_vld='1' then
              rd(0).sob <= '1';
              rd(0).sel <= v_flush_sel;
              rd(0).ena(to_integer(v_flush_sel)) <= '1';
              v_burst_size := req_fifo(to_integer(v_flush_sel)).level;
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
              state <= WAITING;
            end if;
            burst_cnt <= burst_cnt - 1;
                        
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

  -- map requests to bus 
  bus_in_req_ena <= rd(REQ_RAM_READ_DELAY).ena(to_integer(rd(REQ_RAM_READ_DELAY).sel));
  bus_in_req_sob <= rd(REQ_RAM_READ_DELAY).sob;
  bus_in_req_eob <= rd(REQ_RAM_READ_DELAY).eob;
  bus_in_req_eof <= rd(REQ_RAM_READ_DELAY).eof;
  bus_in_req_usr_id <= rd(REQ_RAM_READ_DELAY).sel;
  bus_in_req_usr_frame <= rd(REQ_RAM_READ_DELAY).frame;

  g_write_false : if not WRITE_ENABLE generate
    bus_in_req_data <= (others=>'0');
    bus_in_req_data_vld <= '0';
  end generate;
  
  g_write_true : if WRITE_ENABLE generate
    
  bus_in_req_data <= req_ram_rd.data;
  bus_in_req_data_vld <= req_ram_rd.data_vld;
  
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

  i_req_ram : entity ramlib.ram_sdp
    generic map(
    ADDR_WIDTH => REQ_RAM_ADDR_WIDTH,
    DATA_WIDTH => REQ_RAM_DATA_WIDTH,
    RD_OUTPUT_REGS => 1
  )
  port map(
    clk        => clk,
    rst        => rst,
    wr_clk_en  => '1',
    wr_addr_en => req_ram_wr.addr_vld,
    wr_addr    => std_logic_vector(req_ram_wr.addr),
    wr_data    => req_ram_wr.data,
    rd_clk_en  => '1',
    rd_addr_en => req_ram_rd.addr_vld,
    rd_addr    => std_logic_vector(req_ram_rd.addr),
    rd_data    => req_ram_rd.data,
    rd_data_en => req_ram_rd.data_vld
  );
  

--  -- TODO : Simple dual-port RAM would be sufficient here and might save some RAM blocks.
--  i_req_ram : entity ramlib.ram_tdp
--    generic map(
--      DATA_WIDTH_A      => REQ_RAM_DATA_WIDTH, 
--      DATA_WIDTH_B      => REQ_RAM_DATA_WIDTH,
--      ADDR_WIDTH_A      => REQ_RAM_ADDR_WIDTH,
--      ADDR_WIDTH_B      => REQ_RAM_ADDR_WIDTH,
--      DEPTH_A           => 2**REQ_RAM_ADDR_WIDTH,
--      DEPTH_B           => 2**REQ_RAM_ADDR_WIDTH,
--      INPUT_REGS_A      => 1,
--      INPUT_REGS_B      => 1,
--      OUTPUT_REGS_A     => 1,
--      OUTPUT_REGS_B     => 1,
--      USE_BYTE_ENABLE_A => false,
--      USE_BYTE_ENABLE_B => false,
--      RAM_TYPE          => "block",
--      INIT_FILE         => open
--    )
--    port map(
--      clk_a      => clk,
--      rst_a      => rst,
--      ce_a       => '1',
--      we_a       => req_ram_wr.data_vld,
--      be_a       => open, -- unused
--      addr_a     => std_logic_vector(req_ram_wr.addr),
--      addr_vld_a => req_ram_wr.addr_vld,
--      din_a      => req_ram_wr.data,
--      dout_a     => open, -- unused
--      dout_vld_a => open, -- unused
--      clk_b      => clk,
--      rst_b      => rst,
--      ce_b       => '1',
--      we_b       => '0', -- read only
--      be_b       => open, -- unused
--      addr_b     => std_logic_vector(req_ram_rd.addr),
--      addr_vld_b => req_ram_rd.addr_vld,
--      din_b      => open, -- unused
--      dout_b     => req_ram_rd.data,
--      dout_vld_b => req_ram_rd.data_vld
--    );

  end generate;
  
end architecture;
