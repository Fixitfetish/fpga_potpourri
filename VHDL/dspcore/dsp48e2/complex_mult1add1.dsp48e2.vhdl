-------------------------------------------------------------------------------
--! @file       complex_mult1add1.dsp48e2.vhdl
--! @author     Fixitfetish
--! @date       01/Jan/2022
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

use work.xilinx_dsp_pkg_dsp48e2.all;

--! @brief This is an implementation of the entity complex_mult1add1 for Xilinx UltraScale.
--! One complex multiplication is performed and results can be accumulated.
--!
--! @image html complex_mult1add1.dsp48e2.svg "" width=600px
--!
--! **OPTIMIZATION="PERFORMANCE"**
--! * This implementation requires four instances of the entity signed_mult1add1 .
--! * Chaining is supported.
--! * The number of overall pipeline stages is typically NUM_INPUT_REG + 1 + NUM_OUTPUT_REG.
--! 
--! **OPTIMIZATION="RESOURCES"**
--! * This implementation requires three instances of the entity signed_preadd_mult1add1 .
--! * Chaining is supported.
--! * The number of overall pipeline stages is typically NUM_INPUT_REG + 2 + NUM_OUTPUT_REG.
--!
architecture dsp48e2 of complex_mult1add1 is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "complex_mult1add1(dsp48e2)";

  signal neg_i, conj_x_i, conj_y_i : std_logic := '0';

