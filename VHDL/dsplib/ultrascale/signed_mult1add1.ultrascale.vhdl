-------------------------------------------------------------------------------
--! @file       signed_mult1add1.ultrascale.vhdl
--! @author     Fixitfetish
--! @date       12/Dec/2021
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
library dsplib;
  use dsplib.dsp_pkg_ultrascale.all;

--! @brief This is an implementation of the entity signed_mult1add1 for Xilinx UltraScale.
--! A product of two signed values is added or subtracted to/from a third signed value.
--! Optionally the chain input can be added as well.
--!
--! This implementation requires a single DSP48E2 Slice.
--! Refer to Xilinx UltraScale Architecture DSP48E2 Slice, UG579 (v1.5) October 18, 2017.
--!
--! * Input Data X,Y  : 2 signed values, x<=27 bits, y<=18 bits
--! * Input Data Z    : 1 signed value, z<=48 bits
--! * Input Register  : optional, at least one is strongly recommended
--! * Input Chain     : optional, 48 bits, requires injection after NUM_INPUT_REG cycles 
--! * Result Register : 48 bits, first output register (strongly recommended in most cases)
--! * Rounding        : optional half-up, within DSP cell when chain input is disabled
--! * Output Data     : 1x signed value, max 48 bits
--! * Output Register : optional, after shift-right and saturation
--! * Output Chain    : optional, 48 bits, after NUM_INPUT_REG_XY+1 cycles (assuming NUM_OUTPUT_REG>=1)
--! * Pipeline stages : NUM_INPUT_REG_XY + NUM_OUTPUT_REG (main data path through multiplier)
--!
--! If the input chain is enabled then DSP cell internal rounding is not possible
--! and rounding in logic is required. If the chain input is not required then DSP
--! internal rounding is enabled. In this case also consider using signed_mult1add1_accu.ultrascale .
--! 
--! If NUM_OUTPUT_REG=0 then the accumulator register P is disabled.
--! Though not recommended, this configuration might be useful when DSP cells are chained.
--!
--! This implementation can be chained multiple times.
--! @image html signed_mult1add1.ultrascale.svg "" width=1000px
--!
architecture ultrascale of signed_mult1add1 is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "signed_mult1add1(ultrascale)";

  -- number main path input registers within DSP
  constant NUM_IREG_DSP : natural := NUM_IREG(DSP,NUM_INPUT_REG_XY);

  -- number main path input registers in LOGIC
  constant NUM_IREG_LOGIC : natural := NUM_IREG(LOGIC,NUM_INPUT_REG_XY);

  -- derived constants
  constant ROUND_ENABLE : boolean := OUTPUT_ROUND and (OUTPUT_SHIFT_RIGHT/=0);
  constant PRODUCT_WIDTH : natural := x'length + y'length + 1;
  constant MAX_GUARD_BITS : natural := ACCU_WIDTH - PRODUCT_WIDTH;
  constant GUARD_BITS_EVAL : natural := accu_guard_bits(NUM_SUMMAND,MAX_GUARD_BITS,IMPLEMENTATION);
  constant ACCU_USED_WIDTH : natural := PRODUCT_WIDTH + GUARD_BITS_EVAL;
  constant ACCU_USED_SHIFTED_WIDTH : natural := ACCU_USED_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result'length;

  signal accu : signed(ACCU_WIDTH-1 downto 0);
  signal accu_vld : std_logic := '0';
  signal accu_used : signed(ACCU_USED_WIDTH-1 downto 0);

  signal dsp_rst : std_logic;
  signal dsp_clr : std_logic;
  signal dsp_vld : std_logic;
  signal dsp_neg : std_logic;
  signal dsp_a : signed(x'length-1 downto 0);
  signal dsp_b : signed(y'length-1 downto 0);
  signal dsp_c : signed(z'length-1 downto 0);
  signal dsp_d : signed(1 downto 0);

begin

  -- check chain in/out length
  assert (chainin'length>=ACCU_WIDTH or (not USE_CHAIN_INPUT))
    report "ERROR " & IMPLEMENTATION & ": " &
           "Chain input width must be at least " & integer'image(ACCU_WIDTH) & " bits."
    severity failure;

  -- check input/output length
  assert (x'length<=MAX_WIDTH_D)
    report "ERROR " & IMPLEMENTATION & ": Multiplier input X width cannot exceed " & integer'image(MAX_WIDTH_D)
    severity failure;
  assert (y'length<=MAX_WIDTH_B)
    report "ERROR " & IMPLEMENTATION & ": Multiplier input Y width cannot exceed " & integer'image(MAX_WIDTH_B)
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
    PIPEREGS_RST     => NUM_IREG_LOGIC,
    PIPEREGS_CLR     => NUM_IREG_LOGIC,
    PIPEREGS_VLD     => NUM_IREG_LOGIC,
    PIPEREGS_NEG     => NUM_IREG_LOGIC,
    PIPEREGS_A       => NUM_IREG_LOGIC,
    PIPEREGS_B       => NUM_IREG_LOGIC,
    PIPEREGS_C       => NUM_IREG_C(LOGIC,NUM_INPUT_REG_Z),
    PIPEREGS_D       => 0  -- unused
  )
  port map(
    clk      => clk,
    srst     => open, -- unused
    clkena   => clkena,
    src_rst  => rst,
    src_clr  => clr,
    src_vld  => vld,
    src_neg  => neg,
    src_a    => x,
    src_b    => y,
    src_c    => z,
    src_d    => "00",
    dsp_rst  => dsp_rst,
    dsp_clr  => dsp_clr,
    dsp_vld  => dsp_vld,
    dsp_neg  => dsp_neg,
    dsp_a    => dsp_a,
    dsp_b    => dsp_b,
    dsp_c    => dsp_c,
    dsp_d    => dsp_d
  );

-- TODO
  -- When input X has the maximum supported length and the most negative value than
  -- the negation of X in the preadder would cause an overflow. Only in this special
  -- case the second preadder input D is set to -1 to avoid the overflow. Hence, the
  -- negation of X is not -X but -X-1, which is the most positive value in this case.
  -- Otherwise D is always 0.
--  ireg(NUM_IREG_DSP).d <= (others=>'1')
--    when ( x'length=LIM_WIDTH_A
--           and logic_ireg(0).sub='1' 
--           and (logic_ireg(0).x = to_signed(-2**(LIM_WIDTH_A-1),LIM_WIDTH_A)) )
--    else (others=>'0');

  i_dsp : entity work.xilinx_preadd_macc_standard(ultrascale)
  generic map(
    USE_CHAIN_INPUT  => USE_CHAIN_INPUT,
    USE_C_INPUT      => USE_Z_INPUT,
    USE_D_INPUT      => false,
    USE_NEGATION     => USE_NEGATION,
    NUM_INPUT_REG_AD => NUM_IREG_DSP,
    NUM_INPUT_REG_B  => NUM_IREG_DSP,
    NUM_INPUT_REG_C  => NUM_IREG_C(DSP,NUM_INPUT_REG_Z),
    RELATION_CLR     => "AD",
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
    neg        => dsp_neg,
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
  i_out : entity dsplib.signed_output_logic
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
  PIPESTAGES <= NUM_INPUT_REG_XY + NUM_OUTPUT_REG;

end architecture;
