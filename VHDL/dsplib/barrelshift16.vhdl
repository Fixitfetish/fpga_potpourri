-------------------------------------------------------------------------------
--! @file       barrelshift16.vhdl
--! @author     Fixitfetish
--! @date       02/May/2021
--! @version    0.10
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

--! @brief N-bit Barrel Shifter with left/right shift by 0..15 bits
--!
entity barrelshift16 is
generic (
  --! In cyclic mode the the input EXT is ignored.
  CYCLIC     : boolean := false;
  --! Set true for left shift. Default is right shift.
  LEFT_SHIFT : boolean := false;
  --! Input register. Highly recommended for DSP implementation.
  INPUT_REG  : boolean := false;
  --! Pipeline register. Recommended for some DSP implementations.
  PIPE_REG   : boolean := false;
  --! Output register. Highly recommended for DSP implementation.
  OUTPUT_REG : boolean := false;
  --! Implementation variant selection
  --! * "logic"  = just logic elements without DSP
  --! * "hybrid" = mainly DSP cells with some logic elements to avoid inefficient use of DSP cells
  --! * "dsp"    = only DSP cells even if some DSP cells are used inefficiently (minimum additional logic required)
  VARIANT    : string := "hybrid"
);
port(
  --! clock, optional, only required when input, pipeline and/or output registers are activated
  clk      : in  std_logic := '0'; 
  --! synchronous reset, optional
  rst      : in  std_logic := '0';
  --! clock enable, optional
  ce       : in  std_logic := '1';
  --! Number of shifts, 0..15
  shift    : in  unsigned(3 downto 0);
  --! Shifter input, length must be >=16
  din      : in  std_logic_vector;
  --! Shifter input valid, optional
  din_vld  : in  std_logic := '1';
  --! @brief Extension bit input is shifted into DIN when shift>=1 (required e.g. for barrel shifter chains or special functions).
  --! For a left shift EXT extends DIN on the right side. For a right shift EXT extends DIN on the left side.
  --! Set EXT=(others=>'0') to perform a logical shift. The EXT input is ignored in CYCLIC mode.
  ext      : in  std_logic_vector(15 downto 0) := (others=>'0');
  --! Shifter output has the same size as the shifter input. If shift=0 then DIN is returned.
  dout     : out std_logic_vector;
  --! Shifter output valid
  dout_vld : out std_logic
);
end entity;
