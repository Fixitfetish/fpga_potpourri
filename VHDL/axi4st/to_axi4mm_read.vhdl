library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;
library axi;
  use axi.pkg.all;
library axi4mm;

-- This module converts an AXI4S input stream into an AXI4MM read access (channel AR) and
-- an AXI4MM read response (channel R) into an AXI4S output stream.
--
-- **TUSER input**: Since this entity does not include any buffers this interface expects
-- a axi4s_req_stream.tuser signal per transfer (not byte-wise) with a special format:
-- * TUSER(7 downto 0):  AXI4MM compatible burst length of current packet/burst
-- * TUSER(8)         :  0=data , 1=address header
-- * additional TUSER bits are ignored.
--
entity to_axi4mm_read is
generic(
  -- Number of interleaved input streams. Streams must be numbered without gaps: 0,1,2,3,..
  NUM_STREAMS : positive;
  -- Interleaved stream number according to "DEST" or "ID".
  MODE : string := "ID";
  -- Data word address width at user input and RAM output ports
  ADDR_WIDTH : positive;
  -- Enable AXI4S request pipeline input register(s). Multiple different stages can be configured.
  AXI4S_INPUT_PIPESTAGES : a_pipestage := (0=>bypass);
  -- Enable AXI4S response pipeline output register(s). Multiple different stages can be configured.
  AXI4S_OUTPUT_PIPESTAGES : a_pipestage := (0=>bypass);
  -- Enable AXI4MM pipeline output register(s) for channel AR. Multiple different stages can be configured.
  AXI4MM_OUTPUT_PIPESTAGES : a_pipestage := (0=>bypass);
  -- Enable AXI4MM pipeline input register(s) for channel R. Multiple different stages can be configured.
  AXI4MM_INPUT_PIPESTAGES : a_pipestage := (0=>bypass)
);
port(
  -- AXI clock
  clk              : in  std_logic;
  -- Synchronous reset
  rst              : in  std_logic;
  -- Incoming read request streams(s) from master.
  axi4s_req_stream : in  work.pkg.axi4s;
  -- Outgoing request ready towards master
  axi4s_req_tready : out std_logic;
  -- Outgoing read response streams(s) towards master.
  axi4s_res_stream : out work.pkg.axi4s;
  -- Incoming response ready from master
  axi4s_res_tready : in  std_logic;
  -- AXI4MM AR channel towards slave
  axi4mm_ar        : out axi4mm.pkg.axi4_a;
  -- AXI4MM R channel from slave
  axi4mm_r         : in  axi4mm.pkg.axi4_r;
  -- AXI4MM AW channel ready from slave
  axi4mm_arready   : in  std_logic;
  -- AXI4MM R channel ready towards slave
  axi4mm_rready    : out std_logic
);
begin
  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (MODE="DEST" or MODE="ID")
    report to_axi4mm_read'INSTANCE_NAME & " Selected mode must be DEST or ID to extract interleaved stream number."
    severity failure;
  assert (axi4s_req_stream.tuser'length >= 9)
    report to_axi4mm_read'INSTANCE_NAME &
           " The width of the axi4s_req_stream.tuser input is smaller than 9 bits and therefore not compatible." &
           " Bits 7..0 must include the burst length and bit 8 must be the address flag."
    severity failure;
  assert (axi4s_res_stream.tdata'length = axi4mm_r.data'length)
    report to_axi4mm_read'INSTANCE_NAME &
           " The data width of axi4mm_r input and axi4s_res_stream output must match."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)
end entity;

---------------------------------------------------------------------------------------------------

architecture rtl of to_axi4mm_read is

  constant AXI4MM_DATA_BYTES : positive := axi4mm_r.data'length / 8;
  constant AXI4MM_DATA_BYTES_LOG2 : natural := integer(log2(real(AXI4MM_DATA_BYTES)));

  function get_stream(s:unsigned) return natural is
    variable sint : natural range 0 to 2**s'length-1;
  begin
    sint := to_integer(s);
    assert (sint<NUM_STREAMS)
      report to_axi4mm_read'INSTANCE_NAME & 
             " Index specified in s_stream input TDEST or TID exceeds number of supported streams."
      severity failure;
    return sint;
  end function;

  signal s_stream_i : axi4s_req_stream'subtype;
  signal s_tready_i : axi4s_req_tready'subtype;

  -- indicate whether a AXI4S transfer will happen with the next clock edge
  signal s_transfer : std_logic;

  signal s_index : integer range 0 to NUM_STREAMS-1;
  signal addr_transfer : std_logic;

  -- actual length of burst is burst_length+1 cycles (according to AXI4MM standard)
  signal burst_length : unsigned(7 downto 0);

  type a_addr is array(integer range <>) of unsigned(ADDR_WIDTH-1 downto 0);

  signal next_addr : a_addr(NUM_STREAMS-1 downto 0);
  signal next_first : std_logic_vector(NUM_STREAMS-1 downto 0);

  -- indicate whether a AXI4MM transfer on channel AR will happen with the next clock edge
  signal a_transfer : std_logic;

  -- indicate whether the AXI4MM channel AR pull for more transfers
  signal a_pull : std_logic;

  signal axi4mm_a : axi4mm_ar'subtype;
  signal axi4mm_aready : axi4mm_rready'subtype;
  signal axi4mm_r_i : axi4mm_r'subtype;
  signal axi4mm_rready_i : axi4mm_rready'subtype;
  signal axi4s_res_stream_i : axi4s_res_stream'subtype;
  signal axi4s_res_tready_i : axi4s_res_tready'subtype;

