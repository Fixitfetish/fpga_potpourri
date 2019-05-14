-------------------------------------------------------------------------------
--! @file       fifo_logic_sync2.vhdl
--! @author     Fixitfetish
--! @date       21/Mar/2019
--! @version    0.31
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
--
-- HISTORY
-- 0.10 : 28/May/2016  First version
-- 0.20 : 18/Mar/2019  FIFO depth and thresholds reconfigurable during reset
-- 0.30 : 20/Mar/2019  New generic to define reset value of FIFO full and prog_full flags
-- 0.31 : 21/Mar/2019  Report errors also during reset.  Minor changes and improved comments.
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
--! VHDL Instantiation Template:
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
--! I1 : fifo_logic_sync2
--! generic map (
--!   MAX_FIFO_DEPTH_LOG2 => positive, 
--!   FULL_RESET_VALUE    => std_logic
--! )
--! port map (
--!   clk                      => in  std_logic, -- clock
--!   rst                      => in  std_logic, -- synchronous reset
--!   cfg_fifo_depth_minus1    => unsigned,
--!   cfg_prog_full_threshold  => unsigned,
--!   cfg_prog_empty_threshold => unsigned,
--!   wr_ena                   => in  std_logic, 
--!   wr_ptr                   => out unsigned, 
--!   wr_full                  => out std_logic, 
--!   wr_prog_full             => out std_logic, 
--!   wr_overflow              => out std_logic, 
--!   rd_ena                   => in  std_logic, 
--!   rd_ptr                   => out unsigned, 
--!   rd_empty                 => out std_logic, 
--!   rd_prog_empty            => out std_logic, 
--!   rd_underflow             => out std_logic
--!   level                    => out integer,
--! );
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--!
entity fifo_logic_sync2 is
generic (
  --! @brief Maximum allowed FIFO depth in number of data words, LOG2 to enforce power 2 (mandatory!).
  --! Defines the size of write and read pointer and the range of thresholds.
  MAX_FIFO_DEPTH_LOG2 : positive;
  --! @brief Reset value of the flags wr_full and wr_prog_full
  FULL_RESET_VALUE : std_logic := '1'
);
port (
  --! Clock for read and write port
  clk                      : in  std_logic;
  --! Synchronous reset
  rst                      : in  std_logic;
  --! @brief FIFO depth in number of data words minus 1 (mandatory!). (2**N)-1 is recommended for efficiency.
  --! Can only be changed during reset.
  cfg_fifo_depth_minus1    : unsigned(MAX_FIFO_DEPTH_LOG2-1 downto 0);
  --! @brief 0(unused) < prog full threshold <= cfg_fifo_depth_minus1 .
  --! Can only be changed during reset. Optional, by default unused.
  cfg_prog_full_threshold  : unsigned(MAX_FIFO_DEPTH_LOG2-1 downto 0) := (others=>'0');
  --! @brief 0(unused) < prog empty threshold <= cfg_fifo_depth_minus1 .
  --! Can only be changed during reset. Optional, by default unused.
  cfg_prog_empty_threshold : unsigned(MAX_FIFO_DEPTH_LOG2-1 downto 0) := (others=>'0');
  --! Write data enable
  wr_ena                   : in  std_logic;
  --! Write pointer for RAM based FIFOs with range 0 to cfg_fifo_depth_minus1
  wr_ptr                   : out unsigned(MAX_FIFO_DEPTH_LOG2-1 downto 0);
  --! FIFO full, '1' when level = FIFO depth or during reset when FULL_RESET_VALUE='1'
  wr_full                  : out std_logic;
  --! @brief FIFO programmable full, '1' when level>=cfg_prog_full_threshold .
  --! By default returns FULL_RESET_VALUE when unused and during reset.
  wr_prog_full             : out std_logic;
  --! FIFO overflow (one cycle after wr_ena=1 and wr_full=1)
  wr_overflow              : out std_logic;
  --! Read data enable
  rd_ena                   : in  std_logic;
  --! Read pointer for RAM based FIFOs with range 0 to cfg_fifo_depth_minus1
  rd_ptr                   : out unsigned(MAX_FIFO_DEPTH_LOG2-1 downto 0);
  --! FIFO empty, '1' when level = 0 or during reset
  rd_empty                 : out std_logic;
  --! @brief FIFO programmable empty, '1' when level<=cfg_prog_empty_threshold .
  --! By default returns '1' when unused and during reset.
  rd_prog_empty            : out std_logic;
  --! FIFO underflow (one cycle after rd_ena=1 and rd_empty=1)
  rd_underflow             : out std_logic;
  --! FIFO fill level with range 0 to FIFO depth
  level                    : out unsigned(MAX_FIFO_DEPTH_LOG2 downto 0)
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of fifo_logic_sync2 is

  constant EMPTY_RESET_VALUE : std_logic := '1';

  signal cfg_fifo_depth_minus1_q : unsigned(MAX_FIFO_DEPTH_LOG2-1 downto 0);
  signal cfg_fifo_depth_q : unsigned(MAX_FIFO_DEPTH_LOG2 downto 0);
  signal cfg_prog_full_threshold_q : unsigned(MAX_FIFO_DEPTH_LOG2-1 downto 0);
  signal cfg_prog_empty_threshold_q : unsigned(MAX_FIFO_DEPTH_LOG2-1 downto 0);

  signal wr_ptr_i : unsigned(MAX_FIFO_DEPTH_LOG2-1 downto 0);
  signal rd_ptr_i : unsigned(MAX_FIFO_DEPTH_LOG2-1 downto 0);

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
        full_i <= FULL_RESET_VALUE;
        empty_i <= EMPTY_RESET_VALUE;
        wr_ptr_i <= (others=>'0');
        rd_ptr_i <= (others=>'0');
        wr_prog_full <= FULL_RESET_VALUE;
        rd_prog_empty <= EMPTY_RESET_VALUE;
        cfg_fifo_depth_minus1_q <= cfg_fifo_depth_minus1;
        cfg_fifo_depth_q <= resize(cfg_fifo_depth_minus1,cfg_fifo_depth_q'length) + 1;
        cfg_prog_full_threshold_q <= cfg_prog_full_threshold;
        cfg_prog_empty_threshold_q <= cfg_prog_empty_threshold;

      else

        v_incr := wr_ena and (not full_i); 
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
          if wr_ptr_i=cfg_fifo_depth_minus1_q then
            wr_ptr_i <= (others=>'0');
          else
            wr_ptr_i <= wr_ptr_i + 1;
          end if;
        end if;

        -- increment read pointer
        if v_decr='1' then
          if rd_ptr_i=cfg_fifo_depth_minus1_q then
            rd_ptr_i <= (others=>'0');
          else
            rd_ptr_i <= rd_ptr_i + 1;
          end if;
        end if;

        empty_i <= to_01(v_level=0);
        full_i <= to_01(v_level=cfg_fifo_depth_q);

        if cfg_prog_empty_threshold_q=0 then
          -- unused, keep reset value
          rd_prog_empty <= EMPTY_RESET_VALUE;
        else
          rd_prog_empty <= to_01(v_level<=cfg_prog_empty_threshold_q);
        end if;

        if cfg_prog_full_threshold_q=0 then
          -- unused, keep reset value
          wr_prog_full <= FULL_RESET_VALUE;
        else
          wr_prog_full <= to_01(v_level>=cfg_prog_full_threshold_q);
        end if;

      end if;

      level <= v_level;

      -- report errors (also during reset)
      wr_overflow <= wr_ena and full_i;
      rd_underflow <= rd_ena and empty_i;

    end if; --clock
  end process;

  wr_full <= full_i;
  rd_empty <= empty_i;

  wr_ptr <= wr_ptr_i;
  rd_ptr <= rd_ptr_i;

end architecture;