begin

  assert (OPTIMIZATION="PERFORMANCE" or OPTIMIZATION="RESOURCES")
    report "ERROR " & IMPLEMENTATION & " :" &
           " Supported optimizations are : PERFORMANCE or RESOURCES"
    severity failure;

  neg_i <= neg when NEGATION="DYNAMIC" else '1' when NEGATION="ON" else '0';
  conj_x_i <= conj_x when CONJUGATE_X="DYNAMIC" else '1' when CONJUGATE_X="ON" else '0';
  conj_y_i <= conj_y when CONJUGATE_Y="DYNAMIC" else '1' when CONJUGATE_Y="ON" else '0';


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
 G1 : if OPTIMIZATION="PERFORMANCE" generate
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
  i_re1 : entity work.signed_mult1add1(dsp48e2)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND-1,
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    USE_Z_INPUT        => USE_Z_INPUT,
    USE_NEGATION       => true,
    NUM_INPUT_REG_XY   => NUM_INPUT_REG_XY,
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
    neg        => neg_re1,
    x          => x_re,
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
  i_re2 : entity work.signed_mult1add1(dsp48e2)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND, -- two multiplications per complex multiplication
    USE_CHAIN_INPUT    => true,
    USE_Z_INPUT        => false,
    USE_NEGATION       => true,
    NUM_INPUT_REG_XY   => NUM_INPUT_REG_XY+1, -- additional pipeline register(s) because of chaining
    NUM_INPUT_REG_Z    => 0,
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
    neg        => neg_re2,
    x          => x_im,
    y          => y_im,
    z          => "00",
    result     => result_re,
    result_vld => result_vld,
    result_ovf => result_ovf_re,
    chainin    => chainout_re1,
    chainout   => chainout_re,
    PIPESTAGES => PIPESTAGES
  );

  -- operation:  Im1 = ImChain + Xre*Yim + Zim 
  i_im1 : entity work.signed_mult1add1(dsp48e2)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND-1,
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    USE_Z_INPUT        => USE_Z_INPUT,
    USE_NEGATION       => true,
    NUM_INPUT_REG_XY   => NUM_INPUT_REG_XY,
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
    neg        => neg_im1,
    x          => x_re,
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
  i_im2 : entity work.signed_mult1add1(dsp48e2)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND, -- two multiplications per complex multiplication
    USE_CHAIN_INPUT    => true,
    USE_Z_INPUT        => false,
    USE_NEGATION       => true,
    NUM_INPUT_REG_XY   => NUM_INPUT_REG_XY+1, -- additional pipeline register(s) because of chaining
    NUM_INPUT_REG_Z    => 0,
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
    neg        => neg_im2,
    x          => x_im,
    y          => y_re,
    z          => "00",
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
 G2 : if OPTIMIZATION="RESOURCES" generate
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
       return "SUBTRACT";
     else return "ADD"; end if;

   elsif choice="TEMP_XB" then
     -- XB = Yim * Xre
     if NEGATION="DYNAMIC" or CONJUGATE_Y="DYNAMIC" then
       return "DYNAMIC";
     elsif (CONJUGATE_Y="ON" and NEGATION="OFF") or (CONJUGATE_Y="OFF" and NEGATION="ON") then
       return "SUBTRACT";
     else return "ADD"; end if;

   elsif choice="RE_XA" then
     -- XA = -Xre * Yim
     if NEGATION="DYNAMIC" or CONJUGATE_Y="DYNAMIC" then
       return "DYNAMIC";
     elsif (CONJUGATE_Y="OFF" and NEGATION="OFF") or (CONJUGATE_Y="ON" and NEGATION="ON") then
       return "SUBTRACT";
     else return "ADD"; end if;

   elsif choice="RE_XB" then
     -- XB = -Xim * Yim
     if NEGATION="DYNAMIC" or CONJUGATE_X="DYNAMIC" or CONJUGATE_Y="DYNAMIC" then
       return "DYNAMIC";
     elsif NEGATION="ON" then
       if (CONJUGATE_X="ON" and CONJUGATE_Y="OFF") or (CONJUGATE_X="OFF" and CONJUGATE_Y="ON") then
         return "SUBTRACT";
       else return "ADD"; end if;
     else
       if (CONJUGATE_X="OFF" and CONJUGATE_Y="OFF") or (CONJUGATE_X="ON" and CONJUGATE_Y="ON") then
         return "SUBTRACT";
       else return "ADD"; end if;
     end if;

   elsif choice="IM_XA" then
     -- XA = Xim * Yre
     if NEGATION="DYNAMIC" or CONJUGATE_X="DYNAMIC" then
       return "DYNAMIC";
     elsif (CONJUGATE_X="ON" and NEGATION="OFF") or (CONJUGATE_X="OFF" and NEGATION="ON") then
       return "SUBTRACT";
     else return "ADD"; end if;

   elsif choice="IM_XB" then
     -- XB := -Xre * Yre
     if NEGATION="DYNAMIC" then
       return "DYNAMIC";
     elsif NEGATION="OFF" then
       return "SUBTRACT";
     else return "ADD"; end if;
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
  i_temp : entity work.signed_preadd_mult1add1(dsp48e2)
  generic map(
    NUM_SUMMAND        => 2,
    USE_CHAIN_INPUT    => false,
    USE_Z_INPUT        => false,
    PREADDER_INPUT_XA  => TEMP_PREADDER_XA,
    PREADDER_INPUT_XB  => TEMP_PREADDER_XB,
    NUM_INPUT_REG_XY   => NUM_INPUT_REG_XY,
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
    sub_xa     => temp_neg_xa,
    sub_xb     => temp_neg_xb,
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
  i_re : entity work.signed_preadd_mult1add1(dsp48e2)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND,
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    USE_Z_INPUT        => true,
    PREADDER_INPUT_XA  => RE_PREADDER_XA,
    PREADDER_INPUT_XB  => RE_PREADDER_XB,
    NUM_INPUT_REG_XY   => NUM_INPUT_REG_XY+2, -- 2 more pipeline stages to compensate Z input
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
    sub_xa     => re_neg_xa, --not neg, -- subtract (add)
    sub_xb     => re_neg_xb, --not neg, -- subtract (add)
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
  i_im : entity work.signed_preadd_mult1add1(dsp48e2)
  generic map(
    NUM_SUMMAND        => 2*NUM_SUMMAND,
    USE_CHAIN_INPUT    => USE_CHAIN_INPUT,
    USE_Z_INPUT        => true,
    PREADDER_INPUT_XA  => IM_PREADDER_XA,
    PREADDER_INPUT_XB  => IM_PREADDER_XB,
    NUM_INPUT_REG_XY   => NUM_INPUT_REG_XY+2, -- 2 more pipeline stages to compensate Z input
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
    sub_xa     => im_neg_xa, --neg,     -- add (subtract)
    sub_xb     => im_neg_xb, --not neg, -- subtract (add)
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
