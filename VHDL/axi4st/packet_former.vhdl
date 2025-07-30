-------------------------------------------------------------------------------
-- @file       packet_former.vhdl
-- @author     Fixitfetish
-- @note       VHDL-2008
-- @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;
library ramlib;

use work.pkg.all;

-- The Multi-Stream packet/burst former converts streams of interleaved single transfers without
-- last flag into interleaved packets of a configurable maximum size. Hence, the module
-- sorts interleaved streams within a single AXI4 stream interface into separate buffers.
-- Once a buffer reaches the maximum burst size the module starts to output the packet with
-- the last flag set at the end.
--
-- **Features**
-- * single input interface with multiple arbitrarily interleaved streams
-- * multiple stream-buffers within common RAM (using as few RAM resources as possible)
-- * single output interface with interleaved stream packets of definable maximum size
-- * full back-pressure support
--
-- **Back-Pressure** (s_tready=0)
-- * If the slave is not ready (m_tready=0) to except data then FIFOs will run full and consequently
--   the packet former will not be able except data from the master anymore. 
-- * Under special conditions, e.g. uneven interleaving, a single stream FIFO can run full
--   even though the slave is ready to except data. In this case, all streams from the master might
--   pause (s_tready=0) for a short moment until the FIFO of the current stream index is ready to
--   except new data and the pending input from master can be written to the FIFO.
--   Hence, for full performance a balanced input interleaving is beneficial.
-- * If the master provides a mix of very short and long packets then it might happen that the
--   number of pending packets in the buffer exceeds the maximum supported number.
--   In this case, the packet former signals to the master "not ready" for a short moment.
--
entity packet_former is
generic(
  -- Number of interleaved input streams has an influence on the size of the internal RAM buffer.
  NUM_STREAMS : positive;
  -- Form packets according to "DEST" or "ID" input signal from master. There will be one FIFO
  -- per "DEST" or "ID". The other signal will be just passed through or ignored.
  MODE : string := "ID";
  -- Maximum length of packets in number of AXI transfers. This size influences the size of the internal RAM buffer.
  -- Note that a packet should not be longer than 256 transfers to keep the buffer reasonable small, to allow packet
  -- packet arbitration in short intervals and to be AXI4MM compatible.
  PACKET_SIZE : positive range 1 to 256;
  -- Enable AXI pipeline input register(s). Multiple different stages can be configured
  -- but the last stage should always be ready_breakup, priming or primegating.
  INPUT_PIPESTAGES : a_pipestage := (0=>bypass);
  -- Enable AXI pipeline output register(s). Multiple different stages can be configured
  -- but the first stage should always be ready_breakup, priming or primegating.
  -- At lest one stage is highly recommended.
  OUTPUT_PIPESTAGES : a_pipestage := (0=>bypass);
  -- If MODE="ID" then the TDEST input signal is ignored. If MODE="DEST" then the TID input signal is ignored.
  -- At the corresponding output signal will be set to zero.
  -- Furthermore, the ignored signal is not buffered and the buffer width will be smaller.
  -- Consequently, less RAM resources might be required.
  TDEST_TID_IGNORE : boolean := true;
  -- If the TKEEP input signal is ignored then the corresponding output signal bits will be all HIGH.
  -- Furthermore, the ignored signal is not buffered and the buffer width will be smaller.
  -- Consequently, less RAM resources might be required.
  TKEEP_IGNORE : boolean := true;
  -- If the TSTRB input signal is ignored then the corresponding output signal bits will be all HIGH.
  -- Furthermore, the ignored signal is not buffered and the buffer width will be smaller.
  -- Consequently, less RAM resources might be required.
  TSTRB_IGNORE : boolean := true;
  -- If the TUSER input signal is ignored then the corresponding output signal bits will be all LOW.
  -- Furthermore, the ignored signal is not buffered and the buffer width will be smaller.
  -- Consequently, less RAM resources might be required.
  TUSER_IGNORE : boolean := false;
  -- Disable this option if the TUSER signal of master and slave are related to a complete transfer
  -- rather than individual items/bytes. Trimming/Padding adjusts accordingly. (see spec ARM IHI 0051A, chap 2.8)
  TUSER_ITEMWISE : boolean := false
);
port(
  --! System clock
  clk      : in  std_logic;
  --! Synchronous reset
  rst      : in  std_logic;
  --! incoming interleaved streams(s) from master
  s_stream : in  work.pkg.axi4_s;
  --! outgoing ready towards master
  s_tready : out std_logic;
  -- output stream towards slave
  m_stream : out work.pkg.axi4_s;
  -- output packet length info towards slave, optional
--  m_info   : out work.pkg.axi4_s;
  -- ready signal from slave
  m_tready : in  std_logic
);
begin
  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (MODE="DEST" or MODE="ID")
    report "ERROR in " & packet_former'INSTANCE_NAME & 
           " Packet forming MODE must be according to DEST or ID."
    severity failure;
