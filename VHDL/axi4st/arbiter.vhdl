-------------------------------------------------------------------------------
-- @file       arbiter.vhdl
-- @author     Fixitfetish
-- @note       VHDL-2008
-- @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;

use work.pkg.all;

-- The AXI stream arbiter (multiplexer) interleaves multiple masters to connect to a single slave.
-- Masters and slave must have the same data width. Upsizing or downsizing has to be done separately.
--
-- **Limitations**
-- * DEST width at input and output should match, otherwise output DEST will be trimmed or padded
-- * ID width at input and output should match, otherwise output ID will be trimmed or padded
-- * NULL bytes are neither touched nor removed
entity arbiter is
generic(
  -- Number of slave input ports, i.e. number of masters that can be connected
  NUM_PORTS : positive;
  -- Select arbiter variant : "fixed-priority", "round-robin" or "first-come-first-serve".
  VARIANT : string := "fixed-priority";
  -- Enable AXI pipeline input register for all ports or every port independently.
  -- For independent setting the range (NUM_PORTS-1 downto 0) is expected.
  INPUT_REG : boolean_vector := (0=>false);
  -- With this AXI4 streaming property you enable packet-wise arbitration and consider the LAST bit
  -- of the input streams. (see spec ARM IHI 0051A, chap 3.3)
  -- If disabled then every single transfer is arbitrated.
  CONTINUOUS_PACKETS : boolean := false;
  -- At the output to slave replace/overwrite stream ID from master with arbiter port index.
  -- This can be beneficial to automatically set the ID or to save a few resources because incoming
  -- IDs remain unconnected and can be optimized out.
  REPLACE_ID : boolean := false;
  -- If the TUSER signal is ignored then all bits of output m_stream(n).tuser will be forced to zero.
  -- This setting is useful to avoid TUSER size matching issues when the TUSER signal is unused anyway.
  TUSER_IGNORE : boolean := false;
  -- Disable this option if the TUSER signals of masters and slave are related to a complete transfer
  -- rather than individual items/bytes. Trimming/Padding adjusts accordingly. (see spec ARM IHI 0051A, chap 2.8)
  TUSER_ITEMWISE : boolean := true
);
port(
  aclk         : in  std_logic;
  -- optional AXI reset, active-low, preferably do not connect and use pipelined s_stream.treset instead!
  aresetn      : in  std_logic := '1';
  -- input streams from masters
  s_stream     : in  work.pkg.a_axi4_s(NUM_PORTS-1 downto 0);
  -- ready signals towards masters
  s_tready     : out std_logic_vector(NUM_PORTS-1 downto 0);
  -- output stream towards slave
  m_stream     : out work.pkg.axi4_s;
  -- ready signal from slave
  m_tready     : in  std_logic;
  -- Currently active packet is interrupted/aborted because of missing valid.
  -- Only relevant if CONTINUOUS_PACKETS is enabled.
  error_packet : out std_logic := '0'
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (m_stream.tdata'length=s_stream(s_stream'low).tdata'length)
    report arbiter'INSTANCE_NAME & " Input and output streams must have same data width."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;

-------------------------------------------------------------------------------

architecture rtl of arbiter is

  signal s_stream_i : s_stream'subtype;
  signal s_tready_i : s_tready'subtype;

  signal request : std_logic_vector(NUM_PORTS-1 downto 0);
  signal request_last : std_logic_vector(NUM_PORTS-1 downto 0);

  signal grant_idx : integer range 0 to NUM_PORTS-1;
  signal grant_vld : std_logic;

  signal arbrdy : m_tready'subtype;
  signal arbout : m_stream'subtype;

  signal error_burst : std_logic;

  impure function TYPE_IREG return a_pipestage is
    variable r : a_pipestage(NUM_PORTS-1 downto 0);
  begin
    assert (INPUT_REG'length=1 or INPUT_REG'length=NUM_PORTS)
      report arbiter'INSTANCE_NAME & " Generic INPUT_REG must have length 1 or range (NUM_PORTS-1 downto 0)."
      severity failure;
    r := (others=>bypass);
    if INPUT_REG'length=1 and INPUT_REG(INPUT_REG'low) then
      r := (others=>priming);
    elsif INPUT_REG'length>=2 then
      for i in r'range loop
        if INPUT_REG(i) then r(i) := priming; end if;
      end loop;
    end if;
    return r;
  end function;

