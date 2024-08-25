-------------------------------------------------------------------------------
-- @file       signed_preadd_mult1add1.vhdl
-- @author     Fixitfetish
-- @date       25/Aug/2024
-- @version    0.20
-- @note       VHDL-1993
-- @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Code comments are optimized for SIGASI.
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;

-- This entity abstracts and wraps Xilinx DSP cells for standard preadder,
-- multiplication and accumulate operation.
--
-- Multiply the sum of two signed (XB +/- XA) with a signed Y and accumulate results.
-- Optionally, the chain input and Z input can be added to the product result as well.
--
-- @image html signed_preadd_mult1add1.svg "" width=600px
--
-- The behavior is as follows
--
-- | CLR | VLD | Operation                                 | Comment                |
-- |-----|-----|-------------------------------------------|------------------------|
-- |  1  |  0  | P = undefined                             | reset accumulator      |
-- |  1  |  1  | P = (XB +/- XA)*Y + Z + CHAININ           | restart accumulation   |
-- |  0  |  0  | P = P                                     | hold accumulator       |
-- |  0  |  1  | P = P + (XB +/- XA)*Y + (Z or CHAININ)    | proceed accumulation   |
--
-- All DSP internal registers before the final accumulator P register are considered to be input registers.
-- * The XA and XB path always have the same number of input register.
-- * The MREG after multiplication is considered as second input register in X and Y path.
-- * The Z path bypasses MREG and allows maximum one input register.
-- * The X and Y path should have at least 2 input registers for performance since this ensures MREG activation.
--
-- Limitations
-- * If the two additional inputs CHAININ and C are enabled then accumulation is not possible (because P feedback is not possible).
--   In this case the CLR input is ignored. DSP internal rounding is also not supported in this case.
-- * Preadder always uses XA and/or XB inputs but never the Y input.
--
-- Note that this implementation does not support
-- * SIMD, A:B, WideXOR, pattern detection
-- * CARRY, MULTISIGN
-- * A and B input cascade
--
-- VHDL Instantiation Template:
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
-- I1 : signed_preadd_mult1add1
-- generic map(
--   NUM_SUMMAND      => natural,
--   USE_XB_INPUT     => boolean,
--   USE_NEGATION     => boolean,
--   USE_XA_NEGATION  => boolean,
--   USE_XB_NEGATION  => boolean,
--   NUM_INPUT_REG_X  => natural,
--   NUM_INPUT_REG_Y  => natural,
--   NUM_INPUT_REG_Z  => natural,
--   RELATION_CLR     => string,
--   RELATION_NEG     => string,
--   NUM_OUTPUT_REG   => natural,
--   ROUND_ENABLE     => boolean,
--   ROUND_BIT        => natural
-- )
-- port map(
--   clk          => in  std_logic,
--   rst          => in  std_logic,
--   clkena       => in  std_logic,
--   clr          => in  std_logic,
--   neg          => in  std_logic, -- negate product
--   xa           => in  signed, -- first factor, main input
--   xa_vld       => in  std_logic,
--   xa_neg       => in  std_logic, -- negate xa
--   xb           => in  signed, -- first factor, second preadder input
--   xb_vld       => in  std_logic,
--   xb_neg       => in  std_logic, -- negate xb
--   y            => in  signed, -- second factor
--   z            => in  signed, -- additional summand after multiplication
--   z_vld        => in  std_logic,
--   result       => out signed,
--   result_vld   => out std_logic,
--   result_ovf   => out std_logic,
--   chainin      => in  signed(79 downto 0),
--   chainin_vld  => in  std_logic,
--   chainout     => out signed(79 downto 0),
--   chainout_vld => out std_logic,
--   PIPESTAGES   => out natural
-- );
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--
entity signed_preadd_mult1add1 is
generic (
  -- Enable feedback of accumulator register P into DSP ALU when input port CLR=0
  USE_ACCU : boolean := false;
  -- The number of summands is important to determine the number of additional
  -- guard bits (MSBs) that are required for the accumulation process. @link NUM_SUMMAND More...
  --
  -- The setting is relevant to save logic especially when saturation/clipping
  -- and/or overflow detection is enabled.
  -- * 0 => maximum possible, not recommended (worst case, hardware dependent)
  -- * 1,2,3,.. => overall number of summands
  --
  -- Note that every single summand that contributes to the final accumulator register
  -- counts, i.e. product results, Z and chain inputs. All summands are assumed to have
  -- the same width as a single product.
  NUM_SUMMAND : natural;
  -- Enable additional XB preadder input. Might require more resources and power.
  USE_XB_INPUT : boolean := false;
  -- Enable NEG input port and allow dynamic product negation. Might require more resources and power.
  -- Can be also used for input port Y negation.
  USE_NEGATION : boolean := false;
  -- Enable XA_NEG input port and allow separate dynamic negation of preadder input port XA.
  -- Might require more resources and power. Typically only relevant when USE_XB_INPUT=true
  -- because otherwise preferably the product negation should be used.
  USE_XA_NEGATION : boolean := false;
  -- Enable XB_NEG input port and allow separate dynamic negation of preadder input port XB.
  -- Might require more resources and power. Only relevant when USE_XB_INPUT=true.
  USE_XB_NEGATION : boolean := false;
  -- Number input registers for inputs XA and XB. At least one DSP internal register is required.
  -- Current assumption is that XB input (when enabled) is synchronous to XA input.
  NUM_INPUT_REG_X : positive := 1;
  -- Number of input registers for input Y. At least one DSP internal register is required.
  NUM_INPUT_REG_Y : positive := 1;
  -- Number of registers for input Z. At least one DSP internal register is required.
  NUM_INPUT_REG_Z : positive := 1;
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
  clk          : in  std_logic;
  -- Global pipeline reset (optional, only connect if really required!)
  rst          : in  std_logic := '0';
  -- Clock enable (optional)
  clkena       : in  std_logic := '1';
  -- Clear accumulator (mark first valid input factors of accumulation sequence).
  -- Only relevant when USE_ACCU=true. If accumulation is not wanted then set constant '1'.
  clr          : in  std_logic := '1';
  -- Negation of product , '0'->+(a*b), '1'->-(a*b) . Only relevant when USE_NEGATION=true.
  neg          : in  std_logic := '0';
  -- 1st factor input (also 1st preadder input). Choose width as small as possible! Set "00" if unused.
  xa           : in  signed;
  -- Valid signal synchronous to input XA, high-active. Set '0' if input XA is unused.
  xa_vld       : in  std_logic := '0';
  -- Negation of XA synchronous to input XA, '0'=+xa, '1'=-xa . Only relevant when USE_XA_NEGATION=true.
  xa_neg       : in  std_logic := '0';
  -- 1st factor input (2nd preadder input). Choose width as small as possible! Set "00" if unused (USE_XB_INPUT=false).
  xb           : in  signed;
  -- Valid signal synchronous to input XB, high-active. Set '0' if input XB is unused.
  xb_vld       : in  std_logic := '0';
  -- Negation of XB synchronous to input XB, '0'=+xb, '1'=-xb . Only relevant when USE_XB_NEGATION=true.
  xb_neg       : in  std_logic := '0';
  -- 2nd factor input. Choose width as small as possible!
  y            : in  signed;
  -- Valid signal synchronous to input Y, high-active. Only connect when really required.
  y_vld        : in  std_logic := '1';
  -- Additional summand after multiplication. Choose width as small as possible! Set "00" if unused.
  -- Z is LSB bound to the LSB of the product x*y before shift right. Z can be wider than the product x*y and
  -- already include a partial sum, i.e. Z is similar to the chain input.
  z            : in  signed;
  -- Valid signal synchronous to input Z, high-active. Set '0' if input Z is unused.
  z_vld        : in  std_logic := '0';
  -- Resulting product/accumulator output (optionally rounded and clipped).
  -- The standard result output might be unused when chain output is used instead.
  result       : out signed;
  -- Valid signal for result output, high-active
  result_vld   : out std_logic;
  -- Result output overflow/clipping detection
  result_ovf   : out std_logic;
  -- Input from other chained DSP cell (optional, only used when input enabled and connected).
  -- The chain width is device specific. A maximum width of 80 bits is supported.
  -- If the device specific chain width is smaller then only the LSBs are used.
  -- The chain input can be wider than the product x*y and already include a partial sum.
  chainin      : in  signed(79 downto 0) := (others=>'0');
  -- Valid signal of CHAININ data (PCIN) one cycle ahead of data, high-active. Set '0' if chain input is unused.
  chainin_vld  : in  std_logic := '0';
  -- Result output to other chained DSP cell (optional)
  -- The chain width is device specific. A maximum width of 80 bits is supported.
  -- If the device specific chain width is smaller then only the LSBs are used.
  chainout     : out signed(79 downto 0) := (others=>'0');
  -- Valid signal of CHAINOUT data (PCOUT) one cycle ahead of data, high-active.
  chainout_vld : out std_logic;
  -- Number of pipeline stages from x-in to result-out, constant, depends on configuration and device specific implementation
  PIPESTAGES   : out integer := 1
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (RELATION_CLR="X" or RELATION_CLR="Y" or RELATION_CLR="Z")
    report "ERROR " & signed_preadd_mult1add1'INSTANCE_NAME & ": " & 
           " Generic RELATION_CLR must be X, Y or Z."
    severity failure;

  assert (RELATION_NEG="X" or RELATION_NEG="Y")
    report "ERROR " & signed_preadd_mult1add1'INSTANCE_NAME & ": " & 
           " Generic RELATION_NEG must be X or Y."
    severity failure;

  assert (USE_XB_INPUT or not USE_XB_NEGATION)
    report "ERROR " & signed_preadd_mult1add1'INSTANCE_NAME & ": " &
           "Negation of input port XB not possible because input port XB is disabled." &
           "Set either USE_XB_INPUT=true or USE_XB_NEGATION=false ."
    severity failure;

  assert (USE_XA_NEGATION or not USE_XB_NEGATION)
    report "ERROR " & signed_preadd_mult1add1'INSTANCE_NAME & ": " & 
           "Swap XA and XB input ports and enable USE_XA_NEGATION instead of USE_XB_NEGATION to save resources and power."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;
