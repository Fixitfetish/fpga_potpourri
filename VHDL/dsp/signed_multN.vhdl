-------------------------------------------------------------------------------
--! @file       signed_multN.vhdl
--! @author     Fixitfetish
--! @date       23/Feb/2017
--! @version    0.30
--! @copyright  MIT License
--! @note       VHDL-1993
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library fixitfetish;
 use fixitfetish.ieee_extension_types.all;

--! @brief N parallel and synchronous signed multiplications.
--!
--! @image html signed_multN.svg "" width=600px
--!
--! The behavior is as follows
--! * vld=0  ->  r(n) = r(n)            # hold previous
--! * vld=1  ->  r(n) = +/-(x(n)*y(n))  # multiply
--!
--! The length of the input factors is flexible.
--! The input factors are automatically resized with sign extensions bits to the
--! maximum possible factor length.
--! The maximum length of the input factors is device and implementation specific.
--! The resulting length of all products (x(n)'length + y(n)'length) must be the same.
--!
--! Note that the negation is not supported by all implementations of this entity.
--! 
--! The delay depends on the configuration and the underlying hardware.
--! The number pipeline stages is reported as constant at output port @link PIPESTAGES PIPESTAGES @endlink .
--!
--! VHDL Instantiation Template:
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
--! I1 : signed_multN
--! generic map(
--!   NUM_MULT           => positive, -- number of parallel multiplications
--!   NUM_INPUT_REG      => natural,  -- number of input registers
--!   NUM_OUTPUT_REG     => natural,  -- number of output registers
--!   OUTPUT_SHIFT_RIGHT => natural,  -- number of right shifts
--!   OUTPUT_ROUND       => boolean,  -- enable rounding half-up
--!   OUTPUT_CLIP        => boolean,  -- enable clipping
--!   OUTPUT_OVERFLOW    => boolean   -- enable overflow detection
--! )
--! port map(
--!   clk        => in  std_logic, -- clock
--!   rst        => in  std_logic, -- reset
--!   vld        => in  std_logic, -- valid
--!   neg        => in  std_logic_vector(0 to NUM_MULT-1), -- negation
--!   x          => in  signed_vector(0 to NUM_MULT-1), -- first factors
--!   y          => in  signed_vector(0 to NUM_MULT-1), -- second factors
--!   result     => out signed_vector(0 to NUM_MULT-1), -- product results
--!   result_vld => out std_logic_vector(0 to NUM_MULT-1), -- output valid
--!   result_ovf => out std_logic_vector(0 to NUM_MULT-1), -- output overflow
--!   PIPESTAGES => out natural -- constant number of pipeline stages
--! );
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

entity signed_multN is
generic (
  --! Number of parallel multiplications - mandatory generic!
  NUM_MULT : positive;
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
  --! Negation , '0' -> +(x*y), '1' -> -(x*y). Negation is disabled by default.
  neg        : in  std_logic_vector(0 to NUM_MULT-1) := (others=>'0');
  --! First signed factor for the NUM_MULT multiplications (all X inputs must have same size)
  x          : in  signed_vector(0 to NUM_MULT-1);
  --! Second signed factor for the NUM_MULT multiplications (all Y inputs must have same size)
  y          : in  signed_vector(0 to NUM_MULT-1);
  --! Resulting product output (optionally rounded and clipped).
  result     : out signed_vector(0 to NUM_MULT-1);
  --! Valid signals for result output, high-active
  result_vld : out std_logic_vector(0 to NUM_MULT-1);
  --! Result output overflow/clipping detection
  result_ovf : out std_logic_vector(0 to NUM_MULT-1);
  --! Number of pipeline stages, constant, depends on configuration and device specific implementation
  PIPESTAGES : out natural := 0
);
begin

  assert (not OUTPUT_ROUND) or (OUTPUT_SHIFT_RIGHT/=0)
    report "WARNING signed_multN : Disabled rounding because OUTPUT_SHIFT_RIGHT is 0."
    severity warning;

end entity;