begin

  -- AXI conform input register
  -- NOTE: A ready-breakup stage should be place at the input to decouple the multiple masters
  -- from the arbiter logic and the slave. Otherwise, resolving timing issues will be difficult.
  -- Placing the ready-breakup directly in front of the arbiter logic might be beneficial because
  -- the ready-breakup internal MUX can be merged with the MUX within the arbiter logic.
  -- TODO: In a large arbiter with many ports the wide MUXes might cause timing issues.
  --       Verify if this is case and try another PRIMING stage after the ready-breakup.
  g_in : for n in 0 to NUM_PORTS-1 generate
    pipe : entity work.pipeline
    generic map(
      PIPESTAGES => (0=>TYPE_IREG(n), 1=>ready_breakup),
      CHECK_AXI_COMPLIANCE => false
    )
    port map(
      aclk     => aclk,
      aresetn  => aresetn, -- TODO
      s_stream => s_stream(n),
      s_tready => s_tready(n),
      m_stream => s_stream_i(n),
      m_tready => s_tready_i(n)
    );
  end generate;

  -- assign arbiter request signals
  p_req : process(all)
  begin
    for i in request'range loop
      request(i) <= s_stream_i(i).tvalid;
      request_last(i) <= '1';
      if CONTINUOUS_PACKETS then
        request_last(i) <= s_stream_i(i).tlast;
      end if;
    end loop;
  end process;

  i_arb : entity baselib.arbiter_logic(flex)
  generic map(
    NUM_PORTS       => NUM_PORTS,
    RIGHTMOST_FIRST => true,
    VARIANT         => VARIANT
  ) 
  port map(
    rst          => not aresetn,
    clk          => aclk,
    request      => request,
    request_last => request_last,
    grant_ready  => arbrdy,
    grant        => s_tready_i,
    grant_idx    => grant_idx,
    grant_vld    => grant_vld,
    grant_first  => open,
    grant_last   => open,
    error_burst  => error_burst
  ) ;

  -- multiplex according to grant
  arbout.tvalid <= grant_vld;
  arbout.treset <= s_stream_i(grant_idx).treset;
  arbout.tdata  <= s_stream_i(grant_idx).tdata;
  arbout.tdest  <= s_stream_i(grant_idx).tdest;
  arbout.tkeep  <= s_stream_i(grant_idx).tkeep;
  arbout.tlast  <= s_stream_i(grant_idx).tlast;
  arbout.tstrb  <= s_stream_i(grant_idx).tstrb;
  arbout.tuser  <= s_stream_i(grant_idx).tuser; -- TODO: PKG function for USER pad/trim in case masters and slave have different user width
  arbout.tid    <= std_logic_vector(to_unsigned(grant_idx,arbout.tid'length)) when REPLACE_ID else s_stream_i(grant_idx).tid;
  -- TODO: use bypass procedure with USER, ID, DEST conversion here and then
  --       overwrite Vaild and ID afterwards

  -- AXI conform output register, including ready-breakup stage to improve timing.
  -- Error signal is pipelined as well so that it is aligned to the output stream and the correct stream ID.
  i_outreg : entity work.pipeline
  generic map(
    PIPESTAGES => (0=>ready_breakup, 1=>priming),
    AUX_WIDTH => 1,
    CHECK_AXI_COMPLIANCE => false
  )
  port map(
    aclk     => aclk,
    aresetn  => aresetn,
    s_stream => arbout,
    s_aux(0) => error_burst,
    s_tready => arbrdy,
    m_stream => m_stream,
    m_aux(0) => error_packet,
    m_tready => m_tready
  );

end architecture;
