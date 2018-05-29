-------------------------------------------------------------------------------
--! @file       fifo_level_logic_sync.vhdl
--! @author     Fixitfetish
--! @date       28/May/2016
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
library baselib;
--  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;

--! @brief FIFO level logic for synchronous FIFOs.
--!

entity fifo_level_logic_sync is
generic (
  --! FIFO depth in number of data words (mandatory!)
  FIFO_DEPTH : positive;
  --! 0(unused) < prog full threshold < FIFO_DEPTH
  PROG_FULL_THRESHOLD : natural := 0;
  --! 0(unused) < prog empty threshold < FIFO_DEPTH
  PROG_EMPTY_THRESHOLD : natural := 0
);
port (
  --! Clock for read and write port
  clk        : in  std_logic;
  --! Synchronous reset
  rst        : in  std_logic;
  --! Write data enable
  wr_ena     : in  std_logic;
  --! Read enable
  rd_ena     : in  std_logic;
  --! FIFO fill level
  level      : out unsigned(log2ceil(FIFO_DEPTH)-1 downto 0);
  --! FIFO full
  full       : out std_logic;
  --! FIFO empty
  empty      : out std_logic;
  --! FIFO programmable full
  prog_full  : out std_logic;
  --! FIFO programmable empty
  prog_empty : out std_logic;
  --! FIFO overflow (wr_ena=1 and wr_full=1)
  overflow   : out std_logic;
  --! FIFO underflow (rd_req_ack=1 and rd_empty=1)
  underflow  : out std_logic
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  ASSERT PROG_FULL_THRESHOLD<FIFO_DEPTH
    REPORT "Prog full threshold must be smaller than FIFO depth."
    SEVERITY Error;
  ASSERT PROG_EMPTY_THRESHOLD<FIFO_DEPTH
    REPORT "Prog empty threshold must be smaller than FIFO depth."
    SEVERITY Error;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;

-------------------------------------------------------------------------------

architecture rtl of fifo_level_logic_sync is

  signal empty_i : std_logic;
  signal full_i : std_logic;

begin

  p_fifo_logic : process(clk)
    variable v_level : unsigned(level'range);
  begin
    if rising_edge(clk) then

      if rst='1' then
        v_level := (others=>'0');
        empty_i <= '1';
        full_i <= '0';
        prog_empty <= '0';
        prog_full <= '0';

      else  
        if wr_ena='1' and rd_ena='0' then
          if full_i='0' then
            v_level := v_level + 1;
          end if;
          overflow <= full_i;
        elsif wr_ena='0' and rd_ena='1' then
          if empty_i='0' then
            v_level := v_level - 1;
          end if;
          underflow <= empty_i;
        end if;

        empty_i <= to_01(v_level=0);
        full_i <= to_01(v_level=to_unsigned(FIFO_DEPTH,v_level'length));

        if PROG_EMPTY_THRESHOLD>0 then
          prog_empty <= to_01(v_level<=to_unsigned(PROG_EMPTY_THRESHOLD,v_level'length));
        else
          prog_empty <= '0';
        end if;

        if PROG_FULL_THRESHOLD>0 then
          prog_full <= to_01(v_level>=to_unsigned(PROG_FULL_THRESHOLD,v_level'length));
        else
          prog_full <= '0';
        end if;

      end if;
      
      level <= v_level;

    end if; --clock
  end process;

  empty <= empty_i;
  full <= full_i;
  
end architecture;
