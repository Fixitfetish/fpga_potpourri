library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;
library axi;
  use axi.pkg.all;
library axi4mm;

-- This module converts an AXI4S input stream into an AXI4MM write access (channels AW and W).
--
-- AXI4S and AXI4MM data width must be the same, hence typically you have to upsize or downsize
-- the AXI4S input to match the AXI4MM data width.
-- Efficient AXI4MM transfers require burst support, hence the input stream should be buffered and split into packets/bursts.
-- This module intentionally does not include any buffers because each use case requires a different buffering concept.
-- Hence, an additional AXI4S buffer should be placed at the input of this module, e.g. the axi4s.packet_former .
--
-- **Pipelining** should be preferably done at the AXI4S input rather than the AXI4MM output, simply because it is
-- less complex to pipeline a AXI4S stream. Hence, this module should be located as close to the AXI4MM slave as possible.
-- The entity generics provide pipelining support.
--
-- **TUSER input**: Since this entity does not include any buffers this interface expects a TUSER
-- signal per transfer (not byte-wise) with a special format:
-- * TUSER(7 downto 0):  AXI4MM compatible burst length of current packet/burst
-- * TUSER(8)         :  0=data , 1=address header
-- * additional TUSER bits are ignored.
--
entity to_axi4mm_write is
generic(
  -- Number of interleaved input streams. Streams must be numbered without gaps: 0,1,2,3,..
  NUM_STREAMS : positive;
  -- Interleaved stream number according to "DEST" or "ID".
  MODE : string := "ID";
  -- Data word address width at user input and RAM output ports
  ADDR_WIDTH : positive;
  -- Enable AXI4S pipeline input register(s). Multiple different stages can be configured.
  AXI4S_INPUT_PIPESTAGES : a_pipestage := (0=>bypass);
  -- Enable AXI4MM pipeline output register(s) for channels AW and W. Multiple different stages can be configured.
  AXI4MM_OUTPUT_PIPESTAGES : a_pipestage := (0=>bypass)
);
port(
  -- AXI clock
  clk            : in  std_logic;
  -- Synchronous reset
  rst            : in  std_logic;
  -- Incoming interleaved streams(s) from master.
  s_stream       : in  work.pkg.axi4s;
  -- outgoing ready towards master
  s_tready       : out std_logic;
  -- AXI4MM AW channel towards slave
  axi4mm_aw      : out axi4mm.pkg.axi4_a;
  -- AXI4MM W channel towards slave
  axi4mm_w       : out axi4mm.pkg.axi4_w;
  -- AXI4MM B channel from slave
  axi4mm_b       : in  axi4mm.pkg.axi4_b;
  -- AXI4MM AW channel ready from slave
  axi4mm_awready : in  std_logic;
  -- AXI4MM W channel ready from slave
  axi4mm_wready  : in  std_logic;
  -- AXI4MM B channel ready towards slave
  axi4mm_bready  : out std_logic
);
begin
  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (MODE="DEST" or MODE="ID")
    report to_axi4mm_write'INSTANCE_NAME & " Selected mode must be DEST or ID to extract interleaved stream number."
    severity failure;
  assert (s_stream.tuser'length>=9)
    report to_axi4mm_write'INSTANCE_NAME &
           " The width of the s_stream.tuser input is smaller than 9 bits and therefore not compatible." &
           " Bits 7..0 must include the burst length and bit 8 must be the address flag."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)
end entity;

---------------------------------------------------------------------------------------------------

