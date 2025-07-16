-------------------------------------------------------------------------------
-- @file       pipestage.vhdl
-- @author     Fixitfetish
-- @note       VHDL-2008
-- @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

use work.pkg.t_pipestage;

entity pipestage is
  generic(
    MODE : work.pkg.t_pipestage := bypass;
    AUX_WIDTH : positive := 1
  );
  port(
    aclk     : in  std_logic;
    -- optional active-low AXI reset, used to explicitly reset valid and inject reset into stream,
    -- preferably do not connect and use pipelined s_stream.treset instead!
    aresetn  : in  std_logic := '1';
    -- input from upstream master (slave interface port)
    s_stream : in  work.pkg.axi4_s;
    -- Optional auxiliary signals in addition to the AXI stream. Leave port open if unused.
    s_aux    : in  std_logic_vector(AUX_WIDTH-1 downto 0) := (others=>'-');
    -- ready signal towards upstream master (slave interface port)
    s_tready : out std_logic := '0';
    -- output towards downstream slave (master interface port)
    m_stream : out work.pkg.axi4_s;
    -- Optional auxiliary signals in addition to the AXI stream. Leave port open if unused.
    m_aux    : out std_logic_vector(AUX_WIDTH-1 downto 0);
    -- ready signal from downstream slave (master interface port)
    m_tready : in  std_logic
  );
attribute dont_touch : string;
end entity;

---------------------------------------------------------------------------------------------------

