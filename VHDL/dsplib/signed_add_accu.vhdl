-------------------------------------------------------------------------------
--! @file       signed_add_accu.vhdl
--! @author     Fixitfetish
--! @date       19/Oct/2019
--! @version    0.10
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library baselib;
 use baselib.ieee_extension.all;
 use baselib.ieee_extension_types.all;

--! @brief N parallel synchronous signed additions & accumulators.
--!
--! 1.) LSB bound addition of A and Z
--! 2.) Accumulation of resulting sums
--!
--! If only accumulation without addition is required then only use input A and
--! set input Z to zero.
--!
--! The behavior is as follows
--!
--! | CLR | VLD | Operation                  | Comment
--! |:---:|:---:|:---------------------------|:----------------------
--! |  1  |  0  | r(n) = undefined           | reset accumulator
--! |  1  |  1  | r(n) = a(n) + z(n)         | restart accumulation
--! |  0  |  0  | r(n) = r(n)                | hold accumulator
--! |  0  |  1  | r(n) = r(n) + a(n) + z(n)  | proceed accumulation
--!
--! VHDL Instantiation Template:
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
--! I1 : signed_add_accu
--! generic map(
--!   NUM_ACCU           => positive, -- number of parallel additions & accumulators
--!   GUARD_BITS         => natural,  -- number of additional guard MSBs
--!   NUM_INPUT_REG_A    => positive, -- number of A input registers
--!   NUM_INPUT_REG_Z    => positive, -- number of Z input registers
--!   NUM_OUTPUT_REG     => natural,  -- number of output registers
--!   OUTPUT_SHIFT_RIGHT => natural,  -- number of right shifts
--!   OUTPUT_ROUND       => boolean,  -- enable rounding half-up
--!   OUTPUT_CLIP        => boolean,  -- enable clipping
--!   OUTPUT_OVERFLOW    => boolean,  -- enable overflow detection
--!   NUM_AUXILIARY_BITS => positive  -- number of user defined auxiliary bits
--! )
--! port map(
--!   clk         => in  std_logic, -- clock
--!   rst         => in  std_logic, -- reset
--!   clkena      => in  std_logic, -- clock enable
--!   clr         => in  std_logic, -- clear accu
--!   vld         => in  std_logic, -- valid
--!   aux         => in  std_logic_vector, -- input auxiliary
--!   a           => in  signed_vector, -- input data
--!   z           => in  signed_vector, -- input data
--!   result      => out signed_vector, -- current accumulator contents
--!   result_vld  => out std_logic, -- output valid
--!   result_ovf  => out std_logic_vector, -- output overflow
--!   result_aux  => out std_logic_vector, -- output auxiliary
--!   PIPESTAGES  => out natural -- constant number of pipeline stages
--! );
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--!
entity signed_add_accu is
generic (
  --! Number of parallel additions & accumulators - mandatory generic!
  NUM_ACCU : positive;
  --! @brief The number of additional guard bits (MSBs) that are required for the accumulation process.
  --! @link GUARD_BITS More...
  --!
  --! The resulting required accumulator bit width is determined by GUARD_BITS + max( A_WIDTH, Z_WIDTH ) .
  --! The setting is relevant to efficiently use FPGA resources, especially when DSP cells are used
  --! or saturation/clipping and/or overflow detection is enabled. CHOOSE AS SMALL AS POSSIBLE!
  --! If the value is too small overflows might occur. If the value is too large FPGA resources
  --! might be wasted.
  GUARD_BITS : natural := 0;
  --! @brief Number of additional input registers for main input A. At least one is mandatory.
  --! If available the input registers within the DSP cell are used.
  NUM_INPUT_REG_A : positive := 1;
  --! @brief Number of additional input registers for input Z. At least one is mandatory.
  --! If available the input registers within the DSP cell are used.
  NUM_INPUT_REG_Z : positive := 1;
  --! @brief Number of result output registers. 
  --! At least one register is required which is typically the result/accumulation
  --! register within the DSP cell. A second output register is recommended
  --! when logic for rounding, clipping and/or overflow detection is enabled.
  --! Typically all output registers after the first one are not part of a DSP cell
  --! and therefore implemented in logic.
  NUM_OUTPUT_REG : positive := 1;
  --! Number of bits by which the accumulator result output is shifted right.
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
  --! @brief Number of user-defined auxiliary bits. Can be useful for e.g. last and/or first flags.
  NUM_AUXILIARY_BITS : positive := 1
);
port (
  --! Standard system clock
  clk         : in  std_logic;
  --! Reset result output (optional)
  rst         : in  std_logic := '0';
  --! Clock enable (optional)
  clkena      : in  std_logic := '1';
  --! Clear accumulator (mark first valid input factors of accumulation sequence).
  clr         : in  std_logic;
  --! Valid signal for input, high-active
  vld         : in  std_logic;
  --! Optional input of user-defined auxiliary bits
  aux         : in  std_logic_vector(NUM_AUXILIARY_BITS-1 downto 0) := (others=>'0');
  --! adder input, first summand 
  a           : in  signed_vector(0 to NUM_ACCU-1);
  --! adder input, second summand
  z           : in  signed_vector(0 to NUM_ACCU-1);
  --! Current accumulator output (optionally rounded and clipped).
  result      : out signed_vector(0 to NUM_ACCU-1); --(23 downto 0);
  --! Result output valid signal, high-active whenever the accumulator output is updated
  result_vld  : out std_logic;
  --! Result output overflow/clipping detection
  result_ovf  : out std_logic_vector(0 to NUM_ACCU-1);
  --! Optional output of delayed auxiliary user-defined bits (same length as auxiliary input)
  result_aux  : out std_logic_vector(NUM_AUXILIARY_BITS-1 downto 0);
  --! Number of pipeline stages, constant, depends on configuration and device specific implementation
  PIPESTAGES  : out natural := 1
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (not OUTPUT_ROUND) or (OUTPUT_SHIFT_RIGHT/=0)
    report "WARNING in " & signed_add_accu'INSTANCE_NAME & 
           " Disabled rounding because OUTPUT_SHIFT_RIGHT is 0."
    severity warning;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;