architecture rtl of to_axi4mm_write is

  constant AXI4MM_DATA_BYTES : positive := axi4mm_w.data'length / 8;
  constant AXI4MM_DATA_BYTES_LOG2 : natural := integer(log2(real(AXI4MM_DATA_BYTES)));

  function get_stream(s:unsigned) return natural is
    variable sint : natural range 0 to 2**s'length-1;
  begin
    sint := to_integer(s);
    assert (sint<NUM_STREAMS)
      report to_axi4mm_write'INSTANCE_NAME & 
             " Index specified in s_stream input TDEST or TID exceeds number of supported streams."
      severity failure;
    return sint;
  end function;

  signal s_stream_i : s_stream'subtype;
  signal s_tready_i : s_tready'subtype;

  -- indicate whether a AXI4S transfer will happen with the next clock edge
  signal s_transfer : std_logic;

  signal s_index : integer range 0 to NUM_STREAMS-1;
  signal addr_transfer : std_logic;

  -- actual length of burst is burst_length+1 cycles (according to AXI4MM standard)
  signal burst_length : unsigned(7 downto 0);

  type a_addr is array(integer range <>) of unsigned(ADDR_WIDTH-1 downto 0);

  signal next_addr : a_addr(NUM_STREAMS-1 downto 0);
  signal next_first : std_logic_vector(NUM_STREAMS-1 downto 0);

  -- indicate whether a AXI4MM transfer on channel AW or W will happen with the next clock edge
  signal m_aw_transfer, m_w_transfer : std_logic;

  -- indicate whether the AXI4MM channel AW or W pull for more transfers
  signal m_aw_pull, m_w_pull : std_logic;

  signal axi4mm_aw_i : axi4mm_aw'subtype;
  signal axi4mm_w_i : axi4mm_w'subtype;
  signal axi4mm_wready_i : axi4mm_wready'subtype;
  signal axi4mm_awready_i : axi4mm_awready'subtype;

