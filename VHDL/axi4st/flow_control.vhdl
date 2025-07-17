-------------------------------------------------------------------------------
-- @file       flow_control.vhdl
-- @author     Fixitfetish
-- @note       VHDL-2008
-- @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

-- This module does not include any pipeline registers but just offers a GATE port
-- to control the data rate of an AXI4-Streaming connection.
-- The READY and VALID signal will only pass through when the GATE signal is HIGH.
entity flow_control is
generic(
  -- If enabled then upstream flushing (S_TREADY=1) will be initiated when ARESETN=0.
  READY_DURING_ARESETN : std_logic := '0';
  -- If enabled then upstream flushing (S_TREADY=1) will be initiated when S_STREAM.TRESET=1.
  READY_DURING_TRESET  : std_logic := '0';
  -- Pass through TRESET from upstream transmitter towards downstream receiver.
  -- If disabled then M_STREAM.TRESET will be derived from ARESETN only.
  TRESET_PASS_THROUGH  : boolean := true
);
port(
  -- optional active-low AXI reset, use carefully and only when really required!
  aresetn            : in  std_logic := '1';
  -- active-high signal to control the AND-gate
  gate               : in  std_logic;
  -- input stream from upstream transmitter
  s_stream           : in  work.pkg.axi4_s;
  -- ready/request signal towards upstream transmitter
  s_tready           : out std_logic;
  -- output stream towards downstream receiver
  m_stream           : out work.pkg.axi4_s;
  -- ready signal from downstream receiver
  m_tready           : in  std_logic
);
begin
  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (m_stream.tdata'length=s_stream.tdata'length)
    report flow_control'INSTANCE_NAME & " Input and output data must have the same width."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)
end entity;

-------------------------------------------------------------------------------

architecture rtl of flow_control is

begin

  process(s_stream, gate, aresetn)
  begin
    m_stream <= s_stream;

    -- NOTE: s_stream.tvalid=0 is mandatory when s_stream.treset=1
    m_stream.tvalid <= s_stream.tvalid and gate and aresetn;

    if TRESET_PASS_THROUGH then
      m_stream.treset <= s_stream.treset or not aresetn;
    else
      m_stream.treset <= not aresetn;
    end if;

  end process;

  s_tready <= READY_DURING_ARESETN when aresetn='0' else -- global reset
              READY_DURING_TRESET  when s_stream.treset else -- transmitter driven reset
              (m_tready and gate);

end architecture;
