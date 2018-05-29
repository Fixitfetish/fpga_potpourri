-------------------------------------------------------------------------------
--! @file       arbiter_write_single_to_burst.vhdl
--! @author     Fixitfetish
--! @date       27/May/2018
--! @version    0.50
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
--! * Setting usr_out_req_frame(N)='1' opens the port N. The FIFO is reset and bus_in_req_port_frame(N)='1'. 
--! * Data can be written using the usr_out_req_wr_data(N) and usr_out_req_wr_ena(N) considering the limitations.
--!   If limitations are not considered usr_in_req_wr_ovfl(N) or usr_in_req_wr_fifo_ovfl(N) might be set.
--! * Bursts will be output as soon as BURST_SIZE+1 data words have been provided.
--! * Setting usr_out_req_frame(N)='0' closes the port N. Input data is not accepted anymore and
--!   the FIFO is flushed. A final burst smaller than BURST_SIZE might be generated.
--! * FIFO flushing is completed when bus_in_req_port_frame(N)='0'. 
--!
--! Further ideas for future development
--! * Generic POST_BURST_GAP : add idle gap of X cycles after each burst,
--!   allow adding of a header infront of each burst.
--! * do different priority modes like e.g. round-robin or first-come-first-serve make sense?
--!     
--! @image html arbiter_write_single_to_burst.svg "" width=500px
--!

entity arbiter_write_single_to_burst is
generic(
  --! Number of input ports
  NUM_PORTS  : positive;
  --! Input, output and FIFO/RAM data width. 
  DATA_WIDTH : positive;
  --! Output burst length (minimum length is 2)
  BURST_SIZE : positive;
  --! @brief FIFO depth per input port. LOG2(depth) ensures that the depth is a power of 2.
  --! The depth must be at least double the burst size.
  --! (Example: if BURST_SIZE=7 then FIFO_DEPTH_LOG2>=4 is required)
  FIFO_DEPTH_LOG2 : positive
);
port(
  --! System clock
  clk                     : in  std_logic;
  --! Synchronous reset
  rst                     : in  std_logic;
  --! Data input frame, rising_edge opens a port, falling edge closes a port
  usr_out_req_frame       : in  std_logic_vector(NUM_PORTS-1 downto 0);
  --! Data input valid, only considered when usr_out_req_frame='1'
  usr_out_req_wr_ena      : in  std_logic_vector(NUM_PORTS-1 downto 0);
--  din         : in  slv_array(0 to NUM_PORTS-1)(DATA_WIDTH-1 downto 0);
  usr_out_req_wr_data     : in  slv16_array(0 to NUM_PORTS-1);
  --! @brief Data input overflow.
  --! Occurs when usr_out_req_wr_ena rate is too high and data cannot be written into FIFO on-time.
  --! These output bits are NOT sticky, hence they could also be used as error IRQ source.
  usr_in_req_wr_ovfl      : out std_logic_vector(NUM_PORTS-1 downto 0);
  --! @brief FIFO overflow (one per input port)
  --! These output bits are NOT sticky, hence they could also be used as error IRQ source.
  usr_in_req_wr_fifo_ovfl : out std_logic_vector(NUM_PORTS-1 downto 0);
  --! Bus is ready to accept requests, default is '1', set '0' to pause bus_in_req_wr_ena and bus_in_req_port_ena
  bus_out_req_rdy         : in  std_logic := '1';
  --! Burst data output enable
  bus_in_req_wr_ena       : out std_logic;
  --! Burst data output
  bus_in_req_wr_data      : out std_logic_vector(DATA_WIDTH-1 downto 0);
  --! First data of burst
  bus_in_req_first        : out std_logic;
  --! Last data of burst
  bus_in_req_last         : out std_logic;
  --! Data output frame (one bit per input port)
  bus_in_req_port_frame   : out std_logic_vector(NUM_PORTS-1 downto 0);
  --! Data output valid (one bit per input port)
  bus_in_req_port_ena     : out std_logic_vector(NUM_PORTS-1 downto 0);
  --! User index of corresponding user request port
  bus_in_req_port_idx     : out unsigned(log2ceil(NUM_PORTS)-1 downto 0)
);
begin
  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (2*BURST_SIZE)<=(2**FIFO_DEPTH_LOG2)
    report "ERROR in " & arbiter_write_single_to_burst'INSTANCE_NAME & 
           " FIFO depth must be at least double the burst size."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)
