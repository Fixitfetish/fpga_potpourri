-------------------------------------------------------------------------------
--! @file       signed_mult1add1_accu.vhdl
--! @author     Fixitfetish
--! @date       17/Mar/2017
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

--! @brief A product of two signed values is added or subtracted to/from a third
--! signed value. The results of this operation can be accumulated.
--!
--! @image html signed_mult1add1_accu.svg "" width=600px
--!
--! The behavior is as follows
--! * CLR=1  VLD=0  ->  r = undefined       # reset accumulator
--! * CLR=1  VLD=1  ->  r = z +/-(x*y)      # restart accumulation
--! * CLR=0  VLD=0  ->  r = r               # hold accumulator
--! * CLR=0  VLD=1  ->  r = r + z +/-(x*y)  # proceed accumulation
--!
--! The length of the input factors is flexible.
--! The input factors are automatically resized with sign extensions bits to the
--! maximum possible factor length.
--! The maximum length of the input factors is device and implementation specific.
--!
--! @image html accumulator_register.svg "" width=800px
--!
--! * NUM_SUMMAND = configurable, @link NUM_SUMMAND more... @endlink
--! * ACCU WIDTH = accumulator width (device specific)
--! * PRODUCT WIDTH = x'length + y'length
--! * GUARD BITS = ceil(log2(NUM_SUMMAND))
--! * ACCU USED WIDTH = PRODUCT WIDTH + GUARD BITS <= ACCU WIDTH
--! * OUTPUT SHIFT RIGHT = number of LSBs to prune
--! * OVFL = overflow detection sign bits, all must match the output sign bit otherwise overflow
--! * R = rounding bit (+0.5 when OUTPUT ROUND is enabled)
--! * ACCU USED SHIFTED WIDTH = ACCU USED WIDTH - OUTPUT SHIFT RIGHT
--! * OUTPUT WIDTH = length of result output <= ACCU USED SHIFTED WIDTH
--!
--! \b Example: The input lengths are x'length=18 and y'length=16, hence PRODUCT_WIDTH=34.
--! With NUM_SUMMAND=30 the number of additional guard bits is GUARD_BITS=5.
--! If the output length is 22 then the standard shift-right setting (conservative,
--! without risk of overflow) would be OUTPUT_SHIFT_RIGHT = 34 + 5 - 22 = 17.
--!
--! If just the sum is required but not any further accumulation then set
--! CLR to constant '1' or use the entity signed_mult1add1_sum .
--!
--! The delay depends on the configuration and the underlying hardware.
--! The number pipeline stages is reported as constant at output port @link PIPESTAGES PIPESTAGES @endlink .

--
-- Optimal settings for overflow detection and/or saturation/clipping :
-- GUARD BITS = OUTPUT WIDTH + OUTPUT SHIFT RIGHT + 1 - PRODUCT WIDTH

entity signed_mult1add1_accu is
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
  --! * and so on ...
  --!
  --! Note that for accumulation every product X*Y result, every input Z and
  --! every chain input counts!
  NUM_SUMMAND : natural := 0;
  --! Enable chain input from neighbor DSP cell, i.e. enable additional accumulator input
  USE_CHAIN_INPUT : boolean := false;
  --! @brief Number of additional input registers. At least one is strongly recommended.
  --! If available the input registers within the DSP cell are used.
  NUM_INPUT_REG_XY : natural := 1;
  --! @brief Number of additional input registers for input Z. At least one is strongly recommended.
  --! If available the input registers within the DSP cell are used.
  NUM_INPUT_REG_Z : natural := 1;
  --! @brief Number of result output registers. One is strongly recommended and even required
  --! when the accumulation feature is needed. The first output register is typically the
  --! result/accumulation register within the DSP cell. A second output register is recommended
  --! when logic for rounding, clipping and/or overflow detection is enabled.
  --! Typically all output registers after the first one are not part of a DSP cell
  --! and therefore implemented in logic.
  NUM_OUTPUT_REG : natural := 1;
  --! Number of bits by which the accumulator result output is shifted right
  OUTPUT_SHIFT_RIGHT : natural := 0;
  --! @brief Round 'nearest' (half-up) of result output.
  --! This flag is only relevant when OUTPUT_SHIFT_RIGHT>0.
  --! If the device specific DSP cell supports rounding then rounding is done
  --! within the DSP cell. If rounding in logic is necessary then it is recommended
  --! to use an additional output register.
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
  --! @brief Additional summand after multiplication.
  --! Should have same length as product x*y before shift right, i.e. similar to chain input.
  z          : in  signed;
  --! @brief Resulting product/accumulator output (optionally rounded and clipped).
  --! The standard result output might be unused when chain output is used instead.
  result     : out signed;
  --! Valid signal for result output, high-active
  result_vld : out std_logic;
  --! Result output overflow/clipping detection
  result_ovf : out std_logic;
  --! @brief Input from other chained DSP cell (optional, only used when input enabled and connected).
  --! The chain width is device specific. A maximum width of 80 bits is supported.
  --! If the device specific chain width is smaller then only the LSBs are used.
  chainin    : in  signed(79 downto 0) := (others=>'0');
  --! @brief Result output to other chained DSP cell (optional)
  --! The chain width is device specific. A maximum width of 80 bits is supported.
  --! If the device specific chain width is smaller then only the LSBs are used.
  chainout   : out signed(79 downto 0) := (others=>'0');
  --! @brief Number of pipeline stages, constant, depends on configuration and device specific implementation.
  --! Here the pipeline stages of the main X*Y path through the multiplier are reported.
  PIPESTAGES : out natural := 0
);
begin

  assert (not OUTPUT_ROUND) or (OUTPUT_SHIFT_RIGHT/=0)
    report "WARNING in " & signed_mult1add1_accu'INSTANCE_NAME &
           " Disabled rounding because OUTPUT_SHIFT_RIGHT is 0."
    severity warning;

end entity;

