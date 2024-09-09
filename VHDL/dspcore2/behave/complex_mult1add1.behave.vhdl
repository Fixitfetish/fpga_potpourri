-------------------------------------------------------------------------------
--! @file       complex_mult1add1.behave.vhdl
--! @author     Fixitfetish
--! @date       09/Sep/2024
--! @version    0.25
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Code comments are optimized for SIGASI.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension.all;
  use baselib.ieee_extension_types.all;

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
  constant INSTANCE_NAME : string := complex_mult1add1'INSTANCE_NAME;

  constant ACCU_WIDTH : positive := 64;
  constant MAX_WIDTH_A : positive := 32;
  constant MAX_WIDTH_B : positive := 32;
  constant MAX_WIDTH_C : positive := ACCU_WIDTH;

  --! rounding bit generation (+0.5)
  function RND return signed is
    variable res : signed(ACCU_WIDTH-1 downto 0) := (others=>'0');
  begin 
    if OUTPUT_ROUND and (OUTPUT_SHIFT_RIGHT>=1) then 
      res(OUTPUT_SHIFT_RIGHT-1):='1';
    end if;
    return res;
  end function;

  --! determine number of required additional guard bits (MSBs)
  function accu_guard_bits(
    dflt : natural; -- default value when num_summand=0
    impl : string -- implementation identifier string for warnings and errors
  ) return integer is
    variable res : integer;
  begin
    if NUM_SUMMAND=0 then
      res := dflt; -- maximum possible (default)
    else
      res := LOG2CEIL(NUM_SUMMAND);
      if res>dflt then 
        report "WARNING " & impl & ": Too many summands. " & 
           "Maximum number of " & integer'image(dflt) & " guard bits reached."
           severity warning;
        res:=dflt;
      end if;
    end if;
    return res; 
  end function;


  -- derived constants
  constant PRODUCT_WIDTH : natural := MAXIMUM(x_re'length,x_im'length) + MAXIMUM(y_re'length,y_im'length) + 1;
  constant MAX_GUARD_BITS : natural := ACCU_WIDTH - PRODUCT_WIDTH;
  constant GUARD_BITS_EVAL : natural := accu_guard_bits(MAX_GUARD_BITS,IMPLEMENTATION);
  constant ACCU_USED_WIDTH : natural := PRODUCT_WIDTH + GUARD_BITS_EVAL;
  constant ACCU_USED_SHIFTED_WIDTH : natural := ACCU_USED_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result_re'length;

  constant NUM_INPUT_REG_CTRL : natural := NUM_INPUT_REG_XY;
  signal pipe_rst : std_logic_vector(NUM_INPUT_REG_CTRL downto 0);
  signal pipe_clr : std_logic_vector(NUM_INPUT_REG_CTRL downto 0);
  signal pipe_neg : std_logic_vector(NUM_INPUT_REG_CTRL downto 0);

  constant NUM_INPUT_REG_X : natural := NUM_INPUT_REG_XY; -- TODO : later independent X and Y delays?
  signal pipe_xre : signed_vector(NUM_INPUT_REG_X downto 0)(x_re'length-1 downto 0);
  signal pipe_xim : signed_vector(NUM_INPUT_REG_X downto 0)(x_im'length-1 downto 0);
  signal pipe_xvld  : std_logic_vector(NUM_INPUT_REG_X downto 0);
  signal pipe_xconj : std_logic_vector(NUM_INPUT_REG_X downto 0);

  constant NUM_INPUT_REG_Y : natural := NUM_INPUT_REG_XY; -- TODO : later independent X and Y delays?
  signal pipe_yre : signed_vector(NUM_INPUT_REG_Y downto 0)(y_re'length-1 downto 0);
  signal pipe_yim : signed_vector(NUM_INPUT_REG_Y downto 0)(y_im'length-1 downto 0);
  signal pipe_yvld  : std_logic_vector(NUM_INPUT_REG_Y downto 0);
  signal pipe_yconj : std_logic_vector(NUM_INPUT_REG_Y downto 0);

  signal pipe_zre : signed_vector(NUM_INPUT_REG_Z downto 0)(z_re'length-1 downto 0);
  signal pipe_zim : signed_vector(NUM_INPUT_REG_Z downto 0)(z_im'length-1 downto 0);
  signal pipe_zvld : std_logic_vector(NUM_INPUT_REG_Z downto 0);

  signal are, aim : signed(MAX_WIDTH_A-1 downto 0);
  signal bre, bim : signed(MAX_WIDTH_B-1 downto 0);
  signal cre, cim : signed(MAX_WIDTH_C-1 downto 0);

  signal neg_xre, neg_xim, neg_yre, neg_yim : std_logic;

  signal m_vld, p_vld : std_logic;
  signal m_re, m_im : signed(ACCU_WIDTH-1 downto 0);
  signal p_re, p_im : signed(ACCU_WIDTH-1 downto 0);
  signal chainin_re_i, chainin_im_i : signed(ACCU_WIDTH-1 downto 0);

  signal accu_re, accu_im : signed(ACCU_WIDTH-1 downto 0);
  signal accu_vld : std_logic := '0';
  signal accu_used_re, accu_used_im : signed(ACCU_USED_WIDTH-1 downto 0);

  signal chainin_vld_q : std_logic;
 
begin

  assert OUTPUT_WIDTH<ACCU_USED_SHIFTED_WIDTH or not(OUTPUT_CLIP or OUTPUT_OVERFLOW)
    report INSTANCE_NAME & ": " & "More guard bits required for saturation/clipping and/or overflow detection." &
           "  OUTPUT_WIDTH="            & integer'image(OUTPUT_WIDTH) &
           ", ACCU_USED_SHIFTED_WIDTH=" & integer'image(ACCU_USED_SHIFTED_WIDTH) &
           ", OUTPUT_CLIP="             & boolean'image(OUTPUT_CLIP) &
           ", OUTPUT_OVERFLOW="         & boolean'image(OUTPUT_OVERFLOW)
    severity failure;

  pipe_rst(NUM_INPUT_REG_CTRL) <= rst;
  pipe_clr(NUM_INPUT_REG_CTRL) <= clr;
  pipe_neg(NUM_INPUT_REG_CTRL) <= neg when USE_NEGATION else '0';
  g_ctrl : if NUM_INPUT_REG_CTRL>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if rst/='0' then
          pipe_rst(NUM_INPUT_REG_CTRL-1 downto 0) <= (others=>'1');
          pipe_clr(NUM_INPUT_REG_CTRL-1 downto 0) <= (others=>'1');
          pipe_neg(NUM_INPUT_REG_CTRL-1 downto 0) <= (others=>'0');
        elsif clkena='1' then
          pipe_rst(NUM_INPUT_REG_CTRL-1 downto 0) <= pipe_rst(NUM_INPUT_REG_CTRL downto 1);
          pipe_clr(NUM_INPUT_REG_CTRL-1 downto 0) <= pipe_clr(NUM_INPUT_REG_CTRL downto 1);
          pipe_neg(NUM_INPUT_REG_CTRL-1 downto 0) <= pipe_neg(NUM_INPUT_REG_CTRL downto 1);
        end if;
      end if;
    end process;
  end generate;

  pipe_xre(NUM_INPUT_REG_X) <= x_re;
  pipe_xim(NUM_INPUT_REG_X) <= x_im;
  pipe_xvld(NUM_INPUT_REG_X) <= x_vld;
  pipe_xconj(NUM_INPUT_REG_X) <= x_conj when USE_CONJUGATE_X else '0';
  g_x : if NUM_INPUT_REG_X>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if rst/='0' then
          pipe_xre(NUM_INPUT_REG_X-1 downto 0) <= (others=>(others=>'-'));
          pipe_xim(NUM_INPUT_REG_X-1 downto 0) <= (others=>(others=>'-'));
          pipe_xvld(NUM_INPUT_REG_X-1 downto 0) <= (others=>'0');
          pipe_xconj(NUM_INPUT_REG_X-1 downto 0) <= (others=>'0');
        elsif clkena='1' then
          pipe_xre(NUM_INPUT_REG_X-1 downto 0) <= pipe_xre(NUM_INPUT_REG_X downto 1);
          pipe_xim(NUM_INPUT_REG_X-1 downto 0) <= pipe_xim(NUM_INPUT_REG_X downto 1);
          pipe_xvld(NUM_INPUT_REG_X-1 downto 0) <= pipe_xvld(NUM_INPUT_REG_X downto 1);
          pipe_xconj(NUM_INPUT_REG_X-1 downto 0) <= pipe_xconj(NUM_INPUT_REG_X downto 1);
        end if;
      end if;
    end process;
  end generate;

  pipe_yre(NUM_INPUT_REG_Y) <= y_re;
  pipe_yim(NUM_INPUT_REG_Y) <= y_im;
  pipe_yvld(NUM_INPUT_REG_Y) <= y_vld;
  pipe_yconj(NUM_INPUT_REG_Y) <= y_conj when USE_CONJUGATE_Y else '0';
  g_y : if NUM_INPUT_REG_Y>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if rst/='0' then
          pipe_yre(NUM_INPUT_REG_Y-1 downto 0) <= (others=>(others=>'-'));
          pipe_yim(NUM_INPUT_REG_Y-1 downto 0) <= (others=>(others=>'-'));
          pipe_yvld(NUM_INPUT_REG_Y-1 downto 0) <= (others=>'0');
          pipe_yconj(NUM_INPUT_REG_Y-1 downto 0) <= (others=>'0');
        elsif clkena='1' then
          pipe_yre(NUM_INPUT_REG_Y-1 downto 0) <= pipe_yre(NUM_INPUT_REG_Y downto 1);
          pipe_yim(NUM_INPUT_REG_Y-1 downto 0) <= pipe_yim(NUM_INPUT_REG_Y downto 1);
          pipe_yvld(NUM_INPUT_REG_Y-1 downto 0) <= pipe_yvld(NUM_INPUT_REG_Y downto 1);
          pipe_yconj(NUM_INPUT_REG_Y-1 downto 0) <= pipe_yconj(NUM_INPUT_REG_Y downto 1);
        end if;
      end if;
    end process;
  end generate;

  pipe_zre(NUM_INPUT_REG_Z) <= z_re;
  pipe_zim(NUM_INPUT_REG_Z) <= z_im;
  pipe_zvld(NUM_INPUT_REG_Z) <= z_vld;
  g_z : if NUM_INPUT_REG_Z>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if rst/='0' then
          pipe_zre(NUM_INPUT_REG_Z-1 downto 0) <= (others=>(others=>'-'));
          pipe_zim(NUM_INPUT_REG_Z-1 downto 0) <= (others=>(others=>'-'));
          pipe_zvld(NUM_INPUT_REG_Z-1 downto 0) <= (others=>'0');
        elsif clkena='1' then
          pipe_zre(NUM_INPUT_REG_Z-1 downto 0) <= pipe_zre(NUM_INPUT_REG_Z downto 1);
          pipe_zim(NUM_INPUT_REG_Z-1 downto 0) <= pipe_zim(NUM_INPUT_REG_Z downto 1);
          pipe_zvld(NUM_INPUT_REG_Z-1 downto 0) <= pipe_zvld(NUM_INPUT_REG_Z downto 1);
        end if;
      end if;
    end process;
  end generate;

    process(clk) begin
      if rising_edge(clk) then
        if rst/='0' then
          chainin_vld_q <= '0';
        elsif clkena='1' then
          chainin_vld_q <= chainin_re_vld;
        end if;
      end if;
    end process;


  neg_xre <= pipe_neg(0);
  neg_xim <= pipe_neg(0) xor pipe_xconj(0);
  neg_yre <= '0';
  neg_yim <= pipe_yconj(0);

  are <= resize(pipe_xre(0), are'length) when neg_xre/='1' else -resize(pipe_xre(0), are'length);
  aim <= resize(pipe_xim(0), aim'length) when neg_xim/='1' else -resize(pipe_xim(0), aim'length);
  bre <= resize(pipe_yre(0), bre'length) when neg_yre/='1' else -resize(pipe_yre(0), bre'length);
  bim <= resize(pipe_yim(0), bim'length) when neg_yim/='1' else -resize(pipe_yim(0), bim'length);
  cre <= resize(pipe_zre(0), cre'length) when pipe_zvld(0)='1' else (others=>'0');
  cim <= resize(pipe_zim(0), cim'length) when pipe_zvld(0)='1' else (others=>'0');

  -- use only LSBs of chain input
  chainin_re_i <= resize(chainin_re,ACCU_WIDTH) when chainin_vld_q='1' else (others=>'0');
  chainin_im_i <= resize(chainin_im,ACCU_WIDTH) when chainin_vld_q='1' else (others=>'0');

  m_vld <= pipe_xvld(0) and pipe_yvld(0); -- for a valid product both factors must be valid
  m_re <= (are*bre - aim*bim) when m_vld='1' else (others=>'0');
  m_im <= (are*bim + aim*bre) when m_vld='1' else (others=>'0');

  -- Operation
  p_re <= m_re + cre + chainin_re_i;
  p_im <= m_im + cim + chainin_im_i;
  p_vld <= m_vld or pipe_zvld(0) or chainin_vld_q;

  process(clk)
  begin
    if rising_edge(clk) then
      if rst/='0' then
        accu_vld <= '0';
        accu_re <= (others=>'0');
        accu_im <= (others=>'0');
      elsif clkena='1' then
        accu_vld <= p_vld;
        if pipe_clr(0)='1' or (p_vld='1' and not USE_ACCU) then
          accu_re <= p_re + RND;
          accu_im <= p_im + RND;
        elsif (p_vld='1' and USE_ACCU) then
          accu_re <= p_re + accu_re;
          accu_im <= p_im + accu_im;
        end if;
      end if;
    end if;
  end process;

  chainout_re <= resize(accu_re,chainout_re'length);
  chainout_im <= resize(accu_im,chainout_im'length);
  chainout_re_vld <= p_vld;
  chainout_im_vld <= p_vld;

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