end entity;

-------------------------------------------------------------------------------

architecture rtl of arbiter_write_single_to_burst is

  -- Width of FIFO/Port select signal
  constant FIFO_SEL_WIDTH : positive := log2ceil(NUM_PORTS);

  constant RAM_ADDR_WIDTH : positive := FIFO_SEL_WIDTH + FIFO_DEPTH_LOG2;
  constant RAM_DATA_WIDTH : positive := DATA_WIDTH;

  -- RAM read delay can be adjusted if another RAM/FIFO with more pipeline stages is used.
  constant RAM_READ_DELAY : positive := 2;

  signal usr_out_req_wr_data_q : slv16_array(0 to NUM_PORTS-1);
--  signal usr_out_req_wr_data_q : slv_array(0 to NUM_PORTS-1)(DATA_WIDTH-1 downto 0);
  signal usr_out_req_frame_q : std_logic_vector(NUM_PORTS-1 downto 0);
  signal din_pending : std_logic_vector(NUM_PORTS-1 downto 0);

  -- write port
  type t_wr is
  record
    frame : std_logic_vector(NUM_PORTS-1 downto 0);
    ena : std_logic_vector(NUM_PORTS-1 downto 0);
    sel : unsigned(FIFO_SEL_WIDTH-1 downto 0);
    addr : unsigned(RAM_ADDR_WIDTH-1 downto 0);
    addr_vld : std_logic;
    data : std_logic_vector(DATA_WIDTH-1 downto 0);
  end record;
  signal wr : t_wr;

  type t_fifo is
  record
    wr_ptr : unsigned(FIFO_DEPTH_LOG2-1 downto 0);
    rd_ptr : unsigned(FIFO_DEPTH_LOG2-1 downto 0);
    level  : unsigned(FIFO_DEPTH_LOG2-1 downto 0);
    empty  : std_logic;
    full  : std_logic;
    filled : std_logic;
    active : std_logic;
    flush_triggered : std_logic;
    flush  : std_logic;
    ovfl   : std_logic;
  end record;
  constant DEFAULT_FIFO : t_fifo := (
    wr_ptr => (others=>'0'),
    rd_ptr => (others=>'0'),
    level => (others=>'0'),
    empty => '1',
    full => '0',
    filled => '0',
    active => '0',
    flush_triggered => '0',
    flush => '0',
    ovfl => '0'
  );
  type a_fifo is array(integer range <>) of t_fifo;
  signal fifo : a_fifo(0 to NUM_PORTS-1);

  type t_fifo_ptr is array(integer range <>) of unsigned(FIFO_DEPTH_LOG2-1 downto 0);

  signal burst_cnt : unsigned(FIFO_DEPTH_LOG2-1 downto 0);

  type t_state is (WAITING, BURST);
  signal state : t_state;

  -- RAM READ
  type t_rd is
  record
    ena : std_logic_vector(NUM_PORTS-1 downto 0);
    sel : unsigned(FIFO_SEL_WIDTH-1 downto 0);
    addr : unsigned(RAM_ADDR_WIDTH-1 downto 0);
    addr_vld : std_logic;
    addr_first : std_logic;
    addr_last : std_logic;
    data_en : std_logic;
    data : std_logic_vector(DATA_WIDTH-1 downto 0);
  end record;
  signal rd : t_rd;

  type t_rd_out is
  record
    sel : unsigned(FIFO_SEL_WIDTH-1 downto 0);
    vld : std_logic_vector(NUM_PORTS-1 downto 0);
    first : std_logic;
    last : std_logic;
    frame : std_logic_vector(NUM_PORTS-1 downto 0);
  end record;
  type a_rd_out is array(integer range <>) of t_rd_out;
  signal rd_out : a_rd_out(1 to RAM_READ_DELAY);

  
  -- GTKWave work-around
  signal level0 : unsigned(FIFO_DEPTH_LOG2-1 downto 0);
  signal level1 : unsigned(FIFO_DEPTH_LOG2-1 downto 0);
  signal level2 : unsigned(FIFO_DEPTH_LOG2-1 downto 0);
  signal level3 : unsigned(FIFO_DEPTH_LOG2-1 downto 0);
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
  signal wr_ena : std_logic_vector(NUM_PORTS-1 downto 0);
  signal wr_addr : unsigned(RAM_ADDR_WIDTH-1 downto 0);
  signal wr_sel : unsigned(FIFO_SEL_WIDTH-1 downto 0);
  signal wr_addr_vld : std_logic;
  signal wr_data : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal rd_ena : std_logic_vector(NUM_PORTS-1 downto 0);
  signal rd_addr : unsigned(RAM_ADDR_WIDTH-1 downto 0);
  signal rd_addr_vld : std_logic;
  signal rd_addr_first : std_logic;
  signal rd_addr_last : std_logic;
  signal rd_sel : unsigned(FIFO_SEL_WIDTH-1 downto 0);
  signal rd_data_en : std_logic;
  signal rd_data : std_logic_vector(DATA_WIDTH-1 downto 0);

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