begin

  -- AXI4S conform input register
  i_ireg : entity work.pipeline
  generic map(
    PIPESTAGES => AXI4S_INPUT_PIPESTAGES,
    CHECK_AXI_COMPLIANCE => false
  )
  port map(
    clk      => clk,
    rst      => rst,
    s_stream => s_stream,
    s_tready => s_tready,
    m_stream => s_stream_i,
    m_tready => s_tready_i
  );

  -- Notes
  -- * address transfers can always be accepted immediately 
  -- * the first transfer of a burst requires the AW and W channel to be ready
  -- * further transfers of a burst only require the W channel to be ready
  s_tready_i <= addr_transfer or 
                (m_aw_pull and m_w_pull and next_first(s_index)) or
                (m_w_pull and not next_first(s_index));

  s_transfer <= s_stream_i.tvalid and s_tready_i;

  s_index <= get_stream(unsigned(s_stream_i.tdest)) when MODE="DEST" else
             get_stream(unsigned(s_stream_i.tid))   when MODE="ID";

  addr_transfer <= s_stream_i.tuser(8);
  burst_length  <= unsigned(s_stream_i.tuser(7 downto 0));

  -- The following process keeps track of addresses and burst starts, for each stream separately.
  p_addr : process(clk)
    variable v_addr : s_stream_i.tdata'subtype;
  begin
    if rising_edge(clk) then
      if rst='1' then
        next_addr  <= (others=>(others=>'0')); -- TODO: addr '-'
        next_first <= (others=>'1');
      elsif s_transfer='1' then
        if addr_transfer='1' then
          if s_stream_i.tlast='1' then
            -- receive new address
            -- TODO: multi-cycle address header
            v_addr := s_stream_i.tdata;
            for b in s_stream_i.tstrb'range loop
              if s_stream_i.tstrb(b)='0' then
                v_addr(8*b+7 downto 8*b) := (others=>'0');
              end if;
            end loop;
            -- An address reset always terminates the previous burst, hence a new burst must follow next.
            next_addr(s_index)  <= unsigned(v_addr(ADDR_WIDTH-1 downto 0));
            next_first(s_index) <= '1';
            assert (unsigned(v_addr(AXI4MM_DATA_BYTES_LOG2-1 downto 0))=0)
              report "axi4s.to_axi4mm_write: Incoming address must be aligned to TDATA width, stream index=" & integer'image(s_index)
              severity failure;
          end if;
        else
          -- Increment address with every data transfer and predict start of new bursts.
          next_addr(s_index)  <= next_addr(s_index) + AXI4MM_DATA_BYTES;
          next_first(s_index) <= s_stream_i.tlast;
        end if;
      end if;
    end if;
  end process;


  -- AXI4MM channel AW ----------------------------------------------------------------------------
  p_aw : process(clk)
  begin
    if rising_edge(clk) then
      axi4mm_aw_i.burst  <= "01";
      axi4mm_aw_i.cache  <= (others=>'0');
      axi4mm_aw_i.lock   <= '0';
      axi4mm_aw_i.prot   <= (others=>'0');
      axi4mm_aw_i.qos    <= (others=>'0');
      axi4mm_aw_i.region <= (others=>'0');
      axi4mm_aw_i.size   <= std_logic_vector(to_unsigned(AXI4MM_DATA_BYTES_LOG2,axi4mm_aw_i.size'length));
      axi4mm_aw_i.user   <= std_logic_vector(to_unsigned(0,axi4mm_aw_i.user'length));
      if rst='1' then
        axi4mm_aw_i.valid <= '0';
      else
        -- by default reset valid when slave accepts transfer
        if m_aw_transfer='1' then
          axi4mm_aw_i.valid <= '0';
        end if;
        -- Check if a new transfer is waiting which might require a new address write request.
        -- Only one address write request at the beginning of each burst.
        if s_transfer='1' and addr_transfer='0' and next_first(s_index)='1' then
          axi4mm_aw_i.addr  <= std_logic_vector(resize(next_addr(s_index),axi4mm_aw_i.addr'length));
          axi4mm_aw_i.id    <= std_logic_vector(to_unsigned(s_index,axi4mm_aw_i.id'length));
          axi4mm_aw_i.len   <= std_logic_vector(burst_length);
          axi4mm_aw_i.valid <= '1';
        end if;
      end if;
    end if;
  end process;

  m_aw_transfer <= axi4mm_awready_i and axi4mm_aw_i.valid;
  m_aw_pull     <= axi4mm_awready_i or not axi4mm_aw_i.valid;

  i_oreg_aw : entity axi4mm.pipeline_addr
  generic map(
    PIPESTAGES => AXI4MM_OUTPUT_PIPESTAGES,
    CHECK_AXI_COMPLIANCE => false
  )
  port map(
    clk          => clk,
    slave_data   => axi4mm_aw,
    slave_ready  => axi4mm_awready,
    master_data  => axi4mm_aw_i,
    master_ready => axi4mm_awready_i
  );


  -- AXI4MM channel W -----------------------------------------------------------------------------
  p_w : process(clk)
  begin
    if rising_edge(clk) then
      axi4mm_w_i.strb  <= (others=>'1');
      axi4mm_w_i.user  <= std_logic_vector(to_unsigned(0,axi4mm_w_i.user'length));
      if rst='1' then
        axi4mm_w_i.last  <= '0';
        axi4mm_w_i.valid <= '0';
      else
        -- by default reset valid when slave accepts transfer
        if m_w_transfer='1' then
          axi4mm_w_i.valid <= '0';
        end if;
        -- check if a new data transfer is waiting
        if s_transfer='1' and addr_transfer='0' then
          axi4mm_w_i.data  <= s_stream_i.tdata;
          axi4mm_w_i.last  <= s_stream_i.tlast;
          axi4mm_w_i.valid <= '1';
        end if;
      end if;
    end if;
  end process;

  m_w_transfer  <= axi4mm_wready_i  and axi4mm_w_i.valid;
  m_w_pull      <= axi4mm_wready_i  or not axi4mm_w_i.valid;

  i_oreg_w : entity axi4mm.pipeline_write
  generic map(
    PIPESTAGES => AXI4MM_OUTPUT_PIPESTAGES,
    CHECK_AXI_COMPLIANCE => false
  )
  port map(
    clk          => clk,
    slave_data   => axi4mm_w,
    slave_ready  => axi4mm_wready,
    master_data  => axi4mm_w_i,
    master_ready => axi4mm_wready_i
  );


  -- AXI4MM channel B -----------------------------------------------------------------------------

  -- pull write responses but ignore for now
  axi4mm_bready <= '1';

end architecture;
