-------------------------------------------------------------------------------
--! @file       complex_mult1add1.dsp58.vhdl
--! @author     Fixitfetish
--! @date       29/Dec/2021
--! @version    0.00-draft
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

use work.xilinx_dsp_pkg_dsp58.all;

--! @brief This is an implementation of the entity complex_mult1add1 for Xilinx Versal.
--! One complex multiplication is performed and results can be accumulated.
--!
--! @image html complex_mult1add1.dsp58.svg "" width=600px
--!
--! **OPTIMIZATION="RESOURCES"**
--! * This implementation requires two back-to-back DSP58s.
--! * Chaining is supported.
--! * The number of overall pipeline stages is typically NUM_INPUT_REG_XY + NUM_OUTPUT_REG.
--! 
architecture dsp58 of complex_mult1add1 is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "complex_mult1add1(dsp58)";

  -- number main path input registers within DSP
  constant NUM_IREG_DSP : natural := NUM_IREG(DSP,NUM_INPUT_REG_XY);

  -- number main path input registers in LOGIC
  constant NUM_IREG_LOGIC : natural := NUM_IREG(LOGIC,NUM_INPUT_REG_XY);

  -- derived constants
  constant ROUND_ENABLE : boolean := OUTPUT_ROUND and (OUTPUT_SHIFT_RIGHT/=0);
  constant PRODUCT_WIDTH : natural := x_re'length + y_re'length + 1;
  constant MAX_GUARD_BITS : natural := ACCU_WIDTH - PRODUCT_WIDTH;
  constant GUARD_BITS_EVAL : natural := accu_guard_bits(NUM_SUMMAND,MAX_GUARD_BITS,IMPLEMENTATION);
  constant ACCU_USED_WIDTH : natural := PRODUCT_WIDTH + GUARD_BITS_EVAL;
  constant ACCU_USED_SHIFTED_WIDTH : natural := ACCU_USED_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result_re'length;

  signal dsp_rst : std_logic;
  signal dsp_clr : std_logic;
  signal dsp_vld : std_logic;
  signal dsp_a_conj : std_logic;
  signal dsp_b_conj : std_logic;
  signal dsp_a_re : signed(x_re'length-1 downto 0);
  signal dsp_b_re : signed(y_re'length-1 downto 0);
  signal dsp_c_re : signed(z_re'length-1 downto 0);
  signal dsp_d_re : signed(1 downto 0); -- dummy
  signal dsp_a_im : signed(x_im'length-1 downto 0);
  signal dsp_b_im : signed(y_im'length-1 downto 0);
  signal dsp_c_im : signed(z_im'length-1 downto 0);
  signal dsp_d_im : signed(1 downto 0); -- dummy

  signal accu_re, accu_im : signed(ACCU_WIDTH-1 downto 0);
  signal accu_vld : std_logic := '0';
  signal accu_used_re, accu_used_im : signed(ACCU_USED_WIDTH-1 downto 0);

begin

  -- check chain in/out length
  assert (chainin_re'length>=ACCU_WIDTH and chainin_im'length>=ACCU_WIDTH) or (not USE_CHAIN_INPUT)
    report "ERROR " & IMPLEMENTATION & ": " &
           "Chain input width must be at least " & integer'image(ACCU_WIDTH) & " bits."
    severity failure;

  -- check input/output length
  assert (x_re'length<=18 and x_im'length<=18 and y_re'length<=18 and y_im'length<=18)
    report "ERROR " & IMPLEMENTATION & ": " & 
           "Complex multiplier input width of X and Y is limited to 18."
    severity failure;
  assert (z_re'length<=MAX_WIDTH_C and z_im'length<=MAX_WIDTH_C)
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

  i_feed_re : entity work.xilinx_dsp_input_pipe
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
    src_neg  => '0', -- TODO x_conj,
    src_a    => x_re,
    src_b    => y_re,
    src_c    => z_re,
    src_d    => "00",
    dsp_rst  => dsp_rst,
    dsp_clr  => dsp_clr,
    dsp_vld  => dsp_vld,
    dsp_neg  => dsp_a_conj,
    dsp_a    => dsp_a_re,
    dsp_b    => dsp_b_re,
    dsp_c    => dsp_c_re,
    dsp_d    => dsp_d_re
  );

  i_feed_im : entity work.xilinx_dsp_input_pipe
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
    src_neg  => '0', -- TODO y_conj,
    src_a    => x_im,
    src_b    => y_im,
    src_c    => z_im,
    src_d    => "00",
    dsp_rst  => dsp_rst,
    dsp_clr  => dsp_clr,
    dsp_vld  => dsp_vld,
    dsp_neg  => dsp_b_conj,
    dsp_a    => dsp_a_im,
    dsp_b    => dsp_b_im,
    dsp_c    => dsp_c_im,
    dsp_d    => dsp_d_im
  );

  i_dsp : entity work.xilinx_complex_macc(dsp58)
  generic map(
    USE_CHAIN_INPUT  => USE_CHAIN_INPUT,
    USE_C_INPUT      => USE_Z_INPUT,
    NUM_INPUT_REG_A  => NUM_IREG_DSP,
    NUM_INPUT_REG_B  => NUM_IREG_DSP,
    NUM_INPUT_REG_C  => NUM_IREG_C(DSP,NUM_INPUT_REG_Z),
    RELATION_CLR     => "A",
    RELATION_VLD     => "A",
    NUM_OUTPUT_REG   => 1,
    ROUND_ENABLE     => ROUND_ENABLE and not (USE_CHAIN_INPUT and USE_Z_INPUT),
    ROUND_BIT        => maximum(0,OUTPUT_SHIFT_RIGHT-1)
  )
  port map(
    clk         => clk,
    rst         => rst,
    clkena      => clkena,
    clr         => dsp_clr,
    vld         => dsp_vld,
    a_conj      => dsp_a_conj,
    b_conj      => dsp_b_conj,
    a_re        => dsp_a_re,
    a_im        => dsp_a_im,
    b_re        => dsp_b_re,
    b_im        => dsp_b_im,
    c_re        => dsp_c_re,
    c_im        => dsp_c_im,
    p_re        => accu_re,
    p_im        => accu_im,
    p_vld       => accu_vld,
    p_ovf_re    => open, -- TODO
    p_ovf_im    => open, -- TODO
    chainin_re  => chainin_re,
    chainin_im  => chainin_im,
    chainout_re => chainout_re,
    chainout_im => chainout_im,
    PIPESTAGES  => open
);

  -- cut off unused sign extension bits
  -- (This reduces the logic consumption in the following steps when rounding,
  --  saturation and/or overflow detection is enabled.)
  accu_used_re <= signed(accu_re(ACCU_USED_WIDTH-1 downto 0));
  accu_used_im <= signed(accu_im(ACCU_USED_WIDTH-1 downto 0));

  -- Right-shift and clipping
  -- Enable rounding here when not possible within DSP cell.
  i_out_re : entity work.signed_output_logic
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
    dsp_out     => accu_used_re,
    dsp_out_vld => accu_vld,
    result      => result_re,
    result_vld  => result_vld,
    result_ovf  => result_ovf_re
  );

  i_out_im : entity work.signed_output_logic
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
    dsp_out     => accu_used_im,
    dsp_out_vld => accu_vld,
    result      => result_im,
    result_vld  => open, -- same as real
    result_ovf  => result_ovf_im
  );

  -- report constant number of pipeline register stages
  PIPESTAGES <= NUM_INPUT_REG_XY + NUM_OUTPUT_REG;

end architecture;