-------------------------------------------------------------------------------
--! @file       signed_preadd_mult1add1.vhdl
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

--! @brief Multiply a sum of two signed inputs (+/-XA +/-XB) with the signed input Y
--! and add result to the signed input Z.
--! Optionally the chain input can be added as well.
--! 
--! @image html signed_preadd_mult1add1.svg "" width=600px
--!
--! The behavior is as follows
--! * CLR=1  VLD=0  ->  r = undefined                # reset accumulator
--! * CLR=1  VLD=1  ->  r = (+/-xa +/-xb)*y + z      # restart accumulation
--! * CLR=0  VLD=0  ->  r = r                        # hold accumulator
--! * CLR=0  VLD=1  ->  r = r + (+/-xa +/-xb)*y + z  # proceed accumulation
--!
--! The length of the input factors is flexible.
--! The input factors are automatically resized with sign extensions bits to the
--! maximum possible factor length.
--! The maximum length of the input factors is device and implementation specific.
--!
--! The delay depends on the configuration and the underlying hardware.
--! The number pipeline stages is reported as constant at output port @link PIPESTAGES PIPESTAGES @endlink .
--!
--! VHDL Instantiation Template:
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
--! I1 : signed_preadd_mult1add1
--! generic map(
--!   NUM_SUMMAND        => natural,  -- overall number of summed products
--!   USE_CHAIN_INPUT    => boolean,  -- enable chain input
--!   USE_XB_INPUT       => boolean,  -- enable XB input
--!   USE_Z_INPUT        => boolean,  -- enable Z input
--!   NEGATE_XA          => string,   -- xa negation mode
--!   NEGATE_XB          => string,   -- xb negation mode
--!   NEGATE_Y           => string,   -- y negation mode
--!   NUM_INPUT_REG_X    => natural,  -- number of input registers for XA and XB
--!   NUM_INPUT_REG_Y    => natural,  -- number of input registers for Y
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
--!   neg_xa     => in  std_logic, -- negate xa
--!   neg_xb     => in  std_logic, -- negate xb
--!   neg_y      => in  std_logic, -- negate y
--!   xa         => in  signed, -- first preadder input, first factor
--!   xb         => in  signed, -- second preadder input, first factor
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
entity signed_preadd_mult1add1 is
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
  --! Enable additional preadder input XB.
  USE_XB_INPUT : boolean := false;
  --! Enable additional summand input Z. Note that this might disable the accumulator feature.
  USE_Z_INPUT : boolean := false;
  --! @brief NEGATION mode of input XA.
  --! Options are OFF, ON or DYNAMIC. In OFF and ON mode input port NEG_XA is ignored.
  --! Note that additional logic might be required dependent on mode and FPGA type.
  NEGATE_XA : string := "OFF";
  --! @brief NEGATION mode of input XB.
  --! Options are OFF, ON or DYNAMIC. In OFF and ON mode input port NEG_XB is ignored.
  --! Note that additional logic might be required dependent on mode and FPGA type.
  NEGATE_XB : string := "OFF";
  --! @brief NEGATION mode of input Y, preferably used for product negation.
  --! Options are OFF, ON or DYNAMIC. In OFF and ON mode input port NEG_Y is ignored.
  --! Note that additional logic might be required dependent on mode and FPGA type.
  NEGATE_Y : string := "OFF";
  --! @brief Number of additional input registers for inputs XA and XB. At least one is strongly recommended.
  --! If available the input registers within the DSP cell are used.
  NUM_INPUT_REG_X : natural := 1;
  --! @brief Number of additional input registers for input Y. At least one is strongly recommended.
  --! If available the input registers within the DSP cell are used.
  NUM_INPUT_REG_Y : natural := 1;
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
  --! @brief Negation of XA synchronous to input XA, '0'=+xa, '1'=-xa .
  --! Only relevant in DYNAMIC mode.
  neg_xa     : in  std_logic := '0';
  --! @brief Negation of XB synchronous to input XB, '0'=+xb, '1'=-xb .
  --! Only relevant in DYNAMIC mode when XB input is enabled.
  neg_xb     : in  std_logic := '0';
  --! @brief Negation of Y synchronous to input Y, '0'=+y, '1'=-y , preferably used for product negation.
  --! Only relevant in DYNAMIC mode.
  neg_y      : in  std_logic := '0';
  --! first preadder input (1st signed factor)
  xa         : in  signed;
  --! second preadder input (1st signed factor)
  xb         : in  signed;
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
  --! Here the pipeline stages of the main X path through the multiplier are reported.
  PIPESTAGES : out natural := 1
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (NEGATE_XA="OFF") or (NEGATE_XA="ON") or (NEGATE_XA="DYNAMIC")
    report "ERROR in " & signed_preadd_mult1add1'INSTANCE_NAME & ": " & 
           "Generic NEGATE_XA string must be ON, OFF or DYNAMIC."
    severity failure;

  assert (NEGATE_XB="OFF") or (NEGATE_XB="ON") or (NEGATE_XB="DYNAMIC")
    report "ERROR in " & signed_preadd_mult1add1'INSTANCE_NAME & ": " & 
           "Generic NEGATE_XB string must be ON, OFF or DYNAMIC."
    severity failure;

  assert (NEGATE_Y="OFF") or (NEGATE_Y="ON") or (NEGATE_Y="DYNAMIC")
    report "ERROR in " & signed_preadd_mult1add1'INSTANCE_NAME & ": " & 
           "Generic NEGATE_Y string must be ON, OFF or DYNAMIC."
    severity failure;

  assert (not OUTPUT_ROUND) or (OUTPUT_SHIFT_RIGHT/=0)
    report "WARNING in " & signed_preadd_mult1add1'INSTANCE_NAME &
           " Disabled rounding because OUTPUT_SHIFT_RIGHT is 0."
    severity warning;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;
