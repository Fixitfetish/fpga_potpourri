-------------------------------------------------------------------------------
--! @file       signed_mult_accu.vhdl
--! @author     Fixitfetish
--! @date       08/Feb/2017
--! @version    0.85
--! @copyright  MIT License
--! @note       VHDL-1993
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;

--! @brief Signed Multiply and Accumulate
--!
--! The behavior is as follows
--! * CLR=1  VLD=0  ->  r = undefined   # reset accumulator
--! * CLR=1  VLD=1  ->  r = +/-(x*y)    # restart accumulation
--! * CLR=0  VLD=0  ->  r = r           # hold accumulator
--! * CLR=0  VLD=1  ->  r = r +/-(x*y)  # proceed accumulation
--!
--! The length of the input factors is flexible.
--! The input factors are automatically resized with sign extensions bits to the
--! maximum possible factor length.
--! The maximum length of the input factors is device and implementation specific.
--!
--! If just the sum of products is required but not any further accumulation
--! then set CLR to constant '1'.
--!
--! The delay depends on the configuration and the underlying hardware.
--! The number pipeline stages is reported as constant at output port @link PIPESTAGES PIPESTAGES @endlink .

--
--    <----------------------------------- ACCU WIDTH ------------------------>
--    |        <-------------------------- ACCU USED WIDTH ------------------->
--    |        |              <----------- PRODUCT WIDTH --------------------->
--    |        |              |                                               |
--    +--------+---+----------+-------------------------------+---------------+
--    | unused |  GUARD BITS  |                               |  SHIFT RIGHT  |
--    |SSSSSSSS|OOO|ODDDDDDDDD|DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD|Rxxxxxxxxxxxxxx|
--    +--------+---+----------+-------------------------------+---------------+
--             |   |                                          |
--             |   <------------- OUTPUT WIDTH --------------->
--             <--------- ACCU USED SHIFTED WIDTH ------------>
--
-- ACCU WIDTH = accumulator width (depends on hardware/implementation)
-- PRODUCT WIDTH = ax'length+ay'length = bx'length+by'length
-- NUM_SUMMANDS = number of accumulated products
-- GUARD BITS = ceil(log2(NUM_SUMMANDS))
-- ACCU USED WIDTH = PRODUCT WIDTH + GUARD BITS <= ACCU WIDTH
-- OUTPUT SHIFT RIGHT = number of LSBs to prune
-- OUTPUT WIDTH = r'length
-- ACCU USED SHIFTED WIDTH = ACCU USED WIDTH - OUTPUT SHIFT RIGHT
--
-- S = irrelevant sign extension MSBs
-- O = overflow detection sign bits, all O must be identical otherwise overflow
-- D = output data bits
-- R = rounding bit (+0.5 when round 'nearest' is enabled)
-- x = irrelevant LSBs
--
-- Optimal settings for overflow detection and/or saturation/clipping :
-- GUARD BITS = OUTPUT WIDTH + OUTPUT SHIFT RIGHT + 1 - PRODUCT WIDTH

entity signed_mult_accu is
generic (
  --! @brief The number of summands is important to determine the number of additional
  --! guard bits (MSBs) that are required for the accumulation process. @link NUM_SUMMAND More...
  --! 
  --! The setting is relevant to save logic especially when saturation/clipping
  --! and/or overflow detection is enabled.
  --! * 0 => maximum possible, not recommended (worst case, hardware dependent)
  --! * 1 => just one multiplication without accumulation
  --! * 2 => accumulate up to 2 products
  --! * 3 => accumulate up to 3 products
  --! *  and so on ...
  --! 
  --! Note that every single accumulated product result counts!
  NUM_SUMMAND : natural := 0;
  --! Enable chain input from neighbor DSP cell, i.e. enable additional accumulator input
  USE_CHAIN_INPUT : boolean := false;
  --! @brief Number of additional input registers. At least one is strongly recommended.
  --! If available the input registers within the DSP cell are used.
  NUM_INPUT_REG : natural := 1;
  --! @brief Number of additional result output registers.
  --! At least one is recommended when logic for rounding and/or clipping is enabled.
  --! Typically all output registers are implemented in logic and are not part of a DSP cell.
  NUM_OUTPUT_REG : natural := 0;
  --! Number of bits by which the accumulator result output is shifted right
  OUTPUT_SHIFT_RIGHT : natural := 0;
  --! @brief Round 'nearest' (half-up) of result output.
  --! This flag is only relevant when OUTPUT_SHIFT_RIGHT>0.
  --! If the device specific DSP cell supports rounding then rounding is done
  --! within the DSP cell. If rounding in logic is necessary then it is recommended
  --! to enable the additional output register.
  OUTPUT_ROUND : boolean := true;
  --! Enable clipping when right shifted result exceeds output range.
  OUTPUT_CLIP : boolean := true;
  --! Enable overflow/clipping detection 
  OUTPUT_OVERFLOW : boolean := true
);
port (
  --! Standard system clock
  clk        : in  std_logic;
  --! Reset result output (optional)
  rst        : in  std_logic := '0';
  --! @brief Clear accumulator (mark first valid input factors of accumulation sequence).
  --! If accumulation is not wanted then set constant '1'.
  clr        : in  std_logic;
  --! Valid signal for input factors, high-active
  vld        : in  std_logic;
  --! Add/subtract product , '0' -> +(x*y), '1' -> -(x*y). Subtraction is disabled by default.
  sub        : in  std_logic := '0';
  --! 1st signed factor input
  x          : in  signed;
  --! 2nd signed factor input
  y          : in  signed;
  --! @brief Resulting product/accumulator output (optionally rounded and clipped).
  result     : out signed;
  --! Valid signal for result output, high-active
  result_vld : out std_logic;
  --! Result output overflow/clipping detection
  result_ovf : out std_logic;
  --! @brief Input from other chained DSP cell (optional, only used when input enabled and connected).
  --! The chain width is device specific. A maximum width of 96 bits is supported.
  --! If the device specific chain width is smaller then only the LSBs are used.
  chainin    : in  signed(95 downto 0) := (others=>'0');
  --! @brief Result output to other chained DSP cell (optional)
  --! The chain width is device specific. A maximum width of 96 bits is supported.
  --! If the device specific chain width is smaller then only the LSBs are used.
  chainout   : out signed(95 downto 0) := (others=>'0');
  --! Number of pipeline stages, constant, depends on configuration and device specific implementation
  PIPESTAGES : out natural := 0
);
end entity;

