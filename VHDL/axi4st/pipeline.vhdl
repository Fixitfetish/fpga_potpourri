-------------------------------------------------------------------------------
-- @file       pipeline.vhdl
-- @author     Fixitfetish
-- @note       VHDL-2008
-- @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

use work.pkg.t_pipestage;

-- AXI4 Streaming pipeline
entity pipeline is
  generic(
    PIPESTAGES : work.pkg.a_pipestage := (0 => bypass);
    AUX_WIDTH : positive := 1;
    CHECK_AXI_COMPLIANCE : boolean := true
  );
  port(
    aclk     : in  std_logic;
    -- optional AXI reset, active-low, preferably do not connect and use pipelined s_stream.treset instead!
    aresetn  : in  std_logic := '1';
    -- input stream from master
    s_stream : in  work.pkg.axi4_s;
    -- Optional auxiliary signals in addition to the stream record. Leave port open if unused.
    s_aux    : in  std_logic_vector(AUX_WIDTH-1 downto 0) := (others=>'-');
    -- ready signal towards master
    s_tready : out std_logic;
    -- output stream towards slave
    m_stream : out work.pkg.axi4_s;
    -- Optional auxiliary signals in addition to the stream record. Leave port open if unused.
    m_aux    : out std_logic_vector(AUX_WIDTH-1 downto 0);
    -- ready signal from slave
    m_tready : in  std_logic
  );
end entity;

-------------------------------------------------------------------------------

architecture rtl of pipeline is

  constant LAST_PIPESTAGE : PIPESTAGES'element := PIPESTAGES(PIPESTAGES'high);

  type t_stream_array is array (natural range <>) of s_stream'subtype;
  signal stream_pipeline : t_stream_array(0 to PIPESTAGES'length);

  type t_aux_array is array (natural range <>) of s_aux'subtype;
  signal aux_pipeline  : t_aux_array(0 to PIPESTAGES'length);

  signal ready_pipeline : std_logic_vector(0 to PIPESTAGES'length);

begin

  assert (CHECK_AXI_COMPLIANCE = false) or (LAST_PIPESTAGE = bypass and PIPESTAGES'length = 1) or (LAST_PIPESTAGE = priming) or (LAST_PIPESTAGE = primegating) or (LAST_PIPESTAGE = ready_breakup)
    report "Slave interface is not AXI compliant. Last stage must be PRIMING, PRIMEGATING or READY_BREAKUP."
    severity error;

  stream_pipeline(0)                <= s_stream;
  ready_pipeline(PIPESTAGES'length) <= m_tready;
  aux_pipeline(0)                   <= s_aux;

  g_pipeline : for i in 0 to PIPESTAGES'length - 1 generate

    pipestage : entity work.pipestage
      generic map(
        MODE      => PIPESTAGES(i),
        AUX_WIDTH => AUX_WIDTH
      )
      port map(
        aclk     => aclk,
        aresetn  => aresetn,
        s_stream => stream_pipeline(i),
        s_aux    => aux_pipeline(i),
        s_tready => ready_pipeline(i),
        m_stream => stream_pipeline(i+1),
        m_aux    => aux_pipeline(i+1),
        m_tready => ready_pipeline(i+1)
      );

  end generate;

  m_aux <= aux_pipeline(PIPESTAGES'length);
  m_stream <= stream_pipeline(PIPESTAGES'length);
  s_tready <= ready_pipeline(0);

end architecture;
