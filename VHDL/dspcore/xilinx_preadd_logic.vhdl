-------------------------------------------------------------------------------
--! @file       xilinx_preadd_logic.vhdl
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
library baselib;
  use baselib.ieee_extension.all;

--! @brief This entity implements a generic input logic of the (+/-A +/-D) preadder for Xilinx Devices.
--!
--! Dependent on the preadder input mode the input data might need to be negated
--! using additional logic. Note that negation of the most negative value is
--! critical because an additional MSB is required.
--! In this implementation this is not an issue because the inputs a and d are
--! limited to 26 bits but the preadder input can be 27 bits wide.
--!
--! | PREADD A  | PREADD D  |  DSP_D  |  DSP_A  | DSP_A_NEG  | Operation  | Comment
--! |:---------:|:---------:|:-------:|:-------:|:----------:|:----------:|:-------
--! | ADD       | ADD       |    A    |    D    |   '0' (+)  |    A  +  D | ---
--! | ADD       | SUBTRACT  |    A    |    D    |   '1' (-)  |    A  -  D | ---
--! | ADD       | DYNAMIC   |    A    |    D    |    sub_d   |    A +/- D | ---
--! | SUBTRACT  | ADD       |    D    |    A    |   '1' (-)  |    D  -  A | ---
--! | DYNAMIC   | ADD       |    D    |    A    |    sub_a   |    D +/- A | ---
--! | SUBTRACT  | SUBTRACT  |   -D    |    A    |   '1' (-)  |   -D  -  A | additional logic required
--! | DYNAMIC   | SUBTRACT  |   -D    |    A    |    sub_a   |   -D +/- A | additional logic required
--! | SUBTRACT  | DYNAMIC   |   -A    |    D    |    sub_d   |   -A +/- D | additional logic required
--! | DYNAMIC   | DYNAMIC   | +/-A    |    D    |    sub_d   | +/-A +/- D | additional logic required
--!
--! Refer to 
--! * Xilinx UltraScale Architecture DSP48E2 Slice, UG579 (v1.11) August 30, 2021
--! * Xilinx Versal ACAP DSP Engine, Architecture Manual, AM004 (v1.1.2) July 15, 2021
--!
--! VHDL Instantiation Template:
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
--! I1 : xilinx_preadd_logic
--! generic map(
--!   NEGATE_A  => string,  -- a preadder mode
--!   NEGATE_D  => string   -- d preadder mode
--! )
--! port map(
--!   sub_a      => in  std_logic, -- add/subtract a
--!   sub_d      => in  std_logic, -- add/subtract d
--!   a          => in  signed, -- first preadder input
--!   d          => in  signed, -- second preadder input
--!   dsp_a_neg  => out std_logic, -- negate A
--!   dsp_a      => out signed, -- DSP preadder input A
--!   dsp_d      => out signed -- DSP preadder input D
--! );
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--!
entity xilinx_preadd_logic is
generic (
  --! @brief Preadder mode of input A. Options are ADD, SUBTRACT or DYNAMIC.
  --! In ADD and SUBTRACT mode sub_a is ignored. In dynamic mode sub_a='1' means subtract.
  --! Note that additional logic might be required dependent on mode and FPGA type.
  NEGATE_A : string := "OFF";
  --! @brief Preadder mode of input D. Options are ADD, SUBTRACT or DYNAMIC.
  --! In ADD and SUBTRACT mode sub_d is ignored. In dynamic mode sub_d='1' means subtract.
  --! Note that additional logic might be required dependent on mode and FPGA type.
  NEGATE_D : string := "OFF"
);
port (
  --! @brief Add/subtract, '0' -> +a, '1' -> -a
  --! Only relevant in DYNAMIC mode. In DYNAMIC mode subtraction is disabled by default.
  sub_a      : in  std_logic := '0';
  --! @brief Add/subtract, '0' -> +d, '1' -> -d
  --! Only relevant in DYNAMIC mode. In DYNAMIC mode subtraction is disabled by default.
  sub_d      : in  std_logic := '0';
  --! first preadder input
  a          : in  signed;
  --! second preadder input
  d          : in  signed;
  --! DSP input A negation
  dsp_a_neg  : out std_logic;
  --! DSP preadder input A
  dsp_a      : out signed;
  --! DSP preadder input D
  dsp_d      : out signed
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (NEGATE_A="OFF") or (NEGATE_A="ON") or (NEGATE_A="DYNAMIC")
    report "ERROR in " & xilinx_preadd_logic'INSTANCE_NAME & ": " & 
           "Generic NEGATE_A string must be ON, OFF or DYNAMIC."
    severity failure;

  assert (NEGATE_D="OFF") or (NEGATE_D="ON") or (NEGATE_D="DYNAMIC")
    report "ERROR in " & xilinx_preadd_logic'INSTANCE_NAME & ": " & 
           "Generic NEGATE_D string must be ON, OFF or DYNAMIC."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;

-------------------------------------------------------------------------------

architecture rtl of xilinx_preadd_logic is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "xilinx_preadd_logic";

  constant SWAP_AD : boolean := NEGATE_A="OFF" or NEGATE_D="DYNAMIC";
  
  constant STATIC_NEGATE_A : boolean := NEGATE_A="ON" and NEGATE_D="DYNAMIC";

  constant STATIC_NEGATE_D : boolean := NEGATE_D="ON" and
                                       (NEGATE_A="ON" or NEGATE_A="DYNAMIC");

  constant DYNAMIC_NEGATE_A : boolean := NEGATE_A="DYNAMIC" and NEGATE_D="DYNAMIC";

  constant MAX_INPUT_WIDTH : positive := maximum(a'length, d'length);
  constant MAX_OUTPUT_WIDTH : positive := maximum(dsp_a'length, dsp_d'length);

  signal a_i : signed(MAX_OUTPUT_WIDTH-1 downto 0);
  signal d_i : signed(MAX_OUTPUT_WIDTH-1 downto 0);

  signal dsp_a_i : signed(dsp_a'length-1 downto 0);
  signal dsp_d_i : signed(dsp_d'length-1 downto 0);

begin

  assert (a'length=d'length)
    report "WARNING " & IMPLEMENTATION & ": " & 
           "Input widths of A and D are different."
    severity warning;

  assert (dsp_a'length=dsp_d'length)
    report "WARNING " & IMPLEMENTATION & ": " & 
           "Output widths of DSP_A and DSP_D are different."
    severity warning;

  assert (MAX_OUTPUT_WIDTH>=MAX_INPUT_WIDTH)
    report "WARNING " & IMPLEMENTATION & ": " & 
           "Max output width is smaller than max input width."
    severity warning;

  a_i <= -resize(a,a_i'length) when (STATIC_NEGATE_A or (DYNAMIC_NEGATE_A and sub_a='1')) else resize(a,a_i'length);

  d_i <= -resize(d,d_i'length) when (STATIC_NEGATE_D) else resize(d,d_i'length);

  dsp_a_i <= resize(d_i,dsp_a_i'length) when SWAP_AD else a_i;

  dsp_d_i <= resize(a_i,dsp_d_i'length) when SWAP_AD else d_i;

  dsp_a_neg <= sub_d when (NEGATE_D="DYNAMIC") else
               sub_a when (NEGATE_A="DYNAMIC") else
               '0'   when (NEGATE_A="OFF" and NEGATE_D="OFF") else '1';

  dsp_a <= dsp_a_i;
  dsp_d <= dsp_d_i;

end architecture;
