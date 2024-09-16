-------------------------------------------------------------------------------
-- @file       signed_preadd_mult1add1.vhdl
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
--   NUM_ACCU_CYCLES     => positive,
--   NUM_SUMMAND_CHAININ => natural,
--   NUM_SUMMAND_Z       => natural,
--   USE_XB_INPUT        => boolean,
--   USE_NEGATION        => boolean,
--   USE_XA_NEGATION     => boolean,
--   USE_XB_NEGATION     => boolean,
--   NUM_INPUT_REG_X     => natural,
--   NUM_INPUT_REG_Y     => natural,
--   NUM_INPUT_REG_Z     => natural,
--   RELATION_RST        => string,
--   RELATION_CLR        => string,
--   RELATION_NEG        => string,
--   NUM_OUTPUT_REG      => natural,
--   OUTPUT_SHIFT_RIGHT  => boolean,
--   OUTPUT_ROUND        => boolean,
--   OUTPUT_CLIP         => boolean,
--   OUTPUT_OVERFLOW     => boolean
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
  -- Number of cycles in which products, Z and/or chain inputs are accumulated and contribute
  -- to the accumulation register before it is cleared.
  -- Set 1 (default) to disable accumulation and ignore CLR input.
  -- The number of cycles is important to determine the number of additional
  -- guard bits (MSBs) that are required for the summation/accumulation process.
  -- The setting is also relevant to save logic especially when saturation/clipping
  -- and/or overflow detection is enabled.
  NUM_ACCU_CYCLES : positive := 1;
  -- Number of summands at the chain input that contribute to the accumulation register
  -- in each cycle. Set 0 to disable the chain input (default).
  -- The number of summands is important to determine the number of additional
  -- guard bits (MSBs) that are required for the summation/accumulation process.
  NUM_SUMMAND_CHAININ : natural := 0;
  -- Number of summands at the Z input that contribute to the accumulation register
  -- in each cycle. Set 0 to disable the Z input (default).
  -- The number of summands is important to determine the number of additional
  -- guard bits (MSBs) that are required for the summation/accumulation process.
  NUM_SUMMAND_Z : natural := 0;
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
  clk          : in  std_logic;
  -- Synchronous reset (optional, only connect if really required!)
  rst          : in  std_logic := '0';
  -- Clock enable (optional)
  clkena       : in  std_logic := '1';
  -- Clear accumulator (mark first valid input of accumulation sequence).
  -- Only relevant when USE_ACCU=true. If accumulation is not wanted then set constant '1'.
  clr          : in  std_logic := '1';
  -- Negation of product , '0'->+(x*y), '1'->-(x*y) . Only relevant when USE_NEGATION=true.
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
  -- Pipelined output reset
  result_rst   : out std_logic;
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
  assert (RELATION_RST="X" or RELATION_RST="Y" or RELATION_RST="Z")
    report "ERROR " & signed_preadd_mult1add1'INSTANCE_NAME & ": " & 
           " Generic RELATION_RST must be X, Y or Z."
    severity failure;
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
