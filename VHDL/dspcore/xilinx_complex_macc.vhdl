-------------------------------------------------------------------------------
--! @file       xilinx_complex_macc.vhdl
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

--! @brief This entity abstracts and wraps Xilinx DSP cells for the special
--! complex multiplication and accumulate operation.
--!
--! Multiply complex inputs A and B and accumulate results.
--! Optionally, the chain input and C input can be added to the product result as well.
--!
--! @image html xilinx_complex_macc.svg "" width=600px
--!
--! **ACCU Mode**
--! * Only ChainIn or C can accumulated in addition to A*B.
--!
--! | CLR pending | CLR | VLD | Operation P                     | Comment                                      |
--! |-------------|-----|-----|---------------------------------|----------------------------------------------|
--! |    0 / 1    |  1  |  0  | P = P                           | Hold output register P, set CLR pending bit  |
--! |    0 / 1    |  0  |  0  | P = P                           | Hold output register P, keep CLR pending bit |
--! |    0 / 1    |  1  |  1  | P = RND + A*B + (ChainIn or C)  | Restart Accumulation, clear CLR pending bit  |
--! |      1      |  0  |  1  | P = RND + A*B + (ChainIn or C)  | Restart Accumulation, clear CLR pending bit  |
--! |      0      |  0  |  1  | P =  P  + A*B + (ChainIn or C)  | Proceed Accumulation, clear CLR pending bit  |
--!
--! **SUM Mode** (always CLR=1)
--! * Adding round bit RND not possible when ChainIn and C are used.
--!
--! | CLR | VLD | Operation P                         | Comment                  |
--! |-----|-----|-------------------------------------|--------------------------|
--! |  1  |  0  | P = P                               | Hold output register P   |
--! |  1  |  1  | P = A*B + (2 of RND, ChainIn or C)  |                          |
--!
--! All DSP internal registers before the final accumulator P register are considered to be input registers.
--! * The A and B path always have the same number of input register.
--! * The MREG after multiplication is considered as second input register in A and B path.
--! * The C path bypasses MREG and allows maximum one input register.
--! * The A and B path should have at least 2 input registers for performance since this ensures MREG activation.
--! * DSP external data pipeline registers and delay compensation are NOT realized in this entity.
--!
--! Limitations
--! * If the two additional inputs CHAININ and C are enabled then accumulation is not possible (because P feedback is not possible).
--!   In this case the CLR input is ignored. Rounding is also not supported in this case.
--! * Allowed input width of A and B might be less than for the standard multiplier.
--!
--! Note that this implementation does not support
--! * SIMD, A:B, WideXOR, pattern detection
--! * CARRY, MULTISIGN
--! * A and B input cascade
--!
entity xilinx_complex_macc is
generic (
  --! @brief Enable chain input from neighbor DSP cell.
  --! Note that this disables the accumulator feature when the C input is enabled as well.
  USE_CHAIN_INPUT : boolean := false;
  --! @brief Enable additional C input.
  --! Note that this disables the accumulator feature when the chain input is enabled as well.
  USE_C_INPUT : boolean := false;
  --! Number of DSP internal input registers for input A. At least one is strongly recommended.
  NUM_INPUT_REG_A : natural range 0 to 3 := 1;
  --! Number of DSP internal input registers for input B. At least one is strongly recommended.
  NUM_INPUT_REG_B : natural range 0 to 3 := 1;
  --! Number of DSP internal input registers for input C. At least one is strongly recommended. Set to 0 if unused.
  NUM_INPUT_REG_C : natural range 0 to 1 := 1;
  --! Defines if the input port CLR is synchronous to input signals "A", "B" or "C".
  RELATION_CLR : string := "A";
  --! Defines if the input port VLD is synchronous to input signals "A", "B" or "C".
  RELATION_VLD : string := "A";
  --! Defines if the input port NEG is synchronous to input signals "A" or "B".
  RELATION_NEG : string := "A";
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
  --! Valid signal, high-active
  vld        : in  std_logic;
  --! Negation of product , '0' -> +(a*b), '1' -> -(a*b). Optional and disabled by default.
  neg        : in  std_logic := '0';
  --! Conjugate A, synchronous to A input. Optional and disabled by default.
  a_conj     : in  std_logic := '0';
  --! Conjugate B, synchronous to B input. Optional and disabled by default.
  b_conj     : in  std_logic := '0';
  --! 1st factor, real component
  a_re       : in  signed;
  --! 1st factor, imaginary component
  a_im       : in  signed;
  --! 2nd factor, real component
  b_re       : in  signed;
  --! 2nd factor, imaginary component
  b_im       : in  signed;
  --! @brief Additional summand after multiplication, real component. Set "00" if unused (USE_C_INPUT=false).
  --! C is LSB bound to the LSB of the product a*b before shift right, i.e. similar to chain input.
  c_re       : in  signed;
  --! @brief Additional summand after multiplication, imaginary component. Set "00" if unused (USE_C_INPUT=false).
  --! C is LSB bound to the LSB of the product a*b before shift right, i.e. similar to chain input.
  c_im       : in  signed;
  --! @brief Resulting product/accumulator output, real component.
  --! The standard result output might be unused when chain output is used instead.
  p_re       : out signed;
  --! @brief Resulting product/accumulator output, imaginary component.
  --! The standard result output might be unused when chain output is used instead.
  p_im       : out signed;
  --! Valid signal for result output, high-active
  p_vld      : out std_logic;
  --! Result output real component overflow/underflow
  p_ovf_re   : out std_logic;
  --! Result output imaginary component overflow/underflow
  p_ovf_im   : out std_logic;
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
  --! Number of pipeline stages in AD path, constant, depends on configuration and device specific implementation
  PIPESTAGES : out natural := 1
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (RELATION_CLR="A") or (RELATION_CLR="B") or (RELATION_CLR="C")
    report "ERROR in " & xilinx_complex_macc'INSTANCE_NAME & ": " & 
           "Generic RELATION_CLR string must be A, B or C."
    severity failure;

  assert (RELATION_VLD="A") or (RELATION_VLD="B") or (RELATION_VLD="C")
    report "ERROR in " & xilinx_complex_macc'INSTANCE_NAME & ": " & 
           "Generic RELATION_VLD string must be A, B or C."
    severity failure;

  assert (RELATION_NEG="A") or (RELATION_NEG="B")
    report "ERROR in " & xilinx_complex_macc'INSTANCE_NAME & ": " & 
           "Generic RELATION_NEG string must be A or B."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;