architecture rtl of pipestage is
begin

  p_check : process(aclk)
  begin
    if rising_edge(aclk) then
      -- assertion to avoid unused signal warnings for clock and reset
      assert aresetn /= 'X' 
        report pipestage'instance_name & "aresetn should not be X"
        severity note;
      -- assertion to avoid unused signal warnings for clock and reset
      assert s_stream.treset /= 'X' 
        report pipestage'instance_name & "s_stream.treset should not be X"
        severity note;
    end if;
  end process;

  g_bypass : if MODE=bypass generate
    m_stream <= s_stream;
    m_aux    <= s_aux;
    s_tready <= m_tready;
  end generate;

  g_decouple : if MODE=decouple generate
    -- NOTE: The optional reset can be used to decouple the DS from the US side.
    --       This is useful to flush AXI pipelines and avoid unstable ready and valid signals during reset.
    --       Setting s_tready='1' enables upstream pipeline flushing.
    --       Forcing m_stream.treset='1' will inject the reset into the downstream pipeline.
    --       Forcing m_stream.tvalid='0' will inject invalid data into the downstream pipeline.
    --       Reset values like e.g. '1', 'U', 'X' (simulation!) will enable decoupling. 
    --       The reset source shall be close the decoupling stage to avoid timing issues.
    process(s_stream, aresetn)
    begin
      m_stream <= s_stream;
      m_stream.treset <= s_stream.treset when aresetn='1' else '1';
      m_stream.tvalid <= s_stream.tvalid when aresetn='1' else '0';
    end process;
    m_aux <= s_aux;
    s_tready <= m_tready when aresetn='1' else '1';
  end generate;

  g_simple : if MODE=simple generate
    -- initialize TRESET and TVALID when ARESETN is unused
    signal stream : s_stream'subtype := work.pkg.reset(s_stream);
  begin
    reg : process(aclk)
    begin
      -- NOTE: Do not check for HIGH but LOW state here to avoid simulation initialization issues!
      -- This ensures that the registers are updated as long as the ready signals are not stable.
      if rising_edge(aclk) then
        if m_tready/='0' then
          stream <= s_stream;
          m_aux  <= s_aux;
        end if;
        if not aresetn then
          stream.treset <= '1';
          stream.tvalid <= '0';
        end if;
      end if;
    end process;
    m_stream <= stream;
    s_tready <= m_tready;
  end generate;

  g_priming : if MODE=priming generate
    -- initialize TRESET and TVALID when ARESETN is unused
    signal stream : s_stream'subtype := work.pkg.reset(s_stream);
  begin
    reg : process(aclk)
    begin
      -- NOTE: Do not check for HIGH but LOW state here to avoid simulation initialization issues!
      -- This ensures that the registers are updated as long as the ready signals are not stable.
      if rising_edge(aclk) then
        if s_tready/='0' then
          stream <= s_stream;
          m_aux  <= s_aux;
        end if;
        if not aresetn then
          stream.treset <= '1';
          stream.tvalid <= '0';
        end if;
      end if;
    end process;
    m_stream <= stream;
    s_tready <= m_tready or (not stream.tvalid);
  end generate;

  g_gating : if MODE=gating generate
    -- initialize TRESET and TVALID when ARESETN is unused
    signal stream : s_stream'subtype := work.pkg.reset(s_stream);
  begin
    reg : process(aclk)
    begin
      -- NOTE: Do not check for HIGH but LOW state here to avoid simulation initialization issues!
      -- This ensures that the registers are updated as long as the ready signals are not stable.
      if rising_edge(aclk) then
        if m_tready/='0' and s_stream.tvalid='1' then
          stream <= s_stream;
          m_aux  <= s_aux;
        end if;
        -- NOTE: Do not gate reset because reset will not pass through when valid is low.
        if m_tready/='0' then
          stream.treset <= s_stream.treset;
          stream.tvalid <= s_stream.tvalid;
        end if;
        if not aresetn then
          stream.treset <= '1';
          stream.tvalid <= '0';
        end if;
      end if;
    end process;
    m_stream <= stream;
    s_tready <= m_tready;
  end generate;

  g_primegating : if MODE=primegating generate
    -- initialize TRESET and TVALID when ARESETN is unused
    signal stream : s_stream'subtype := work.pkg.reset(s_stream);
  begin
    reg : process(aclk)
    begin
      -- NOTE: Do not check for HIGH but LOW state here to avoid simulation initialization issues!
      -- This ensures that the registers are updated as long as the ready signals are not stable.
      if rising_edge(aclk) then
        if s_tready/='0' and s_stream.tvalid='1' then
          stream <= s_stream;
          m_aux  <= s_aux;
        end if;
        -- NOTE: Do not gate reset because reset will not pass through when valid is low.
        if s_tready/='0' then
          stream.treset <= s_stream.treset;
          stream.tvalid <= s_stream.tvalid;
        end if;
        if not aresetn then
          stream.treset <= '1';
          stream.tvalid <= '0';
        end if;
      end if;
    end process;
    m_stream <= stream;
    s_tready <= m_tready or (not m_stream.tvalid);
  end generate;

  g_ready_breakup : if MODE=ready_breakup generate
    -- expansion register
    signal stream_q : s_stream'subtype := work.pkg.reset(s_stream);
    signal aux_q : s_aux'subtype;
    attribute dont_touch of stream_q : signal is "true"; --"true|yes" or "false|no"
    attribute dont_touch of aux_q : signal is "true"; --"true|yes" or "false|no"
  begin
    reg : process(aclk)
    begin
      -- NOTE: Do not check for HIGH but LOW state here to avoid simulation initialization issues!
      -- This ensures that the registers are updated as long as the ready signals are not stable.
      if rising_edge(aclk) then
        -- accept data into expansion register until it is valid
        if s_tready/='0' and m_tready/='1' then
          stream_q <= s_stream;
          aux_q <= s_aux;
        end if;
        -- if the expansion register data is accepted then we must clear the valid register
        if aresetn='0' or m_tready/='0' then
          stream_q.tvalid <= '0';
        end if;
      end if;
    end process;
    -- upstream ready as long as there is nothing in the expansion register
    s_tready <= not stream_q.tvalid;
    -- selecting the expansion register if it has valid data otherwise pass through incoming upstream data
    m_stream <= stream_q when stream_q.tvalid='1' else s_stream;
    m_aux    <= aux_q    when stream_q.tvalid='1' else s_aux;
  end generate;

end architecture;
