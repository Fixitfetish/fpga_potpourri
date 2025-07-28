-------------------------------------------------------------------------------
-- @file       demux.vhdl
-- @author     Fixitfetish
-- @note       VHDL-2008
-- @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

use work.pkg.all;

-- The AXI stream demultiplexer deinterleaves a single master stream into multiple slave streams
-- according to the TDEST or TID signal. Master and slaves must have same the data width.
-- Upsizing or downsizing has to be done separately if required.
--
-- **IMPORTANT NOTE**: Since the demultiplexer does not include any internal buffer it will wait for
-- for the addressed slave to be ready to accept new data. In this case, the other slaves will be stalled.
-- Hence, it is recommended to ensure the slaves are always ready or to add a buffer or FIFO for each slave
-- at the demultiplexer output.
--
-- **Limitations**
-- * TDEST width at input and output should match, otherwise output TDEST will be trimmed or padded
-- * TID width at input and output should match, otherwise output TID will be trimmed or padded
-- * NULL bytes are neither touched nor removed
-- * Master and slave interface can have different TUSER signal length but consider the requirements
--   for trimming and padding.
entity demux is
generic(
  -- Number of master output ports, i.e. number of slaves that can be connected
  NUM_PORTS : positive;
  -- Demultiplex according to "DEST" or "ID" input signal from master
  MODE : string := "DEST";
  -- Enable AXI pipeline input register(s). Multiple different stages can be configured.
  -- A ready-breakup as last input stage directly before the demux can be beneficial to decouple
  -- the master from the demux logic.
  INPUT_PIPESTAGES : a_pipestage := (0=>bypass);
  -- Enable AXI pipeline output register(s) at all output ports. Multiple different stages can be configured.
  -- A ready-breakup stage should be placed at each output to decouple the multiple slaves
  -- from the demux logic and the master. Otherwise, resolving timing issues might be difficult.
  -- An additional primegating output stage will significantly decrease the toggling rate at each
  -- output port.
  OUTPUT_PIPESTAGES : a_pipestage := (0=>bypass);
  -- If the TUSER signal is ignored then all bits of output m_stream(n).tuser will be forced to zero.
  -- This setting is useful to avoid TUSER size matching issues when the TUSER signal is unused anyway.
  TUSER_IGNORE : boolean := false;
  -- Disable this option if the TUSER signals of master and slaves are related to a complete transfer
  -- rather than individual items/bytes. Trimming/Padding adjusts accordingly. (see spec ARM IHI 0051A, chap 2.8)
  TUSER_ITEMWISE : boolean := true
);
port(
  aclk         : in  std_logic;
  -- optional AXI reset, active-low, preferably do not connect and use pipelined s_stream.treset instead!
  aresetn      : in  std_logic := '1';
  -- input stream from master
  s_stream     : in  work.pkg.axi4_s;
  -- ready signal towards master
  s_tready     : out std_logic;
  -- output streams towards slaves
  m_stream     : out work.pkg.a_axi4_s(NUM_PORTS-1 downto 0);
  -- ready signals from slaves
  m_tready     : in  std_logic_vector(NUM_PORTS-1 downto 0)
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (s_stream.tdata'length=m_stream(m_stream'low).tdata'length)
    report demux'INSTANCE_NAME & " Input and output streams must have same data width."
    severity failure;
  assert (MODE="DEST" or MODE="ID")
    report demux'INSTANCE_NAME & " Demultiplexer MODE must be according to DEST or ID."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;

-------------------------------------------------------------------------------

architecture rtl of demux is

  signal s_stream_i : s_stream'subtype;
  signal s_tready_i : s_tready'subtype;
  signal m_stream_i : m_stream'subtype;
  signal m_tready_i : m_tready'subtype;

  function get_port(p:unsigned) return natural is
    variable pint : natural range 0 to 2**p'length-1;
  begin
    pint := to_integer(p);
    assert (pint<NUM_PORTS)
      report demux'INSTANCE_NAME & " Index specified in s_stream input DEST or ID exceeds range of m_stream output ports."
      severity failure;
    return pint;
  end function;

  signal sel : integer range 0 to NUM_PORTS-1;

begin

  -- AXI conform input register
  -- NOTE: A ready-breakup stage should be placed at the input to decouple the master from
  -- the demux logic and the slaves. Otherwise, resolving timing issues might be difficult.
  i_inreg : entity work.pipeline
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

  sel <= get_port(unsigned(s_stream_i.tdest)) when MODE="DEST" else
         get_port(unsigned(s_stream_i.tid))   when MODE="ID";
  s_tready_i <= m_tready_i(sel);

  p_demux : process(s_stream_i, sel, aresetn)
    variable m : m_stream_i'element; -- auxiliary variable for procedure output
  begin
    for p in 0 to NUM_PORTS-1 loop
      -- duplicate incoming master signals to all slaves
      -- (incl. interface adjustments -> padding, trimming and some error checks)
      work.pkg.bypass(
        s_stream => s_stream_i,
        m_stream => m,
        TUSER_IGNORE => TUSER_IGNORE,
        TUSER_ITEMWISE => TUSER_ITEMWISE
      );
      m_stream_i(p) <= m;
      m_stream_i(p).treset <= s_stream_i.treset or not aresetn;
      -- overwrite and set valid according to destination
      if p=sel then
        m_stream_i(p).tvalid <= s_stream_i.tvalid and aresetn;
      else
        m_stream_i(p).tvalid <= '0';
      end if;
    end loop;
  end process;

  -- AXI conform output register
  -- NOTE: A ready-breakup stage should be placed at each output to decouple the multiple slaves
  -- from the demux logic and the master. Otherwise, resolving timing issues might be difficult.
  -- An additional primegating output stage will significantly decrease the toggling rate at each
  -- output port.
  g_out : for p in 0 to NUM_PORTS-1 generate
    pipe : entity work.pipeline
    generic map(
      PIPESTAGES => OUTPUT_PIPESTAGES,
      CHECK_AXI_COMPLIANCE => false
    )
    port map(
      aclk     => aclk,
      aresetn  => aresetn,
      s_stream => m_stream_i(p),
      s_tready => m_tready_i(p),
      m_stream => m_stream(p),
      m_tready => m_tready(p)
    );
  end generate;

end architecture;
