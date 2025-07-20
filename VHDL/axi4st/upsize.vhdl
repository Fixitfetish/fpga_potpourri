-------------------------------------------------------------------------------
-- @file       upsize.vhdl
-- @author     Fixitfetish
-- @note       VHDL-2008
-- @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

  use work.pkg.all;

-- Upsize the upstream transmitter data width by an integer ratio (1,2,3,4,5,..) for downstream receivers with larger data width.
--
-- **Extensions to the AXI4-Stream standard**
-- * According to the AXI4-Streaming specification an item is 8 bits (1 byte) wide.
--   However, this module allows any item width. Each TSTRB/TKEEP bit corresponds to one item.
--   The item width at input and output must match of course.
-- * The AXI4-Streaming specification defines/recommends a 2^n number of items (bytes) in TDATA.
--   Hence, the upsize ratio must also be a power-of-2.
--   However, this module allows any positive integer number of items in TDATA and
--   therefore also any positive integer upsize ratio.
--
-- At the end of an input packet (TLAST=1) the output transfer will be completed.
-- Unused items (bytes) will be padded and marked as position items (TSTRB=0 and TKEEP=1).
-- In this case, also the output TLAST flag will be set.
-- Hence, frequent short input packets can cause very inefficient upsizing.
-- Note that at the output there will be always at least RATIO-1 invalid cycles between
-- two transfers. This is important for following stages since it simplifies the
-- implementation of clock divider, arbiter, etc.
--
-- There is limited multi-stream support for TID and TDEST interleaving.
-- An TID or TDEST change is only allowed in the following cases.
-- * The previous input transfer before the TID or TDEST change had the TLAST flag set.
-- * The input transfers of an TID/TDEST come in bursts which are aligned to the output transfer size.
--
-- The **TUSER Signal** of the master and slave interface can have different lengths.
-- The TUSER signal is trimmed/padded automatically but consider the following
-- * Set USER_IGNORE=true if the user signal is unused.
-- * If USER_ITEMWISE=true then the tuser'length at the input and output must be a multiple of tstrb'length.
-- * If USER_ITEMWISE=false then the tuser'length at the output should be greater or equal than at the input.
--   All consecutive input transfers that merge into the same output transfer must have identical user signal contents.
--
-- **Notes**
-- * TDEST width at input and output should match, otherwise output TDEST will be trimmed or padded
-- * TID width at input and output should match, otherwise output TID will be trimmed or padded
-- * NULL items (bytes) are neither touched nor removed
-- * This module intentionally only includes the really required flip-flops. The user can easily
--   add more pipeline stages as needed for the design and to meet the timing.
-- * For better timing it is recommended to place a ready-breakup pipeline stage directly in-front
--   of the input. Also more/other pipeline stages are possible, but they should be preferably
--   at the input because the input data width is smaller and the output is registered anyway.
entity upsize is
generic (
  -- Enable AXI pipeline input register(s). Multiple different stages can be configured
  -- but the last stage should always be ready_breakup, priming or primegating.
  INPUT_PIPESTAGES : a_pipestage := (0=>bypass);
  -- Enable AXI pipeline output register(s). Multiple different stages can be configured.
  -- Note that one output priming pipeline stage is always included.
  OUTPUT_PIPESTAGES : a_pipestage := (0=>bypass);
  -- If compression is enabled then an upsized (padded) unit will immediately be output after the LAST flag 
  -- without additional clock cycles for padding. The s_tready will remain HIGH in this case.
  -- Hence, there might not always be RATIO-1 invalid cycles between two output transfers.
  -- This feature can be useful to maintain the highest possible throughput even if the LAST flag splits a stream into separate packets.
  COMPRESSION : boolean := false;
  -- If the TDEST signal is ignored then all bits of output m_stream.tdest will be forced to zero.
  -- This setting is useful to avoid TDEST size matching issues when the TDEST signal is unused anyway.
  TDEST_IGNORE : boolean := false;
  -- If the TID signal is ignored then all bits of output m_stream.tid will be forced to zero.
  -- This setting is useful to avoid TID size matching issues when the TID signal is unused anyway.
  TID_IGNORE : boolean := false;
  -- If the TUSER signal is ignored then all bits of output m_stream.tuser will be forced to zero.
  -- This setting is useful to avoid TUSER size matching issues when the TUSER signal is unused anyway.
  TUSER_IGNORE : boolean := false;
  -- Disable this option if the TUSER signal of master and slave are related to a complete transfer
  -- rather than individual items (bytes). Trimming/Padding adjusts accordingly. (see spec ARM IHI 0051A, chap 2.8)
  TUSER_ITEMWISE : boolean := true
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
  assert (s_stream.tdata'length mod s_stream.tstrb'length = 0)
    report upsize'INSTANCE_NAME & "The master input TDATA width must be an integer multiple of the TSTRB width."
    severity failure;
  assert (m_stream.tdata'length mod m_stream.tstrb'length = 0)
    report upsize'INSTANCE_NAME & "The slave output TDATA width must be an integer multiple of the TSTRB width."
    severity failure;
  assert (m_stream.tdata'length mod s_stream.tdata'length = 0) and (m_stream.tstrb'length mod s_stream.tstrb'length = 0)
    report upsize'INSTANCE_NAME & "The slave output TDATA and TSTRB width must be an integer multiple of the master input TDATA and TSTRB width."
    severity failure;
  assert (m_stream.tuser'length mod m_stream.tstrb'length = 0) or TUSER_IGNORE
    report upsize'INSTANCE_NAME & " In m_stream output the user width must be a multiple of the number of data items (bytes)."
    severity failure;
  assert (s_stream.tuser'length mod s_stream.tstrb'length = 0) or TUSER_IGNORE
    report upsize'INSTANCE_NAME & " In s_stream input the user width must be a multiple of the number of data items (bytes)."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;

-------------------------------------------------------------------------------

architecture rtl of upsize is

  -- According to the AXI4-Streaming specification an item is 8 bits (1 byte) wide.
  -- However, this module allows any item width. Each TSTRB/TKEEP bit corresponds to one item.
  -- The item width at input and output must match of course.
  constant ITEM_WIDTH : positive := s_stream.tdata'length / s_stream.tstrb'length;

  -- The AXI4-Streaming specification defines/recommends a 2^n number of items (bytes) in TDATA.
  -- Hence,the upsize ratio must also be a power of 2.
  -- However, this module allows any positive integer number of items in TDATA and
  -- therefore also any positive integer upsize ratio.
  constant RATIO : positive := m_stream.tdata'length / s_stream.tdata'length;

  -- Items per upsize unit. A unit is transferred as it is and is not touched during upsizing.
  -- Only if TKEEP=0 marks all items of a unit as null items and packing is enabled then a unit can be removed from the stream.
  constant UNIT_ITEMS : positive := s_stream.tstrb'length;
  constant UNIT_WIDTH : positive := UNIT_ITEMS * ITEM_WIDTH;

  signal s_stream_i : s_stream'subtype;
  signal s_tready_i : s_tready'subtype;
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
    aclk     => aclk,
    aresetn  => aresetn,
    s_stream => s_stream,
    s_tready => s_tready,
    m_stream => s_stream_i,
    m_tready => s_tready_i
  );

  g_bypass : if RATIO=1 generate
    -- bypass with interface adjustments -> padding, trimming and some error checks
    process(s_stream_i)
      variable m : m_stream_i'subtype; -- auxiliary variable for procedure output
    begin
      work.pkg.bypass(
        s_stream => s_stream_i,
        m_stream => m,
        TDEST_IGNORE => TDEST_IGNORE,
        TID_IGNORE => TID_IGNORE,
        TUSER_IGNORE => TUSER_IGNORE,
        TUSER_ITEMWISE => TUSER_ITEMWISE
      );
      m_stream_i <= m;
    end process;
    s_tready_i <= m_tready_i;
  end generate;

  g_up : if RATIO>=2 generate
    impure function USER_SLAVE_LENGTH return positive is
    begin
      if TUSER_ITEMWISE or TUSER_IGNORE then
        return s_stream.tuser'length;
      else
        return (RATIO * s_stream.tuser'length);
      end if;
    end function;

    signal slave : work.pkg.axi4_s(
      tdata(RATIO*UNIT_WIDTH - 1 downto 0),
      tdest(s_stream.tdest'length - 1 downto 0),
      tid(s_stream.tid'length - 1 downto 0),
      tkeep(RATIO*UNIT_ITEMS - 1 downto 0),
      tstrb(RATIO*UNIT_ITEMS - 1 downto 0),
      tuser(USER_SLAVE_LENGTH - 1 downto 0)
    ) := (
      tdata  => (others=>'-'),
      tdest  => (others=>'-'),
      tid    => (others=>'-'),
      tkeep  => (others=>'-'),
      tstrb  => (others=>'-'),
      tuser  => (others=>'-'),
      tlast  => '0',
      tvalid => '0',
      treset => '1'
    );

    signal slave_pause : std_logic; -- slave is not ready to accept available data (back-pressure)
    signal slave_ce : std_logic; -- slave will accept data with next clock edge
    signal master_ce : std_logic; -- master will provide new data with next clock edge
    signal sel : std_logic_vector(0 to RATIO-1) := (others=>'0');
    signal padding : std_logic := '0'; -- if true then pad position items (bytes) to complete output transfer
    signal reset : boolean;

  begin

    reset <= (aresetn='0') or (s_stream_i.treset='1');
    s_tready_i <= (not padding) and (not slave_pause);
    master_ce <= s_stream_i.tvalid and s_tready_i;

    p_sel: process(aclk)
    begin
      if rising_edge(aclk) then
        if master_ce='1' or padding='1' then
          sel <= sel ror 1;
        end if;
        if reset or (COMPRESSION and master_ce='1' and s_stream_i.tlast='1') then
          sel(0) <= '1';
          sel(1 to RATIO-1) <= (others=>'0');
        end if;
      end if;
    end process;

    -- Start padding after TLAST flag. Once a slave transfer unit is completed stop padding and
    -- wait for new input from master to start with next transfer unit.
    padding <= '0' when (sel(0)='1' or COMPRESSION) else slave.tlast;

    p_data: process(aclk)
    begin
      if rising_edge(aclk) then

        for i in 0 to RATIO-1 loop
          if (master_ce='1' or padding='1') and sel(i)='1' then

            if i=0 and COMPRESSION then
              -- prefill output transfer unit with NULL items (bytes)
              slave.tkeep <= (slave.tkeep'range => '0');
              slave.tstrb <= (slave.tkeep'range => '0');
            end if;

            slave.tdata(UNIT_WIDTH*(i+1)-1 downto UNIT_WIDTH*i) <= s_stream_i.tdata;
            slave.tstrb(UNIT_ITEMS*(i+1)-1 downto UNIT_ITEMS*i) <= s_stream_i.tstrb;
            slave.tkeep(UNIT_ITEMS*(i+1)-1 downto UNIT_ITEMS*i) <= s_stream_i.tkeep;
            if TUSER_ITEMWISE and (not TUSER_IGNORE) then
              slave.tuser(USER_SLAVE_LENGTH*(i+1)-1 downto USER_SLAVE_LENGTH*i) <= s_stream_i.tuser;
            end if;

            if slave.tlast='1' and i/=0 then
              -- pad null items (bytes) to complete unit transfer towards slave
              slave.tdata(UNIT_WIDTH*(i+1)-1 downto UNIT_WIDTH*i) <= (others=>'-'); -- TODO: optional
              slave.tstrb(UNIT_ITEMS*(i+1)-1 downto UNIT_ITEMS*i) <= (others=>'0');
              slave.tkeep(UNIT_ITEMS*(i+1)-1 downto UNIT_ITEMS*i) <= (others=>'0');
              if TUSER_ITEMWISE and (not TUSER_IGNORE) then
                slave.tuser(USER_SLAVE_LENGTH*(i+1)-1 downto USER_SLAVE_LENGTH*i) <= (others=>'0');
              end if;
            end if;

            if i=0 then
              slave.tlast <= s_stream_i.tlast;
              slave.tdest <= s_stream_i.tdest;
              slave.tid   <= s_stream_i.tid;
              if (not TUSER_ITEMWISE) and (not TUSER_IGNORE) then
                slave.tuser <= s_stream_i.tuser;
              end if;
            else
              if COMPRESSION then
                slave.tlast <= s_stream_i.tlast;
              else
                -- hold LAST flag during padding
                slave.tlast <= s_stream_i.tlast or slave.tlast;
              end if;
              assert (slave.tdest=s_stream_i.tdest or slave.tlast='1')
                report  upsize'INSTANCE_NAME & " Unaligned input stream TDEST change without prior TLAST flag."
                severity failure;
              assert (slave.tid=s_stream_i.tid or slave.tlast='1')
                report  upsize'INSTANCE_NAME & " Unaligned input stream TID change without prior TLAST flag."
                severity failure;
              assert (slave.tuser=s_stream_i.tuser or slave.tlast='1' or TUSER_ITEMWISE or TUSER_IGNORE)
                report  upsize'INSTANCE_NAME & " Unaligned non-itemwise user input signal change without prior TLAST flag."
                severity failure;
            end if;
          end if;
        end loop;

        if TUSER_IGNORE then
          slave.tuser <= (others=>'-');
        end if;

      end if;
    end process;

    p_valid: process(aclk)
    begin
      if rising_edge(aclk) then
        if slave_ce='1' then
          slave.tvalid <= '0';
        end if;

        if COMPRESSION and master_ce='1' and s_stream.tlast='1' then
          -- complete slave transfer immediately after LAST flag
          slave.tvalid <= '1';
        elsif (master_ce='1' or padding='1') and sel(RATIO-1)='1' then
          -- set valid when slave transfer data is complete
          slave.tvalid <= '1';
        end if;

        if reset then
          slave.tvalid <= '0';
          slave.treset <= '1';
        else
          slave.treset <= '0';
        end if;
      end if;
    end process;

    -- map output register to stream (incl. interface adjustments -> padding, trimming and some error checks)
    process(slave)
      variable m : m_stream_i'subtype; -- auxiliary variable for procedure output
    begin
      work.pkg.bypass(
        s_stream => slave,
        m_stream => m,
        TDEST_IGNORE => TDEST_IGNORE,
        TID_IGNORE => TID_IGNORE,
        TUSER_IGNORE => TUSER_IGNORE,
        TUSER_ITEMWISE => TUSER_ITEMWISE
      );
      m_stream_i <= m;
    end process;

    slave_ce <= m_stream_i.tvalid and m_tready_i;
    slave_pause <= m_stream_i.tvalid and (not m_tready_i);

  end generate g_up;

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
