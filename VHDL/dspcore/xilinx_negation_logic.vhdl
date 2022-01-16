-------------------------------------------------------------------------------
--! @file       xilinx_negation_logic.vhdl
--! @author     Fixitfetish
--! @date       15/Jan/2022
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
--! **NEAGTE_B="OFF"** : The product negation follows the negation of D.
--!
--! | NEGATE A | NEGATE D | DSP_A | DSP_D | DSP_A_NEG       | DSP_B_NEG | Operation       | Comment
--! |:--------:|:--------:|:-----:|:-----:|:---------------:|:---------:|:---------------:|:-------
--! | OFF      | OFF      |   A   |   D   |     '0' (+)     |  '0' (+)  | (   A   +D) * B | ---
--! | ON       | OFF      |   A   |   D   |     '1' (-)     |  '0' (+)  | (  -A   +D) * B | ---
--! | OFF      | ON       |   A   |   D   |     '1' (-)     |  '1' (-)  | (   A   -D) * B | ---
--! | ON       | ON       |   A   |   D   |     '0' (+)     |  '1' (-)  | (  -A   -D) * B | ---
--! | OFF      | DYNAMIC  |   A   |   D   |      neg_d      |   neg_d   | (   A +/-D) * B | ---
--! | ON       | DYNAMIC  |   A   |   D   |    not neg_d    |   neg_d   | (  -A +/-D) * B | ---
--! | DYNAMIC  | OFF      |   A   |   D   |      neg_a      |  '0' (+)  | (+/-A   +D) * B | ---
--! | DYNAMIC  | ON       |   A   |   D   |    not neg_a    |  '1' (-)  | (+/-A   -D) * B | ---
--! | DYNAMIC  | DYNAMIC  |   A   |   D   | neg_a xor neg_d |   neg_d   | (+/-A +/-D) * B | ---
--!
--! **USE_D_INPUT=false** :
--! If input D is unused then all A and B negation options can be realized without preadder
--! because only the product negation DSP_B_NEG is required.
--! Hence, the preadder is disabled to save energy.
--! 
--! | NEGATE A | NEGATE B |    DSP_B_NEG    | Operation   | Comment
--! |:--------:|:--------:|----------------:|:-----------:|:-------
--! | OFF      | OFF      |      '0' (+)    |    A *    B | ---
--! | OFF      | ON       |      '1' (-)    |    A *   -B | ---
--! | ON       | OFF      |      '1' (-)    |   -A *    B | ---
--! | ON       | ON       |      '0' (+)    |   -A *   -B | ---
--! | OFF      | DYNAMIC  |      neg_b      |    A * +/-B | ---
--! | ON       | DYNAMIC  |    not neg_b    |   -A * +/-B | ---
--! | DYNAMIC  | OFF      |      neg_a      | +/-A *    B | ---
--! | DYNAMIC  | ON       |    not neg_a    | +/-A *   -B | ---
--! | DYNAMIC  | DYNAMIC  | neg_a xor neg_b | +/-A * +/-B | ---
--!
--! Refer to 
--! * Xilinx UltraScale Architecture DSP48E2 Slice, UG579 (v1.11) August 30, 2021
--! * Xilinx Versal ACAP DSP Engine, Architecture Manual, AM004 (v1.1.2) July 15, 2021
--!
--! VHDL Instantiation Template:
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
--! I1 : xilinx_negation_logic
--! generic map(
--!   USE_D_INPUT => boolean,
--!   NEGATE_A    => string,  -- mode "OFF", "ON" or "DYNAMIC"
--!   NEGATE_B    => string,  -- mode "OFF", "ON" or "DYNAMIC"
--!   NEGATE_D    => string   -- mode "OFF", "ON" or "DYNAMIC"
--! )
--! port map(
--!   neg_a        => in  std_logic, -- negate a
--!   neg_b        => in  std_logic, -- negate b
--!   neg_d        => in  std_logic, -- negate d
--!   a            => in  signed, -- first preadder input
--!   d            => in  signed, -- second preadder input
--!   dsp_a_neg    => out std_logic, -- negate A
--!   dsp_b_neg    => out std_logic, -- negate B = negate product (since DSP58)
--!   dsp_a        => out signed, -- DSP preadder input A
--!   dsp_d        => out signed  -- DSP preadder input D
--! );
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--!
entity xilinx_negation_logic is
generic (
  --! Enable additional D preadder input.
  USE_D_INPUT : boolean := false;
  --! @brief NEGATION mode of input A. Options are OFF, ON or DYNAMIC.
  --! In OFF and ON mode input port NEG_A is ignored.
  --! Note that additional logic might be required dependent on mode and FPGA type.
  NEGATE_A : string := "OFF";
  --! @brief NEGATION mode of input B. Options are OFF, ON or DYNAMIC.
  --! In OFF and ON mode input port NEG_B is ignored.
  --! Note that additional logic might be required dependent on mode and FPGA type.
  NEGATE_B : string := "OFF";
  --! @brief NEGATION mode of input D. Options are OFF, ON or DYNAMIC.
  --! In OFF and ON mode input port NEG_D is ignored.
  --! Note that additional logic might be required dependent on mode and FPGA type.
  NEGATE_D : string := "OFF"
);
port (
  --! @brief Add/subtract, '0' -> +a, '1' -> -a
  --! Only relevant in DYNAMIC mode. In DYNAMIC mode negation is disabled by default.
  neg_a      : in  std_logic := '0';
  --! @brief Add/subtract, '0' -> +b, '1' -> -b
  --! Only relevant in DYNAMIC mode. In DYNAMIC mode negation is disabled by default.
  neg_b      : in  std_logic := '0';
  --! @brief Add/subtract, '0' -> +d, '1' -> -d
  --! Only relevant in DYNAMIC mode. In DYNAMIC mode negation is disabled by default.
  neg_d      : in  std_logic := '0';
  --! first preadder input
  a          : in  signed;
  --! second preadder input
  d          : in  signed;
  --! DSP input A negation
  dsp_a_neg  : out std_logic;
  --! DSP input B negation = product negation
  dsp_b_neg  : out std_logic;
  --! DSP preadder input A
  dsp_a      : out signed;
  --! DSP preadder input D
  dsp_d      : out signed
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (NEGATE_A="OFF") or (NEGATE_A="ON") or (NEGATE_A="DYNAMIC")
    report "ERROR in " & xilinx_negation_logic'INSTANCE_NAME & ": " & 
           "Generic NEGATE_A string must be ON, OFF or DYNAMIC."
    severity failure;

  assert (NEGATE_B="OFF") or (NEGATE_B="ON") or (NEGATE_B="DYNAMIC")
    report "ERROR in " & xilinx_negation_logic'INSTANCE_NAME & ": " & 
           "Generic NEGATE_B string must be ON, OFF or DYNAMIC."
    severity failure;

  assert (NEGATE_D="OFF") or (NEGATE_D="ON") or (NEGATE_D="DYNAMIC")
    report "ERROR in " & xilinx_negation_logic'INSTANCE_NAME & ": " & 
           "Generic NEGATE_D string must be ON, OFF or DYNAMIC."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;

-------------------------------------------------------------------------------

architecture rtl of xilinx_negation_logic is

  signal neg_a_i, neg_b_i, neg_d_i :std_logic;

begin

  neg_a_i <= neg_a when NEGATE_A="DYNAMIC" else '1' when NEGATE_A="ON" else '0';
  neg_b_i <= neg_b when NEGATE_B="DYNAMIC" else '1' when NEGATE_B="ON" else '0';
  neg_d_i <= neg_d when NEGATE_D="DYNAMIC" else '1' when NEGATE_D="ON" else '0';

  GDOFF : if not USE_D_INPUT generate
    dsp_a_neg <= '0'; -- unused, preadder can be disabled
    dsp_b_neg <= neg_a_i xor neg_b_i;
  end generate;

  GDON : if USE_D_INPUT generate
    dsp_a_neg <= neg_a_i xor neg_b_i xor neg_d_i;
    dsp_b_neg <= neg_b_i xor neg_d_i;
  end generate;

  -- DSP58 does not require manipulation of A and D data input ports.
  dsp_a <= a;
  dsp_d <= d;

end architecture;

