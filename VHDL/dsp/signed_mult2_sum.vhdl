-------------------------------------------------------------------------------
--! @file       signed_mult2_sum.vhdl
--! @author     Fixitfetish
--! @date       24/Jan/2017
--! @version    0.60
--! @copyright  MIT License
--! @note       VHDL-1993
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;

--! @brief Two signed multiplications and sum of both
--! 
--! The behavior is as follows
--! * VLD=0  then  r = r
--! * VLD=1  then  r = +/-(x0*y0) +/-(x1*y1)
--! 
--! The resulting length of all products x(n)*y(n) must be the same.
--! 
--! The delay depends on the configuration and the underlying hardware. The
--! number pipeline stages is reported as constant at output port PIPE.

entity signed_mult2_sum is
generic (
  --! @brief Number of additional input registers. At least one is strongly recommended.
  --! If available the input registers within the DSP cell are used.
  NUM_INPUT_REG : natural := 1;
  --! @brief Additional data output register (recommended when logic for rounding and/or clipping is enabled)
  --! Typically the output register is implemented in logic. 
  OUTPUT_REG : boolean := false;
  --! Number of bits by which the accumulator result output is shifted right
  OUTPUT_SHIFT_RIGHT : natural := 0;
  --! Round data output (only relevant when OUTPUT_SHIFT_RIGHT>0)
  OUTPUT_ROUND : boolean := true;
  --! Enable clipping when right shifted result exceeds output range
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
  --! Valid signal for result output, high-active
  r_vld    : out std_logic;
  --! @brief Resulting product/accumulator output (optionally rounded and clipped).
  --! The standard result output might be unused when chain output is used instead.
  r_out    : out signed;
  --! Output overflow/clipping detection
  r_ovf    : out std_logic;
  --! @brief Result output to other chained DSP cell (optional)
  --! The chain width is device specific. A maximum width of 96 bits is supported.
  --! If the device specific chain width is smaller then only the LSBs are used.
  chainout : out signed(95 downto 0) := (others=>'0');
  --! Number of pipeline stages, constant, depends on configuration and device specific implementation
  PIPE     : out natural := 0
);
begin

  assert (x0'length+y0'length)=(x1'length+y1'length)
    report "ERROR signed_mult2_sum : All products must result in same size."
    severity failure;

  assert (not OUTPUT_ROUND) or (OUTPUT_SHIFT_RIGHT>0)
    report "WARNING signed_mult2_sum : Disabled rounding because OUTPUT_SHIFT_RIGHT is 0."
    severity warning;

end entity;

