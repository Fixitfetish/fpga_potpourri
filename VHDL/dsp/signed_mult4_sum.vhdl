-------------------------------------------------------------------------------
--! @file       signed_mult4_sum.vhdl
--! @author     Fixitfetish
--! @date       14/Feb/2017
--! @version    0.50
--! @copyright  MIT License
--! @note       VHDL-1993
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;

--! @brief Four signed multiplications and sum of all product results.
--!
--! @image html signed_mult4_sum.svg "" width=600px
--!
--! The behavior is as follows
--! * VLD=0  then  r = r
--! * VLD=1  then  r = +/-(x0*y0) +/-(x1*y1) +/-...
--!
--! The length of the input factors is flexible.
--! The input factors are automatically resized with sign extensions bits to the
--! maximum possible factor length.
--! The maximum length of the input factors is device and implementation specific.
--! The resulting length of all products (x(n)'length + y(n)'length) must be the same.
--!
--! @image html accumulator_register.svg "" width=800px
--! * NUM_SUMMAND = 4
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
--! With NUM_SUMMAND=4 the number of additional guard bits is GUARD_BITS=2.
--! If the output length is 22 then the standard shift-right setting (conservative,
--! without risk of overflow) would be OUTPUT_SHIFT_RIGHT = 34 + 2 - 22 = 13.
--!
--! The delay depends on the configuration and the underlying hardware.
--! The number pipeline stages is reported as constant at output port @link PIPESTAGES PIPESTAGES @endlink .

entity signed_mult4_sum is
generic (
  --! @brief Number of additional input registers. At least one is strongly recommended.
  --! If available the input registers within the DSP cell are used.
  NUM_INPUT_REG : natural := 1;
  --! @brief Number of result output registers. One is strongly recommended.
  --! The first output register is typically the result register within the DSP cell. 
  --! A second output register is recommended
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
  --! Valid signal for input factors, high-active
  vld        : in  std_logic;
  --! Add/subtract for all products n=0..3 , '0' -> +(x(n)*y(n)), '1' -> -(x(n)*y(n)). Subtraction is disabled by default.
  sub        : in  std_logic_vector(0 to 3) := (others=>'0');
  --! 1st product, 1st signed factor input
  x0         : in  signed;
  --! 1st product, 2nd signed factor input
  y0         : in  signed;
  --! 2nd product, 1st signed factor input
  x1         : in  signed;
  --! 2nd product, 2nd signed factor input
  y1         : in  signed;
  --! 3rd product, 1st signed factor input
  x2         : in  signed;
  --! 3rd product, 2nd signed factor input
  y2         : in  signed;
  --! 4th product, 1st signed factor input
  x3         : in  signed;
  --! 4th product, 2nd signed factor input
  y3         : in  signed;
  --! @brief Resulting product/accumulator output (optionally rounded and clipped).
  --! The standard result output might be unused when chain output is used instead.
  result     : out signed;
  --! Valid signal for result output, high-active
  result_vld : out std_logic;
  --! Result output overflow/clipping detection
  result_ovf : out std_logic;
  --! @brief Result output to other chained DSP cell (optional)
  --! The chain width is device specific. A maximum width of 96 bits is supported.
  --! If the device specific chain width is smaller then only the LSBs are used.
  chainout   : out signed(95 downto 0) := (others=>'0');
  --! Number of pipeline stages, constant, depends on configuration and device specific implementation
  PIPESTAGES : out natural := 0
);
begin

  assert (     (x0'length+y0'length)=(x1'length+y1'length)
           and (x0'length+y0'length)=(x2'length+y2'length)
           and (x0'length+y0'length)=(x3'length+y3'length) )
    report "ERROR signed_mult4_sum : All products must result in same size."
    severity failure;

  assert (not OUTPUT_ROUND) or (OUTPUT_SHIFT_RIGHT/=0)
    report "WARNING signed_mult4_sum : Disabled rounding because OUTPUT_SHIFT_RIGHT is 0."
    severity warning;

end entity;

