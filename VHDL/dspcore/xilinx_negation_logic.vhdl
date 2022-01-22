-------------------------------------------------------------------------------
--! @file       xilinx_negation_logic.vhdl
--! @author     Fixitfetish
--! @date       15/Jan/2022
--! @version    0.10
--! @note       VHDL-2008
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
--!   USE_D_INPUT    => boolean,
--!   USE_NEGATION   => boolean,
--!   USE_A_NEGATION => boolean,
--!   USE_D_NEGATION => boolean
--! )
--! port map(
--!   neg          => in  std_logic, -- negate product
--!   neg_a        => in  std_logic, -- negate a
--!   neg_d        => in  std_logic, -- negate d
--!   a            => in  signed, -- first preadder input
--!   d            => in  signed, -- second preadder input
--!   neg_preadd   => out std_logic, -- negate preadder input A
--!   neg_product  => out std_logic, -- negate product (since DSP58)
--!   dsp_a        => out signed, -- DSP preadder input A
--!   dsp_d        => out signed  -- DSP preadder input D
--! );
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--!
entity xilinx_negation_logic is
generic (
  --! Enable additional D preadder input. Might require more resources and power.
  USE_D_INPUT : boolean := false;
  --! @brief Enable NEG input port and allow product negation. Might require more resources and power.
  --! Can be also used for input port B negation.
  USE_NEGATION : boolean := false;
  --! @brief Enable NEG_A input port and allow separate negation of preadder input port A.
  --! Might require more resources and power. Typically only relevant when USE_D_INPUT=true
  --! because otherwise preferably the product negation should be used.
  USE_A_NEGATION : boolean := false;
  --! @brief Enable NEG_D input port and allow separate negation of preadder input port D.
  --! Might require more resources and power. Only relevant when USE_D_INPUT=true.
  USE_D_NEGATION : boolean := false
);
port (
  --! Negation of product , '0'->+(a*b), '1'->-(a*b) . Only relevant when USE_NEGATION=true.
  neg         : in  std_logic := '0';
  --! @brief Negation of A synchronous to input A, '0'=+a, '1'=-a . Only relevant when USE_A_NEGATION=true.
  neg_a       : in  std_logic := '0';
  --! @brief Negation of D synchronous to input D, '0'=+d, '1'=-d . Only relevant when USE_D_NEGATION=true.
  neg_d       : in  std_logic := '0';
  --! first preadder input
  a           : in  signed;
  --! second preadder input
  d           : in  signed;
  --! DSP internal negation of preadder input DSP_A
  neg_preadd  : out std_logic;
  --! DSP internal negation of product (since DSP58)
  neg_product : out std_logic;
  --! DSP preadder input A
  dsp_a       : out signed;
  --! DSP preadder input D
  dsp_d       : out signed
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (USE_D_INPUT or not USE_D_NEGATION)
    report "ERROR " & xilinx_negation_logic'INSTANCE_NAME & ": " & 
           "Negation of input port D not possible because input port D is disabled."
    severity failure;

  assert (USE_A_NEGATION or not USE_D_NEGATION)
    report "ERROR " & xilinx_negation_logic'INSTANCE_NAME & ": " & 
           "Swap A and D input ports and enable USE_A_NEGATION instead of USE_D_NEGATION to save resources and power."
    severity failure;

  assert (dsp_a'length>=a'length)
    report "ERROR " & xilinx_negation_logic'INSTANCE_NAME & ": " & 
           "DSP_A output width shall not be smaller then A input width."
    severity failure;

  assert (dsp_d'length>=d'length or not USE_D_INPUT)
    report "ERROR " & xilinx_negation_logic'INSTANCE_NAME & ": " & 
           "DSP_D output width shall not be smaller then D input width."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;

-------------------------------------------------------------------------------

-- TODO
-- * IF B is DYNAMIC then also A and D must be dynamic
-- * instead of negating B do negate A and D

architecture dsp48e2 of xilinx_negation_logic is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "xilinx_negation_logic(dsp48e2)";

  signal neg_i, neg_a_i, neg_d_i :std_logic;

  signal dsp_a_i : signed(dsp_a'length-1 downto 0);
  signal dsp_d_i : signed(dsp_d'length-1 downto 0);

begin

  assert (USE_D_INPUT and a'length=d'length)
    report "WARNING " & IMPLEMENTATION & ": " & 
           "Input widths of A and D are different."
    severity warning;

  neg_i   <= neg   when USE_NEGATION   else '0'; -- product negation
  neg_a_i <= neg_a when USE_A_NEGATION else '0';
  neg_d_i <= neg_d when USE_D_NEGATION else '0';

  -- always pass through A
  dsp_a_i <= resize(a,dsp_a_i'length);

  -- Negate port D when necessary
  g_neg_d : if not USE_D_INPUT generate
    dsp_d_i <= (others=>'0');
  elsif (USE_NEGATION nor USE_D_NEGATION) generate
    -- just pass through D when negation is not required
    dsp_d_i <= resize(d,dsp_d_i'length);
  else generate
    constant D_WIDTH : positive := dsp_d'length;
    constant D_MAX : signed(D_WIDTH-1 downto 0) := to_signed(2**(D_WIDTH-1)-1,D_WIDTH);
    constant D_MIN : signed(D_WIDTH-1 downto 0) := not D_MAX;
--    constant D_MAX : signed(D_WIDTH-1 downto 0) := (D_WIDTH-1=>'0', others=>'1');
--    constant D_MIN : signed(D_WIDTH-1 downto 0) := (D_WIDTH-1=>'1', others=>'0');
    signal negate : std_logic;
    signal temp : signed(D_WIDTH-1 downto 0);
   begin
    negate <= neg_i xor neg_d_i;
    temp <= resize(d,temp'length);
    -- Includes clipping to most positive value when most negative value is negated.
    dsp_d_i <= D_MAX when (d'length=D_WIDTH and negate='1' and temp=D_MIN) else -temp when negate='1' else temp;
  end generate;

  neg_product <= '0'; -- not available in DSP48
  neg_preadd <= neg_i xor neg_a_i;

  dsp_a <= dsp_a_i;
  dsp_d <= dsp_d_i;

end architecture;

-------------------------------------------------------------------------------

architecture dsp58 of xilinx_negation_logic is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "xilinx_negation_logic(dsp58)";

  signal neg_i, neg_a_i, neg_d_i :std_logic;

begin

  assert (USE_D_INPUT and a'length=d'length)
    report "WARNING " & IMPLEMENTATION & ": " & 
           "Input widths of A and D are different."
    severity warning;

  neg_i   <= neg   when USE_NEGATION   else '0'; -- product negation
  neg_a_i <= neg_a when USE_A_NEGATION else '0';
  neg_d_i <= neg_d when USE_D_NEGATION else '0';

  neg_product <= (neg_d_i xor neg_i) when USE_D_INPUT else
                 (neg_a_i xor neg_i); -- just product negation required, when either A or B is negated

  neg_preadd  <= (neg_d_i xor neg_a_i) when USE_D_INPUT else
                 '0'; -- unused, preadder can be disabled

  -- DSP58 does not require manipulation of A and D data input ports.
  dsp_a <= resize(a,dsp_a'length);
  dsp_d <= resize(d,dsp_d'length) when USE_D_INPUT else to_signed(0,dsp_d'length);

end architecture;
