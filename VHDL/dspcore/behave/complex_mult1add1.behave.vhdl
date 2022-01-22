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





 --------------------------------------------------------------------------------------------------
 -- Operation with 4 DSP cells and chaining
 -- *  Re1 = ReChain + Xre*Yre + Zre
 -- *  Im1 = ImChain + Xre*Yim + Zim
 -- *  Re2 = Re1     - Xim*Yim
 -- *  Im2 = Im1     + Xim*Yre
 --
 -- Notes
 -- * Re1/Im1 can add Z input in addition to chain input
 -- * Re2/Im2 can add round bit and accumulate in addition to chain input
 --------------------------------------------------------------------------------------------------
 G4DSP : if OPTIMIZATION="PERFORMANCE" generate
  signal chainout_re1 : signed(79 downto 0);
  signal chainout_im1 : signed(79 downto 0);
  signal dummy_re, dummy_im : signed(ACCU_WIDTH-1 downto 0);
  -- identifier for reports of warnings and errors
  constant CHOICE : string := IMPLEMENTATION & " with optimization=PERFORMANCE";
  signal neg_re1, neg_re2, neg_im1, neg_im2 : std_logic;
 begin

  neg_re1 <= neg_i;
  neg_im1 <= neg_i xor conj_y_i;
  neg_re2 <= (not neg_i) xor conj_x_i xor conj_y_i;
  neg_im2 <= neg_i xor conj_x_i;

  -- Operation:  Re1 = ReChain + Xre*Yre + Zre
  i_re1 : entity work.signed_preadd_mult1add1(behave)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND-1,
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    USE_XB_INPUT       => false, -- unused
    USE_Z_INPUT        => USE_Z_INPUT,
    NEGATE_XA          => "DYNAMIC", -- TODO : open
    NEGATE_XB          => open, -- unused
    NEGATE_Y           => open, -- TODO : use instead of XA
    NUM_INPUT_REG_X    => NUM_INPUT_REG_XY,
    NUM_INPUT_REG_Y    => NUM_INPUT_REG_XY,
    NUM_INPUT_REG_Z    => NUM_INPUT_REG_Z,
    NUM_OUTPUT_REG     => 1,
    OUTPUT_SHIFT_RIGHT => 0,
    OUTPUT_ROUND       => false,
    OUTPUT_CLIP        => false,
    OUTPUT_OVERFLOW    => false
  )
  port map (
    clk        => clk,
    rst        => rst,
    clkena     => clkena,
    clr        => '1',
    vld        => vld,
    neg_xa     => neg_re1,
    neg_xb     => open, -- unused
    neg_y      => open, -- TODO instead of xa
    xa         => x_re,
    xb         => "00", -- unused
    y          => y_re,
    z          => z_re,
    result     => dummy_re, -- unused
    result_vld => open, -- unused
    result_ovf => open, -- unused
    chainin    => chainin_re,
    chainout   => chainout_re1,
    PIPESTAGES => open  -- unused
  );

  -- operation:  Re2 = Re1 - Xim*Yim   (accumulation possible)
  i_re2 : entity work.signed_preadd_mult1add1(behave)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND, -- two multiplications per complex multiplication
    USE_CHAIN_INPUT    => true,
    USE_XB_INPUT       => false, -- unused
    USE_Z_INPUT        => false,
    NEGATE_XA          => "DYNAMIC", -- TODO : open
    NEGATE_XB          => open, -- unused
    NEGATE_Y           => open, -- TODO : use instead of XA
    NUM_INPUT_REG_X    => NUM_INPUT_REG_XY+1, -- additional pipeline register(s) because of chaining
    NUM_INPUT_REG_Y    => NUM_INPUT_REG_XY+1, -- additional pipeline register(s) because of chaining
    NUM_INPUT_REG_Z    => 0, -- unused
    NUM_OUTPUT_REG     => NUM_OUTPUT_REG,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => OUTPUT_ROUND,
    OUTPUT_CLIP        => OUTPUT_CLIP,
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
  )
  port map (
    clk        => clk,
    rst        => rst,
    clkena     => clkena,
    clr        => clr, -- accumulator enabled in last instance only!
    vld        => vld,
    neg_xa     => neg_re2,
    neg_xb     => open, -- unused
    neg_y      => open, -- TODO instead of xa
    xa         => x_im,
    xb         => "00", -- unused
    y          => y_im,
    z          => "00", -- unused
    result     => result_re,
    result_vld => result_vld,
    result_ovf => result_ovf_re,
    chainin    => chainout_re1,
    chainout   => chainout_re,
    PIPESTAGES => PIPESTAGES
  );

  -- operation:  Im1 = ImChain + Xre*Yim + Zim 
  i_im1 : entity work.signed_preadd_mult1add1(behave)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND-1,
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    USE_XB_INPUT       => false, -- unused
    USE_Z_INPUT        => USE_Z_INPUT,
    NEGATE_XA          => "DYNAMIC", -- TODO : open
    NEGATE_XB          => open, -- unused
    NEGATE_Y           => open, -- TODO : use instead of XA
    NUM_INPUT_REG_X    => NUM_INPUT_REG_XY,
    NUM_INPUT_REG_Y    => NUM_INPUT_REG_XY,
    NUM_INPUT_REG_Z    => NUM_INPUT_REG_Z,
    NUM_OUTPUT_REG     => 1,
    OUTPUT_SHIFT_RIGHT => 0,
    OUTPUT_ROUND       => false,
    OUTPUT_CLIP        => false,
    OUTPUT_OVERFLOW    => false
  )
  port map (
    clk        => clk,
    rst        => rst,
    clkena     => clkena,
    clr        => '1',
    vld        => vld,
    neg_xa     => neg_im1,
    neg_xb     => open, -- unused
    neg_y      => open, -- TODO instead of xa
    xa         => x_re,
    xb         => "00", -- unused
    y          => y_im,
    z          => z_im,
    result     => dummy_im, -- unused
    result_vld => open, -- unused
    result_ovf => open, -- unused
    chainin    => chainin_im,
    chainout   => chainout_im1,
    PIPESTAGES => open  -- unused
  );

  -- operation:  Im2 = Im1 + Xim*Yre   (accumulation possible)
  i_im2 : entity work.signed_preadd_mult1add1(behave)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND, -- two multiplications per complex multiplication
    USE_CHAIN_INPUT    => true,
    USE_XB_INPUT       => false, -- unused
    USE_Z_INPUT        => false,
    NEGATE_XA          => "DYNAMIC", -- TODO : open
    NEGATE_XB          => open, -- unused
    NEGATE_Y           => open, -- TODO : use instead of XA
    NUM_INPUT_REG_X    => NUM_INPUT_REG_XY+1, -- additional pipeline register(s) because of chaining
    NUM_INPUT_REG_Y    => NUM_INPUT_REG_XY+1, -- additional pipeline register(s) because of chaining
    NUM_INPUT_REG_Z    => 0, -- unused
    NUM_OUTPUT_REG     => NUM_OUTPUT_REG,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => OUTPUT_ROUND,
    OUTPUT_CLIP        => OUTPUT_CLIP,
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
  )
  port map (
    clk        => clk,
    rst        => rst,
    clkena     => clkena,
    clr        => clr, -- accumulator enabled in last instance only!
    vld        => vld,
    neg_xa     => neg_im2,
    neg_xb     => open, -- unused
    neg_y      => open, -- TODO instead of xa
    xa         => x_im,
    xb         => "00", -- unused
    y          => y_re,
    z          => "00", -- unused
    result     => result_im,
    result_vld => open, -- same as real component
    result_ovf => result_ovf_im,
    chainin    => chainout_im1,
    chainout   => chainout_im,
    PIPESTAGES => open  -- same as real component
  );

 end generate;


 --------------------------------------------------------------------------------------------------
 -- Operation with 3 DSP cells  (Z input not supported !)
 -- *  Temp =           ( Yre + Yim) * Xre 
 -- *  Re   = ReChain + (-Xre - Xim) * Yim + Temp
 -- *  Im   = ImChain + ( Xim - Xre) * Yre + Temp
 --
 -- USE_CHAIN_INPUT=true
 -- * accumulation not possible because P feedback must be disabled
 -- * The rounding (i.e. +0.5) not possible within DSP.
 --   But rounding bit can be injected at the first chain link where USE_CHAIN_INPUT=false
 --------------------------------------------------------------------------------------------------
 G3DSP : if OPTIMIZATION="RESOURCES" generate
  constant TEMP_WIDTH : positive := x_re'length + y_re'length + 1;
  signal temp : signed(TEMP_WIDTH-1 downto 0);
  -- identifier for reports of warnings and errors
  constant CHOICE : string := IMPLEMENTATION & " with optimization=RESOURCES";

  function PREADDER(choice:string) return string is
  begin
   if choice="TEMP_XA" then
     -- XA = Yre * Xre
     if NEGATION="DYNAMIC" then
       return "DYNAMIC";
     elsif NEGATION="ON" then
       return "ON";
     else return "OFF"; end if;

   elsif choice="TEMP_XB" then
     -- XB = Yim * Xre
     if NEGATION="DYNAMIC" or CONJUGATE_Y="DYNAMIC" then
       return "DYNAMIC";
     elsif (CONJUGATE_Y="ON" and NEGATION="OFF") or (CONJUGATE_Y="OFF" and NEGATION="ON") then
       return "ON";
     else return "OFF"; end if;

   elsif choice="RE_XA" then
     -- XA = -Xre * Yim
     if NEGATION="DYNAMIC" or CONJUGATE_Y="DYNAMIC" then
       return "DYNAMIC";
     elsif (CONJUGATE_Y="OFF" and NEGATION="OFF") or (CONJUGATE_Y="ON" and NEGATION="ON") then
       return "ON";
     else return "OFF"; end if;

   elsif choice="RE_XB" then
     -- XB = -Xim * Yim
     if NEGATION="DYNAMIC" or CONJUGATE_X="DYNAMIC" or CONJUGATE_Y="DYNAMIC" then
       return "DYNAMIC";
     elsif NEGATION="ON" then
       if (CONJUGATE_X="ON" and CONJUGATE_Y="OFF") or (CONJUGATE_X="OFF" and CONJUGATE_Y="ON") then
         return "ON";
       else return "OFF"; end if;
     else
       if (CONJUGATE_X="OFF" and CONJUGATE_Y="OFF") or (CONJUGATE_X="ON" and CONJUGATE_Y="ON") then
         return "ON";
       else return "OFF"; end if;
     end if;

   elsif choice="IM_XA" then
     -- XA = Xim * Yre
     if NEGATION="DYNAMIC" or CONJUGATE_X="DYNAMIC" then
       return "DYNAMIC";
     elsif (CONJUGATE_X="ON" and NEGATION="OFF") or (CONJUGATE_X="OFF" and NEGATION="ON") then
       return "ON";
     else return "OFF"; end if;

   elsif choice="IM_XB" then
     -- XB := -Xre * Yre
     if NEGATION="DYNAMIC" then
       return "DYNAMIC";
     elsif NEGATION="OFF" then
       return "ON";
     else return "OFF"; end if;
   else
     return "INVALID";
   end if;
  end function;

  -- separate constants and functions for better visibility in simulator
  constant TEMP_PREADDER_XA : string := PREADDER("TEMP_XA");
  constant TEMP_PREADDER_XB : string := PREADDER("TEMP_XB");
  constant RE_PREADDER_XA : string := PREADDER("RE_XA");
  constant RE_PREADDER_XB : string := PREADDER("RE_XB");
  constant IM_PREADDER_XA : string := PREADDER("IM_XA");
  constant IM_PREADDER_XB : string := PREADDER("IM_XB");

  signal temp_neg_xa, re_neg_xa, im_neg_xa : std_logic;
  signal temp_neg_xb, re_neg_xb, im_neg_xb : std_logic;

 begin

  assert (not USE_Z_INPUT)
    report "ERROR " & CHOICE & " :" &
           " Z input not supported with selected optimization."
    severity failure;
  assert (not USE_CHAIN_INPUT)
    report "NOTE " & CHOICE & " :" &
           " Selected optimization does not allow accumulation when chain input is used. Ignoring CLR input port."
    severity note;

  -- negation signals only considered in preadder DYNAMIC mode
  temp_neg_xa <= neg_i; -- Yre*Xre
  temp_neg_xb <= neg_i xor conj_y; -- Yim*Xre

  -- Operation:
  -- Temp = ( Yre + Yim) * Xre  ... raw with full resolution
  i_temp : entity work.signed_preadd_mult1add1(behave)
  generic map(
    NUM_SUMMAND        => 2,
    USE_CHAIN_INPUT    => false,
    USE_XB_INPUT       => true,
    USE_Z_INPUT        => false,
    NEGATE_XA          => TEMP_PREADDER_XA,
    NEGATE_XB          => TEMP_PREADDER_XB,
    NEGATE_Y           => open,
    NUM_INPUT_REG_X    => NUM_INPUT_REG_XY,
    NUM_INPUT_REG_Y    => NUM_INPUT_REG_XY,
    NUM_INPUT_REG_Z    => open, -- unused
    NUM_OUTPUT_REG     => 1,
    OUTPUT_SHIFT_RIGHT => 0, -- raw temporary result for following RE and IM stage
    OUTPUT_ROUND       => false,
    OUTPUT_CLIP        => false,
    OUTPUT_OVERFLOW    => false
  )
  port map(
    clk        => clk, -- clock
    rst        => rst, -- reset
    clkena     => clkena,
    clr        => open,
    vld        => vld, -- valid
    neg_xa     => temp_neg_xa,
    neg_xb     => temp_neg_xb,
    xa         => y_re, -- first factor
    xb         => y_im, -- first factor
    y          => x_re, -- second factor
    z          => "00", -- unused
    result     => temp, -- temporary result
    result_vld => open, -- not needed
    result_ovf => open, -- not needed
    chainin    => open, -- unused
    chainout   => open, -- unused
    PIPESTAGES => open
  );

  -- negation signals only considered in preadder DYNAMIC mode
  re_neg_xa <= (not neg_i) xor conj_y; -- -Xre*Yim
  re_neg_xb <= (not neg_i) xor conj_x xor conj_y; -- -Xim*Yim

  -- Operation:
  -- Re = ReChain + (-Xre - Xim) * Yim + Temp   (accumulation only when chain input unused)
  i_re : entity work.signed_preadd_mult1add1(behave)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND,
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    USE_XB_INPUT       => true,
    USE_Z_INPUT        => true,
    NEGATE_XA          => RE_PREADDER_XA,
    NEGATE_XB          => RE_PREADDER_XB,
    NEGATE_Y           => open,
    NUM_INPUT_REG_X    => NUM_INPUT_REG_XY+2, -- 2 more pipeline stages to compensate Z input
    NUM_INPUT_REG_Y    => NUM_INPUT_REG_XY+2, -- 2 more pipeline stages to compensate Z input
    NUM_INPUT_REG_Z    => 1,
    NUM_OUTPUT_REG     => NUM_OUTPUT_REG,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => OUTPUT_ROUND,
    OUTPUT_CLIP        => OUTPUT_CLIP,
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
  )
  port map(
    clk        => clk, -- clock
    rst        => rst, -- reset
    clkena     => clkena,
    clr        => clr, -- clear
    vld        => vld, -- valid
    neg_xa     => re_neg_xa, --not neg, -- subtract (add)
    neg_xb     => re_neg_xb, --not neg, -- subtract (add)
    xa         => x_re,
    xb         => x_im,
    y          => y_im,
    z          => temp,
    result     => result_re,
    result_vld => result_vld,
    result_ovf => result_ovf_re,
    chainin    => chainin_re,
    chainout   => chainout_re,
    PIPESTAGES => PIPESTAGES
  );

  -- negation signals only considered in preadder DYNAMIC mode
  im_neg_xa <= neg_i xor conj_x; -- Xim*Yre
  im_neg_xb <= (not neg_i); -- -Xre*Yre

  -- Operation:
  -- Im = ImChain + ( Xim - Xre) * Yre + Temp   (accumulation only when chain input unused)
  i_im : entity work.signed_preadd_mult1add1(behave)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND,
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    USE_XB_INPUT       => true,
    USE_Z_INPUT        => true,
    NEGATE_XA          => IM_PREADDER_XA,
    NEGATE_XB          => IM_PREADDER_XB,
    NEGATE_Y           => open,
    NUM_INPUT_REG_X    => NUM_INPUT_REG_XY+2, -- 2 more pipeline stages to compensate Z input
    NUM_INPUT_REG_Y    => NUM_INPUT_REG_XY+2, -- 2 more pipeline stages to compensate Z input
    NUM_INPUT_REG_Z    => 1,
    NUM_OUTPUT_REG     => NUM_OUTPUT_REG,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => OUTPUT_ROUND,
    OUTPUT_CLIP        => OUTPUT_CLIP,
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
  )
  port map(
    clk        => clk, -- clock
    rst        => rst, -- reset
    clkena     => clkena,
    clr        => clr, -- clear
    vld        => vld, -- valid
    neg_xa     => im_neg_xa, --neg,     -- add (subtract)
    neg_xb     => im_neg_xb, --not neg, -- subtract (add)
    xa         => x_im,
    xb         => x_re,
    y          => y_re,
    z          => temp,
    result     => result_im,
    result_vld => open, -- same as real component
    result_ovf => result_ovf_im,
    chainin    => chainin_im,
    chainout   => chainout_im,
    PIPESTAGES => open -- same as real component
  );

 end generate;

end architecture;
