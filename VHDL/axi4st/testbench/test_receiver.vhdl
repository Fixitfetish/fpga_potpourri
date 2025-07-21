-------------------------------------------------------------------------------
-- @file       test_receiver.vhdl
-- @author     Fixitfetish
-- @note       VHDL-2008
-- @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

-- Test Receiver/Slave for simulation purposes.
entity test_receiver is
generic(
  -- Value of first data item/byte
  FIRST_DATA_ITEM    : integer := 0;
  TUSER_ITEMWISE     : boolean := true;
  TUSER_IGNORE       : boolean := false;
  -- Set ALWAYS_READY=false to throttle receiver speed with random TREADY signal (back-pressure)
  ALWAYS_READY       : boolean := false;
  -- LFSR length of PRBS generator for TREADY signal generation when ALWAYS_READY=false
  TAPS_RDY           : positive := 19
);
port(
  rst          : in  std_logic;
  clk          : in  std_logic;
  -- input stream from master
  s_stream     : in  work.pkg.axi4_s;
  -- ready signal towards master
  s_tready     : out std_logic
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of test_receiver is

  constant ITEMS : positive := s_stream.tstrb'length;
  constant ITEM_WIDTH : positive := s_stream.tdata'length / ITEMS;

  signal sr_rdy : std_logic_vector(TAPS_RDY downto 1) := (others=>'0');
  signal next_rdy : std_logic;
  signal s_ce : std_logic;

begin

  s_ce <= s_tready and s_stream.tvalid;

  next_rdy <= '1' when ALWAYS_READY else sr_rdy(TAPS_RDY);

  p_rdy: process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        sr_rdy(TAPS_RDY downto 2) <= (others=>'0');
        sr_rdy(1) <= '1';
      elsif s_tready='0' or s_ce='1' then
      sr_rdy(TAPS_RDY downto 2) <= sr_rdy(TAPS_RDY-1 downto 1);
      sr_rdy(1) <= sr_rdy(TAPS_RDY) xor sr_rdy(TAPS_RDY-2);
      end if;
    end if;
  end process;

  s_tready <= next_rdy;

  p_data: process(clk)
    variable v_cnt, v_val : unsigned(ITEM_WIDTH-1 downto 0);
  begin
    if rising_edge(clk) then
      if rst='1' then
        v_cnt := to_unsigned(FIRST_DATA_ITEM, v_cnt'length);
      elsif (s_ce='1' and (TUSER_IGNORE or s_stream.tuser(0)='0')) then
        -- verify new item/byte values
        for n in 0 to ITEMS-1 loop
          if (s_stream.tkeep(n) and s_stream.tstrb(n))='1' then
            v_val := unsigned(s_stream.tdata(ITEM_WIDTH*(n+1)-1 downto ITEM_WIDTH*n));
            assert v_val = v_cnt
              report test_receiver'instance_name & "Expected item/byte value " & integer'image(to_integer(v_cnt)) & " but received " & integer'image(to_integer(v_val))
              severity failure;
            v_cnt := v_cnt + 1;
          end if;
        end loop;
      end if;
    end if;
  end process;

end architecture;
