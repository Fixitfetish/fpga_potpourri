-------------------------------------------------------------------------------
--! @file       ram_arbiter_read.vhdl
--! @author     Fixitfetish
--! @date       20/Oct/2018
--! @version    0.71
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;
library ramlib;
  use ramlib.ram_arbiter_pkg.all;

--! @brief Arbiter that transforms single read requests (stream) from multiple user ports
--! to read request bursts at the single RAM port. The read data is demultiplexed
--! back to the user ports.
--!
--! This arbiter has a definable number of user ports and one RAM port.
--! The RAM port provides sequential requests bursts of data words for each user port.
--! The burst size is configurable but the same for all.
--! 
--! In **single-shot** mode the arbiter automatically stops requesting data from memory
--! after the configured last address has been accessed. Further user requests are ignored.
--! The status signal wrap='1' and active='0' signals the end of the single-shot. 
--! Furthermore, the last read completion data of the single-shot is marked with EOF though
--! the user frame signal might still be active. 
--! It is recommended that the user resets the frame signal when either wrap='1' or EOF='1'.
--! Before another single-shot can be started the user must always reset the frame signal.
--!
--! NOTES: 
--! * User port 0 has the highest priority and user port NUM_PORTS-1 has the lowest priority.
--! * The data width of each user port, the RAM port is DATA_WIDTH.
--! * If only one user port is open/active then continuous streaming is possible.
--!
--! Signal Prefix Naming (also useful for record mapping):
--! * usr_out : user output port, signals that the user generate (e.g. requests)
--! * usr_in : user input port, signals that the user receives (e.g. status)
--! * ram_out : ram output port, signals that are originated by the ram (e.g. status or read data)
--! * ram_in : ram input port, signals that feed the bus (e.g. write/read requests)
--!
--! For more details refer to the entities arbiter_mux_stream_to_burst and arbiter_demux_single_to_stream
--! which are used for this implementation.
--! Also consider using the optional entity ram_arbiter_read_data_width_adapter at the user interface
--! to adapt different user data widths to the RAM width.
--!  
--! @image html ram_arbiter_read.svg "" width=500px
--!
entity ram_arbiter_read is
generic(
  --! Number of user input ports
  NUM_PORTS : positive;
  --! RAM data width at user input and RAM output ports
  DATA_WIDTH : positive;
  --! Data word address width at user input and RAM output ports
  ADDR_WIDTH : positive;
  --! Maximum length of bursts in number of data word requests (or cycles)
  BURST_SIZE : positive;
  --! Maximum completion (RAM read) delay from bus_in_req to bus_out_cpl.
  MAX_CPL_DELAY : positive
);
port(
  --! System clock
  clk              : in  std_logic;
  --! Synchronous reset
  rst              : in  std_logic;
  --! User read request input port(s)
  usr_out_port     : in  a_ram_arbiter_usr_out_port(0 to NUM_PORTS-1);
  --! User read status output
  usr_in_port      : out a_ram_arbiter_usr_in_port(0 to NUM_PORTS-1);
  --! RAM is ready to accept data input
  ram_out_rdy      : in  std_logic;
  --! RAM request address
  ram_in_addr      : out std_logic_vector(ADDR_WIDTH-1 downto 0);
  --! RAM request enable
  ram_in_ena       : out std_logic;
  --! Marker for first request of a burst with incrementing address
  ram_in_first     : out std_logic;
  --! Marker for last request of a burst with incrementing address
  ram_in_last      : out std_logic;
  --! Read data returned by RAM 
  ram_out_data     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
  --! Read data valid returned by RAM
  ram_out_data_vld : in  std_logic
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of ram_arbiter_read is

  -- Width of FIFO/Port select signal
  constant USER_ID_WIDTH : positive := log2ceil(NUM_PORTS);

  constant FIFO_DEPTH_LOG2 : positive := log2ceil(2*BURST_SIZE);

  signal mux_usr_req_frame    : std_logic_vector(NUM_PORTS-1 downto 0);
  signal mux_usr_req_ena      : std_logic_vector(NUM_PORTS-1 downto 0);
  signal mux_usr_req_ovfl     : std_logic_vector(NUM_PORTS-1 downto 0);
  signal mux_bus_req_rdy      : std_logic;
  signal mux_bus_req_sob      : std_logic;
  signal mux_bus_req_eob      : std_logic;
  signal mux_bus_req_eof      : std_logic;
  signal mux_bus_req_id       : unsigned(USER_ID_WIDTH-1 downto 0);
  signal mux_bus_req_ena      : std_logic;
  signal mux_bus_req_frame    : std_logic_vector(NUM_PORTS-1 downto 0);
  signal mux_usr_req_fifo_ovfl: std_logic_vector(NUM_PORTS-1 downto 0);

  signal mux_usr_req_frame_q : std_logic_vector(NUM_PORTS-1 downto 0);
  signal mux_bus_req_frame_q : std_logic_vector(NUM_PORTS-1 downto 0);

  type a_wr_addr is array(integer range <>) of unsigned(ADDR_WIDTH-1 downto 0);
  signal addr_next : a_wr_addr(NUM_PORTS-1 downto 0);
  signal addr_incr_active : std_logic_vector(NUM_PORTS-1 downto 0); 
  signal wrap : std_logic_vector(NUM_PORTS-1 downto 0);
  signal next_is_addr_last : std_logic_vector(NUM_PORTS-1 downto 0);
  signal next_is_eof : std_logic_vector(NUM_PORTS-1 downto 0);

  type r_cfg is
  record
    --! start address (requires rising edge of frame signal)
    addr_first : unsigned(ADDR_WIDTH-1 downto 0); 
    --! last address before wrap (requires rising edge of frame signal)
    addr_last : unsigned(ADDR_WIDTH-1 downto 0); 
    --! '1'=single-shot mode , '0'=continuous with wrap (requires rising edge of frame signal)
    single_shot : std_logic;
  end record;
  constant DEFAULT_CFG : r_cfg := (
    addr_first=>(others=>'-'),
    addr_last=>(others=>'-'),
    single_shot => '-'
  );
  type a_cfg is array(integer range <>) of r_cfg;
  signal cfg : a_cfg(NUM_PORTS-1 downto 0); 

  -----------------------
  -- Sequence FIFO
  -----------------------

  -- Data width of the request sequence FIFO (port index + EOF flag)
  constant SEQ_FIFO_WIDTH : positive := USER_ID_WIDTH + 1;

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
  signal seq_fifo_cpl_id : unsigned(USER_ID_WIDTH-1 downto 0);
  signal seq_fifo_cpl_eof : std_logic;


  signal usr_in_cpl_data      : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal usr_in_cpl_data_vld  : std_logic_vector(NUM_PORTS-1 downto 0);
  signal usr_in_cpl_data_eof  : std_logic_vector(NUM_PORTS-1 downto 0);
  signal usr_in_cpl_rdy       : std_logic_vector(NUM_PORTS-1 downto 0);
  signal usr_out_cpl_ack      : std_logic_vector(NUM_PORTS-1 downto 0) := (others=>'1');
  signal usr_in_cpl_ack_ovfl  : std_logic_vector(NUM_PORTS-1 downto 0);
  signal usr_in_cpl_fifo_ovfl : std_logic_vector(NUM_PORTS-1 downto 0);


  -- GTKWave work-around
  signal seq_fifo_wr_ena : std_logic;
  signal seq_fifo_level : integer;

begin

  -- GTKWave work-around
  seq_fifo_wr_ena <= seq_fifo.wr_ena;
  seq_fifo_level <= seq_fifo.level;


  g_usr_req : for n in 0 to NUM_PORTS-1 generate
    -- TX
    mux_usr_req_frame(n) <= usr_out_port(n).req_frame;
    -- ignore user requests after end of single-shot
    mux_usr_req_ena(n) <= usr_out_port(n).req_ena and addr_incr_active(n);
    -- RX
    usr_in_port(n).active <= addr_incr_active(n) and mux_bus_req_frame(n) when rising_edge(clk);
    usr_in_port(n).wrap <= wrap(n);
    usr_in_port(n).req_ovfl <= mux_usr_req_ovfl(n);
    usr_in_port(n).req_fifo_ovfl <= mux_usr_req_fifo_ovfl(n);
    usr_in_port(n).addr_next <= addr_next(n);
  end generate;

  mux_bus_req_rdy <= ram_out_rdy when rising_edge(clk);

  i_mux : entity ramlib.arbiter_mux_stream_to_burst
  generic map(
    NUM_PORTS  => NUM_PORTS,
    DATA_WIDTH => DATA_WIDTH, -- TODO # data unused
    BURST_SIZE => BURST_SIZE,
    FIFO_DEPTH_LOG2 => FIFO_DEPTH_LOG2,
    WRITE_ENABLE => false
  )
  port map (
    clk                     => clk,
    rst                     => rst,
    usr_out_req_frame       => mux_usr_req_frame,
    usr_out_req_ena         => mux_usr_req_ena,
    usr_out_req_wr_data     => (others=>(others=>'0')), -- unused
    usr_in_req_ovfl         => mux_usr_req_ovfl,
    usr_in_req_fifo_ovfl    => mux_usr_req_fifo_ovfl,
    bus_out_req_rdy         => mux_bus_req_rdy,
    bus_in_req_ena          => mux_bus_req_ena,
    bus_in_req_sob          => mux_bus_req_sob,
    bus_in_req_eob          => mux_bus_req_eob,
    bus_in_req_eof          => mux_bus_req_eof,
    bus_in_req_usr_id       => mux_bus_req_id,
    bus_in_req_usr_frame    => mux_bus_req_frame,
    bus_in_req_data         => open,
    bus_in_req_data_vld     => open
  );

  p_addr : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        cfg <= (others=>DEFAULT_CFG);
        addr_next <= (others=>(others=>'-'));
        addr_incr_active <= (others=>'1');
        wrap <= (others=>'0');

        -- ensure no rising edge after reset, e.g. when din_frame is still '1'
        mux_usr_req_frame_q <= (others=>'1');

        mux_bus_req_frame_q <= (others=>'0');
        
      else    
        mux_usr_req_frame_q <= mux_usr_req_frame;
        mux_bus_req_frame_q <= mux_bus_req_frame;

        for n in 0 to (NUM_PORTS-1) loop
          if mux_usr_req_frame(n)='1' and mux_usr_req_frame_q(n)='0' then
            -- start channel, hold configuration        
            cfg(n).addr_first <= usr_out_port(n).cfg_addr_first;
            cfg(n).addr_last <= usr_out_port(n).cfg_addr_last;
            cfg(n).single_shot <= usr_out_port(n).cfg_single_shot;
            -- reset address
            wrap(n) <= '0';    
            addr_next(n) <= usr_out_port(n).cfg_addr_first;
            addr_incr_active(n) <= '1';

          elsif mux_bus_req_frame(n)='0' and mux_bus_req_frame_q(n)='1' then
            -- end of channel
            -- re-activate address increment after single-shot
            -- (important for first user request of next frame)
            addr_incr_active(n) <= '1';

          elsif mux_bus_req_ena='1' and mux_bus_req_id=n and addr_incr_active(n)='1' then
            -- address increment
            addr_next(n) <= addr_next(n) + 1;
            if next_is_addr_last(n)='1' then
              wrap(n) <= '1';
              -- single-shot or continuous 
              if cfg(n).single_shot='0' then
                addr_next(n) <= cfg(n).addr_first;
              end if;
              -- set inactive when single-slot finished 
              addr_incr_active(n) <= not cfg(n).single_shot;
            end if;
          end if;
        end loop;
        
      end if;
    end if;    
  end process;

  g_last : for n in 0 to (NUM_PORTS-1) generate
    next_is_addr_last(n) <= '1' when (addr_next(n)=cfg(n).addr_last) else '0';
    next_is_eof(n) <= cfg(n).single_shot and next_is_addr_last(n);
  end generate;

  p_ram_req : process(clk)
    variable v_active : std_logic;
    variable v_single_shot : std_logic;
    variable v_addr : unsigned(ADDR_WIDTH-1 downto 0); 
  begin
    if rising_edge(clk) then
      if rst='1' then
        ram_in_ena <= '0';
        ram_in_first <= '0';
        ram_in_last <= '0';
        ram_in_addr <= (others=>'-');
        
      else
        v_active := addr_incr_active(to_integer(mux_bus_req_id));
        v_single_shot := cfg(to_integer(mux_bus_req_id)).single_shot;
        v_addr := addr_next(to_integer(mux_bus_req_id));

        ram_in_ena <= mux_bus_req_ena and v_active;
        ram_in_first <= mux_bus_req_sob and v_active;
        if v_single_shot='1' and v_addr=cfg(to_integer(mux_bus_req_id)).addr_last then
          -- always set last flag for last write of single-shot
          ram_in_last <= v_active;
        else
          ram_in_last <= mux_bus_req_eob and v_active;
        end if;
        ram_in_addr <= std_logic_vector(v_addr);
      end if;
    end if;    
  end process;

  -----------------------------------------------------------------------------
  -- Sequence FIFO
  -----------------------------------------------------------------------------

  -- write only to SEQ-FIFO as long as address increment (single-shot) is active
  seq_fifo.wr_ena <= mux_bus_req_ena and addr_incr_active(to_integer(mux_bus_req_id));
  seq_fifo.wr_data(mux_bus_req_id'length-1 downto 0) <= std_logic_vector(mux_bus_req_id);
  seq_fifo.wr_data(seq_fifo.wr_data'high) <= mux_bus_req_eof or next_is_eof(to_integer(mux_bus_req_id));

  i_seq_fifo : entity ramlib.fifo_sync
  generic map (
    FIFO_WIDTH => SEQ_FIFO_WIDTH,
    FIFO_DEPTH => SEQ_FIFO_DEPTH,
    USE_BLOCK_RAM => true,
--    RAM_TYPE => "block",
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

  seq_fifo.rd_ack <= ram_out_data_vld;
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
    bus_out_cpl_data        => ram_out_data, 
    bus_out_cpl_data_vld    => ram_out_data_vld, 
    usr_in_cpl_rdy          => usr_in_cpl_rdy, 
    usr_out_cpl_ack         => usr_out_cpl_ack, 
    usr_in_cpl_ack_ovfl     => usr_in_cpl_ack_ovfl, 
    usr_in_cpl_data         => usr_in_cpl_data, 
    usr_in_cpl_data_vld     => usr_in_cpl_data_vld, 
    usr_in_cpl_data_eof     => usr_in_cpl_data_eof, 
    usr_in_cpl_fifo_ovfl    => usr_in_cpl_fifo_ovfl
  );

  g_usr_cpl : for n in 0 to NUM_PORTS-1 generate
    usr_out_cpl_ack(n) <= usr_out_port(n).cpl_ack;
    usr_in_port(n).cpl_rdy <= usr_in_cpl_rdy(n);
    usr_in_port(n).cpl_ack_ovfl <= usr_in_cpl_ack_ovfl(n);
    usr_in_port(n).cpl_fifo_ovfl <= usr_in_cpl_fifo_ovfl(n);
    usr_in_port(n).cpl_data_vld <= usr_in_cpl_data_vld(n);
    usr_in_port(n).cpl_data_eof <= usr_in_cpl_data_eof(n);
    usr_in_port(n).cpl_data <= usr_in_cpl_data;
  end generate;

end architecture;
