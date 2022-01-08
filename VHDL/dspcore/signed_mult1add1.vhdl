-------------------------------------------------------------------------------
--! @file       signed_mult1add1.vhdl
--! @author     Fixitfetish
--! @date       01/Jan/2022
--! @version    0.10
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Code comments are optimized for SIGASI and DOXYGEN.
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;

--! @brief A product of two signed values is added or subtracted to/from a third signed value.
--! Optionally the chain input can be added as well.
--!
--! @image html signed_mult1add1.svg "" width=600px
--!
--! The behavior is as follows
--! * CLR=1  VLD=0  ->  r = undefined                  # reset accumulator
--! * CLR=1  VLD=1  ->  r = +/-(x*y) + z + chainin     # restart accumulation
--! * CLR=0  VLD=0  ->  r = r                          # hold accumulator
--! * CLR=0  VLD=1  ->  r = r +/-(x*y) + z + chainin   # proceed accumulation
--!
--! The length of the input factors is flexible.
--! The input factors are automatically resized with sign extensions bits to the
--! maximum possible factor length.
--! The maximum length of the input factors is device and implementation specific.
--!
--! @image html accumulator_register.svg "" width=800px
--!
--! * NUM_SUMMAND = 2 (or 3 when cahain input is enabled)
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
--! With NUM_SUMMAND=3 the number of additional guard bits is GUARD_BITS=2.
--! If the output length is 22 then the standard shift-right setting (conservative,
--! without risk of overflow) would be OUTPUT_SHIFT_RIGHT = 34 + 2 - 22 = 14.
--!
--! The delay depends on the configuration and the underlying hardware.
--! The number pipeline stages is reported as constant at output port @link PIPESTAGES PIPESTAGES @endlink .
--!
--! VHDL Instantiation Template:
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
--! I1 : signed_mult1add1
--! generic map(
--!   NUM_SUMMAND        => natural,  -- overall number of summed products
--!   USE_CHAIN_INPUT    => boolean,  -- enable chain input
--!   USE_Z_INPUT        => boolean,  -- enable Z input
--!   USE_NEGATION       => boolean,  -- enable NEG port
--!   NUM_INPUT_REG_XY   => natural,  -- number of input registers for X and Y
--!   NUM_INPUT_REG_Z    => natural,  -- number of input registers for Z
--!   NUM_OUTPUT_REG     => natural,  -- number of output registers
--!   OUTPUT_SHIFT_RIGHT => natural,  -- number of right shifts
--!   OUTPUT_ROUND       => boolean,  -- enable rounding half-up
--!   OUTPUT_CLIP        => boolean,  -- enable clipping
--!   OUTPUT_OVERFLOW    => boolean   -- enable overflow detection
--! )
--! port map(
--!   clk        => in  std_logic, -- clock
--!   rst        => in  std_logic, -- reset
--!   clkena     => in  std_logic, -- clock enable
--!   clr        => in  std_logic, -- clear accu
--!   vld        => in  std_logic, -- valid
--!   neg        => in  std_logic, -- negation
--!   x          => in  signed, -- first factor
--!   y          => in  signed, -- second factor
--!   z          => in  signed, -- additional summand after multiplication
--!   result     => out signed, -- multiply-add result
--!   result_vld => out std_logic, -- output valid
--!   result_ovf => out std_logic, -- output overflow
--!   chainin    => in  signed(79 downto 0), -- chain input
--!   chainout   => out signed(79 downto 0), -- chain output
--!   PIPESTAGES => out natural -- constant number of pipeline stages
--! );
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--!
entity signed_mult1add1 is
generic (
  --! @brief The number of summands is important to determine the number of additional
  --! guard bits (MSBs) that are required for the accumulation process. @link NUM_SUMMAND More...
  --!
  --! The setting is relevant to save logic especially when saturation/clipping
  --! and/or overflow detection is enabled.
  --! * 0 => maximum possible, not recommended (worst case, hardware dependent)
  --! * 1,2,3,.. => overall number of summands
  --!
  --! Note that every single summand at the final adder counts, i.e. product result, Z and chain input.
  NUM_SUMMAND : natural := 2;
  --! @brief Enable chain input from neighbor DSP cell, i.e. enable additional summand input.
  --! Enabling the chain input might disable the accumulator feature.
  USE_CHAIN_INPUT : boolean := false;
  --! Enable additional Z input. Note that this might disable the accumulator feature.
  USE_Z_INPUT : boolean := false;
  --! Enable negation. If disabled the input port NEG will be ignored.
  USE_NEGATION : boolean := false;
  --! @brief Number of additional input registers for inputs X and Y. At least one is strongly recommended.
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
  --! Reset result output (optional, only connect if really required!)
  rst        : in  std_logic := '0';
  --! Clock enable (optional)
  clkena     : in  std_logic := '1';
  --! @brief Clear accumulator (mark first valid input factors of accumulation sequence).
  --! This port might be ignored when USE_CHAIN_INPUT=true and/or USE_Z_INPUT=true.
  --! If accumulation is not wanted then set constant '1' (default).
  clr        : in  std_logic := '1';
  --! Valid signal for input factors, high-active
  vld        : in  std_logic;
  --! @brief Negation of product , '0' -> +(x*y), '1' -> -(x*y). 
  --! Negation is disabled by default.
  neg        : in  std_logic := '0';
  --! 1st signed factor input
  x          : in  signed;
  --! 2nd signed factor input
  y          : in  signed;
  --! @brief Additional summand after multiplication. Set "00" if unused (USE_Z_INPUT=false).
  --! Z is LSB bound to the LSB of the product x*y before shift right, i.e. similar to chain input.
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
  PIPESTAGES : out natural := 1
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (not OUTPUT_ROUND) or (OUTPUT_SHIFT_RIGHT/=0)
    report "WARNING in " & signed_mult1add1'INSTANCE_NAME &
           " Disabled rounding because OUTPUT_SHIFT_RIGHT is 0."
    severity warning;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;
