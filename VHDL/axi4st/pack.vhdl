-------------------------------------------------------------------------------
-- @file       pack.vhdl
-- @author     Fixitfetish
-- @note       VHDL-2008
-- @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

use work.pkg.all;

-- Packing removes null items (TKEEP deasserted) and compresses the data stream.
-- All items of the output will have the corresponding TKEEP asserted.
-- Only the last items of a TLAST=1 transfer might have TKEEP deasserted.
-- TODO 1: USER signal.
-- TODO 2: what about different TID and TDEST ?
--
-- **Extensions to the AXI4-Stream standard**
-- * According to the AXI4-Streaming specification an item is 8 bits (1 byte) wide.
--   However, this module allows any item width. Each TSTRB/TKEEP bit corresponds to one item.
--   The item width at input and output must match of course.
--
-- **Limitations**
-- * TDEST width at input and output should match, otherwise output TDEST will be trimmed or padded
-- * TID width at input and output should match, otherwise output TID will be trimmed or padded
-- * Master and slave interface can have different user signal length but at both interfaces the
--   TUSER'length must be a multiple of TSTRB'length ... unless TUSER_IGNORE=true.
--   The user signal will trimmed or padded if the lengths do not match.
entity pack is
generic (
  -- Enable AXI pipeline input register(s). Multiple different stages can be configured
  -- but the last stage should always be ready_breakup, priming or primegating.
  INPUT_PIPESTAGES : a_pipestage := (0=>bypass);
  -- Enable AXI pipeline output register(s). Multiple different stages can be configured
  -- but the first stage should always be ready_breakup, priming or primegating.
  -- At least one stage is highly recommended.
  OUTPUT_PIPESTAGES : a_pipestage := (0=>priming);
  -- If the TDEST signal is ignored then all bits of output m_stream.tdest will be forced to zero.
  -- This setting is useful to avoid TDEST size matching issues when the TDEST signal is unused anyway.
  TDEST_IGNORE : boolean := false;
  -- If the TID signal is ignored then all bits of output m_stream.tid will be forced to zero.
  -- This setting is useful to avoid TID size matching issues when the TID signal is unused anyway.
  TID_IGNORE : boolean := false;
  -- If the TUSER signal is ignored then all bits of output m_stream.tuser will be forced to zero.
  -- This setting is useful to avoid TUSER size matching issues when the TUSER signal is unused anyway.
  TUSER_IGNORE : boolean := false
);
port(
  aclk     : in  std_logic;
  -- optional AXI reset, active-low, preferably do not connect and use pipelined s_stream.treset instead!
  aresetn  : in  std_logic := '1';
  -- input stream from master
  s_stream : in  work.pkg.axi4_s;
  -- ready signal towards master
  s_tready : out std_logic;
  -- output stream towards slave
  m_stream : out work.pkg.axi4_s;
  -- ready signal from slave
  m_tready : in  std_logic
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (s_stream.tdata'length mod s_stream.tkeep'length = 0)
    report pack'INSTANCE_NAME & "The master input TDATA width must be an integer multiple of the TKEEP width."
    severity failure;
  assert (s_stream.tdata'length = m_stream.tdata'length)
    report pack'INSTANCE_NAME & "The TDATA width of master input and slave output must match."
    severity failure;
  assert (m_stream.tuser'length mod m_stream.tstrb'length = 0) or TUSER_IGNORE
    report pack'INSTANCE_NAME & "In slave output the user width must be a multiple of the number of data items."
    severity failure;
  assert (s_stream.tuser'length mod s_stream.tstrb'length = 0) or TUSER_IGNORE
    report pack'INSTANCE_NAME & "In master input the user width must be a multiple of the number of data items."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;

-------------------------------------------------------------------------------

architecture rtl of pack is

  -- Each TSTRB/TKEEP bit corresponds to one item.
  constant N_ITEMS : positive := s_stream.tkeep'length;

  -- According to the AXI4-Streaming specification an item is 8 bits (1 byte) wide.
  -- However, this module allows any item width. The item width at input and output must match of course.
  constant ITEM_WIDTH : positive := s_stream.tdata'length / N_ITEMS;

  signal s_stream_i : s_stream'subtype;
  signal s_tready_i : s_tready'subtype;
  signal m_packed   : s_stream'subtype;
  signal m_stream_i : m_stream'subtype;
  signal m_tready_i : m_tready'subtype;

  -- Output user width before padding/trimming. Must be at least 1 if the USER signal is ignored.
  constant USER_WIDTH : positive := s_stream.tuser'length;

  -- slave will valid accept data with next clock edge
  signal slave_ce : std_logic;

  -- master will provide new data with next clock edge
  signal master_ce : std_logic;

  signal last_pending : std_logic := '0';

  -- item index offset
  signal idx_offset : natural range 0 to N_ITEMS := 0;

  -- output item buffer
  type a_item is array(integer range <>) of std_logic_vector(ITEM_WIDTH-1 downto 0);
  signal item : a_item(2*N_ITEMS-2 downto 0);
  signal item_tstrb : std_logic_vector(2*N_ITEMS-2 downto 0) := (others=>'0');
  signal item_tkeep : std_logic_vector(2*N_ITEMS-2 downto 0) := (others=>'0');

begin

  -- optional input pipeline stages
  i_ireg : entity work.pipeline
  generic map(
    PIPESTAGES => INPUT_PIPESTAGES,
    CHECK_AXI_COMPLIANCE => false
  )
  port map(
    aclk     => aclk,
    aresetn  => aresetn,
    s_stream => s_stream,
    s_tready => s_tready,
    m_stream => s_stream_i,
    m_tready => s_tready_i
  );

  -- pull new data from master
  -- * as long as output data is not complete and invalid
  -- * when slave is ready to accept data
  -- * when there is not an incomplete last transfer to slave pending 
  s_tready_i <= (m_tready_i and not last_pending) or not m_packed.tvalid;

  master_ce <= s_stream_i.tvalid and s_tready_i;

  p : process(aclk)
    variable idx : natural range 0 to 2*N_ITEMS-2;
  begin
    if rising_edge(aclk) then

      -- By default reset downstream valid when receiver accepts data in the same cycle.
      -- Overwrite downstream valid below when new data is provided.
      if m_tready_i='1' then
        m_packed.tvalid <= '0';
        m_packed.tlast  <= '0';
      end if;

      -- move remaining output items into next output window when previous window is transferred to slave
      if slave_ce='1' then
        item(N_ITEMS-2 downto 0) <= item(2*N_ITEMS-2 downto N_ITEMS); 
        item_tstrb(N_ITEMS-2 downto 0) <= item_tstrb(2*N_ITEMS-2 downto N_ITEMS); 
        item_tkeep(N_ITEMS-2 downto 0) <= item_tkeep(2*N_ITEMS-2 downto N_ITEMS); 
        item_tstrb(2*N_ITEMS-2 downto N_ITEMS) <= (others=>'0'); -- clear old, relevant in TLAST case
        item_tkeep(2*N_ITEMS-2 downto N_ITEMS) <= (others=>'0'); -- clear old, relevant in TLAST case
      end if;

      -- proceed with new valid input data
      if master_ce then
        idx := idx_offset;
  
        -- loop over all input items
        for n in 0 to N_ITEMS-1 loop
          if s_stream_i.tkeep(n) = '1' then
            -- move item from input to output
            item(idx) <= s_stream_i.tdata(ITEM_WIDTH*(n+1)-1 downto ITEM_WIDTH+n);
            item_tstrb(idx) <= s_stream_i.tstrb(n);
            item_tkeep(idx) <= '1';
            idx := idx + 1;
          end if;
        end loop;
        -- check if output transfer is complete 
        if idx >= N_ITEMS then
          -- mark output as complete and valid
          m_packed.tvalid <= '1';
          m_packed.tdest <= s_stream_i.tdest;
          m_packed.tid <= s_stream_i.tid;
          if idx = N_ITEMS then
            -- TLAST marks last item of transfer
            m_packed.tlast <= s_stream_i.tlast;
            last_pending <= '0';
          else
            -- TLAST marks one of the remaining items => incomplete transfer in next cycle
            last_pending <= '1';
          end if;
          idx_offset <= idx - N_ITEMS;
        else
          -- output is not yet complete
          m_packed.tlast <= s_stream_i.tlast;
          if s_stream_i.tlast then
            -- flush to output
            m_packed.tvalid <= '1';
            m_packed.tdest <= s_stream_i.tdest;
            m_packed.tid <= s_stream_i.tid;
            idx_offset <= 0;
          else  
            -- wait for next input and proceed with last index
            idx_offset <= idx;
          end if;
        end if;

      elsif last_pending then
        -- output incomplete transfer of remaining items
        m_packed.tvalid <= '1';
        m_packed.tlast <= '1';
        idx_offset <= 0;
        last_pending <= '0';
      end if;

      -- reset handling
      if s_stream_i.treset or not aresetn then
        m_packed.treset <= '1';
        m_packed.tvalid <= '0';
        m_packed.tlast  <= '0';
        idx_offset <= 0;
        last_pending <= '0';
      else
        m_packed.treset <= '0';    
      end if;

    end if;
  end process;

  p_map : process(item, item_tstrb, item_tkeep)
  begin
    for n in 0 to N_ITEMS-1 loop
      m_packed.tdata(ITEM_WIDTH*(n+1)-1 downto ITEM_WIDTH+n) <= item(n);
      m_packed.tstrb(n) <= item_tstrb(n);
      m_packed.tkeep(n) <= item_tkeep(n);
    end loop;
  end process;

  slave_ce <= m_packed.tvalid and m_tready_i;

  -- map output register to stream (incl. interface adjustments -> padding, trimming and some error checks)
  process(m_packed)
    variable m : m_stream_i'subtype; -- auxiliary variable for procedure output
  begin
    work.pkg.bypass(
      s_stream => m_packed,
      m_stream => m,
      TDEST_IGNORE => TDEST_IGNORE,
      TID_IGNORE => TID_IGNORE,
      TUSER_IGNORE => TUSER_IGNORE
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
    aclk     => aclk,
    aresetn  => aresetn,
    s_stream => m_stream_i,
    s_tready => m_tready_i,
    m_stream => m_stream,
    m_tready => m_tready
  );

end architecture;