begin

  -- GTKWave work-around
  level0 <= fifo(0).level;
  level1 <= fifo(1).level;
  level2 <= fifo(2).level;
  level3 <= fifo(3).level;
  ptr0 <= fifo(0).wr_ptr;
  ptr1 <= fifo(1).wr_ptr;
  ptr2 <= fifo(2).wr_ptr;
  ptr3 <= fifo(3).wr_ptr;
  g_gtkwave : for n in 0 to (NUM_PORTS-1) generate
    fifo_active(n) <= fifo(n).active;
    fifo_empty(n) <= fifo(n).empty;
    fifo_full(n) <= fifo(n).full;
    fifo_filled(n) <= fifo(n).filled;
    fifo_flush_triggered(n) <= fifo(n).flush_triggered;
    fifo_flush(n) <= fifo(n).flush;
  end generate;
  wr_addr <= wr.addr;
  wr_addr_vld <= wr.addr_vld;
  wr_sel <= wr.sel;
  wr_data <= wr.data;
  wr_ena <= wr.ena;
  wr_frame <= wr.frame;

  rd_ena <= rd.ena;
  rd_addr <= rd.addr;
  rd_addr_vld <= rd.addr_vld;
  rd_addr_first <= rd.addr_first;
  rd_addr_last <= rd.addr_last;
  rd_sel <= rd.sel;
  rd_data <= rd.data;
  rd_data_en <= rd.data_en;


  p_input_arbiter : process(clk)
    variable v_din_vld : std_logic_vector(NUM_PORTS-1 downto 0);
    variable v_din_pending_new : std_logic_vector(NUM_PORTS-1 downto 0);
    variable v_din_ack : std_logic_vector(NUM_PORTS-1 downto 0);
  begin
    if rising_edge(clk) then

      v_din_vld := usr_out_req_wr_ena and usr_out_req_frame;
      v_din_pending_new := v_din_vld or din_pending;
      v_din_ack := get_next(v_din_pending_new);

      wr.frame <= v_din_pending_new or usr_out_req_frame;

      if rst='1' then
        din_pending <= (others=>'0');
        usr_out_req_frame_q <= (others=>'0');
        usr_out_req_wr_data_q <= (others=>(others=>'-'));
        usr_in_req_wr_ovfl <= (others=>'0');
        wr.sel <= (others=>'0');
        wr.ena <= (others=>'0');

      else
        -- by default register all incoming inputs
        usr_out_req_frame_q <= usr_out_req_frame; -- TODO  frame_q goes low only when not pending ?
        for n in 0 to (NUM_PORTS-1) loop
          if v_din_vld(n)='1' then
            usr_out_req_wr_data_q(n) <= usr_out_req_wr_data(n); 
          end if;
        end loop;

        wr.sel <= get_next(v_din_pending_new);
        wr.ena <= v_din_ack;

        -- handling of pending bits and overflow errors
        din_pending <= v_din_pending_new and (not v_din_ack);
        usr_in_req_wr_ovfl <= din_pending and v_din_vld;

      end if; --reset 
    end if; --clock
  end process;


  p_fifo_logic : process(clk)
    variable v_level : t_fifo_ptr(0 to NUM_PORTS-1);
    variable v_wr_frame_q : std_logic_vector(NUM_PORTS-1 downto 0);
  begin
    if rising_edge(clk) then
      for n in 0 to (NUM_PORTS-1) loop
        v_level(n) := fifo(n).level;
        if rst='1' or (fifo(n).flush='1' and fifo(n).empty='1') then
          fifo(n) <= DEFAULT_FIFO;
        else
          if wr.ena(n)='1' then
            fifo(n).wr_ptr <= fifo(n).wr_ptr + 1;
          end if;    
          if rd.ena(n)='1' then
            fifo(n).rd_ptr <= fifo(n).rd_ptr + 1;
          end if;
          if wr.ena(n)='1' and rd.ena(n)='0' then
            v_level(n) := fifo(n).level + 1;
          elsif wr.ena(n)='0' and rd.ena(n)='1' then
            v_level(n) := fifo(n).level - 1;
          end if;
          fifo(n).empty <= to_01(v_level(n)=0);
          fifo(n).full <= to_01(v_level(n)=to_unsigned(2**FIFO_DEPTH_LOG2-1,FIFO_DEPTH_LOG2));
          fifo(n).ovfl <= fifo(n).full and to_01(v_level(n)=0);
          fifo(n).level <= v_level(n);
          fifo(n).active <= fifo(n).active or (usr_out_req_frame(n) and (not usr_out_req_frame_q(n)));
          -- Ensure that the wr_ptr does not change anymore after flush has been triggered.
          fifo(n).flush_triggered <= fifo(n).flush_triggered or (v_wr_frame_q(n) and (not wr.frame(n)));
          if v_level(n)>BURST_SIZE then
            fifo(n).filled <= '1';
            fifo(n).flush <= '0';
          else
            fifo(n).filled <= '0';
            -- Enable flush only when no more full bursts are are active or pending. 
            fifo(n).flush <= fifo(n).flush or (fifo(n).flush_triggered and (not rd.ena(n)));
          end if;
        end if; --reset
      end loop; 
      v_wr_frame_q := wr.frame; -- for edge detection
    end if; --clock
  end process;

  p_output : process(clk)
    variable v_burst_full_pending : std_logic_vector(NUM_PORTS-1 downto 0);
    variable v_burst_flush_pending : std_logic_vector(NUM_PORTS-1 downto 0);
    variable v_burst_size : unsigned(FIFO_DEPTH_LOG2-1 downto 0);
    variable v_full_sel : unsigned(FIFO_SEL_WIDTH-1 downto 0);
    variable v_full_sel_vld : std_logic;
    variable v_flush_sel : unsigned(FIFO_SEL_WIDTH-1 downto 0);
    variable v_flush_sel_vld : std_logic;
  begin
    if rising_edge(clk) then

      for n in 0 to (NUM_PORTS-1) loop
        v_burst_full_pending(n) := fifo(n).filled;
        v_burst_flush_pending(n) := fifo(n).flush and (not fifo(n).empty);
      end loop;

      v_full_sel := get_next(v_burst_full_pending);
      v_full_sel_vld := slv_or(v_burst_full_pending);

      -- Full pending bursts have priority before flush.
      -- In case of a flush the FIFO filling stopped already and overflows can't occur anymore.
      -- Flushing starts after one idle cycle to ensure a stable FIFO level.  
      if unsigned(rd.ena)/=0 then
        v_burst_flush_pending := (others=>'0');
      end if;
      v_flush_sel := get_next(v_burst_flush_pending);
      v_flush_sel_vld := slv_or(v_burst_flush_pending);

      rd.addr_first <= '0';
      rd.addr_last <= '0';

      if rst='1' then
        rd.ena <= (others=>'0');
        rd.sel <= (others=>'0');
        burst_cnt <= (others=>'-');
        state <= WAITING;

      elsif bus_out_req_rdy='1' then
          
        case state is
          when WAITING =>
            burst_cnt <= (others=>'0');
            rd.ena <= (others=>'0');

            if v_full_sel_vld='1' then
              rd.addr_first <= '1';
              rd.sel <= v_full_sel;
              rd.ena(to_integer(v_full_sel)) <= '1';
              burst_cnt <= to_unsigned(BURST_SIZE,burst_cnt'length);
              state <= BURST;
            elsif v_flush_sel_vld='1' then
              rd.addr_first <= '1';
              rd.sel <= v_flush_sel;
              rd.ena(to_integer(v_flush_sel)) <= '1';
              v_burst_size := fifo(to_integer(v_flush_sel)).level;
              burst_cnt <= v_burst_size;
              if v_burst_size=1 then
                rd.addr_last <= '1';
              else
                state <= BURST;
              end if;
            end if;

          when BURST =>
            rd.ena(to_integer(rd.sel)) <= '1';
            if burst_cnt=2 then 
              rd.addr_last <= '1';
              state <= WAITING;
            end if;
            burst_cnt <= burst_cnt - 1;
                        
        end case;  

      else
        rd.ena <= (others=>'0');
        
      end if; --reset 
    end if; --clock
  end process;

  -- write port mux before RAM input register
  wr.addr_vld <= wr.ena(to_integer(wr.sel)); -- TODO use slv_or ?
  wr.addr(RAM_ADDR_WIDTH-1 downto FIFO_DEPTH_LOG2) <= wr.sel;
  wr.addr(FIFO_DEPTH_LOG2-1 downto 0) <= fifo(to_integer(wr.sel)).wr_ptr;
  wr.data <= usr_out_req_wr_data_q(to_integer(wr.sel));

  -- read port mux before RAM input register
  rd.addr_vld <= rd.ena(to_integer(rd.sel));
  rd.addr(RAM_ADDR_WIDTH-1 downto FIFO_DEPTH_LOG2) <= rd.sel;
  rd.addr(FIFO_DEPTH_LOG2-1 downto 0) <= fifo(to_integer(rd.sel)).rd_ptr;

  -- handle read delay
  rd_out(1).vld <= rd.ena when rising_edge(clk);
  rd_out(1).first <= rd.addr_first when rising_edge(clk);
  rd_out(1).last <= rd.addr_last when rising_edge(clk);
  rd_out(1).sel <= rd.addr(RAM_ADDR_WIDTH-1 downto FIFO_DEPTH_LOG2) when rising_edge(clk);

  g_out : for n in 0 to (NUM_PORTS-1) generate
    usr_in_req_wr_fifo_ovfl(n) <= fifo(n).ovfl;
    rd_out(1).frame(n) <= fifo(n).active when rising_edge(clk);
  end generate;

  g_ram_delay : for d in 2 to RAM_READ_DELAY generate
    rd_out(d) <= rd_out(d-1) when rising_edge(clk);
  end generate;

  bus_in_req_wr_data <= rd.data;
  bus_in_req_wr_ena <= rd.data_en;
  
  bus_in_req_port_ena <= rd_out(RAM_READ_DELAY).vld;  
  bus_in_req_first <= rd_out(RAM_READ_DELAY).first;
  bus_in_req_last <= rd_out(RAM_READ_DELAY).last;
  bus_in_req_port_frame <= rd_out(RAM_READ_DELAY).frame;
  bus_in_req_port_idx <= rd_out(RAM_READ_DELAY).sel;

  i_dpram : entity ramlib.ram_sdp
    generic map(
    ADDR_WIDTH => RAM_ADDR_WIDTH,
    DATA_WIDTH => RAM_DATA_WIDTH,
    RD_OUTPUT_REGS => 1
  )
  port map(
    clk        => clk,
    rst        => rst,
    wr_clk_en  => '1',
    wr_addr_en => wr.addr_vld,
    wr_addr    => std_logic_vector(wr.addr),
    wr_data    => wr.data,
    rd_clk_en  => '1',
    rd_addr_en => rd.addr_vld,
    rd_addr    => std_logic_vector(rd.addr),
    rd_data    => rd.data,
    rd_data_en => rd.data_en
  );
  

--  -- TODO : Simple dual-port RAM would be sufficient here and might save some RAM blocks.
--  i_dpram : entity ramlib.ram_tdp
--    generic map(
--      DATA_WIDTH_A      => RAM_DATA_WIDTH, 
--      DATA_WIDTH_B      => RAM_DATA_WIDTH,
--      ADDR_WIDTH_A      => RAM_ADDR_WIDTH,
--      ADDR_WIDTH_B      => RAM_ADDR_WIDTH,
--      DEPTH_A           => 2**RAM_ADDR_WIDTH,
--      DEPTH_B           => 2**RAM_ADDR_WIDTH,
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
--      we_a       => wr.addr_vld,
--      be_a       => open, -- unused
--      addr_a     => std_logic_vector(wr.addr),
--      addr_vld_a => wr.addr_vld,
--      din_a      => wr.data,
--      dout_a     => open, -- unused
--      dout_vld_a => open, -- unused
--      clk_b      => clk,
--      rst_b      => rst,
--      ce_b       => '1',
--      we_b       => '0', -- read only
--      be_b       => open, -- unused
--      addr_b     => std_logic_vector(rd.addr),
--      addr_vld_b => rd.addr_vld,
--      din_b      => open, -- unused
--      dout_b     => rd.data,
--      dout_vld_b => rd.data_en
--    );

  
end architecture;
