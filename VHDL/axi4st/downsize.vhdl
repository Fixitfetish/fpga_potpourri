-------------------------------------------------------------------------------
-- @file       downsize.vhdl
-- @author     Fixitfetish
-- @note       VHDL-2008
-- @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

use work.pkg.all;

-- Downsize the upstream transmitter data width by an integer ratio (1,2,3,4,5,..) for downstream receivers with smaller data width.
--
-- **Extensions to the AXI4-Stream standard**
-- * According to the AXI4-Streaming specification an item is 8 bits (1 byte) wide.
--   However, this module allows any item width. Each TSTRB/TKEEP bit corresponds to one item.
--   The item width at input and output must match of course.
-- * The AXI4-Streaming specification defines/recommends a 2^n number of items (bytes) in TDATA.
--   Hence, the downsize ratio must also be a power-of-2.
--   However, this module allows any positive integer number of items in TDATA and
--   therefore also any positive integer downsize ratio.
--
-- Note that due to back-pressure typically the input will not be ready for RATIO-1 cycles after an input transfer.
-- Only when packing is enabled and invalid units are removed the TREADY towards master might be set earlier.
--
-- **Limitations**
-- * DEST width at input and output should match, otherwise output DEST will be trimmed or padded
-- * ID width at input and output should match, otherwise output ID will be trimmed or padded
-- * Master and slave interface can have different user signal length but at both interfaces the
--   user'length must be a multiple of strb'length ... unless USER_IGNORE=true.
--   The user signal will trimmed or padded if the lengths do not match.
entity downsize is
generic (
  -- Enable AXI pipeline input register(s). Multiple different stages can be configured
  -- but the last stage should always be ready_breakup, priming or primegating.
  INPUT_PIPESTAGES : a_pipestage := (0=>bypass);
  -- Enable AXI pipeline output register(s). Multiple different stages can be configured
  -- but the first stage should always be ready_breakup, priming or primegating.
  -- At lest one stage is highly recommended.
  OUTPUT_PIPESTAGES : a_pipestage := (0=>priming);
  -- If packing is enabled then downsized units consisting of just null items (TKEEP and TLAST deasserted) are removed and not passed to the output.
  -- Note that in this case every LAST input transfer cannot consist of all null items.
  PACKING : boolean := false;
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
  assert (s_stream.tdata'length mod s_stream.tstrb'length = 0)
    report downsize'INSTANCE_NAME & "The master input TDATA width must be an integer multiple of the TSTRB width."
    severity failure;
  assert (m_stream.tdata'length mod m_stream.tstrb'length = 0)
    report downsize'INSTANCE_NAME & "The slave output TDATA width must be an integer multiple of the TSTRB width."
    severity failure;
  assert (s_stream.tdata'length mod m_stream.tdata'length = 0) and (s_stream.tstrb'length mod m_stream.tstrb'length = 0)
    report downsize'INSTANCE_NAME & "The master input TDATA and TSTRB width must be an integer multiple of the slave output TDATA and TSTRB width."
    severity failure;
  assert (m_stream.tuser'length mod m_stream.tstrb'length = 0) or TUSER_IGNORE
    report downsize'INSTANCE_NAME & "In slave output the user width must be a multiple of the number of data items."
    severity failure;
  assert (s_stream.tuser'length mod s_stream.tstrb'length = 0) or TUSER_IGNORE
    report downsize'INSTANCE_NAME & "In master input the user width must be a multiple of the number of data items."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;

-------------------------------------------------------------------------------

architecture rtl of downsize is

  -- According to the AXI4-Streaming specification an item is 8 bits (1 byte) wide.
  -- However, this module allows any item width. Each TSTRB/TKEEP bit corresponds to one item.
  -- The item width at input and output must match of course.
  constant ITEM_WIDTH : positive := s_stream.tdata'length / s_stream.tstrb'length;

  -- The AXI4-Streaming specification defines/recommends a 2^n number of items (bytes) in TDATA.
  -- Hence,the downsize ratio must also be a power of 2.
  -- However, this module allows any positive integer number of items in TDATA and
  -- therefore also any positive integer downsize ratio.
  constant RATIO : positive := s_stream.tdata'length / m_stream.tdata'length;

  -- Items per downsize unit. A unit is transferred as it is and is not touched during downsizing.
  -- Only if TKEEP=0 marks all items of a unit as null items and packing is enabled then a unit can be removed from the stream.
  constant UNIT_ITEMS : positive := m_stream.tstrb'length;
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

  -- unregistered bypass
  g_bypass : if RATIO=1 generate
    -- bypass with interface adjustments -> padding, trimming and some error checks
    process(s_stream_i)
      variable m : m_stream_i'subtype; -- auxiliary variable for procedure output
    begin
      work.pkg.bypass(
        s_stream => s_stream_i,
        m_stream => m,
        TUSER_IGNORE => TUSER_IGNORE
      );
      m_stream_i <= m;
    end process;
    s_tready_i <= m_tready_i;
  end generate;

  -- unregistered downsizing
  g_down : if RATIO>=2 generate
    -- Output user width before padding/trimming. Must be at least 1 if the USER signal is ignored.
    constant USER_WIDTH : positive := maximum(1,s_stream.tuser'length/RATIO);
    -- slave will valid accept data with next clock edge
    signal slave_ce : std_logic;
    signal sel : integer range 0 to RATIO-1 := 0;

    signal unit : work.pkg.a_axi4_s(RATIO-1 downto 0)(
      tdata(UNIT_WIDTH - 1 downto 0),
      tdest(s_stream.tdest'length - 1 downto 0),
      tid(s_stream.tid'length - 1 downto 0),
      tkeep(UNIT_ITEMS - 1 downto 0),
      tstrb(UNIT_ITEMS - 1 downto 0),
      tuser(USER_WIDTH - 1 downto 0)
    );

    signal valid, mask : std_logic_vector(RATIO-1 downto 0);
    signal valid_remaining : integer range 0 to RATIO := 0;

  begin

    -- pull new data from master
    -- * when the last valid unit of a master transfer is accepted by the slave
    -- * until master provides valid data
    s_tready_i <= '1' when ((valid_remaining<=1) and m_tready_i='1') else (not s_stream_i.tvalid);

    -- detect and mark valid input units
    p_vld : process(s_stream_i)
      variable keep : std_logic := '1';
    begin
      for n in valid'range loop
        if PACKING then
          -- A unit is removed and marked as invalid when for all items in the unit TSTRB and TKEEP are deasserted.
          keep := or (s_stream_i.tstrb(UNIT_ITEMS*(n+1)-1 downto UNIT_ITEMS*n) or s_stream_i.tkeep(UNIT_ITEMS*(n+1)-1 downto UNIT_ITEMS*n));
        end if;
        valid(n) <= s_stream_i.tvalid and keep;
      end loop;
    end process;

    p_sel_count : process(valid, mask)
     variable valid_masked : valid'subtype;
     variable v_count : integer range 0 to RATIO := 0;
    begin
      valid_masked := valid and not mask;
      -- index of next valid unit (INDEX_OF_RIGHTMOST_ONE)
      sel <= RATIO-1; -- by default select last unit of input vector
      for i in valid_masked'reverse_range loop
        if valid_masked(i)='1' then sel<=i; exit; end if;
      end loop;
      -- number of remaining valid units in input vector (NUMBER_OF_ONES)
      v_count := 0; -- by default 0 valid items remaining in input vector
      for i in valid_masked'range loop
        if valid_masked(i)='1' then v_count:=v_count+1; end if;
      end loop;
      valid_remaining <= v_count;
    end process;

    p_mask: process(aclk)
    begin
      if rising_edge(aclk) then
        if s_stream_i.treset or not aresetn then
          mask <= (others=>'0');
        elsif slave_ce='1' then
          if valid_remaining=1 then
            mask <= (others=>'0');
          else
            mask(sel) <= '1';
          end if;
        end if;
      end if;
    end process;

    -- restructure input from master into output unit size for slave
    p_in: process(aresetn, s_stream_i, valid)
      variable last : std_logic;
    begin
      last := s_stream_i.tlast;
      -- Loop must run backwards to detect last valid unit within input transfer for correct TLAST signaling at output.
      for n in unit'range loop
        unit(n).tdata  <= s_stream_i.tdata(UNIT_WIDTH*(n+1)-1 downto UNIT_WIDTH*n);
        unit(n).tstrb  <= s_stream_i.tstrb(UNIT_ITEMS*(n+1)-1 downto UNIT_ITEMS*n);
        unit(n).tkeep  <= s_stream_i.tkeep(UNIT_ITEMS*(n+1)-1 downto UNIT_ITEMS*n);
        unit(n).tdest  <= s_stream_i.tdest;
        unit(n).tid    <= s_stream_i.tid;
        unit(n).treset <= s_stream_i.treset or not aresetn;
        unit(n).tvalid <= valid(n);

        -- Ensure that TLAST is only set for the last valid unit of an input transfer.
        -- For preceding units in the same input transfer TLAST must be deasserted.
        if valid(n)='1' then
          unit(n).tlast <= last;
          last := '0';
        else
          unit(n).tlast <= '0';
        end if;

        if TUSER_IGNORE then
          unit(n).tuser <= (others=>'-'); -- irrelevant
        else
          unit(n).tuser <= s_stream_i.tuser(USER_WIDTH*(n+1)-1 downto USER_WIDTH*n);
        end if;
      end loop;
    end process;

    -- multiplexer (incl.interface adjustments -> padding, trimming and some error checks)
    process(unit, sel)
      variable m : m_stream_i'subtype; -- auxiliary variable for procedure output
    begin
      work.pkg.bypass(
        s_stream => unit(sel),
        m_stream => m,
        TUSER_IGNORE => TUSER_IGNORE
      );
      m_stream_i <= m;
    end process;

    slave_ce <= m_stream_i.tvalid and m_tready_i;

  end generate g_down;

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
