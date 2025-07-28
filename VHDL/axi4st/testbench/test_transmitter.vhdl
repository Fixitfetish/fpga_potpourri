-------------------------------------------------------------------------------
-- @file       test_transmitter.vhdl
-- @author     Fixitfetish
-- @note       VHDL-2008
-- @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

-- Test Transmitter/Master for simulation purposes.
entity test_transmitter is
generic(
  TDEST              : natural := 0;
  TID                : natural := 0;
  -- Value of first data item/byte
  FIRST_DATA_ITEM    : integer := 0;
  -- Address transmitted in header, set negative to disable header
  ADDR_HEADER        : integer := -1;
  TUSER_ITEMWISE     : boolean := true;
  -- Set ALWAYS_VALID=false to throttle transmitter speed with random TVALID signal.
  ALWAYS_VALID       : boolean := false;
  -- LFSR length of PRBS generator for TVALID signal generation when ALWAYS_VALID=false
  TAPS_VLD           : positive := 9
);
port(
  rst          : in  std_logic;
  clk          : in  std_logic;
  -- output stream towards slave
  m_stream     : out work.pkg.axi4_s;
  -- ready signal from slave
  m_tready     : in  std_logic
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of test_transmitter is

  constant IS_ADDR_HEADER : boolean := (ADDR_HEADER>=0);

  constant ITEMS : positive := m_stream.tstrb'length;
  constant ITEM_WIDTH : positive := m_stream.tdata'length / ITEMS;
  constant TUSER_BITS : positive := m_stream.tuser'length;

  signal sr_vld : std_logic_vector(TAPS_VLD downto 1) := (others=>'0');
  signal next_vld : std_logic;
  signal next_header : boolean;

begin

  next_vld <= '1' when ALWAYS_VALID else sr_vld(TAPS_VLD);

  p_vld: process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        sr_vld(TAPS_VLD downto 2) <= (others=>'0');
        sr_vld(1) <= '1';
      elsif (m_tready='1' or m_stream.tvalid='0') then
      sr_vld(TAPS_VLD downto 2) <= sr_vld(TAPS_VLD-1 downto 1);
      sr_vld(1) <= sr_vld(TAPS_VLD) xor sr_vld(TAPS_VLD-2);
      end if;
    end if;
  end process;


  p_data: process(clk)
    variable v_cnt : unsigned(ITEM_WIDTH-1 downto 0);
  begin
    if rising_edge(clk) then
      m_stream.treset <= '0';
      if rst='1' then
        m_stream <= work.pkg.reset(m_stream);
        m_stream.tuser <= (others=>'0');
        next_header <= IS_ADDR_HEADER;
        if IS_ADDR_HEADER then
          v_cnt := to_unsigned(ADDR_HEADER mod 2**v_cnt'length, v_cnt'length);
        else
          v_cnt := to_unsigned(FIRST_DATA_ITEM, v_cnt'length);
        end if;
      elsif (m_tready='1' or m_stream.tvalid='0') then
        m_stream.tvalid <= next_vld;
        if next_vld='1' then
         m_stream.tdest <= std_logic_vector(to_unsigned(TDEST,m_stream.tdest'length));
         m_stream.tid <= std_logic_vector(to_unsigned(TID,m_stream.tid'length));
         if next_header then
          -- addr
          m_stream.tdata <= std_logic_vector(to_signed(ADDR_HEADER,m_stream.tdata'length));
          m_stream.tstrb <= (others=>'1');
          m_stream.tkeep <= (others=>'1');
          m_stream.tlast <= '1';
          m_stream.tuser(0) <= '1';
          next_header <= false;
         else
          -- data
          for n in 0 to ITEMS-1 loop
            m_stream.tdata(ITEM_WIDTH*(n+1)-1 downto ITEM_WIDTH*n) <= std_logic_vector(v_cnt);
            m_stream.tstrb(n) <= '1';
            m_stream.tkeep(n) <= '1';
            v_cnt := v_cnt + 1;
          end loop;
          m_stream.tlast <= '0';
          m_stream.tuser(0) <= '0';
          if v_cnt=0 then
            m_stream.tlast <= '1';
          end if;
         end if;
        end if; --header

      end if; --rst
    end if; --clk
  end process;

end architecture;
