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
--! | ADD       | DYNAMIC   |    A    |    D    |    neg_d   |    A +/- D | ---
--! | SUBTRACT  | ADD       |    D    |    A    |   '1' (-)  |    D  -  A | ---
--! | DYNAMIC   | ADD       |    D    |    A    |    neg_a   |    D +/- A | ---
--! | SUBTRACT  | SUBTRACT  |   -D    |    A    |   '1' (-)  |   -D  -  A | additional logic required
--! | DYNAMIC   | SUBTRACT  |   -D    |    A    |    neg_a   |   -D +/- A | additional logic required
--! | SUBTRACT  | DYNAMIC   |   -A    |    D    |    neg_d   |   -A +/- D | additional logic required
--! | DYNAMIC   | DYNAMIC   | +/-A    |    D    |    neg_d   | +/-A +/- D | additional logic required
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
--!   NEGATE_B  => string,  -- b preadder mode
--!   NEGATE_D  => string   -- d preadder mode
--! )
--! port map(
--!   neg_a      => in  std_logic, -- add/subtract a
--!   neg_b      => in  std_logic, -- add/subtract b
--!   neg_d      => in  std_logic, -- add/subtract d
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
  --! @brief Negation mode of input A. Options are OFF, ON or DYNAMIC.
  --! In OFF and ON mode the input port neg_a is ignored.
  --! Note that additional logic might be required dependent on mode and FPGA type.
  NEGATE_A : string := "OFF";
  --! @brief Negation mode of input B. Options are OFF, ON or DYNAMIC.
  --! In OFF and ON mode the input port neg_b is ignored.
  --! Note that additional logic might be required dependent on mode and FPGA type.
  NEGATE_B : string := "OFF";
  --! @brief Negation mode of input D. Options are OFF, ON or DYNAMIC.
  --! In OFF and ON mode the input port neg_d is ignored.
  --! Note that additional logic might be required dependent on mode and FPGA type.
  NEGATE_D : string := "OFF"
);
port (
  --! @brief Add/subtract, '0' -> +a, '1' -> -a
  --! Only relevant in DYNAMIC mode. In DYNAMIC mode subtraction is disabled by default.
  neg_a      : in  std_logic := '0';
  --! @brief Add/subtract, '0' -> +b, '1' -> -b . Only relevant in DYNAMIC mode.
  neg_b      : in  std_logic := '0';
  --! @brief Add/subtract, '0' -> +d, '1' -> -d . Only relevant in DYNAMIC mode.
  neg_d      : in  std_logic := '0';
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

  assert (NEGATE_B="OFF") or (NEGATE_B="ON") or (NEGATE_B="DYNAMIC")
    report "ERROR in " & xilinx_preadd_logic'INSTANCE_NAME & ": " & 
           "Generic NEGATE_B string must be ON, OFF or DYNAMIC."
    severity failure;

  assert (NEGATE_D="OFF") or (NEGATE_D="ON") or (NEGATE_D="DYNAMIC")
    report "ERROR in " & xilinx_preadd_logic'INSTANCE_NAME & ": " & 
           "Generic NEGATE_D string must be ON, OFF or DYNAMIC."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;

-------------------------------------------------------------------------------

-- TODO
-- * IF B is DYNAMIC then also A and D must be dynamic
-- * instead of negating B do negate A and D

architecture rtl of xilinx_preadd_logic is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "xilinx_preadd_logic";

  function gNEG(s:string) return string is
  begin
    if NEGATE_B="DYNAMIC" or s="DYNAMIC" then
      return "DYNAMIC";
    elsif NEGATE_B="ON" and s="OFF" then
      return "ON";
    elsif NEGATE_B="ON" and s="ON" then
      return "OFF";
    else
      return s;
    end if;
  end function;

  constant cNEGATE_A : string := gNEG(NEGATE_A);
  constant cNEGATE_D : string := gNEG(NEGATE_D);

  constant SWAP_AD : boolean := cNEGATE_A="OFF" or cNEGATE_D="DYNAMIC";
  
  constant STATIC_NEGATE_A : boolean := cNEGATE_A="ON" and cNEGATE_D="DYNAMIC";

  constant STATIC_NEGATE_D : boolean := cNEGATE_D="ON" and
                                       (cNEGATE_A="ON" or cNEGATE_A="DYNAMIC");

  constant DYNAMIC_NEGATE_A : boolean := cNEGATE_A="DYNAMIC" and cNEGATE_D="DYNAMIC";

  constant MAX_INPUT_WIDTH : positive := maximum(a'length, d'length);
  constant MAX_OUTPUT_WIDTH : positive := maximum(dsp_a'length, dsp_d'length);

  signal neg_a_i, neg_b_i, neg_d_i :std_logic;
  signal neg_a_i2, neg_d_i2 :std_logic;

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

  neg_a_i <= neg_a when NEGATE_A="DYNAMIC" else '1' when NEGATE_A="ON" else '0';
  neg_b_i <= neg_b when NEGATE_B="DYNAMIC" else '1' when NEGATE_B="ON" else '0';
  neg_d_i <= neg_d when NEGATE_D="DYNAMIC" else '1' when NEGATE_D="ON" else '0';

  neg_a_i2 <= neg_a_i xor neg_b_i; -- only relevant in DYNAMIC mode
  neg_d_i2 <= neg_d_i xor neg_b_i; -- only relevant in DYNAMIC mode

  a_i <= -resize(a,a_i'length) when (STATIC_NEGATE_A or (DYNAMIC_NEGATE_A and neg_a_i2='1')) else resize(a,a_i'length);

  d_i <= -resize(d,d_i'length) when (STATIC_NEGATE_D) else resize(d,d_i'length);

  dsp_a_i <= resize(d_i,dsp_a_i'length) when SWAP_AD else a_i;

  dsp_d_i <= resize(a_i,dsp_d_i'length) when SWAP_AD else d_i;

  dsp_a_neg <= neg_d_i2 when (cNEGATE_D="DYNAMIC") else
               neg_a_i2 when (cNEGATE_A="DYNAMIC") else
               '0'   when (cNEGATE_A="OFF" and cNEGATE_D="OFF") else '1';

  dsp_a <= dsp_a_i;
  dsp_d <= dsp_d_i;

end architecture;
