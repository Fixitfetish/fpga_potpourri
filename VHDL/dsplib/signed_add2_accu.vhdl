-------------------------------------------------------------------------------
--! @file       signed_add2_accu.vhdl
--! @author     Fixitfetish
--! @date       09/Feb/2018
--! @version    0.10
--! @copyright  MIT License
--! @note       VHDL-1993
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library baselib;
 use baselib.ieee_extension.all;

--! @brief Signed DSP cell accumulator with two input summands and full precision
--! support.
--!
--! Input width equals of width of DSP cell output register.
--! The addition and accumulation of all inputs is LSB bound.
--! Alternatively, one of the two inputs can also be the chain input.

entity signed_add2_accu is
generic (
  --! @brief The number of summands is important to determine the number of additional
  --! guard bits (MSBs) that are required for the accumulation process. @link NUM_SUMMAND More...
  --!
  --! The setting is relevant to save logic especially when saturation/clipping
  --! and/or overflow detection is enabled.
  --! * 0 => maximum possible, not recommended (worst case, hardware dependent)
  --! * 1 => just one summand without accumulation
  --! * 2 => accumulate up to 2 summands
  --! * 3 => accumulate up to 3 summands
  --! * and so on ...
  --!
  --! Note that every single accumulated summand result counts!
  NUM_SUMMAND : natural := 0;
  --! Enable chain input from neighbor DSP cell, i.e. enable additional accumulator input
  USE_CHAIN_INPUT : boolean := false;
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
  OUTPUT_OVERFLOW : boolean := true
);
port (
  --! Standard system clock
  clk        : in  std_logic;
  --! Reset result output, high-active (optional)
  rst        : in  std_logic := '0';
  --! @brief Clear accumulator, high-active.
  --! Mark first valid input of accumulation sequence (synchronous to input A).
  --! If accumulation is not wanted then set constant '1'.
  clr        : in  std_logic;
  --! Valid signal for main input A, high-active
  vld        : in  std_logic;
  --! Signed input A
  a          : in  signed;
  --! @brief Signed input Z. Usage depends on DSP cell.
  --! Typically only considered when chain input is disabled
  z          : in  signed;
  --! @brief Resulting accumulator output (optionally rounded and clipped).
  --! The standard result output might be unused when chain output is used instead.
  result     : out signed;
  --! Valid signal for result output, high-active
  result_vld : out std_logic;
  --! Result output overflow/clipping detection
  result_ovf : out std_logic;
  --! @brief Input from other chained DSP cell (optional, only used when input enabled and connected).
  --! The chain width is device specific. A maximum width of 80 bits is supported.
  --! If the device specific chain width is smaller then only the LSBs are used.
  chainin  : in  signed(79 downto 0) := (others=>'0');
  --! @brief Result output to other chained DSP cell (optional)
  --! The chain width is device specific. A maximum width of 80 bits is supported.
  --! If the device specific chain width is smaller then only the LSBs are used.
  chainout   : out signed(79 downto 0) := (others=>'0');
  --! Number of pipeline stages, constant, depends on configuration and device specific implementation
  PIPESTAGES : out natural := 0
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (not OUTPUT_ROUND) or (OUTPUT_SHIFT_RIGHT/=0)
    report "WARNING in " & signed_add2_accu'INSTANCE_NAME & 
           " Disabled rounding because OUTPUT_SHIFT_RIGHT is 0."
    severity warning;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;