--  assert (KEEP_IGNORE and STRB_IGNORE)
--    report "ERROR in " & packet_former'INSTANCE_NAME & 
--           " Buffering of the KEEP and STRB signals is not yet supported."
--    severity failure;
--  assert (not USER_IGNORE)
--    report "ERROR in " & packet_former'INSTANCE_NAME & 
--           " Buffering of the USER signal is currently always enabled."
--    severity failure;
--  assert (DEST_ID_IGNORE)
--    report "ERROR in " & packet_former'INSTANCE_NAME & 
--           " Buffering of the DEST or ID signal is not yet supported."
--    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)
end entity;

-------------------------------------------------------------------------------

architecture rtl of packet_former is

  -- Width of FIFO/Port select signal
  constant ID_WIDTH : positive := log2ceil(NUM_STREAMS);
  constant USER_INPUT_WIDTH : positive := s_stream.tuser'length;

  constant MAX_PACKET_LENGTH_LOG2 : positive := 8;
  constant PACKET_SIZE_LOG2 : positive := log2ceil(PACKET_SIZE);
  constant FIFO_DEPTH_LOG2 : positive := PACKET_SIZE_LOG2 + 1;
  constant RAM_ADDR_WIDTH : positive := ID_WIDTH + FIFO_DEPTH_LOG2;
  constant RAM_MAX_WIDTH : positive := 1 + s_stream.tdata'length + s_stream.tkeep'length + s_stream.tstrb'length + s_stream.tuser'length + s_stream.tdest'length + s_stream.tid'length;

  impure function RAM_DATA_WIDTH return positive is
    variable r : positive range 1 to RAM_MAX_WIDTH := s_stream.tdata'length + 1; -- always data and last flag
  begin
    if not TKEEP_IGNORE then r := r + s_stream.tkeep'length; end if;
    if not TSTRB_IGNORE then r := r + s_stream.tstrb'length; end if;
    if not TUSER_IGNORE then r := r + s_stream.tuser'length; end if;
    if not TDEST_TID_IGNORE then
      if MODE="ID"   then r := r + s_stream.tdest'length; end if;
      if MODE="DEST" then r := r + s_stream.tid'length; end if;
    end if;
    return r;
  end function;

  impure function to_ram(
    data : std_logic_vector;
    last : std_logic;
    keep : std_logic_vector;
    strb : std_logic_vector;
    user : std_logic_vector;
    dest : std_logic_vector;
    id   : std_logic_vector
  ) return std_logic_vector is
    variable r : std_logic_vector(RAM_DATA_WIDTH-1 downto 0);
    variable offset : positive range 1 to RAM_MAX_WIDTH := data'length + 1;
  begin
    r(data'length-1 downto 0) := data;
    r(data'length)            := last;
    if not TKEEP_IGNORE then
      r(offset+keep'length-1 downto offset) := keep;
      offset := offset + keep'length;
    end if;
    if not TSTRB_IGNORE then
      r(offset+strb'length-1 downto offset) := strb;
      offset := offset + strb'length;
    end if;
    if not TUSER_IGNORE then
      r(offset+user'length-1 downto offset) := user;
      offset := offset + user'length;
    end if;
    if not TDEST_TID_IGNORE then
      if MODE="ID" then 
        r(offset+dest'length-1 downto offset) := dest;
      elsif MODE="DEST" then 
        r(offset+id'length-1 downto offset) := id;
      end if;
    end if;
    return r;
  end function;

  impure function from_ram(
    slv          : std_logic_vector;
    valid        : std_logic;
    stream       : unsigned; -- stream ID
    packetlen    : unsigned; -- packet length
    axi4s_format : work.pkg.axi4_s
  ) return work.pkg.axi4_s is
    variable s : axi4s_format'subtype;
    variable offset : positive range 1 to RAM_MAX_WIDTH := s.tdata'length + 1;
    constant user_width_relevant : natural := maximum(minimum(s.tuser'length-MAX_PACKET_LENGTH_LOG2,USER_INPUT_WIDTH),0);
  begin
    assert (s.tuser'length>=MAX_PACKET_LENGTH_LOG2) 
      report "axi4st.packet_former: Insertion of packet length information requires TUSER width of at least " & integer'image(MAX_PACKET_LENGTH_LOG2)
      severity failure;
    assert (user_width_relevant=USER_INPUT_WIDTH)
      report "axi4st.packet_former: Trimming TUSER input bits from " & integer'image(USER_INPUT_WIDTH) & " to " & integer'image(user_width_relevant)
      severity warning;
    s.tvalid := valid;
    s.tdata  := slv(s.tdata'length-1 downto 0);
    s.tlast  := slv(s.tdata'length);
    if TKEEP_IGNORE then
      s.tkeep := (others=>'1');
    else
      s.tkeep := slv(offset+s.tkeep'length-1 downto offset);
      offset := offset + s.tkeep'length;
    end if;
    if TSTRB_IGNORE then
      s.tstrb := (others=>'1');
    else
      s.tstrb := slv(offset+s.tstrb'length-1 downto offset);
      offset := offset + s.tstrb'length;
    end if;

    -- add packet/burst length header to TUSER
    s.tuser := (others=>'0'); -- preset TUSER 
    s.tuser(MAX_PACKET_LENGTH_LOG2-1 downto 0) := std_logic_vector(resize(packetlen, MAX_PACKET_LENGTH_LOG2));
    if not TUSER_IGNORE then
      if user_width_relevant>0 then
        s.tuser(user_width_relevant+MAX_PACKET_LENGTH_LOG2-1 downto MAX_PACKET_LENGTH_LOG2) := slv(offset+user_width_relevant-1 downto offset);
      end if;
      offset := offset + USER_INPUT_WIDTH;
    end if;

    if MODE="ID" then
      s.tid := std_logic_vector(resize(stream, s.tid'length));
      s.tdest := (others=>'0');
      if not TDEST_TID_IGNORE then s.tdest := slv(offset+s.tdest'length-1 downto offset); end if;
    elsif MODE="DEST" then
      s.tdest := std_logic_vector(resize(stream, s.tdest'length));
      s.tid := (others=>'0');
      if not TDEST_TID_IGNORE then s.tid := slv(offset+s.tid'length-1 downto offset); end if;
    end if;
    return s;
  end function;

  -- TODO : currently "ultra" does not work, because read cock enable support is required
  -- (Note: Ultra can work if max depth is 4096, see ram_tdp_uram288.ultrascale.vhdl)
  constant RAM_TYPE : string := "block";

  function RAM_INPUT_REGS return natural is
  begin
    if RAM_TYPE="ultra" then 
      return 2; -- Xilinx Ultra-RAM
    else
      return 1; -- standard Block-RAM
    end if;
  end function;

  function RAM_OUTPUT_REGS return natural is
  begin
     if RAM_TYPE="ultra" then 
       return 2; -- Xilinx Ultra-RAM
     else
       return 1; -- standard Block-RAM
     end if;
  end function;

  constant RAM_READ_LATENCY : natural := RAM_INPUT_REGS + RAM_OUTPUT_REGS;

  function get_stream(s:unsigned) return natural is
    variable sint : natural;
  begin
    sint := to_integer(s);
    assert (sint<NUM_STREAMS)
      report "ERROR in " & packet_former'INSTANCE_NAME & 
             " Index specified in s_stream input DEST or ID exceeds number of supported streams."
      severity failure;
    return sint;
  end function;

  -- input stream index = FIFO index
  signal sel, sel_q : integer range 0 to NUM_STREAMS-1;

  type t_fifo is
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
    level        : unsigned(FIFO_DEPTH_LOG2 downto 0);
  end record;
  type a_fifo is array(integer range <>) of t_fifo;
  signal fifo : a_fifo(0 to NUM_STREAMS-1);

  -- Packet FIFO holds stream ID and packet length
  constant PACKET_FIFO_WIDTH : positive := ID_WIDTH + PACKET_SIZE_LOG2;

  -- very conservative depth, considering the worst-case that for some streams the LAST bit is set with every transfer
  constant PACKET_FIFO_DEPTH : positive := NUM_STREAMS * PACKET_SIZE;

  type t_packet_fifo is
  record
    rst          : std_logic;
    wr_ena       : std_logic;
    wr_full      : std_logic;
    wr_prog_full : std_logic;
    wr_overflow  : std_logic;
    wr_data      : std_logic_vector(PACKET_FIFO_WIDTH-1 downto 0);
    rd_ack       : std_logic;
    rd_valid     : std_logic;
    rd_prog_empty: std_logic;
    rd_data      : std_logic_vector(PACKET_FIFO_WIDTH-1 downto 0);
    level        : integer;
  end record;
  signal packet_fifo : t_packet_fifo;

  type t_packet is
  record
    transfer_valid : std_logic;
    transfer_count : unsigned(PACKET_SIZE_LOG2-1 downto 0);
    stream         : unsigned(ID_WIDTH-1 downto 0);
    length         : unsigned(PACKET_SIZE_LOG2-1 downto 0);
  end record;
  signal packet : t_packet;

  type t_ram is
  record
    addr : unsigned(RAM_ADDR_WIDTH-1 downto 0);
    addr_vld : std_logic;
    data : std_logic_vector(RAM_DATA_WIDTH-1 downto 0);
    data_vld : std_logic;
  end record;
  signal ram_wr : t_ram;
  signal ram_rd : t_ram;

  -- incoming interleaved streams(s) from master after input register pipeline
  signal s_stream_i : s_stream'subtype;

  signal s_stream_q : s_stream'subtype;
  signal s_tready_i : s_tready'subtype;

  -- packet length counters in the range 0 to PACKET_SIZE-1 , 0 means length=1
  signal wr_count : unsigned_vector(0 to NUM_STREAMS-1)(PACKET_SIZE_LOG2-1 downto 0);

  signal read_clkena : std_logic;

  signal packet_stream_q : unsigned_vector(1 to RAM_READ_LATENCY)(ID_WIDTH-1 downto 0);
  signal packet_length_q : unsigned_vector(1 to RAM_READ_LATENCY)(PACKET_SIZE_LOG2-1 downto 0);

  signal m_stream_i : m_stream'subtype;
  signal m_tready_i : m_tready'subtype;

begin

  -- input pipeline stages
  i_ireg : entity work.pipeline
  generic map(
    PIPESTAGES => INPUT_PIPESTAGES,
    CHECK_AXI_COMPLIANCE => false
  )
  port map(
    aclk     => clk,
    aresetn  => not rst, -- TODO
    s_stream => s_stream,
    s_tready => s_tready,
    m_stream => s_stream_i,
    m_tready => s_tready_i
  );


  -- get and check current stream index
  sel <= get_stream(unsigned(s_stream_i.tdest)) when MODE="DEST" else
         get_stream(unsigned(s_stream_i.tid))   when MODE="ID";

  -- the packet former is not ready to except new input data if
  -- * the FIFO of the current stream index is full
  -- * the overall number of pending packets in the buffer has reached its maximum 
  s_tready_i <= (not fifo(sel).wr_prog_full) and not packet_fifo.wr_full;

  -- The following input register stage prevents the ready signal from being directly fed back
  -- into the FIFOs and is important for timing.
  p_ireg: process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        s_stream_q <= work.pkg.reset(s_stream_q);
        sel_q <= 0;
      elsif (s_stream_i.tvalid and s_tready_i) then
        -- accept current input value and stream towards FIFO
        s_stream_q <= s_stream_i;
        sel_q <= sel;
      else
        s_stream_q.tvalid <= '0';
      end if;
    end if;
  end process;

  g_fifo : for n in 0 to (NUM_STREAMS-1) generate
    signal s_last : std_logic;
  begin

    s_last <= s_stream_q.tlast when sel_q=n else '0';

    -- TODO: reset FIFO also when flushing is completed 
    fifo(n).rst <= rst;
    fifo(n).wr_ena <= s_stream_q.tvalid when sel_q=n else '0';

    -- counter to determine the last flag insertion points
    p_wr_count: process(clk)
    begin
      if rising_edge(clk) then
        if rst='1' then
          wr_count(n) <= (others=>'0');
        elsif (fifo(n).wr_ena='1') then
          if wr_count(n)=(PACKET_SIZE-1) or s_last='1' then
            wr_count(n) <= (others=>'0');
          else
            wr_count(n) <= wr_count(n) + 1;
          end if;
        end if;
      end if;
    end process;

    i_logic : entity ramlib.fifo_logic_sync
    generic map(
      MAX_FIFO_DEPTH_LOG2 => FIFO_DEPTH_LOG2,
      FULL_RESET_VALUE => open
    )
    port map(
      clk                      => clk,
      rst                      => fifo(n).rst,
      cfg_fifo_depth_minus1    => to_unsigned(2**FIFO_DEPTH_LOG2-1, FIFO_DEPTH_LOG2),
      cfg_prog_full_threshold  => to_unsigned(2**FIFO_DEPTH_LOG2-1, FIFO_DEPTH_LOG2), -- little margin required!
      cfg_prog_empty_threshold => to_unsigned(PACKET_SIZE, FIFO_DEPTH_LOG2),
      wr_ena                   => fifo(n).wr_ena,
      wr_ptr                   => fifo(n).wr_ptr,
      wr_full                  => fifo(n).wr_full,
      wr_prog_full             => fifo(n).wr_prog_full,
      wr_overflow              => fifo(n).wr_overflow,
      rd_ena                   => fifo(n).rd_ena,
      rd_ptr                   => fifo(n).rd_ptr,
      rd_empty                 => fifo(n).rd_empty,
      rd_prog_empty            => fifo(n).rd_prog_empty,
      rd_underflow             => open,
      level                    => fifo(n).level
    );

    fifo(n).rd_ena <= read_clkena and packet.transfer_valid and not fifo(n).rd_empty when packet.stream=n else '0';

  end generate;


  -- Packet FIFO : Whenever the last transfer of a packet is written to the RAM buffer additional
  -- information about stream ID and length of the packet is written to this auxiliary FIFO.
  -- Reading from the FIFO provides the correct first-come-first-serve packet order for the output stream.
  -- Note that the packet length might be required by consequent modules at the packet begin
  -- already. Hence, the packet length is determined on the buffer input side so that the length
  -- is available when the first transfer of a packet is read from the buffer.

  -- TODO: Consider the case that the last burst of a stream is not complete, i.e. the TLAST flag is missing.
  --       Instead of padding dummy data with TLAST (which will be also written into RAM) you could also 
  --       send a dummy address trailer which terminates the incomplete burst (no additional RAM write!).
  --       This should work because the address header/trailer always has the TLAST set.

  -- Detect either last flag from incoming stream or locally generated end of packet according to max packet size.
  packet_fifo.wr_ena <= s_stream_q.tvalid and (s_stream_q.tlast or baselib.ieee_extension.to_01(wr_count(sel_q)=(PACKET_SIZE-1)));
  packet_fifo.wr_data <= std_logic_vector(to_unsigned(sel_q,ID_WIDTH)) & std_logic_vector(wr_count(sel_q));
  packet_fifo.rst <= rst;

  i_packet_fifo : entity ramlib.fifo_sync(ultrascale) -- TODO: remove arch
  generic map (
    FIFO_WIDTH           => PACKET_FIFO_WIDTH,
    FIFO_DEPTH           => PACKET_FIFO_DEPTH,
    RAM_TYPE             => "dist",
    ACKNOWLEDGE_MODE     => true
  )
  port map (
    clock         => clk, -- clock
    reset         => packet_fifo.rst, -- synchronous reset
    level         => packet_fifo.level,
    wr_ena        => packet_fifo.wr_ena,
    wr_din        => packet_fifo.wr_data,
    wr_full       => packet_fifo.wr_full,
    wr_prog_full  => packet_fifo.wr_prog_full,
    wr_overflow   => packet_fifo.wr_overflow,
    rd_req_ack    => packet_fifo.rd_ack,
    rd_dout       => packet_fifo.rd_data,
    rd_valid      => packet_fifo.rd_valid,
    rd_empty      => open,
    rd_prog_empty => packet_fifo.rd_prog_empty,
    rd_underflow  => open
  );

  -- Acknowledge a packet when reading from buffer is completed and get information about next packet from FIFO.
  packet_fifo.rd_ack <= read_clkena and packet_fifo.rd_valid when packet.transfer_count=0 else '0';

  p_packet_read: process(clk)
  begin
    if rising_edge(clk) then
      if packet_fifo.rst='1' then
        packet.transfer_valid <= '0';
        packet.transfer_count <= (others=>'0');
        packet.stream <= (others=>'-');
        packet.length <= (others=>'-');
      elsif read_clkena='1' then
        if packet.transfer_count=0 then
          if packet_fifo.rd_valid then
            packet.transfer_valid <= '1';
            packet.transfer_count <= unsigned(packet_fifo.rd_data(PACKET_SIZE_LOG2-1 downto 0));
            packet.stream <= unsigned(packet_fifo.rd_data(ID_WIDTH+PACKET_SIZE_LOG2-1 downto PACKET_SIZE_LOG2));
            packet.length <= unsigned(packet_fifo.rd_data(PACKET_SIZE_LOG2-1 downto 0));
          else
            packet.transfer_valid <= '0';
          end if;
        else
          packet.transfer_count <= packet.transfer_count - 1;
        end if;
      end if;
    end if;
  end process;


  -- write port mux before RAM input register
  ram_wr.addr_vld <= s_stream_q.tvalid;
  ram_wr.addr(RAM_ADDR_WIDTH-1 downto FIFO_DEPTH_LOG2) <= to_unsigned(sel_q,ID_WIDTH);
  ram_wr.addr(FIFO_DEPTH_LOG2-1 downto 0) <= fifo(sel_q).wr_ptr;
  ram_wr.data_vld <= ram_wr.addr_vld;
  ram_wr.data <= to_ram( data => s_stream_q.tdata,
                         last => packet_fifo.wr_ena,
                         keep => s_stream_q.tkeep,
                         strb => s_stream_q.tstrb,
                         user => s_stream_q.tuser,
                         dest => s_stream_q.tdest,
                         id   => s_stream_q.tid
                       );

  -- read port mux before RAM input register
  ram_rd.addr_vld <= packet.transfer_valid;
  ram_rd.addr(RAM_ADDR_WIDTH-1 downto FIFO_DEPTH_LOG2) <= packet.stream;
  ram_rd.addr(FIFO_DEPTH_LOG2-1 downto 0) <= fifo(to_integer(packet.stream)).rd_ptr;

  -- The RAM in connection with the request FIFO logic acts as data buffer and FIFO.
  i_ram : entity ramlib.ram_sdp
  generic map(
    WR_DATA_WIDTH => RAM_DATA_WIDTH,
    RD_DATA_WIDTH => RAM_DATA_WIDTH,
    WR_DEPTH => 2**RAM_ADDR_WIDTH,
    WR_USE_BYTE_ENABLE => false,
    WR_INPUT_REGS => RAM_INPUT_REGS,
    RD_INPUT_REGS => RAM_INPUT_REGS,
    RD_OUTPUT_REGS => RAM_OUTPUT_REGS,
    RAM_TYPE => RAM_TYPE,
    COMMON_CLOCK => true,
    INTERNAL_RD_LATENCY => -1,
    INIT_FILE => open
  )
  port map(
    wr_clk     => clk,
    wr_rst     => rst,
    wr_clk_en  => '1',
    wr_en      => ram_wr.addr_vld,
    wr_addr    => std_logic_vector(ram_wr.addr),
    wr_be      => open, -- unused
    wr_data    => ram_wr.data,
    rd_clk     => clk,
    rd_rst     => rst,
    rd_clk_en  => read_clkena,
    rd_en      => ram_rd.addr_vld,
    rd_addr    => std_logic_vector(ram_rd.addr),
    rd_data    => ram_rd.data,
    rd_data_en => ram_rd.data_vld
  );

  p_ram_pipe : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        packet_stream_q <= (others=>(others=>'0'));
        packet_length_q <= (others=>(others=>'0'));
      elsif read_clkena='1' then
        packet_stream_q(1) <= packet.stream;
        packet_stream_q(2 to RAM_READ_LATENCY) <= packet_stream_q(1 to RAM_READ_LATENCY-1);
        packet_length_q(1) <= packet.length;
        packet_length_q(2 to RAM_READ_LATENCY) <= packet_length_q(1 to RAM_READ_LATENCY-1);
      end if;
    end if;
  end process;

  -- pull (valid) data from buffer
  read_clkena <= m_tready_i or not ram_rd.data_vld;

  process(ram_rd, packet_stream_q, packet_length_q)
    variable s : work.pkg.axi4_s(
      tdata(s_stream.tdata'length-1 downto 0),
      tdest(s_stream.tdest'length-1 downto 0),
      tid(s_stream.tid'length-1 downto 0),
      tkeep(s_stream.tkeep'length-1 downto 0),
      tstrb(s_stream.tstrb'length-1 downto 0),
      tuser(USER_INPUT_WIDTH+MAX_PACKET_LENGTH_LOG2-1 downto 0)
    );
    variable m : m_stream_i'subtype;
  begin
    -- RAM output to AXI record
    s := from_ram( slv          => ram_rd.data,
                   valid        => ram_rd.data_vld,
                   stream       => packet_stream_q(RAM_READ_LATENCY),
                   packetlen    => packet_length_q(RAM_READ_LATENCY),
                   axi4s_format => s
                 );
    -- bypass with interface adjustments -> padding, trimming and some error checks
    work.pkg.bypass(
      s_stream       => s,
      m_stream       => m,
      TUSER_IGNORE   => TUSER_IGNORE,
      TUSER_ITEMWISE => TUSER_ITEMWISE
    );
    m_stream_i <= m;
  end process;

  -- output pipeline stages
  i_oreg : entity work.pipeline
  generic map(
    PIPESTAGES => OUTPUT_PIPESTAGES,
    CHECK_AXI_COMPLIANCE => false
  )
  port map(
    aclk     => clk,
    aresetn  => not rst, -- TODO
    s_stream => m_stream_i,
    s_tready => m_tready_i,
    m_stream => m_stream,
    m_tready => m_tready
  );

end architecture;
