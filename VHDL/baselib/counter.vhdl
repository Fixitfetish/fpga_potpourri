-------------------------------------------------------------------------------
--! @file       counter.vhdl
--! @author     Fixitfetish
--! @date       09/May/2017
--! @version    0.10
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

--! @brief Generic incrementing and decrementing counter
--!
--! After reset the counter output is load_init.
--! With incr='1' and decr='0' the counter output is incremented with the next cycle.
--! When load_max (count_max='1') is already reached the counter wraps to load_min.
--! With decr='1' and incr='0' the counter output is decremented with the next cycle.
--! When load_min (count_min='1') is already reached the counter wraps to load_max.
--! When incr=decr the counter output does not change.
--!
entity counter is
generic (
  --! Counter width in bits (mandatory!)
  COUNTER_WIDTH : positive
);
port (
  --! Clock
  clk        : in  std_logic;
  --! Synchronous reset
  rst        : in  std_logic;
  --! Initial counter value after reset, can be positive or negative
  load_init  : in  std_logic_vector(COUNTER_WIDTH-1 downto 0);
  --! Minimum counter value, can be positive or negative
  load_min   : in  std_logic_vector(COUNTER_WIDTH-1 downto 0);
  --! Maximum counter value, can be positive or negative
  load_max   : in  std_logic_vector(COUNTER_WIDTH-1 downto 0);
  --! Increment Counter. Set OPEN or '0' if unused.
  incr       : in  std_logic := '0';
  --! Decrement Counter. Set OPEN or '0' if unused.
  decr       : in  std_logic := '0';
  --! Counter value, can be interpreted as unsigned or signed
  count      : out std_logic_vector(COUNTER_WIDTH-1 downto 0);
  --! Marks minimum value, useful for e.g. counter cascades. Counter will wrap with next decrement.
  count_min  : out std_logic;
  --! Marks maximum value, useful for e.g. counter cascades. Counter will wrap with next increment.
  count_max  : out std_logic
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of counter is
  
  signal count_i : std_logic_vector(COUNTER_WIDTH-1 downto 0);
  signal count_min_i : std_logic;
  signal count_max_i : std_logic;
  
begin
  
  p : process(clk)
    variable v_count : std_logic_vector(COUNTER_WIDTH-1 downto 0);
  begin
    if rising_edge(clk) then
      v_count := count_i;
          
      if rst='1' then
        -- counter initialization
        v_count := load_init;
        
      elsif incr='1' and decr='0' then
        -- counter increment
        if count_max_i='1' then
          -- counter wrap
          v_count := load_min;
        else
          v_count := std_logic_vector(unsigned(count_i)+1);
        end if;  

      elsif decr='1' and incr='0' then
        -- counter decrement
        if count_min_i='1' then
          -- counter wrap
          v_count := load_max;
        else
          v_count := std_logic_vector(unsigned(count_i)-1);
        end if;  
     
      end if; -- reset

      count_i <= v_count;

      -- minimum/maximum detection
      -- (note: in special cases minimum and maximum could be the same!)
      if v_count=load_min then
        count_min_i <= '1';
      else
        count_min_i <= '0';
      end if;
  
      if v_count=load_max then
        count_max_i <= '1';
      else
        count_max_i <= '0';
      end if;  

    end if; -- clock
  end process;

  -- final output
  count <= count_i;
  count_min <= count_min_i;
  count_max <= count_max_i;

end architecture;
