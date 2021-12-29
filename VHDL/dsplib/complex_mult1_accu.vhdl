-------------------------------------------------------------------------------
--! @file       complex_mult1_accu.vhdl
--! @author     Fixitfetish
--! @date       30/Jan/2021
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

--! @brief Complex Multiply and Accumulate
--!
--! @image html complex_mult1_accu.svg "" width=600px
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
--! If just the sum of products is required but not any further accumulation
--! then set CLR to constant '1'.
--!
--! The delay depends on the configuration and the underlying hardware.
--! The number pipeline stages is reported as constant at output port @link PIPESTAGES PIPESTAGES @endlink .
--!
--! TODO:
--! Optimal settings for overflow detection and/or saturation/clipping :
--! GUARD BITS = OUTPUT WIDTH + OUTPUT SHIFT RIGHT + 1 - PRODUCT WIDTH
--!
entity complex_mult1_accu is
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
  --! Note that every single accumulated product result counts!
  NUM_SUMMAND : natural := 0;
  --! Enable chain input from neighbor DSP cell, i.e. enable additional accumulator input : TODO
  USE_CHAIN_INPUT : boolean := false;
  --! @brief Number of additional input registers. At least one is strongly recommended.
  --! If available the input registers within the DSP cell are used.
  NUM_INPUT_REG : natural := 1;
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
  OUTPUT_OVERFLOW : boolean := true;
  --! @brief OPTIMIZATION : TODO
  --! * MAXIMUM_PERFORMANCE
  --! * MINIMUM_DSP_CELLS
  OPTIMIZATION : string := "MAXIMUM_PERFORMANCE"
);
port (
  --! Standard system clock
  clk        : in  std_logic;
  --! Global pipeline reset (optional, only connect if really required!)
  rst        : in  std_logic := '0';
  --! Clock enable (optional)
  clkena     : in  std_logic := '1';
  --! @brief Clear accumulator (mark first valid input factors of accumulation sequence).
  --! If accumulation is not wanted then set constant '1'.
  clr        : in  std_logic;
  --! Valid signal for input factors, high-active
  vld        : in  std_logic;
  --! @brief Negation of product , '0' -> +(x*y), '1' -> -(x*y). 
  --! Negation is disabled by default.
  neg        : in  std_logic := '0';
  --! 1st factor input, real component
  x_re       : in  signed;
  --! 1st factor input, imaginary component
  x_im       : in  signed;
  --! 2nd factor input, real component
  y_re       : in  signed;
  --! 2nd factor input, imaginary component
  y_im       : in  signed;
  --! @brief Resulting product/accumulator output (optionally rounded and clipped).
  --! The standard result output might be unused when chain output is used instead.
  result_re  : out signed;
  result_im  : out signed;
  --! Valid signal for result output, high-active
  result_vld : out std_logic;
  --! Result output overflow/clipping detection
  result_ovf : out std_logic;
  --! @brief Input from other chained DSP cell (optional, only used when input enabled and connected).
  --! The chain width is device specific. A maximum width of 80 bits is supported.
  --! If the device specific chain width is smaller then only the LSBs are used.
  chainin_re : in  signed(79 downto 0) := (others=>'0');
  chainin_im : in  signed(79 downto 0) := (others=>'0');
  --! @brief Result output to other chained DSP cell (optional)
  --! The chain width is device specific. A maximum width of 80 bits is supported.
  --! If the device specific chain width is smaller then only the LSBs are used.
  chainout_re: out signed(79 downto 0) := (others=>'0');
  chainout_im: out signed(79 downto 0) := (others=>'0');
  --! Number of pipeline stages, constant, depends on configuration and device specific implementation
  PIPESTAGES : out natural := 1
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (not OUTPUT_ROUND) or (OUTPUT_SHIFT_RIGHT/=0)
    report "WARNING in complex_mult1_accu :" &
           " Disabled rounding because OUTPUT_SHIFT_RIGHT is 0."
    severity warning;
  assert (x_re'length=x_im'length) and (y_re'length=y_im'length)
    report "ERROR in complex_mult1_accu :" &
           " Real and imaginary components must have same size."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;