begin

  -- Request Channel ------------------------------------------------------------------------------

  -- AXI4S conform input register
  ireg_axi4s : entity work.pipeline
  generic map(
    PIPESTAGES => AXI4S_INPUT_PIPESTAGES,
    CHECK_AXI_COMPLIANCE => false
  )
  port map(
    clk      => clk,
    rst      => rst,
    s_stream => axi4s_req_stream,
    s_tready => axi4s_req_tready,
    m_stream => s_stream_i,
    m_tready => s_tready_i
  );

  -- Notes
  -- * address transfers can always be accepted immediately 
  s_tready_i <= addr_transfer or a_pull;

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
              report "axi4s.to_axi4mm_read: Incoming address must be aligned to TDATA width, stream index=" & integer'image(s_index)
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
      axi4mm_a.burst  <= "01";
      axi4mm_a.cache  <= (others=>'0');
      axi4mm_a.lock   <= '0';
      axi4mm_a.prot   <= (others=>'0');
      axi4mm_a.qos    <= (others=>'0');
      axi4mm_a.region <= (others=>'0');
      axi4mm_a.size   <= std_logic_vector(to_unsigned(AXI4MM_DATA_BYTES_LOG2,axi4mm_a.size'length));
      axi4mm_a.user   <= std_logic_vector(to_unsigned(0,axi4mm_a.user'length));
      if rst='1' then
        axi4mm_a.valid <= '0';
      else
        -- by default reset valid when slave accepts transfer
        if a_transfer='1' then
          axi4mm_a.valid <= '0';
        end if;
        -- Check if a new transfer is waiting which might require a new address write request.
        -- Only one address write request at the beginning of each burst.
        if s_transfer='1' and addr_transfer='0' and next_first(s_index)='1' then
          axi4mm_a.addr  <= std_logic_vector(resize(next_addr(s_index),axi4mm_a.addr'length));
          axi4mm_a.id    <= std_logic_vector(to_unsigned(s_index,axi4mm_a.id'length));
          axi4mm_a.len   <= std_logic_vector(burst_length);
          axi4mm_a.valid <= '1';
        end if;
      end if;
    end if;
  end process;

  a_transfer <= axi4mm_aready and axi4mm_a.valid;
  a_pull     <= axi4mm_aready or not axi4mm_a.valid;

  oreg_axi4mm : entity axi4mm.pipeline_addr
  generic map(
    PIPESTAGES => AXI4MM_OUTPUT_PIPESTAGES,
    CHECK_AXI_COMPLIANCE => false
  )
  port map(
    clk          => clk,
    slave_data   => axi4mm_ar,
    slave_ready  => axi4mm_arready,
    master_data  => axi4mm_a,
    master_ready => axi4mm_aready
  );


  -- Response Channel -----------------------------------------------------------------------------

  ireg_axi4mm : entity axi4mm.pipeline_read
  generic map(
    PIPESTAGES => AXI4MM_INPUT_PIPESTAGES,
    CHECK_AXI_COMPLIANCE => false
  )
  port map(
    clk          => clk,
    slave_data   => axi4mm_r,
    slave_ready  => axi4mm_rready,
    master_data  => axi4mm_r_i,
    master_ready => axi4mm_rready_i
  );

  assert (axi4s_res_stream_i.tid'length>=axi4mm_r_i.id'length)
    report "axi4s.to_axi4mm_read: Response ID must be trimmed to " & integer'image(axi4s_res_stream_i.tid'length) & " bits."
    severity warning;

  process(axi4mm_r_i.id)
  begin
    if axi4s_res_stream_i.tid'length<axi4mm_r_i.id'length then
      axi4s_res_stream_i.tid <= axi4mm_r_i.id(axi4s_res_stream_i.tid'length-1 downto 0); -- ID trimming
    else
      axi4s_res_stream_i.tid <= (others=>'0');
      axi4s_res_stream_i.tid(axi4mm_r_i.id'length-1 downto 0) <= axi4mm_r_i.id; -- ID padding
    end if;
  end process;

  axi4s_res_stream_i.tdata  <= axi4mm_r_i.data;
  axi4s_res_stream_i.tdest  <= (others=>'0');
  axi4s_res_stream_i.tkeep  <= (others=>'1'); -- returned data bytes are assumed to be all valid
  axi4s_res_stream_i.tlast  <= axi4mm_r_i.last;
  axi4s_res_stream_i.tstrb  <= (others=>'1'); -- returned data bytes are assumed to be all valid
  axi4s_res_stream_i.tuser  <= (others=>'0'); -- separate user signal, because axi4mm_r.user and r.tuser are probably not compatible
  axi4s_res_stream_i.tvalid <= axi4mm_r_i.valid;

  axi4mm_rready_i <= axi4s_res_tready_i;

  -- AXI4S conform output register
  oreg_axi4s : entity work.pipeline
  generic map(
    PIPESTAGES => AXI4S_OUTPUT_PIPESTAGES,
    CHECK_AXI_COMPLIANCE => false
  )
  port map(
    clk      => clk,
    rst      => rst,
    s_stream => axi4s_res_stream_i,
    s_tready => axi4s_res_tready_i,
    m_stream => axi4s_res_stream,
    m_tready => axi4s_res_tready
  );

end architecture;
