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
--! | ADD       | DYNAMIC   |    A    |    D    |    d_sub   |    A +/- D | ---
--! | SUBTRACT  | ADD       |    D    |    A    |   '1' (-)  |    D  -  A | ---
--! | DYNAMIC   | ADD       |    D    |    A    |    a_sub   |    D +/- A | ---
--! | SUBTRACT  | SUBTRACT  |   -D    |    A    |   '1' (-)  |   -D  -  A | additional logic required
--! | DYNAMIC   | SUBTRACT  |   -D    |    A    |    a_sub   |   -D +/- A | additional logic required
--! | SUBTRACT  | DYNAMIC   |   -A    |    D    |    d_sub   |   -A +/- D | additional logic required
--! | DYNAMIC   | DYNAMIC   | +/-A    |    D    |    d_sub   | +/-A +/- D | additional logic required
--!
--! Refer to 
--! * Xilinx UltraScale Architecture DSP48E2 Slice, UG579 (v1.11) August 30, 2021
--! * Xilinx Versal ACAP DSP Engine, Architecture Manual, AM004 (v1.1.2) July 15, 2021
--!
--! VHDL Instantiation Template:
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
--! I1 : xilinx_preadd_logic
--! generic map(
--!   PREADDER_INPUT_A  => string,  -- a preadder mode
--!   PREADDER_INPUT_D  => string   -- d preadder mode
--! )
--! port map(
--!   a_sub      => in  std_logic, -- add/subtract a
--!   d_sub      => in  std_logic, -- add/subtract d
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
  PREADDER_INPUT_A : string := "ADD";
  --! @brief Preadder mode of input D. Options are ADD, SUBTRACT or DYNAMIC.
  --! In ADD and SUBTRACT mode sub_d is ignored. In dynamic mode sub_d='1' means subtract.
  --! Note that additional logic might be required dependent on mode and FPGA type.
  PREADDER_INPUT_D : string := "ADD"
);
port (
  --! @brief Add/subtract, '0' -> +a, '1' -> -a
  --! Only relevant in DYNAMIC mode. In DYNAMIC mode subtraction is disabled by default.
  a_sub      : in  std_logic := '0';
  --! @brief Add/subtract, '0' -> +d, '1' -> -d
  --! Only relevant in DYNAMIC mode. In DYNAMIC mode subtraction is disabled by default.
  d_sub      : in  std_logic := '0';
  --! first preadder input
  a          : in  signed;
  --! second preadder input
  d          : in  signed;
  --! DSP_A negation
  dsp_a_neg  : out std_logic;
  --! DSP preadder input A
  dsp_a      : out signed;
  --! DSP preadder input D
  dsp_d      : out signed
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (PREADDER_INPUT_A="ADD") or (PREADDER_INPUT_A="SUBTRACT") or (PREADDER_INPUT_A="DYNAMIC")
    report "ERROR in " & xilinx_preadd_logic'INSTANCE_NAME & ": " & 
           "Generic PREADDER_INPUT_A string must be ADD, SUBTRACT or DYNAMIC."
    severity failure;

  assert (PREADDER_INPUT_D="ADD") or (PREADDER_INPUT_D="SUBTRACT") or (PREADDER_INPUT_D="DYNAMIC")
    report "ERROR in " & xilinx_preadd_logic'INSTANCE_NAME & ": " & 
           "Generic PREADDER_INPUT_D string must be ADD, SUBTRACT or DYNAMIC."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;

-------------------------------------------------------------------------------

architecture rtl of xilinx_preadd_logic is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "xilinx_preadd_logic";

  constant SWAP_AD : boolean := PREADDER_INPUT_A="ADD" or PREADDER_INPUT_D="DYNAMIC";
  
  constant STATIC_NEGATE_A : boolean := PREADDER_INPUT_A="SUBTRACT" and PREADDER_INPUT_D="DYNAMIC";

  constant STATIC_NEGATE_D : boolean := PREADDER_INPUT_D="SUBTRACT" and
                                       (PREADDER_INPUT_A="SUBTRACT" or PREADDER_INPUT_A="DYNAMIC");

  constant DYNAMIC_NEGATE_A : boolean := PREADDER_INPUT_A="DYNAMIC" and PREADDER_INPUT_D="DYNAMIC";

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

  a_i <= -resize(a,a_i'length) when (STATIC_NEGATE_A or (DYNAMIC_NEGATE_A and a_sub='1')) else resize(a,a_i'length);

  d_i <= -resize(d,d_i'length) when (STATIC_NEGATE_D) else resize(d,d_i'length);

  dsp_a_i <= resize(d_i,dsp_a_i'length) when SWAP_AD else a_i;

  dsp_d_i <= resize(a_i,dsp_d_i'length) when SWAP_AD else d_i;

  dsp_a_neg <= d_sub when (PREADDER_INPUT_D="DYNAMIC") else
               a_sub when (PREADDER_INPUT_A="DYNAMIC") else
               '0'   when (PREADDER_INPUT_A="ADD" and PREADDER_INPUT_D="ADD") else '1';

  dsp_a <= dsp_a_i;
  dsp_d <= dsp_d_i;

end architecture;
