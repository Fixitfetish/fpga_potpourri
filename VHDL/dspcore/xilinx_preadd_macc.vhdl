-------------------------------------------------------------------------------
--! @file       xilinx_preadd_macc.vhdl
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

--! @brief This entity abstracts and wraps Xilinx DSP cells for standard preadder,
--! multiplication and accumulate operation.
--!
--! Multiply the sum of two signed (D +/- A) with a signed B and accumulate results.
--! Optionally, the chain input and C input can be added to the product result as well.
--!
--! @image html xilinx_preadd_macc.svg "" width=600px
--!
--! The behavior is as follows
--!
--! | CLR | VLD | Operation                                 | Comment                |
--! |-----|-----|-------------------------------------------|------------------------|
--! |  1  |  0  | P = undefined                             | reset accumulator      |
--! |  1  |  1  | P = (D +/- A)*B + C + CHAININ             | restart accumulation   |
--! |  0  |  0  | P = P                                     | hold accumulator       |
--! |  0  |  1  | P = P + (D +/- A)*B + (C or CHAININ)      | proceed accumulation   |
--!
--! All DSP internal registers before the final accumulator P register are considered to be input registers.
--! * The A and D path always have the same number of input register.
--! * The MREG after multiplication is considered as second input register in AD and B path.
--! * The C path bypasses MREG and allows maximum one input register.
--! * The AD and B path should have at least 2 input registers for performance since this ensures MREG activation.
--! * DSP external data pipeline registers and delay compensation are NOT realized in this entity.
--!
--! Limitations
--! * If the two additional inputs CHAININ and C are enabled then accumulation is not possible (because P feedback is not possible).
--!   In this case the CLR input is ignored. Rounding is also not supported in this case.
--! * Preadder always uses A and/or D inputs but never the B input.
--!
--! Note that this implementation does not support
--! * SIMD, A:B, WideXOR, pattern detection
--! * CARRY, MULTISIGN
--! * A and B input cascade
--!
--! VHDL Instantiation Template:
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
--! I1 : xilinx_preadd_macc
--! generic map(
--!   USE_CHAIN_INPUT => boolean,
--!   USE_C_INPUT     => boolean,
--!   USE_D_INPUT     => boolean,
--!   NEGATE_A        => string,  -- mode "OFF", "ON" or "DYNAMIC"
--!   NEGATE_B        => string,  -- mode "OFF", "ON" or "DYNAMIC"
--!   NEGATE_D        => string   -- mode "OFF", "ON" or "DYNAMIC"
--! )
--! port map(
--!   neg_a        => in  std_logic, -- negate a
--!   neg_b        => in  std_logic, -- negate b
--!   neg_d        => in  std_logic, -- negate d
--!   a            => in  signed, -- first factor, main input
--!   b            => in  signed, -- second factor
--!   c            => in  signed, -- additional summand after multiplication
--!   d            => in  signed, -- first factor, second preadder input
--! );
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--!
entity xilinx_preadd_macc is
generic (
  --! @brief Enable chain input from neighbor DSP cell.
  --! Note that this disables the accumulator feature when the C input is enabled as well.
  USE_CHAIN_INPUT : boolean := false;
  --! @brief Enable additional C input.
  --! Note that this disables the accumulator feature when the chain input is enabled as well.
  USE_C_INPUT : boolean := false;
  --! Enable additional D preadder input.
  USE_D_INPUT : boolean := false;
  --! @brief NEGATION mode of input A.
  --! Options are OFF, ON or DYNAMIC. In OFF and ON mode input port NEG_A is ignored.
  --! Note that additional logic might be required dependent on mode and FPGA type.
  NEGATE_A : string := "OFF";
  --! @brief NEGATION mode of input B, preferably used for product negation.
  --! Options are OFF, ON or DYNAMIC. In OFF and ON mode input port NEG_B is ignored.
  --! Note that additional logic might be required dependent on mode and FPGA type.
  NEGATE_B : string := "OFF";
  --! @brief NEGATION mode of input D.
  --! Options are OFF, ON or DYNAMIC. In OFF and ON mode input port NEG_D is ignored.
  --! Note that additional logic might be required dependent on mode and FPGA type.
  NEGATE_D : string := "OFF";
  --! Number of DSP internal input registers for inputs A and D. At least one is strongly recommended.
  NUM_INPUT_REG_AD : natural range 0 to 3 := 1;
  --! Number of DSP internal input registers for input B. At least one is strongly recommended.
  NUM_INPUT_REG_B : natural range 0 to 3 := 1;
  --! @brief Number of DSP internal input registers for input C.
  --! At least one is strongly recommended. Set to 0 if unused.
  NUM_INPUT_REG_C : natural range 0 to 1 := 1;
  --! Defines if the CLR input port is synchronous to input signals "AD", "B" or "C".
  RELATION_CLR : string := "AD";
  --! @brief Number of result output registers within the DSP cell.
  --! One is strongly recommended and even required when the accumulation feature is needed
  NUM_OUTPUT_REG : natural range 0 to 1 := 1;
  --! Round enable = DSP internal round bit addition
  ROUND_ENABLE : boolean := false;
  --! Index of additional round bit for 'nearest' (half-up) rounding of P output.
  ROUND_BIT : natural := 0
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
  clr        : in  std_logic := '1';
  --! Valid signal synchronous to inputs A and D, high-active
  vld        : in  std_logic;
  --! @brief Negation of A synchronous to input A, '0'=+a, '1'=-a .
  --! Only relevant in DYNAMIC mode.
  neg_a      : in  std_logic := '0';
  --! @brief Negation of B synchronous to input B, '0'=+b, '1'=-b , preferably used for product negation.
  --! Only relevant in DYNAMIC mode.
  neg_b      : in  std_logic := '0';
  --! @brief Negation of D synchronous to input D, '0'=+d, '1'=-d
  --! Only relevant in DYNAMIC mode when D input is enabled.
  neg_d      : in  std_logic := '0';
  --! 1st factor input (also 1st preadder input)
  a          : in  signed;
  --! 2nd factor input
  b          : in  signed;
  --! @brief Additional summand after multiplication. Set "00" if unused (USE_C_INPUT=false).
  --! C is LSB bound to the LSB of the product a*b before shift right, i.e. similar to chain input.
  c          : in  signed;
  --! 1st factor input (2nd preadder input).  Set "00" if unused (USE_D_INPUT=false).
  d          : in  signed;
  --! @brief Resulting product/accumulator output.
  --! The standard result output might be unused when chain output is used instead.
  p          : out signed;
  --! Valid signal for result output, high-active
  p_vld      : out std_logic;
  --! @brief Input from other chained DSP cell (optional, only used when input enabled and connected).
  --! The chain width is device specific. A maximum width of 80 bits is supported.
  --! If the device specific chain width is smaller then only the LSBs are used.
  chainin    : in  signed(79 downto 0) := (others=>'0');
  --! @brief Result output to other chained DSP cell (optional)
  --! The chain width is device specific. A maximum width of 80 bits is supported.
  --! If the device specific chain width is smaller then only the LSBs are used.
  chainout   : out signed(79 downto 0) := (others=>'0');
  --! Number of pipeline stages in AD path, constant, depends on configuration and device specific implementation
  PIPESTAGES : out natural := 1
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (NEGATE_A="OFF") or (NEGATE_A="ON") or (NEGATE_A="DYNAMIC")
    report "ERROR in " & xilinx_preadd_macc'INSTANCE_NAME & ": " & 
           "Generic NEGATE_A string must be ON, OFF or DYNAMIC."
    severity failure;

  assert (NEGATE_B="OFF") or (NEGATE_B="ON") or (NEGATE_B="DYNAMIC")
    report "ERROR in " & xilinx_preadd_macc'INSTANCE_NAME & ": " & 
           "Generic NEGATE_B string must be ON, OFF or DYNAMIC."
    severity failure;

  assert (NEGATE_D="OFF") or (NEGATE_D="ON") or (NEGATE_D="DYNAMIC")
    report "ERROR in " & xilinx_preadd_macc'INSTANCE_NAME & ": " & 
           "Generic NEGATE_D string must be ON, OFF or DYNAMIC."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;
