-------------------------------------------------------------------------------
--! @file       complex_mult1add1.behave.vhdl
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

use work.xilinx_dsp_pkg_behave.all;

--! @brief This is an implementation of the entity complex_mult1add1 for Xilinx UltraScale.
--! One complex multiplication is performed and results can be accumulated.
--!
--! @image html complex_mult1add1.behave.svg "" width=600px
--!
--! **OPTIMIZATION="PERFORMANCE"**
--! * This implementation requires four instances of the entity signed_mult1add1 .
--! * Chaining is supported.
--! * The number of overall pipeline stages is typically NUM_INPUT_REG_XY + 1 + NUM_OUTPUT_REG.
--!
--! **OPTIMIZATION="RESOURCES"**
--! * This implementation requires three instances of the entity signed_preadd_mult1add1 .
--! * Chaining is supported.
--! * The number of overall pipeline stages is typically NUM_INPUT_REG_XY + 2 + NUM_OUTPUT_REG.
--!
architecture behave of complex_mult1add1 is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "complex_mult1add1(behave)";

  -- derived constants
  constant ROUND_ENABLE : boolean := OUTPUT_ROUND and (OUTPUT_SHIFT_RIGHT/=0);
  constant PRODUCT_WIDTH : natural := MAXIMUM(x_re'length,x_im'length) + MAXIMUM(y_re'length,y_im'length) + 1;
  constant MAX_GUARD_BITS : natural := ACCU_WIDTH - PRODUCT_WIDTH;
  constant GUARD_BITS_EVAL : natural := accu_guard_bits(NUM_SUMMAND,MAX_GUARD_BITS,IMPLEMENTATION);
  constant ACCU_USED_WIDTH : natural := PRODUCT_WIDTH + GUARD_BITS_EVAL;
  constant ACCU_USED_SHIFTED_WIDTH : natural := ACCU_USED_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result_re'length;

  signal dsp_rst : std_logic;
  signal dsp_clr : std_logic;
  signal dsp_vld : std_logic;
  signal dsp_neg : std_logic;
  signal dsp_conj_x : std_logic;
  signal dsp_conj_y : std_logic;
  signal dsp_xre : signed(x_re'length-1 downto 0);
  signal dsp_yre : signed(y_re'length-1 downto 0);
  signal dsp_zre : signed(z_re'length-1 downto 0);
  signal dsp_xim : signed(x_im'length-1 downto 0);
  signal dsp_yim : signed(y_im'length-1 downto 0);
  signal dsp_zim : signed(z_im'length-1 downto 0);

  -- dummy
  signal dsp_dre, dsp_dim : signed(1 downto 0);

  signal are, aim : signed(MAX_WIDTH_A-1 downto 0);
  signal bre, bim : signed(MAX_WIDTH_B-1 downto 0);
  signal cre, cim : signed(MAX_WIDTH_C-1 downto 0);

  signal neg_i, conj_x_i, conj_y_i : std_logic := '0';
  signal neg_xre,neg_xim,neg_yre,neg_yim : std_logic;

  signal clr_q : std_logic;
  signal p_re, p_im : signed(ACCU_WIDTH-1 downto 0);
  signal chainin_re_i, chainin_im_i : signed(ACCU_WIDTH-1 downto 0);

  signal accu_re, accu_im : signed(ACCU_WIDTH-1 downto 0);
  signal accu_vld : std_logic := '0';
  signal accu_used_re, accu_used_im : signed(ACCU_USED_WIDTH-1 downto 0);


begin

  assert OUTPUT_WIDTH<ACCU_USED_SHIFTED_WIDTH or not(OUTPUT_CLIP or OUTPUT_OVERFLOW)
    report "ERROR " & IMPLEMENTATION & ": " &
           "More guard bits required for saturation/clipping and/or overflow detection."
    severity failure;

  i_feed_re : entity work.xilinx_dsp_input_pipe
  generic map(
    PIPEREGS_RST     => NUM_INPUT_REG_XY,
    PIPEREGS_CLR     => NUM_INPUT_REG_XY,
    PIPEREGS_VLD     => NUM_INPUT_REG_XY,
    PIPEREGS_NEG_A   => NUM_INPUT_REG_XY,
    PIPEREGS_NEG_B   => NUM_INPUT_REG_XY,
    PIPEREGS_NEG_D   => NUM_INPUT_REG_XY,
    PIPEREGS_A       => NUM_INPUT_REG_XY,
    PIPEREGS_B       => NUM_INPUT_REG_XY,
    PIPEREGS_C       => NUM_INPUT_REG_Z,
    PIPEREGS_D       => NUM_INPUT_REG_XY
  )
  port map(
    clk       => clk,
    srst      => open, -- unused
    clkena    => clkena,
    src_rst   => rst,
    src_clr   => clr,
    src_vld   => vld,
    src_neg_a => neg,
    src_neg_b => conj_x,
    src_neg_d => conj_y,
    src_a     => x_re,
    src_b     => y_re,
    src_c     => z_re,
    src_d     => "00",
    dsp_rst   => dsp_rst,
    dsp_clr   => dsp_clr,
    dsp_vld   => dsp_vld,
    dsp_neg_a => dsp_neg,
    dsp_neg_b => dsp_conj_x,
    dsp_neg_d => dsp_conj_y,
    dsp_a     => dsp_xre,
    dsp_b     => dsp_yre,
    dsp_c     => dsp_zre,
    dsp_d     => dsp_dre
  );

  i_feed_im : entity work.xilinx_dsp_input_pipe
  generic map(
    PIPEREGS_RST     => NUM_INPUT_REG_XY,
    PIPEREGS_CLR     => NUM_INPUT_REG_XY,
    PIPEREGS_VLD     => NUM_INPUT_REG_XY,
    PIPEREGS_NEG_A   => NUM_INPUT_REG_XY,
    PIPEREGS_NEG_B   => NUM_INPUT_REG_XY,
    PIPEREGS_NEG_D   => NUM_INPUT_REG_XY,
    PIPEREGS_A       => NUM_INPUT_REG_XY,
    PIPEREGS_B       => NUM_INPUT_REG_XY,
    PIPEREGS_C       => NUM_INPUT_REG_Z,
    PIPEREGS_D       => NUM_INPUT_REG_XY
  )
  port map(
    clk       => clk,
    srst      => open, -- unused
    clkena    => clkena,
    src_rst   => rst,
    src_clr   => clr,
    src_vld   => vld,
    src_neg_a => open,
    src_neg_b => open,
    src_neg_d => open,
    src_a     => x_im,
    src_b     => y_im,
    src_c     => z_im,
    src_d     => "00",
    dsp_rst   => open,
    dsp_clr   => open,
    dsp_vld   => open,
    dsp_neg_a => open,
    dsp_neg_b => open,
    dsp_neg_d => open,
    dsp_a     => dsp_xim,
    dsp_b     => dsp_yim,
    dsp_c     => dsp_zim,
    dsp_d     => dsp_dim
  );

  neg_i    <= dsp_neg    when NEGATION="DYNAMIC"    else '1' when NEGATION="ON"    else '0';
  conj_x_i <= dsp_conj_x when CONJUGATE_X="DYNAMIC" else '1' when CONJUGATE_X="ON" else '0';
  conj_y_i <= dsp_conj_y when CONJUGATE_Y="DYNAMIC" else '1' when CONJUGATE_Y="ON" else '0';

  neg_xre <= neg_i;
  neg_xim <= neg_i xor conj_x_i;
  neg_yre <= '0';
  neg_yim <= conj_y_i;

  are <= resize(dsp_xre, are'length) when neg_xre/='1' else -resize(dsp_xre, are'length);
  aim <= resize(dsp_xim, aim'length) when neg_xim/='1' else -resize(dsp_xim, aim'length);
  bre <= resize(dsp_yre, bre'length) when neg_yre/='1' else -resize(dsp_yre, bre'length);
  bim <= resize(dsp_yim, bim'length) when neg_yim/='1' else -resize(dsp_yim, bim'length);
  cre <= resize(dsp_zre, cre'length) when USE_Z_INPUT else (others=>'0');
  cim <= resize(dsp_zim, cim'length) when USE_Z_INPUT else (others=>'0');

  -- use only LSBs of chain input
  chainin_re_i <= resize(chainin_re,ACCU_WIDTH) when USE_CHAIN_INPUT else (others=>'0');
  chainin_im_i <= resize(chainin_im,ACCU_WIDTH) when USE_CHAIN_INPUT else (others=>'0');

  -- Operation
  p_re <= (are*bre - aim*bim) + cre + chainin_re_i;
  p_im <= (are*bim + aim*bre) + cim + chainin_im_i;

  -- CLR pending bit
  pclr : process(clk) begin
    if rising_edge(clk) then
      if rst/='0' then
        clr_q <= '0';
      elsif clkena='1' then
        if dsp_clr='1' and dsp_vld='0' then
          clr_q <= '1';
        elsif dsp_vld='1' then
          clr_q <= '0';
        end if;
      end if;
    end if;
  end process;

  -- pipelined output valid signal
  g_dspreg_on : if NUM_OUTPUT_REG=1 generate
  begin
    process(clk)
    begin
      if rising_edge(clk) then
        if rst/='0' then
          accu_vld <= '0';
          accu_re <= (others=>'0');
          accu_im <= (others=>'0');
        else
          if clkena='1' then
            accu_vld <= dsp_vld;
            -- Update and accumulate only valid values
            if dsp_vld='1' then
              if dsp_clr='1' or clr_q='1' then
                accu_re <= p_re + signed(RND(ROUND_ENABLE,OUTPUT_SHIFT_RIGHT));
                accu_im <= p_im + signed(RND(ROUND_ENABLE,OUTPUT_SHIFT_RIGHT));
              else
                accu_re <= p_re + accu_re;
                accu_im <= p_im + accu_im;
              end if;
            end if;
          end if;
        end if;
      end if;
    end process;
  end generate;
  g_dspreg_off : if NUM_OUTPUT_REG=0 generate
    accu_vld <= dsp_vld;
    accu_re <= p_re + signed(RND(ROUND_ENABLE,OUTPUT_SHIFT_RIGHT));
    accu_im <= p_im + signed(RND(ROUND_ENABLE,OUTPUT_SHIFT_RIGHT));
  end generate;

  chainout_re <= resize(accu_re,chainout_re'length);
  chainout_im <= resize(accu_im,chainout_im'length);

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
    OUTPUT_ROUND       => false,
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
    OUTPUT_ROUND       => false,
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
