-------------------------------------------------------------------------------
--! @file       fifo_logic_sync.vhdl
--! @author     Fixitfetish
--! @date       18/Mar/2019
--! @version    0.20
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
  use baselib.ieee_extension.all;

--! @brief FIFO logic for synchronous RAM based FIFOs.
--!
--! The level is incremented with every write enable but only when the FIFO is not full.
--! The level is decremented with every read enable but only when the FIFO is not empty.
--! If the FIFO is neither full nor empty and write and read enable occur in the same
--! cycle then the level remains unchanged.
--!
--! The write/read pointer can be used as write/read address for RAM based FIFOs.
--! The range of both pointers is 0 to FIFO_DEPTH-1. After reset both pointers are 0.
--! Both pointers only have the same value when the FIFO is either empty or full.
--! The write pointer is incremented with every write enable but only if the FIFO is not full.
--! The read pointer is incremented with every read enable but only if the FIFO is not empty.
--! Writing to a full FIFO or reading from an empty FIFO will not change the write or read pointer.
--! To not override already existing values in the FIFO it is recommended to disable the RAM write
--! enable when the FIFO is full, hence "only" the value that caused the overflow is lost.
--! For timing reasons the write and read pointer are calculated independently of the level.
--! If write and/or read pointer are unused the corresponding logic will typically be optimized out.
--! Note that a RAM can be used most efficiently when the FIFO depth is a power of 2.
--!
--! Writing to a full FIFO will cause an overflow flag in the next cycle.
--! Reading from an empty FIFO  will cause an underflow flag in the next cycle.
--!
entity fifo_logic_sync is
generic (
  --! @brief Maximum allowed FIFO depth in number of data words, LOG2 to enforce power 2 (mandatory!).
  --! Defines the size of write and read pointer and the range of thresholds.
  MAX_FIFO_DEPTH_LOG2 : positive
);
port (
  --! Clock for read and write port
  clk                      : in  std_logic;
  --! Synchronous reset
  rst                      : in  std_logic;
  --! @brief FIFO depth in number of data words (mandatory!). Power of 2 is recommended for efficiency.
  --! Can only be changed during reset.
  cfg_fifo_depth           : unsigned(MAX_FIFO_DEPTH_LOG2-1 downto 0);
  --! @brief 0(unused) < prog full threshold < cfg_fifo_depth
  --! Can only be changed during reset.
  cfg_prog_full_threshold  : unsigned(MAX_FIFO_DEPTH_LOG2-1 downto 0) := (others=>'0');
  --! @brief 0(unused) < prog empty threshold < cfg_fifo_depth
  --! Can only be changed during reset.
  cfg_prog_empty_threshold : unsigned(MAX_FIFO_DEPTH_LOG2-1 downto 0) := (others=>'0');
  --! Write data enable
  wr_ena                   : in  std_logic;
  --! Write pointer for RAM based FIFOs with range 0 to cfg_fifo_depth-1
  wr_ptr                   : out unsigned(MAX_FIFO_DEPTH_LOG2-1 downto 0);
  --! FIFO full, '1' when level=FIFO_DEPTH
  wr_full                  : out std_logic;
  --! FIFO programmable full, '1' when level>=cfg_prog_full_threshold
  wr_prog_full             : out std_logic;
  --! FIFO overflow (when wr_ena=1 and wr_full=1)
  wr_overflow              : out std_logic;
  --! Read data enable
  rd_ena                   : in  std_logic;
  --! Read pointer for RAM based FIFOs with range 0 to cfg_fifo_depth-1
  rd_ptr                   : out unsigned(MAX_FIFO_DEPTH_LOG2-1 downto 0);
  --! FIFO empty, '1' when level=0
  rd_empty                 : out std_logic;
  --! FIFO programmable empty, '1' when level<=cfg_prog_empty_threshold
  rd_prog_empty            : out std_logic;
  --! FIFO underflow (when rd_ena=1 and rd_empty=1)
  rd_underflow             : out std_logic;
  --! FIFO fill level with range 0 to cfg_fifo_depth
  level                    : out unsigned(MAX_FIFO_DEPTH_LOG2-1 downto 0)
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of fifo_logic_sync is

  constant PTR_LENGTH : positive := MAX_FIFO_DEPTH_LOG2;
  constant PTR_MAX : unsigned(PTR_LENGTH-1 downto 0) := to_unsigned(FIFO_DEPTH-1,PTR_LENGTH);

  signal cfg_fifo_depth_q : unsigned(MAX_FIFO_DEPTH_LOG2-1 downto 0);
  signal cfg_prog_full_threshold_q : unsigned(MAX_FIFO_DEPTH_LOG2-1 downto 0);
  signal cfg_prog_empty_threshold_q : unsigned(MAX_FIFO_DEPTH_LOG2-1 downto 0);

  signal wr_ptr_i : unsigned(PTR_LENGTH-1 downto 0);
  signal rd_ptr_i : unsigned(PTR_LENGTH-1 downto 0);

  signal empty_i : std_logic;
  signal full_i : std_logic;

begin

  p_fifo_logic : process(clk)
    variable v_incr : std_logic;
    variable v_decr : std_logic;
    variable v_level : unsigned(level'range);
  begin
    if rising_edge(clk) then

      if rst='1' then
        v_level := (others=>'0');
        empty_i <= '1';
        full_i <= '0';
        wr_ptr_i <= (others=>'0');
        rd_ptr_i <= (others=>'0');
        wr_prog_full <= '0';
        rd_prog_empty <= '1';
        wr_overflow <= '0';
        rd_underflow <= '0';
        cfg_fifo_depth_q <= cfg_fifo_depth;
        cfg_prog_full_threshold_q <= cfg_prog_full_threshold;
        cfg_prog_empty_threshold_q <= cfg_prog_empty_threshold;

      else

        wr_overflow <= wr_ena and full_i;
        v_incr := wr_ena and (not full_i); 

        rd_underflow <= rd_ena and empty_i;
        v_decr := rd_ena and (not empty_i); 

        -- increment/decrement level
        if v_incr='1' and v_decr='0' then
          -- just write
          v_level := v_level + 1;
        elsif v_incr='0' and v_decr='1' then
          -- just read
          v_level := v_level - 1;
        end if;
              
        -- increment write pointer
        if v_incr='1' then
          if wr_ptr_i=PTR_MAX then
            wr_ptr_i <= (others=>'0');
          else
            wr_ptr_i <= wr_ptr_i + 1;
          end if;
        end if;

        -- increment read pointer
        if v_decr='1' then
          if rd_ptr_i=PTR_MAX then
            rd_ptr_i <= (others=>'0');
          else
            rd_ptr_i <= rd_ptr_i + 1;
          end if;
        end if;

        empty_i <= to_01(v_level=0);
        full_i <= to_01(v_level=cfg_fifo_depth_q);

        if cfg_prog_empty_threshold_q>0 then
          rd_prog_empty <= to_01(v_level<=cfg_prog_empty_threshold_q);
        else
          rd_prog_empty <= '1'; -- keep reset value
        end if;

        if cfg_prog_full_threshold_q>0 then
          wr_prog_full <= to_01(v_level>=cfg_prog_full_threshold_q);
        else
          wr_prog_full <= '0'; -- keep reset value
        end if;

      end if;
      
      level <= v_level;

    end if; --clock
  end process;

  wr_full <= full_i;
  rd_empty <= empty_i;

  wr_ptr <= wr_ptr_i;
  rd_ptr <= rd_ptr_i;
  
end architecture;
