-------------------------------------------------------------------------------
-- @file       complex_mult1add1.vhdl
-- @author     Fixitfetish
-- @date       15/Sep/2024
-- @note       VHDL-2008
-- @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Code comments are optimized for SIGASI.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

-- Multiply the two complex inputs X and Y. Optionally, the complex chain input
-- and complex Z input can be added to the product result as well.
--
-- The behavior is as follows
--
-- | NEG | X_CONJ | Y_CONJ | Operation                |
-- |:---:|:------:|:------:|:-------------------------|
-- |  0  |    0   |    0   | M =      X  *      Y     |
-- |  0  |    0   |    1   | M =      X  * conj(Y)    |
-- |  0  |    1   |    0   | M = conj(X) *      Y     |
-- |  0  |    1   |    1   | M = conj(X) * conj(Y)    |
-- |  1  |    0   |    0   | M = -      X  *      Y   |
-- |  1  |    0   |    1   | M = -      X  * conj(Y)  |
-- |  1  |    1   |    0   | M = - conj(X) *      Y   |
-- |  1  |    1   |    1   | M = - conj(X) * conj(Y)  |
--
-- | CLR | VLD | Operation                      | Comment                   |
-- |-----|-----|--------------------------------|---------------------------|
-- |  1  |  0  | P = undefined                  | reset accumulator         |
-- |  1  |  1  | P = +/-M + Z + CHAININ         | restart/no accumulation   |
-- |  0  |  0  | P = P                          | hold accumulator/output   |
-- |  0  |  1  | P = P +/-M + (Z or CHAININ)    | proceed accumulation      |
--
-- The length of the input factors X and Y is flexible, but the real and imaginary components should have the same length.
-- The input factors are automatically resized with sign extensions bits to the maximum possible factor length.
-- The maximum length of the input factors is device and implementation specific.
-- The summand inputs Z and CHAININ are LSB bound to the LSB of the product M.
-- Output P is the result before the optional shift right, clipping and rounding.
--
-- @image html accumulator_register.svg "" width=800px
--
-- * NUM_SUMMAND = configurable, @link NUM_SUMMAND more... @endlink
-- * ACCU WIDTH = accumulator width (device specific)
-- * PRODUCT WIDTH = x'length + y'length
-- * GUARD BITS = ceil(log2(NUM_SUMMAND))
-- * ACCU USED WIDTH = PRODUCT WIDTH + GUARD BITS <= ACCU WIDTH
-- * OUTPUT SHIFT RIGHT = number of LSBs to prune
-- * OVFL = overflow detection sign bits, all must match the output sign bit otherwise overflow
-- * R = rounding bit (+0.5 when OUTPUT ROUND is enabled)
-- * ACCU USED SHIFTED WIDTH = ACCU USED WIDTH - OUTPUT SHIFT RIGHT
-- * OUTPUT WIDTH = length of result output <= ACCU USED SHIFTED WIDTH
--
-- \b Example: The input lengths are x'length=18 and y'length=16, hence PRODUCT_WIDTH=34.
-- With NUM_SUMMAND=30 the number of additional guard bits is GUARD_BITS=5.
-- If the output length is 22 then the standard shift-right setting (conservative,
-- without risk of overflow) would be OUTPUT_SHIFT_RIGHT = 34 + 5 - 22 = 17.
--
-- If just the sum of products is required but not any further accumulation
-- then set CLR to constant '1'.
--
-- The delay depends on the configuration and the underlying hardware.
-- The number pipeline stages is reported as constant at output port PIPESTAGES.
--
-- TODO:
-- Optimal settings for overflow detection and/or saturation/clipping :
-- GUARD BITS = OUTPUT WIDTH + OUTPUT SHIFT RIGHT + 1 - PRODUCT WIDTH
--
entity complex_mult1add1 is
generic (
  -- OPTIMIZATION can be either "PERFORMANCE" or "RESOURCES"
  OPTIMIZATION : string := "RESOURCES";
  -- Number of cycles in which products, Z and/or chain inputs are accumulated and contribute
  -- to the accumulation register before it is cleared.
  -- Set 1 (default) to disable accumulation and ignore CLR input.
  -- The number of cycles is important to determine the number of additional
  -- guard bits (MSBs) that are required for the summation/accumulation process.
  -- The setting is also relevant to save logic especially when saturation/clipping
  -- and/or overflow detection is enabled.
  NUM_ACCU_CYCLES : positive := 1;
  -- Number of complex summands at the chain input that contribute to the accumulation register
  -- in each cycle. Set 0 to disable the chain input (default).
  -- The number of summands is important to determine the number of additional
  -- guard bits (MSBs) that are required for the summation/accumulation process.
  NUM_SUMMAND_CHAININ : natural := 0;
  -- Number of complex summands at the Z input that contribute to the accumulation register
  -- in each cycle. Set 0 to disable the Z input (default).
  -- The number of summands is important to determine the number of additional
  -- guard bits (MSBs) that are required for the summation/accumulation process.
  NUM_SUMMAND_Z : natural := 0;
  -- Enable NEG input port and allow dynamic product negation. Might require more resources and power.
  USE_NEGATION : boolean := false;
  -- Enable X_CONJ input port for complex conjugate X, i.e. negation of input port X_IM.
  USE_CONJUGATE_X : boolean := false;
  -- Enable Y_CONJ input port for complex conjugate Y, i.e. negation of input port Y_IM.
  USE_CONJUGATE_Y : boolean := false;
  -- Number of input registers for inputs X and Y. At least one DSP internal register is required.
  NUM_INPUT_REG_XY : positive := 1;
  -- Number of registers for input Z. At least one DSP internal register is required.
  -- NOTE: In the 3-DSP mode (e.g. DSP48E2 with OPTIMIZATION="RESOURCES") the Z input is not supported
  -- and NUM_INPUT_REG_Z defines the number of pipeline registers from the 1st to the 2nd stage.
  -- Try NUM_INPUT_REG_Z=2 if you face timing issues.
  NUM_INPUT_REG_Z : positive := 1;
  -- Defines if the RST input port is synchronous to input signal "X", "Y" or "Z".
  RELATION_RST : string := "X";
  -- Defines if the CLR input port is synchronous to input signal "X", "Y" or "Z".
  RELATION_CLR : string := "X";
  -- Defines if the product negation input port NEG is synchronous to input signal "X" or "Y".
  RELATION_NEG : string := "X";
  -- Number of result output registers. At least one DSP internal register is required.
  NUM_OUTPUT_REG : positive := 1;
  -- Number of bits by which the accumulator result output is shifted right
  OUTPUT_SHIFT_RIGHT : natural := 0;
  -- Round 'nearest' (half-up) of result output.
  -- This flag is only relevant when OUTPUT_SHIFT_RIGHT>0.
  -- If the device specific DSP cell supports rounding then rounding is done
  -- within the DSP cell. If rounding in logic is necessary then it is recommended
  -- to use an additional output register.
  OUTPUT_ROUND : boolean := true;
  -- Enable clipping when right shifted result exceeds output range.
  OUTPUT_CLIP : boolean := true;
  -- Enable overflow/clipping detection 
  OUTPUT_OVERFLOW : boolean := true
);
port (
  -- Standard system clock
  clk             : in  std_logic;
  -- Global pipeline reset (optional, only connect if really required!)
  rst             : in  std_logic := '0';
  -- Clock enable (optional)
  clkena          : in  std_logic := '1';
  -- Clear accumulator (mark first valid input factors of accumulation sequence).
  -- If accumulation is not wanted then set constant '1'.
  clr             : in  std_logic := '1';
  -- Negation of product , '0' -> +(x*y), '1' -> -(x*y). Only relevant when USE_NEGATION=true .
  neg             : in  std_logic := '0';
  -- 1st factor input, real component
  x_re            : in  signed;
  -- 1st factor input, imaginary component
  x_im            : in  signed;
  x_vld           : in  std_logic;
  -- Complex conjugate X , '0' -> +x_im, '1' -> -x_im. Only relevant when USE_CONJUGATE_X=true .
  x_conj          : in  std_logic := '0';
  -- 2nd factor input, real component
  y_re            : in  signed;
  -- 2nd factor input, imaginary component
  y_im            : in  signed;
  y_vld           : in  std_logic;
  -- Complex conjugate Y , '0' -> +y_im, '1' -> -y_im. Only relevant when USE_CONJUGATE_Y=true .
  y_conj          : in  std_logic := '0';
  -- Additional summand after multiplication, real component. Set "00" if unused.
  -- Z is LSB bound to the LSB of the product x*y before shift right, i.e. similar to chain input.
  z_re            : in  signed;
  -- Additional summand after multiplication, imaginary component. Set "00" if unused.
  -- Z is LSB bound to the LSB of the product x*y before shift right, i.e. similar to chain input.
  z_im            : in  signed;
  -- Valid signal synchronous to input Z, high-active. Set '0' if input Z is unused.
  z_vld           : in  std_logic := '0';
  -- Resulting product/accumulator output (optionally rounded and clipped).
  -- The standard result output might be unused when chain output is used instead.
  result_re       : out signed;
  result_im       : out signed;
  -- Valid signal for result output, high-active
  result_vld      : out std_logic;
  -- Result output real component overflow/clipping detection
  result_ovf_re   : out std_logic;
  -- Result output imaginary component overflow/clipping detection
  result_ovf_im   : out std_logic;
  -- Pipelined output reset
  result_rst      : out std_logic;
  -- Input from other chained DSP cell (optional, only used when input enabled and connected).
  -- The chain width is device specific. A maximum width of 80 bits is supported.
  -- If the device specific chain width is smaller then only the LSBs are used.
  chainin_re      : in  signed(79 downto 0) := (others=>'0');
  chainin_im      : in  signed(79 downto 0) := (others=>'0');
  -- Valid signal of chain input one cycle ahead of PCIN, high-active. Set '0' if chain input is unused.
  -- For timing reasons two separate signals though both are synchronous.
  chainin_re_vld  : in  std_logic := '0';
  chainin_im_vld  : in  std_logic := '0';
  -- Result output to other chained DSP cell (optional)
  -- The chain width is device specific. A maximum width of 80 bits is supported.
  -- If the device specific chain width is smaller then only the LSBs are used.
  chainout_re     : out signed(79 downto 0) := (others=>'0');
  chainout_im     : out signed(79 downto 0) := (others=>'0');
  -- Valid signal of chain output one cycle ahead of PCOUT, high-active.
  -- For timing reasons two separate signals though both are synchronous.
  chainout_re_vld : out std_logic;
  chainout_im_vld : out std_logic;
  -- Number of pipeline stages in X path, constant, depends on configuration and device specific implementation
  PIPESTAGES      : out integer := 1
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (RELATION_RST="X" or RELATION_RST="Y" or RELATION_RST="Z")
    report "ERROR " & complex_mult1add1'INSTANCE_NAME & ": " & 
           " Generic RELATION_RST must be X, Y or Z."
    severity failure;
  assert (RELATION_CLR="X" or RELATION_CLR="Y" or RELATION_CLR="Z")
    report "ERROR " & complex_mult1add1'INSTANCE_NAME & ": " & 
           " Generic RELATION_CLR must be X, Y or Z."
    severity failure;
  assert (RELATION_NEG="X" or RELATION_NEG="Y")
    report "ERROR " & complex_mult1add1'INSTANCE_NAME & ": " & 
           " Generic RELATION_NEG must be X or Y."
    severity failure;
  assert (x_re'length=x_im'length)
    report "ERROR in " & complex_mult1add1'INSTANCE_NAME & ": " & 
           " Real and imaginary components of X input must have same size."
    severity failure;
  assert (y_re'length=y_im'length)
    report "ERROR in " & complex_mult1add1'INSTANCE_NAME & ": " & 
           " Real and imaginary components of Y input must have same size."
    severity failure;
  assert (z_re'length=z_im'length)
    report "ERROR in " & complex_mult1add1'INSTANCE_NAME & ": " & 
           " Real and imaginary components of Z input must have same size."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;
