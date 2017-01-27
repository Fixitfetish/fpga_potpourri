-------------------------------------------------------------------------------
--! @file       signed_mult2.vhdl
--! @author     Fixitfetish
--! @date       24/Jan/2017
--! @version    0.10
--! @copyright  MIT License
--! @note       VHDL-1993
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;

--! @brief Two independent signed multiplications.
--!
--! The behavior is as follows
--! * vld=0  ->  r(n) = r(n)       # hold previous
--! * vld=1  ->  r(n) = x(n)*y(n)  # multiply
--!
--! The length of the input factors is flexible.
--! The maximum width of the input factors is device and implementation specific.
--!
--! The delay depends on the configuration and the underlying hardware.
--! The number pipeline stages is reported as constant at output port PIPE.

--
--    <----------------------------------- ACCU WIDTH ------------------------>
--    |        <-------------------------- ACCU USED WIDTH ------------------->
--    |        |              <----------- PRODUCT WIDTH --------------------->
--    |        |              |                                               |
--    +--------+---+----------+-------------------------------+---------------+
--    | unused |  GUARD BITS  |                               |  SHIFT RIGHT  |
--    |SSSSSSSS|OOO|ODDDDDDDDD|DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD|Rxxxxxxxxxxxxxx|
--    +--------+---+----------+-------------------------------+---------------+
--             |   |                                          |
--             |   <------------- OUTPUT WIDTH --------------->
--             <--------- ACCU USED SHIFTED WIDTH ------------>
--
-- ACCU WIDTH = accumulator width (depends on hardware/implementation)
-- PRODUCT WIDTH = ax'length+ay'length = bx'length+by'length
-- NUM_SUMMANDS = number of accumulated products
-- GUARD BITS = ceil(log2(NUM_SUMMANDS))
-- ACCU USED WIDTH = PRODUCT WIDTH + GUARD BITS <= ACCU WIDTH
-- OUTPUT SHIFT RIGHT = number of LSBs to prune
-- OUTPUT WIDTH = r'length
-- ACCU USED SHIFTED WIDTH = ACCU USED WIDTH - OUTPUT SHIFT RIGHT
--
-- S = irrelevant sign extension MSBs
-- O = overflow detection sign bits, all O must be identical otherwise overflow
-- D = output data bits
-- R = rounding bit (+0.5 when round 'nearest' is enabled)
-- x = irrelevant LSBs
--
-- Optimal settings for overflow detection and/or saturation/clipping :
-- GUARD BITS = OUTPUT WIDTH + OUTPUT SHIFT RIGHT + 1 - PRODUCT WIDTH

entity signed_mult2 is
generic (
  --! @brief Number of additional input registers. At least one is strongly recommended.
  --! If available the input registers within the DSP cell are used.
  NUM_INPUT_REG : natural := 1;
  --! @brief Additional result output register (recommended when logic for rounding and/or clipping is enabled).
  --! Typically the output register is implemented in logic. 
  OUTPUT_REG : boolean := false;
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
  clk      : in  std_logic;
  --! Reset result output (optional)
  rst      : in  std_logic := '0';
  --! Valid signal for input factors, high-active
  vld      : in  std_logic;
  --! Add/subtract for all products n=0..1 , '0' -> +(x(n)*y(n)), '1' -> -(x(n)*y(n)). Subtraction is disabled by default.
  sub      : in  std_logic_vector(0 to 1) := (others=>'0');
  --! 1st product, 1st signed factor input
  x0       : in  signed;
  --! 1st product, 2nd signed factor input
  y0       : in  signed;
  --! 2nd product, 1st signed factor input
  x1       : in  signed;
  --! 2nd product, 2nd signed factor input
  y1       : in  signed;
  --! Valid signals for result output, high-active
  r_vld    : out std_logic_vector(0 to 1);
  --! Resulting 1st product output (optionally rounded and clipped).
  r0_out   : out signed;
  --! Resulting 2nd product output (optionally rounded and clipped).
  r1_out   : out signed;
  --! Output overflow/clipping detection
  r_ovf    : out std_logic_vector(0 to 1);
  --! Number of pipeline stages, constant, depends on configuration and device specific implementation
  PIPE     : out natural := 0
);
begin

  assert (not OUTPUT_ROUND) or (OUTPUT_SHIFT_RIGHT>0)
    report "WARNING signed_mult2 : Disabled rounding because OUTPUT_SHIFT_RIGHT is 0."
    severity warning;

end entity;

