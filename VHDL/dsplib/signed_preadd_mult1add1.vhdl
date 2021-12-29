-------------------------------------------------------------------------------
--! @file       signed_preadd_mult1add1.vhdl
--! @author     Fixitfetish
--! @date       12/Dec/2021
--! @version    0.10
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;

--! @brief Multiply a sum of two signed inputs (+/-XA +/-XB) with the signed input Y
--! and add result to the signed input Z.
--! Optionally the chain input can be added as well.
--! 
--! @image html signed_preadd_mult1add1_sum.svg "" width=600px
--!
--! The behavior is as follows
--! * CLR=1  VLD=0  ->  r = undefined                # reset accumulator
--! * CLR=1  VLD=1  ->  r = (+/-xb +/-xb)*y + z      # restart accumulation
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
--!   PREADDER_INPUT_XA  => string,   -- xa preadder mode
--!   PREADDER_INPUT_XB  => string,   -- xb preadder mode
--!   NUM_INPUT_REG_XY   => natural,  -- number of input registers for XA, XB and Y
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
--!   clr        => in  std_logic, -- clear accu
--!   vld        => in  std_logic, -- valid
--!   sub_xa     => in  std_logic, -- add/subtract xa
--!   sub_xb     => in  std_logic, -- add/subtract xb
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
  --! @brief Preadder mode of input XA. Options are ADD, SUBTRACT or DYNAMIC.
  --! In ADD and SUBTRACT mode sub_xa is ignored. In dynamic mode sub_xa='1' means subtract.
  --! Note that additional logic might be required dependent on mode and FPGA type.
  PREADDER_INPUT_XA : string := "ADD";
  --! @brief Preadder mode of input XB. Options are ADD, SUBTRACT or DYNAMIC.
  --! In ADD and SUBTRACT mode sub_xb is ignored. In dynamic mode sub_xb='1' means subtract.
  --! Note that additional logic might be required dependent on mode and FPGA type.
  PREADDER_INPUT_XB : string := "ADD";
  --! @brief Number of additional input registers for inputs XA, XB and Y. At least one is strongly recommended.
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
  --! Reset result output (optional)
  rst        : in  std_logic := '0';
  --! @brief Clear accumulator (mark first valid input factors of accumulation sequence).
  --! This port might be ignored when USE_CHAIN_INPUT=true.
  --! If accumulation is not wanted then set constant '1' (default).
  clr        : in  std_logic := '1';
  --! Valid signal for input factors, high-active
  vld        : in  std_logic;
  --! @brief Add/subtract product, '0' -> +(xa)*y, '1' -> -(xa)*y . 
  --! Only relevant in DYNAMIC mode. In DYNAMIC mode subtraction is disabled by default.
  sub_xa     : in  std_logic := '0';
  --! @brief Add/subtract product, '0' -> +(xb)*y, '1' -> -(xb)*y . 
  --! Only relevant in DYNAMIC mode. In DYNAMIC mode subtraction is disabled by default.
  sub_xb     : in  std_logic := '0';
  --! first preadder input (1st signed factor)
  xa         : in  signed;
  --! second preadder input (1st signed factor)
  xb         : in  signed;
  --! 2nd signed factor input
  y          : in  signed;
  --! @brief Additional summand after multiplication. Set "00" if unused.
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
  --! Number of pipeline stages, constant, depends on configuration and device specific implementation
  PIPESTAGES : out natural := 1
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (not OUTPUT_ROUND) or (OUTPUT_SHIFT_RIGHT/=0)
    report "WARNING in " & signed_preadd_mult1add1'INSTANCE_NAME &
           " Disabled rounding because OUTPUT_SHIFT_RIGHT is 0."
    severity warning;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;

