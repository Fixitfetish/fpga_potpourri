-------------------------------------------------------------------------------
--! @file       signed_preadd_mult1add1.behave.vhdl
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

use work.xilinx_dsp_pkg_behave.all;

--! @brief This is an implementation of the entity signed_preadd_mult1add1
--! for Xilinx UltraScale.
--! Multiply a sum of two signed (+/-XA +/-XB) with a signed Y and accumulate results.
--!
--! This implementation requires a single DSP48E2 Slice.
--! Refer to Xilinx UltraScale Architecture DSP48E2 Slice, UG579 (v1.11) August 30, 2021
--!
--! * Input Data X    : 2 signed values, each max 26 bits
--! * Input Data Y    : 1 signed value, max 18 bits
--! * Input Register  : optional, at least one is strongly recommended
--! * Input Chain     : optional, 48 bits
--! * Accu Register   : 48 bits, first output register (strongly recommended in most cases)
--! * Rounding        : optional half-up, within DSP cell
--! * Output Data     : 1x signed value, max 48 bits
--! * Output Register : optional, after shift-right and saturation
--! * Output Chain    : optional, 48 bits
--! * Pipeline stages : NUM_INPUT_REG + NUM_OUTPUT_REG
--!
--! If NUM_OUTPUT_REG=0 then the accumulator register P is disabled.
--! This configuration is not recommended but might be useful when DSP cells are chained.
--!
--! Dependent on the preadder input mode the input data might need to be negated
--! using additional logic. Note that negation of the most negative value is
--! critical because an additional MSB is required.
--! In this implementation this is not an issue because the inputs xa and xb are
--! limited to 26 bits but the preadder input can be 27 bits wide.
--!
--! | PREADD XA | PREADD XB | Input D | Input A | Preadd +/- | Operation  | Comment
--! |:---------:|:---------:|:-------:|:-------:|:----------:|:----------:|:-------
--! | ADD       | ADD       |    XA   |   XB    |   '0' (+)  |    D  +  A | ---
--! | ADD       | SUBTRACT  |    XA   |   XB    |   '1' (-)  |    D  -  A | ---
--! | ADD       | DYNAMIC   |    XA   |   XB    |   sub_xb   |    D +/- A | ---
--! | SUBTRACT  | ADD       |    XB   |   XA    |   '1' (-)  |    D  -  A | ---
--! | SUBTRACT  | SUBTRACT  |   -XB   |   XA    |   '1' (-)  |   -D  -  A | additional logic required
--! | SUBTRACT  | DYNAMIC   |   -XA   |   XB    |   sub_xb   |   -D +/- A | additional logic required
--! | DYNAMIC   | ADD       |    XB   |   XA    |   sub_xa   |    D +/- A | ---
--! | DYNAMIC   | SUBTRACT  |   -XB   |   XA    |   sub_xa   |   -D +/- A | additional logic required
--! | DYNAMIC   | DYNAMIC   | +/-XA   |   XB    |   sub_xb   | +/-D +/- A | additional logic required
--!
--! This implementation can be chained multiple times.
--! If the chain input is used then the
--! * the accumulator feature is disabled, i.e. CLR input is ignored
--! * the DSP internal rounding is disabled, i.e. the rounding requires additional logic
--!
--! @image html signed_preadd_mult1add1.dsp48e2.svg "" width=1000px
--!
architecture behave of signed_preadd_mult1add1 is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "signed_preadd_mult1add1(behave)";

  -- derived constants
  constant ROUND_ENABLE : boolean := OUTPUT_ROUND and (OUTPUT_SHIFT_RIGHT/=0);
  constant PRODUCT_WIDTH : natural := MAXIMUM(xa'length,xb'length) + y'length + 1;
  constant MAX_GUARD_BITS : natural := ACCU_WIDTH - PRODUCT_WIDTH;
  constant GUARD_BITS_EVAL : natural := accu_guard_bits(NUM_SUMMAND,MAX_GUARD_BITS,IMPLEMENTATION);
  constant ACCU_USED_WIDTH : natural := PRODUCT_WIDTH + GUARD_BITS_EVAL;
  constant ACCU_USED_SHIFTED_WIDTH : natural := ACCU_USED_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result'length;

  signal dsp_rst : std_logic;
  signal dsp_clr : std_logic;
  signal dsp_vld : std_logic;
  signal dsp_neg_a : std_logic;
  signal dsp_neg_b : std_logic;
  signal dsp_neg_d : std_logic;
  signal dsp_a : signed(xa'length-1 downto 0);
  signal dsp_b : signed(y'length-1 downto 0);
  signal dsp_c : signed(z'length-1 downto 0);
  signal dsp_d : signed(xb'length-1 downto 0);

  signal accu : signed(ACCU_WIDTH-1 downto 0);
  signal accu_vld : std_logic := '0';
  signal accu_used : signed(ACCU_USED_WIDTH-1 downto 0);

begin

  -- check chain in/out length
  assert (chainin'length>=ACCU_WIDTH or (not USE_CHAIN_INPUT))
    report "ERROR " & IMPLEMENTATION & ": " &
           "Chain input width must be at least " & integer'image(ACCU_WIDTH) & " bits."
    severity failure;

  -- check input/output length
  assert (xa'length<MAX_WIDTH_D and xb'length<MAX_WIDTH_D)
    report "ERROR " & IMPLEMENTATION & ": " &
           "Preadder inputs XA and XB width cannot exceed " & integer'image(MAX_WIDTH_D-1)
    severity failure;
  assert (y'length<=MAX_WIDTH_B)
    report "ERROR " & IMPLEMENTATION & ": " &
           "Multiplier input Y width cannot exceed " & integer'image(MAX_WIDTH_B)
    severity failure;
  assert (z'length<=MAX_WIDTH_C)
    report "ERROR " & IMPLEMENTATION & ": Summand input Z width cannot exceed " & integer'image(MAX_WIDTH_C)
    severity failure;

  assert GUARD_BITS_EVAL<=MAX_GUARD_BITS
    report "ERROR " & IMPLEMENTATION & ": " &
           "Maximum number of accumulator bits is " & integer'image(ACCU_WIDTH) & " ." &
           "Input bit widths allow only maximum number of guard bits = " & integer'image(MAX_GUARD_BITS)
    severity failure;

  assert OUTPUT_WIDTH<ACCU_USED_SHIFTED_WIDTH or not(OUTPUT_CLIP or OUTPUT_OVERFLOW)
    report "ERROR " & IMPLEMENTATION & ": " &
           "More guard bits required for saturation/clipping and/or overflow detection."
    severity failure;

  i_feed : entity work.xilinx_dsp_input_pipe
  generic map(
    PIPEREGS_RST     => NUM_INPUT_REG_X,
    PIPEREGS_CLR     => NUM_INPUT_REG_X,
    PIPEREGS_VLD     => NUM_INPUT_REG_X,
    PIPEREGS_NEG_A   => NUM_INPUT_REG_X,
    PIPEREGS_NEG_B   => NUM_INPUT_REG_Y,
    PIPEREGS_NEG_D   => NUM_INPUT_REG_X,
    PIPEREGS_A       => NUM_INPUT_REG_X,
    PIPEREGS_B       => NUM_INPUT_REG_Y,
    PIPEREGS_C       => NUM_INPUT_REG_Z,
    PIPEREGS_D       => NUM_INPUT_REG_X
  )
  port map(
    clk       => clk,
    srst      => open, -- unused
    clkena    => clkena,
    src_rst   => rst,
    src_clr   => clr,
    src_vld   => vld,
    src_neg_a => neg_xa,
    src_neg_b => neg_y,
    src_neg_d => neg_xb,
    src_a     => xa,
    src_b     => y,
    src_c     => z,
    src_d     => xb,
    dsp_rst   => dsp_rst,
    dsp_clr   => dsp_clr,
    dsp_vld   => dsp_vld,
    dsp_neg_a => dsp_neg_a,
    dsp_neg_b => dsp_neg_b,
    dsp_neg_d => dsp_neg_d,
    dsp_a     => dsp_a,
    dsp_b     => dsp_b,
    dsp_c     => dsp_c,
    dsp_d     => dsp_d
  );

  i_dsp : entity work.xilinx_preadd_macc(behave)
  generic map(
    USE_CHAIN_INPUT  => USE_CHAIN_INPUT,
    USE_C_INPUT      => USE_Z_INPUT,
    USE_D_INPUT      => USE_XB_INPUT,
    NEGATE_A         => NEGATE_XA,
    NEGATE_B         => NEGATE_Y,
    NEGATE_D         => NEGATE_XB,
    NUM_INPUT_REG_AD => 0,
    NUM_INPUT_REG_B  => 0,
    NUM_INPUT_REG_C  => 0,
    RELATION_CLR     => "AD", -- TODO : make flexible ?
    NUM_OUTPUT_REG   => 1,
    ROUND_ENABLE     => ROUND_ENABLE and not (USE_CHAIN_INPUT and USE_Z_INPUT),
    ROUND_BIT        => maximum(0,OUTPUT_SHIFT_RIGHT-1)
  )
  port map(
    clk        => clk,
    rst        => rst,
    clkena     => clkena,
    clr        => dsp_clr,
    vld        => dsp_vld,
    neg_a      => dsp_neg_a,
    neg_b      => dsp_neg_b,
    neg_d      => dsp_neg_d,
    a          => dsp_a,
    b          => dsp_b,
    c          => dsp_c,
    d          => dsp_d,
    p          => accu,
    p_vld      => accu_vld,
    chainin    => chainin,
    chainout   => chainout,
    PIPESTAGES => open
);

  -- cut off unused sign extension bits
  -- (This reduces the logic consumption in the following steps when rounding,
  --  saturation and/or overflow detection is enabled.)
  accu_used <= accu(ACCU_USED_WIDTH-1 downto 0);

  -- Right-shift and clipping
  -- Enable rounding here when not possible within DSP cell.
  i_out : entity work.signed_output_logic
  generic map(
    PIPELINE_STAGES    => NUM_OUTPUT_REG-1,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => (ROUND_ENABLE and USE_CHAIN_INPUT and USE_Z_INPUT),
    OUTPUT_CLIP        => OUTPUT_CLIP,
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
  )
  port map (
    clk         => clk,
    rst         => rst,
    clkena      => clkena,
    dsp_out     => accu_used,
    dsp_out_vld => accu_vld,
    result      => result,
    result_vld  => result_vld,
    result_ovf  => result_ovf
  );

  -- report constant number of pipeline register stages
  PIPESTAGES <= NUM_INPUT_REG_X + NUM_OUTPUT_REG;

end architecture;
