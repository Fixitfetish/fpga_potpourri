-------------------------------------------------------------------------------
--! @file       complex_mult1add1.dsp58.vhdl
--! @author     Fixitfetish
--! @date       15/Sep/2024
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Code comments are optimized for SIGASI.
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library unisim;

use work.xilinx_dsp_pkg_dsp58.all;

-- This is an implementation of the entity complex_mult1add1 for AMD/Xilinx DSP58.
--
-- **OPTIMIZATION="PERFORMANCE"**
-- * This implementation requires four instances of the entity signed_preadd_mult1add1 with disabled preadder.
-- * This implementation requires four DSP58s.
-- * X input width is limited to 27 bits and Y input to 24 bits.
-- * Chaining is supported.
-- * Additional Z summand input is supported.
-- * Accumulation is not supported when chain and Z input are used.
-- * The number of overall pipeline stages is typically NUM_INPUT_REG_XY + 1 + NUM_OUTPUT_REG.
--
-- **OPTIMIZATION="RESOURCES" with x and y input width <=24 bits**
-- * This implementation requires three instances of the entity signed_preadd_mult1add1 .
-- * This implementation requires three DSP58s.
-- * X and Y input width is limited to 24 bits.
-- * Chaining is supported.
-- * Additional Z summand input is NOT supported.
-- * Accumulation is not supported when chain input is used.
-- * The number of overall pipeline stages is typically NUM_INPUT_REG_XY + 2 + NUM_OUTPUT_REG.
--
-- **OPTIMIZATION="RESOURCES" with x and y input width <=18 bits**
-- * This implementation instantiates the primitive DSPCPLX which requires two back-to-back DSP58s.
-- * X and Y input width is limited to 18 bits.
-- * Chaining is supported.
-- * Additional Z summand input is supported.
-- * Accumulation is not supported when chain and Z input are used.
-- * The number of overall pipeline stages is typically NUM_INPUT_REG_XY + NUM_OUTPUT_REG.
--
-- Refer to Xilinx Versal ACAP DSP Engine, Architecture Manual, AM004 (v1.2.1) September 11, 2022
--
architecture dsp58 of complex_mult1add1 is

  constant X_INPUT_WIDTH   : positive := maximum(x_re'length,x_im'length);
  constant Y_INPUT_WIDTH   : positive := maximum(y_re'length,y_im'length);
  constant MAX_INPUT_WIDTH : positive := maximum(X_INPUT_WIDTH,Y_INPUT_WIDTH);

  -- TODO: later independent X and Y input registers ?
  constant NUM_INPUT_REG_X : positive := NUM_INPUT_REG_XY;
  constant NUM_INPUT_REG_Y : positive := NUM_INPUT_REG_XY;

  signal neg_i, x_conj_i, y_conj_i : std_logic := '0';

begin

  neg_i    <= neg    when USE_NEGATION    else '0';
  x_conj_i <= x_conj when USE_CONJUGATE_X else '0';
  y_conj_i <= y_conj when USE_CONJUGATE_Y else '0';

 --------------------------------------------------------------------------------------------------
 -- Operation with 4 DSP cells and chaining
 -- *  Re1 = ReChain + Xre*Yre + Zre
 -- *  Im1 = ImChain + Xre*Yim + Zim
 -- *  Re2 = Re1     - Xim*Yim + ReAccu
 -- *  Im2 = Im1     + Xim*Yre + ImAccu
 --
 -- Notes
 -- * Re1/Im1 can add Z input in addition to chain input
 -- * Re2/Im2 can add round bit and accumulate in addition to chain input
 -- * TODO : also allows complex preadder => different entity complex_preadd_macc !?
 --------------------------------------------------------------------------------------------------
 G4DSP : if OPTIMIZATION="PERFORMANCE" or OPTIMIZATION="G4DSP" generate
  -- identifier for reports of warnings and errors
  constant CHOICE : string := "(optimization=PERFORMANCE, 4 DSPs):: ";
  signal chain_re , chain_im: signed(79 downto 0);
  signal chain_re_vld, chain_im_vld : std_logic;
  signal dummy_re, dummy_im : signed(ACCU_WIDTH-1 downto 0);
 begin

  assert (NUM_INPUT_REG_X>=2 and NUM_INPUT_REG_Y>=2)
    report complex_mult1add1'INSTANCE_NAME & CHOICE &
           "For high-speed the X and Y paths should have at least two input registers."
    severity warning;

  assert (X_INPUT_WIDTH<=MAX_WIDTH_AD)
    report complex_mult1add1'INSTANCE_NAME & CHOICE &
           "Multiplier input X width cannot exceed " & integer'image(MAX_WIDTH_AD)
    severity failure;

  assert (Y_INPUT_WIDTH<=MAX_WIDTH_B)
    report complex_mult1add1'INSTANCE_NAME & CHOICE &
           "Multiplier input Y width cannot exceed " & integer'image(MAX_WIDTH_B) & ". Maybe swap X and Y inputs ?"
    severity failure;

  -- Operation:  Re1 = ReChain + Xre*Yre + Zre
  i_re1 : entity work.signed_preadd_mult1add1(dsp58)
  generic map(
    NUM_ACCU_CYCLES     => open, -- accumulator disabled
    NUM_SUMMAND_CHAININ => 2*NUM_SUMMAND_CHAININ, -- two single summands per complex chain input
    NUM_SUMMAND_Z       => 2*NUM_SUMMAND_Z, -- two single summands per complex Z input
    USE_XB_INPUT        => false, -- unused
    USE_NEGATION        => USE_NEGATION,
    USE_XA_NEGATION     => open, -- unused
    USE_XB_NEGATION     => open, -- unused
    NUM_INPUT_REG_X     => NUM_INPUT_REG_X,
    NUM_INPUT_REG_Y     => NUM_INPUT_REG_Y,
    NUM_INPUT_REG_Z     => NUM_INPUT_REG_Z,
    RELATION_RST        => RELATION_RST,
    RELATION_CLR        => open, -- unused
    RELATION_NEG        => RELATION_NEG,
    NUM_OUTPUT_REG      => 1,
    OUTPUT_SHIFT_RIGHT  => 0,     -- result output unused
    OUTPUT_ROUND        => false, -- result output unused
    OUTPUT_CLIP         => false, -- result output unused
    OUTPUT_OVERFLOW     => false  -- result output unused
  )
  port map (
    clk          => clk,
    rst          => rst,
    clkena       => clkena,
    clr          => open, -- unused
    neg          => neg_i,
    xa           => x_re,
    xa_vld       => x_vld,
    xa_neg       => open, -- unused
    xb           => "00", -- unused
    xb_vld       => open, -- unused
    xb_neg       => open, -- unused
    y            => y_re,
    y_vld        => y_vld,
    z            => z_re,
    z_vld        => z_vld,
    result       => dummy_re, -- unused
    result_vld   => open, -- unused
    result_ovf   => open, -- unused
    result_rst   => open, -- unused
    chainin      => chainin_re,
    chainin_vld  => chainin_re_vld,
    chainout     => chain_re,
    chainout_vld => chain_re_vld,
    PIPESTAGES   => open  -- unused
  );

  -- operation:  Re2 = Re1 - Xim*Yim   (accumulation possible)
  i_re2 : entity work.signed_preadd_mult1add1(dsp58)
  generic map(
    NUM_ACCU_CYCLES     => NUM_ACCU_CYCLES, -- accumulator enabled in last chain link only!
    NUM_SUMMAND_CHAININ => 2*NUM_SUMMAND_CHAININ + 2*NUM_SUMMAND_Z + 1,
    NUM_SUMMAND_Z       => 0, -- unused
    USE_XB_INPUT        => false, -- unused
    USE_NEGATION        => true,
    USE_XA_NEGATION     => USE_CONJUGATE_X,
    USE_XB_NEGATION     => open, -- unused
    NUM_INPUT_REG_X     => NUM_INPUT_REG_X + 1,
    NUM_INPUT_REG_Y     => NUM_INPUT_REG_Y + 1,
    NUM_INPUT_REG_Z     => open, -- unused
    RELATION_RST        => RELATION_RST,
    RELATION_CLR        => RELATION_CLR,
    RELATION_NEG        => RELATION_NEG, -- TODO : neg and y_conj must have same relation. force "Y" ?
    NUM_OUTPUT_REG      => NUM_OUTPUT_REG,
    OUTPUT_SHIFT_RIGHT  => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND        => OUTPUT_ROUND,
    OUTPUT_CLIP         => OUTPUT_CLIP,
    OUTPUT_OVERFLOW     => OUTPUT_OVERFLOW
  )
  port map (
    clk          => clk,
    rst          => rst,
    clkena       => clkena,
    clr          => clr, -- accumulator enabled in last chain link only!
    neg          => (not neg_i) xor y_conj_i,
    xa           => x_im,
    xa_vld       => x_vld,
    xa_neg       => x_conj_i,
    xb           => "00", -- unused
    xb_vld       => open, -- unused
    xb_neg       => open, -- unused
    y            => y_im,
    y_vld        => y_vld,
    z            => "00", -- unused
    z_vld        => open, -- unused
    result       => result_re,
    result_vld   => result_vld,
    result_ovf   => result_ovf_re,
    result_rst   => result_rst,
    chainin      => chain_re,
    chainin_vld  => chain_re_vld,
    chainout     => chainout_re,
    chainout_vld => chainout_re_vld,
    PIPESTAGES   => PIPESTAGES
  );

  -- operation:  Im1 = ImChain + Xre*Yim + Zim 
  i_im1 : entity work.signed_preadd_mult1add1(dsp58)
  generic map(
    NUM_ACCU_CYCLES     => open, -- accumulator disabled
    NUM_SUMMAND_CHAININ => 2*NUM_SUMMAND_CHAININ, -- two single summands per complex chain input
    NUM_SUMMAND_Z       => 2*NUM_SUMMAND_Z, -- two single summands per complex Z input
    USE_XB_INPUT        => false, -- unused
    USE_NEGATION        => USE_CONJUGATE_Y,
    USE_XA_NEGATION     => USE_NEGATION,
    USE_XB_NEGATION     => open, -- unused
    NUM_INPUT_REG_X     => NUM_INPUT_REG_X,
    NUM_INPUT_REG_Y     => NUM_INPUT_REG_Y,
    NUM_INPUT_REG_Z     => NUM_INPUT_REG_Z,
    RELATION_RST        => RELATION_RST,
    RELATION_CLR        => open, -- unused
    RELATION_NEG        => RELATION_NEG, -- TODO : fixed to "Y" ?
    NUM_OUTPUT_REG      => 1,
    OUTPUT_SHIFT_RIGHT  => 0,     -- result output unused
    OUTPUT_ROUND        => false, -- result output unused
    OUTPUT_CLIP         => false, -- result output unused
    OUTPUT_OVERFLOW     => false  -- result output unused
  )
  port map (
    clk          => clk,
    rst          => rst,
    clkena       => clkena,
    clr          => open,
    neg          => y_conj_i,
    xa           => x_re,
    xa_vld       => x_vld,
    xa_neg       => neg_i,
    xb           => "00", -- unused
    xb_vld       => open, -- unused
    xb_neg       => open, -- unused
    y            => y_im,
    y_vld        => y_vld,
    z            => z_im,
    z_vld        => z_vld,
    result       => dummy_im, -- unused
    result_vld   => open, -- unused
    result_ovf   => open, -- unused
    result_rst   => open, -- unused
    chainin      => chainin_im,
    chainin_vld  => chainin_im_vld,
    chainout     => chain_im,
    chainout_vld => chain_im_vld,
    PIPESTAGES   => open  -- unused
  );

  -- operation:  Im2 = Im1 + Xim*Yre   (accumulation possible)
  i_im2 : entity work.signed_preadd_mult1add1(dsp58)
  generic map(
    NUM_ACCU_CYCLES     => NUM_ACCU_CYCLES, -- accumulator enabled in last chain link only!
    NUM_SUMMAND_CHAININ => 2*NUM_SUMMAND_CHAININ + 2*NUM_SUMMAND_Z + 1,
    NUM_SUMMAND_Z       => 0, -- unused
    USE_XB_INPUT        => false, -- unused
    USE_NEGATION        => USE_NEGATION,
    USE_XA_NEGATION     => USE_CONJUGATE_X,
    USE_XB_NEGATION     => open, -- unused
    NUM_INPUT_REG_X     => NUM_INPUT_REG_X + 1,
    NUM_INPUT_REG_Y     => NUM_INPUT_REG_Y + 1,
    NUM_INPUT_REG_Z     => open, -- unused
    RELATION_RST        => RELATION_RST,
    RELATION_CLR        => RELATION_CLR,
    RELATION_NEG        => RELATION_NEG,
    NUM_OUTPUT_REG      => NUM_OUTPUT_REG,
    OUTPUT_SHIFT_RIGHT  => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND        => OUTPUT_ROUND,
    OUTPUT_CLIP         => OUTPUT_CLIP,
    OUTPUT_OVERFLOW     => OUTPUT_OVERFLOW
  )
  port map (
    clk          => clk,
    rst          => rst,
    clkena       => clkena,
    clr          => clr, -- accumulator enabled in last chain link only!
    neg          => neg_i,
    xa           => x_im,
    xa_vld       => x_vld,
    xa_neg       => x_conj_i,
    xb           => "00", -- unused
    xb_vld       => open, -- unused
    xb_neg       => open, -- unused
    y            => y_re,
    y_vld        => y_vld,
    z            => "00", -- unused
    z_vld        => open, -- unused
    result       => result_im,
    result_vld   => open, -- same as real component
    result_ovf   => result_ovf_im,
    result_rst   => open, -- same as real component
    chainin      => chain_im,
    chainin_vld  => chain_im_vld,
    chainout     => chainout_im,
    chainout_vld => chainout_im_vld,
    PIPESTAGES   => open  -- same as real component
  );

 end generate G4DSP;


 --------------------------------------------------------------------------------------------------
 -- Operation with 3 DSP cells
 -- *  Temp =           ( Yre - Yim) * Xim 
 -- *  Re   = ReChain + ( Xre - Xim) * Yre + Temp  = ReChain + (Xre * Yre) - (Xim * Yim)
 -- *  Im   = ImChain + ( Xre + Xim) * Yim + Temp  = ImChain + (Xre * Yim) + (Xim * Yre)
 --
 -- Notes
 -- * Z input not supported !
 -- * factor inputs X and Y are limited to 2x24 bits
 --
 -- If the chain input is used, i.e. when the chainin_vld is connected and not static, then
 -- * accumulation not possible because P feedback must be disabled
 -- * The rounding (i.e. +0.5) not possible within DSP.
 --   But rounding bit can be injected at the first chain link where the chain input is unused.
 --------------------------------------------------------------------------------------------------
 G3DSP : if (OPTIMIZATION="RESOURCES" and MAX_INPUT_WIDTH>18) or OPTIMIZATION="G3DSP" generate
  -- identifier for reports of warnings and errors
  constant CHOICE : string := "(optimization=RESOURCES, 3 DSPs):: ";
  constant TEMP_WIDTH : positive := x_re'length + y_re'length + 1;
  signal temp : signed(TEMP_WIDTH-1 downto 0);
  signal temp_vld : std_logic;
 begin

  assert (NUM_INPUT_REG_X>=2 and NUM_INPUT_REG_Y>=2)
    report complex_mult1add1'INSTANCE_NAME & CHOICE &
           "For high-speed the X and Y paths should have at least two input registers."
    severity warning;

  assert (chainin_re_vld/='1' and chainin_im_vld/='1') or (NUM_ACCU_CYCLES=1)
    report complex_mult1add1'INSTANCE_NAME & CHOICE &
           "Selected optimization does not allow simultaneous chain input and accumulation."
    severity warning;

  assert (MAX_INPUT_WIDTH<=MAX_WIDTH_B)
    report complex_mult1add1'INSTANCE_NAME & CHOICE &
           "Multiplier input X and Y width cannot exceed " & integer'image(MAX_WIDTH_B)
    severity failure;

  assert (z_vld/='1')
    report complex_mult1add1'INSTANCE_NAME & CHOICE &
           "Z input not supported with selected optimization."
    severity failure;

  -- Operation:
  -- Temp = ( Yre - Yim) * Xim  ... raw with full resolution
  i_temp : entity work.signed_preadd_mult1add1(dsp58)
  generic map(
    NUM_ACCU_CYCLES     => open, -- accumulator disabled
    NUM_SUMMAND_CHAININ => 0, -- unused
    NUM_SUMMAND_Z       => 0, -- unused
    USE_XB_INPUT        => true,
    USE_NEGATION        => USE_NEGATION or USE_CONJUGATE_X,
    USE_XA_NEGATION     => true,
    USE_XB_NEGATION     => false, -- unused
    NUM_INPUT_REG_X     => NUM_INPUT_REG_Y, -- X/Y swapped because Y requires preadder
    NUM_INPUT_REG_Y     => NUM_INPUT_REG_X, -- X/Y swapped because Y requires preadder
    NUM_INPUT_REG_Z     => open, -- unused
    RELATION_RST        => RELATION_RST,
    RELATION_CLR        => open, -- unused
    RELATION_NEG        => RELATION_NEG,
    NUM_OUTPUT_REG      => 1,
    OUTPUT_SHIFT_RIGHT  => 0, -- raw temporary result for following RE and IM stage
    OUTPUT_ROUND        => false,
    OUTPUT_CLIP         => false,
    OUTPUT_OVERFLOW     => false
  )
  port map(
    clk          => clk, -- clock
    rst          => rst, -- reset
    clkena       => clkena,
    clr          => open, -- unused
    neg          => neg_i xor x_conj_i,
    xa           => y_im, -- first factor
    xa_vld       => y_vld,
    xa_neg       => not y_conj_i,
    xb           => y_re, -- first factor
    xb_vld       => y_vld,
    xb_neg       => open, -- unused
    y            => x_im, -- second factor
    y_vld        => x_vld,
    z            => "00", -- unused
    z_vld        => open, -- unused
    result       => temp, -- temporary result
    result_vld   => temp_vld,
    result_ovf   => open, -- not needed
    result_rst   => open, -- unused
    chainin      => open, -- unused
    chainin_vld  => open, -- unused
    chainout     => open, -- unused
    chainout_vld => open, -- unused
    PIPESTAGES   => open  -- unused
  );

  -- Operation:
  -- Re = ReChain + (Xre - Xim) * Yre + Temp   (accumulation only when chain input unused)
  i_re : entity work.signed_preadd_mult1add1(dsp58)
  generic map(
    NUM_ACCU_CYCLES     => NUM_ACCU_CYCLES, -- accumulator enabled in last chain link only!
    NUM_SUMMAND_CHAININ => 2*NUM_SUMMAND_CHAININ, -- two single summands per complex chain input
    NUM_SUMMAND_Z       => 1, -- temp contributes with two summands because of preadder but one of those is subtracted here again
    USE_XB_INPUT        => true,
    USE_NEGATION        => USE_NEGATION,
    USE_XA_NEGATION     => true,
    USE_XB_NEGATION     => false, -- unused
    NUM_INPUT_REG_X     => NUM_INPUT_REG_X + NUM_INPUT_REG_Z + 1,
    NUM_INPUT_REG_Y     => NUM_INPUT_REG_Y + NUM_INPUT_REG_Z + 1,
    NUM_INPUT_REG_Z     => NUM_INPUT_REG_Z,
    RELATION_RST        => RELATION_RST,
    RELATION_CLR        => RELATION_CLR,
    RELATION_NEG        => RELATION_NEG,
    NUM_OUTPUT_REG      => NUM_OUTPUT_REG,
    OUTPUT_SHIFT_RIGHT  => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND        => OUTPUT_ROUND,
    OUTPUT_CLIP         => OUTPUT_CLIP,
    OUTPUT_OVERFLOW     => OUTPUT_OVERFLOW
  )
  port map(
    clk          => clk,
    rst          => rst,
    clkena       => clkena,
    clr          => clr, -- only relevant when accumulator is enabled
    neg          => neg_i,
    xa           => x_im,
    xa_vld       => x_vld,
    xa_neg       => not x_conj_i,
    xb           => x_re,
    xb_vld       => x_vld,
    xb_neg       => open, -- unused
    y            => y_re,
    y_vld        => y_vld,
    z            => temp,
    z_vld        => temp_vld,
    result       => result_re,
    result_vld   => result_vld,
    result_ovf   => result_ovf_re,
    result_rst   => result_rst,
    chainin      => chainin_re,
    chainin_vld  => chainin_re_vld,
    chainout     => chainout_re,
    chainout_vld => chainout_re_vld,
    PIPESTAGES   => PIPESTAGES
  );

  -- Operation:
  -- Im = ImChain + ( Xre + Xim) * Yim + Temp   (accumulation only when chain input unused)
  i_im : entity work.signed_preadd_mult1add1(dsp58)
  generic map(
    NUM_ACCU_CYCLES     => NUM_ACCU_CYCLES, -- accumulator enabled in last chain link only!
    NUM_SUMMAND_CHAININ => 2*NUM_SUMMAND_CHAININ, -- two single summands per complex chain input
    NUM_SUMMAND_Z       => 1, -- temp contributes with two summands because of preadder but one of those is subtracted here again
    USE_XB_INPUT        => true,
    USE_NEGATION        => USE_NEGATION or USE_CONJUGATE_Y,
    USE_XA_NEGATION     => USE_CONJUGATE_X,
    USE_XB_NEGATION     => false, -- unused
    NUM_INPUT_REG_X     => NUM_INPUT_REG_X + NUM_INPUT_REG_Z + 1,
    NUM_INPUT_REG_Y     => NUM_INPUT_REG_Y + NUM_INPUT_REG_Z + 1,
    NUM_INPUT_REG_Z     => NUM_INPUT_REG_Z,
    RELATION_RST        => RELATION_RST,
    RELATION_CLR        => RELATION_CLR,
    RELATION_NEG        => RELATION_NEG,
    NUM_OUTPUT_REG      => NUM_OUTPUT_REG,
    OUTPUT_SHIFT_RIGHT  => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND        => OUTPUT_ROUND,
    OUTPUT_CLIP         => OUTPUT_CLIP,
    OUTPUT_OVERFLOW     => OUTPUT_OVERFLOW
  )
  port map(
    clk          => clk,
    rst          => rst,
    clkena       => clkena,
    clr          => clr, -- only relevant when accumulator is enabled
    neg          => neg_i xor y_conj_i,
    xa           => x_im,
    xa_vld       => x_vld,
    xa_neg       => x_conj_i,
    xb           => x_re,
    xb_vld       => x_vld,
    xb_neg       => open, -- unused
    y            => y_im,
    y_vld        => y_vld,
    z            => temp,
    z_vld        => temp_vld,
    result       => result_im,
    result_vld   => open, -- same as real component
    result_ovf   => result_ovf_im,
    result_rst   => open, -- same as real component
    chainin      => chainin_im,
    chainin_vld  => chainin_im_vld,
    chainout     => chainout_im,
    chainout_vld => chainout_im_vld,
    PIPESTAGES   => open  -- same as real component
  );

 end generate G3DSP;


 --------------------------------------------------------------------------------------------------
 -- Special Operation with 2 back-to-back DSP cells plus chain and Z input.
 --
 -- Notes
-- * last Z input in chain not supported, when accumulation is required !
-- * factor inputs X and Y are limited to 2x18 bits
 --------------------------------------------------------------------------------------------------
 G2DSP : if (OPTIMIZATION="RESOURCES" and MAX_INPUT_WIDTH<=18) or OPTIMIZATION="G2DSP" generate
  -- identifier for reports of warnings and errors
  constant CHOICE : string := "(optimization=RESOURCES, 2 DSPs):: ";

  -- Max input width
  constant INPUT_WIDTH : positive := 18;

  constant DSPREG : t_dspreg := GET_NUM_DSPCPLX_REG(
    aregs => NUM_INPUT_REG_X,
    bregs => NUM_INPUT_REG_Y,
    cregs => NUM_INPUT_REG_Z
  );

  -- This function calculates the number registers that are required to correctly
  -- align data and control signals at the input of the DSP cell.
  -- DSP internal delays are intentionally not compensated here.
  function GET_NUM_LOGIC_REG return t_logicreg is
    variable reg : t_logicreg;
  begin
    reg.A := NUM_INPUT_REG_X - DSPREG.A - DSPREG.M;
    reg.B := NUM_INPUT_REG_Y - DSPREG.B - DSPREG.M;
    reg.C := NUM_INPUT_REG_Z - DSPREG.C;
    reg.D := 0; -- unused
    -- Reset signal delay compensation
    if    RELATION_RST="X"  then reg.RST := reg.A;
    elsif RELATION_RST="Y"  then reg.RST := reg.B;
    elsif RELATION_RST="Z"  then reg.RST := reg.C;
    else  reg.RST := 0; end if;
    -- Accu clear control signal delay compensation
    if    RELATION_CLR="X"  then reg.CLR := reg.A;
    elsif RELATION_CLR="Y"  then reg.CLR := reg.B;
    elsif RELATION_CLR="Z"  then reg.CLR := reg.C;
    else  reg.CLR := 0; end if;
    -- Product negation control signal delay compensation
    if    RELATION_NEG="X" then reg.NEG := reg.A;
    elsif RELATION_NEG="Y" then reg.NEG := reg.B;
    else  reg.NEG := 0; end if;
    return reg;
  end function;
  constant LOGICREG : t_logicreg := GET_NUM_LOGIC_REG;

  function RELATION_CLR_ABC return string is
  begin
    if    RELATION_CLR="X"  then return "A";
    elsif RELATION_CLR="Y"  then return "B";
    elsif RELATION_CLR="Z"  then return "C";
    else  return "INVALID";
    end if;
  end function;

  -- Number of overall summands that contribute to the DSP internal accumulation/output register P
  -- * Chain and Z inputs and product itself
  -- * Factor 2 because each complex summand contributes with 2 single summands
  constant NUM_SUMMAND : natural := (NUM_SUMMAND_CHAININ + NUM_SUMMAND_Z + 1) * 2 * NUM_ACCU_CYCLES;

  -- derived constants
  constant ROUND_ENABLE : boolean := OUTPUT_ROUND and (OUTPUT_SHIFT_RIGHT/=0);
  constant PRODUCT_WIDTH : natural := x_re'length + y_re'length;
  constant MAX_GUARD_BITS : natural := ACCU_WIDTH - PRODUCT_WIDTH;
  constant GUARD_BITS_EVAL : natural := accu_guard_bits(NUM_SUMMAND,MAX_GUARD_BITS,CHOICE);
  constant ACCU_USED_WIDTH : natural := PRODUCT_WIDTH + GUARD_BITS_EVAL;
  constant ACCU_USED_SHIFTED_WIDTH : natural := ACCU_USED_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result_re'length;

  -- OPMODE control signal
  signal opmode : std_logic_vector(8 downto 0);

  -- ALUMODE control signal
  signal alumode : std_logic_vector(3 downto 0);

  signal dsp_rst   : std_logic;
  signal dsp_clr   : std_logic;
  signal dsp_neg   : std_logic;
  signal dsp_a_vld : std_logic;
  signal dsp_b_vld : std_logic;
  signal dsp_c_vld : std_logic;
  signal dsp_a_conj : std_logic;
  signal dsp_b_conj : std_logic;
  signal a_conj : std_logic;
  signal b_conj : std_logic;

  signal a_re : signed(x_re'length-1 downto 0);
  signal b_re : signed(y_re'length-1 downto 0);
  signal dsp_a_re : signed(INPUT_WIDTH-1 downto 0);
  signal dsp_b_re : signed(INPUT_WIDTH-1 downto 0);
  signal dsp_c_re : signed(z_re'length-1 downto 0);
  signal dsp_a_im : signed(x_im'length-1 downto 0);
  signal dsp_b_im : signed(y_im'length-1 downto 0);
  signal dsp_c_im : signed(z_im'length-1 downto 0);

  signal dsp_d_re : signed(1 downto 0); -- dummy
  signal dsp_d_im : signed(1 downto 0); -- dummy

  signal p_change, p_round, pcout_vld : std_logic;

  signal chainin_re_i, chainout_re_i : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal chainin_im_i, chainout_im_i : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal dsp_ofl_re, dsp_ofl_im : std_logic;
  signal dsp_ufl_re, dsp_ufl_im : std_logic;

  signal accu_re, accu_im : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal accu_vld : std_logic := '0';
  signal accu_rnd : std_logic := '0';
  signal accu_rst : std_logic := '0';
  signal accu_used_re, accu_used_im : signed(ACCU_USED_WIDTH-1 downto 0);

  signal clr_i : std_logic := '0';

 begin

  assert (DSPREG.M=1)
    report complex_mult1add1'INSTANCE_NAME & CHOICE &
           "DSP internal pipeline register after multiplier is disabled. FIX: use at least two input registers at ports X and Y."
    severity warning;

  assert (x_re'length<=INPUT_WIDTH and x_im'length<=INPUT_WIDTH)
    report complex_mult1add1'INSTANCE_NAME & CHOICE &
           "Multiplier input X width cannot exceed " & integer'image(INPUT_WIDTH)
    severity failure;

  assert (y_re'length<=INPUT_WIDTH and y_im'length<=INPUT_WIDTH)
    report complex_mult1add1'INSTANCE_NAME & CHOICE &
           "Multiplier input Y width cannot exceed " & integer'image(INPUT_WIDTH)
    severity failure;

  assert (z_re'length<=MAX_WIDTH_C and z_im'length<=MAX_WIDTH_C)
    report complex_mult1add1'INSTANCE_NAME & CHOICE &
           "Summand input Z width cannot exceed " & integer'image(MAX_WIDTH_C)
    severity failure;

  assert (NUM_INPUT_REG_X=NUM_INPUT_REG_Y)
    report complex_mult1add1'INSTANCE_NAME & CHOICE &
           "For now the number of input registers in X and Y path must be the same."
    severity failure;

  assert GUARD_BITS_EVAL<=MAX_GUARD_BITS
    report complex_mult1add1'INSTANCE_NAME & CHOICE &
           "Maximum number of accumulator bits is " & integer'image(ACCU_WIDTH) & " ." &
           "Input bit widths allow only maximum number of guard bits = " & integer'image(MAX_GUARD_BITS)
    severity failure;

  assert OUTPUT_WIDTH<ACCU_USED_SHIFTED_WIDTH or not(OUTPUT_CLIP or OUTPUT_OVERFLOW)
    report complex_mult1add1'INSTANCE_NAME & CHOICE &
           "More guard bits required for saturation/clipping and/or overflow detection." &
           "  OUTPUT_WIDTH="            & integer'image(OUTPUT_WIDTH) &
           ", ACCU_USED_SHIFTED_WIDTH=" & integer'image(ACCU_USED_SHIFTED_WIDTH) &
           ", OUTPUT_CLIP="             & boolean'image(OUTPUT_CLIP) &
           ", OUTPUT_OVERFLOW="         & boolean'image(OUTPUT_OVERFLOW)
    severity failure;

  clr_i <= clr when NUM_ACCU_CYCLES>=2 else '0';

  i_feed_re : entity work.xilinx_input_pipe
  generic map(
    PIPEREGS_RST     => LOGICREG.RST,
    PIPEREGS_CLR     => LOGICREG.CLR,
    PIPEREGS_NEG     => LOGICREG.NEG,
    PIPEREGS_A       => LOGICREG.A,
    PIPEREGS_B       => LOGICREG.B,
    PIPEREGS_C       => LOGICREG.C,
    PIPEREGS_D       => LOGICREG.D
  )
  port map(
    clk       => clk,
    srst      => open, -- unused
    clkena    => clkena,
    src_rst   => rst,
    src_clr   => clr_i,
    src_neg   => neg_i,
    src_a_vld => x_vld,
    src_b_vld => y_vld,
    src_c_vld => z_vld,
    src_d_vld => open,
    src_a_neg => x_conj_i,
    src_d_neg => open,
    src_a     => x_re,
    src_b     => y_re,
    src_c     => z_re,
    src_d     => "00", -- unused
    dsp_rst   => dsp_rst,
    dsp_clr   => dsp_clr,
    dsp_neg   => dsp_neg,
    dsp_a_vld => dsp_a_vld,
    dsp_b_vld => dsp_b_vld,
    dsp_c_vld => dsp_c_vld,
    dsp_d_vld => open, -- unused
    dsp_a_neg => a_conj,
    dsp_d_neg => open,
    dsp_a     => a_re,
    dsp_b     => b_re,
    dsp_c     => dsp_c_re,
    dsp_d     => dsp_d_re
  );

  i_feed_im : entity work.xilinx_input_pipe
  generic map(
    PIPEREGS_RST     => LOGICREG.RST,
    PIPEREGS_CLR     => LOGICREG.CLR,
    PIPEREGS_NEG     => LOGICREG.B, -- misused for y_conj signal delay
    PIPEREGS_A       => LOGICREG.A,
    PIPEREGS_B       => LOGICREG.B,
    PIPEREGS_C       => LOGICREG.C,
    PIPEREGS_D       => LOGICREG.D
  )
  port map(
    clk       => clk,
    srst      => open, -- unused
    clkena    => clkena,
    src_rst   => rst,
    src_clr   => clr_i,
    src_neg   => y_conj_i,
    src_a_vld => x_vld,
    src_b_vld => y_vld,
    src_c_vld => z_vld,
    src_d_vld => open,
    src_a_neg => open,
    src_d_neg => open,
    src_a     => x_im,
    src_b     => y_im,
    src_c     => z_im,
    src_d     => "00", -- unused
    dsp_rst   => open,
    dsp_clr   => open,
    dsp_neg   => b_conj,
    dsp_a_vld => open,
    dsp_b_vld => open,
    dsp_c_vld => open,
    dsp_d_vld => open,
    dsp_a_neg => open,
    dsp_d_neg => open,
    dsp_a     => dsp_a_im,
    dsp_b     => dsp_b_im,
    dsp_c     => dsp_c_im,
    dsp_d     => dsp_d_im
  );


  -- Negate port A because NEG and A_RE are synchronous.
  g_neg_a : if RELATION_NEG="X" generate
    constant re_max : signed(INPUT_WIDTH-1 downto 0) := to_signed(2**(INPUT_WIDTH-1)-1,INPUT_WIDTH);
    constant re_min : signed(INPUT_WIDTH-1 downto 0) := not re_max;
    signal re : signed(INPUT_WIDTH-1 downto 0);
  begin
    -- Includes clipping to most positive value when most negative value is negated.
    re <= resize(a_re,INPUT_WIDTH);
    dsp_a_re <= re_max when (a_re'length=INPUT_WIDTH and dsp_neg='1' and re=re_min) else -re when dsp_neg='1' else re;
    dsp_a_conj <= dsp_neg xor a_conj;
    -- pass through port B
    dsp_b_re <= resize(b_re,dsp_b_re'length);
    dsp_b_conj <= b_conj;
  end generate;

  -- Negate port B because NEG and B_RE are synchronous.
  g_neg_b : if RELATION_NEG="Y" generate
    constant re_max : signed(INPUT_WIDTH-1 downto 0) := to_signed(2**(INPUT_WIDTH-1)-1,INPUT_WIDTH);
    constant re_min : signed(INPUT_WIDTH-1 downto 0) := not re_max;
    signal re : signed(INPUT_WIDTH-1 downto 0);
  begin
    -- Includes clipping to most positive value when most negative value is negated.
    re <= resize(b_re,INPUT_WIDTH);
    dsp_b_re <= re_max when (b_re'length=INPUT_WIDTH and dsp_neg='1' and re=re_min) else -re when dsp_neg='1' else re;
    dsp_b_conj <= dsp_neg xor b_conj;
    -- pass through port A
    dsp_a_re <= resize(a_re,dsp_a_re'length);
    dsp_a_conj <= a_conj;
  end generate;

  i_mode : entity work.xilinx_mode_logic
  generic map(
    USE_ACCU     => (NUM_ACCU_CYCLES>=2),
    USE_PREADDER => open, -- unused
    ENABLE_ROUND => ROUND_ENABLE,
    NUM_AREG     => DSPREG.A,
    NUM_BREG     => DSPREG.B,
    NUM_CREG     => DSPREG.C,
    NUM_DREG     => DSPREG.D, -- irrelevant
    NUM_ADREG    => 0, -- AD register does not contribute to input delay! (see AM004 v1.2.1, Table 22)
    NUM_MREG     => DSPREG.M,
    RELATION_CLR => RELATION_CLR_ABC
  )
  port map(
    clk       => clk,
    rst       => dsp_rst,
    clkena    => clkena,
    clr       => dsp_clr,
    neg       => open, -- unused
    a_neg     => open, -- unused
    a_vld     => dsp_a_vld,
    b_vld     => dsp_b_vld,
    c_vld     => dsp_c_vld,
    d_vld     => open, -- unused
    pcin_vld  => chainin_re_vld,  -- TODO: chainin_valid
    negate    => open, -- unused
    inmode    => open, -- unused
    opmode    => opmode,
    alumode   => alumode,
    p_change  => p_change,
    p_round   => p_round,
    pcout_vld => pcout_vld
  );

  -- use only LSBs of chain input
  chainin_re_i <= std_logic_vector(chainin_re(ACCU_WIDTH-1 downto 0));
  chainin_im_i <= std_logic_vector(chainin_im(ACCU_WIDTH-1 downto 0));

  i_dspcplx : unisim.VCOMPONENTS.DSPCPLX
  generic map(
     ACASCREG_IM                  => 1, -- integer := 1;
     ACASCREG_RE                  => 1, -- integer := 1;
     ADREG                        => DSPREG.AD,
     ALUMODEREG_IM                => DSPREG.ALUMODE,
     ALUMODEREG_RE                => DSPREG.ALUMODE,
     AREG_IM                      => DSPREG.A, -- integer := 2;
     AREG_RE                      => DSPREG.A, -- integer := 2;
     AUTORESET_PATDET_IM          => "NO_RESET", -- string := "NO_RESET";
     AUTORESET_PATDET_RE          => "NO_RESET", -- string := "NO_RESET";
     AUTORESET_PRIORITY_IM        => "RESET", -- string := "RESET";
     AUTORESET_PRIORITY_RE        => "RESET", -- string := "RESET";
     A_INPUT_IM                   => "DIRECT", -- string := "DIRECT";
     A_INPUT_RE                   => "DIRECT", -- string := "DIRECT";
     BCASCREG_IM                  => 1, -- integer := 1;
     BCASCREG_RE                  => 1, -- integer := 1;
     BREG_IM                      => DSPREG.B, -- integer := 2;
     BREG_RE                      => DSPREG.B, -- integer := 2;
     B_INPUT_IM                   => "DIRECT", -- string := "DIRECT";
     B_INPUT_RE                   => "DIRECT", -- string := "DIRECT";
     CARRYINREG_IM                => 1, -- integer := 1;
     CARRYINREG_RE                => 1, -- integer := 1;
     CARRYINSELREG_IM             => 1, -- integer := 1;
     CARRYINSELREG_RE             => 1, -- integer := 1;
     CONJUGATEREG_A               => DSPREG.INMODE,
     CONJUGATEREG_B               => DSPREG.INMODE,
     CREG_IM                      => DSPREG.C, -- integer := 1;
     CREG_RE                      => DSPREG.C, -- integer := 1;
     IS_ALUMODE_IM_INVERTED       => (others=>'0'), -- std_logic_vector(3 downto 0) := "0000";
     IS_ALUMODE_RE_INVERTED       => (others=>'0'), -- std_logic_vector(3 downto 0) := "0000";
     IS_ASYNC_RST_INVERTED        => '0', -- bit := '0';
     IS_CARRYIN_IM_INVERTED       => '0', -- bit := '0';
     IS_CARRYIN_RE_INVERTED       => '0', -- bit := '0';
     IS_CLK_INVERTED              => '0', -- bit := '0';
     IS_CONJUGATE_A_INVERTED      => '0', -- bit := '0';
     IS_CONJUGATE_B_INVERTED      => '0', -- bit := '0';
     IS_OPMODE_IM_INVERTED        => (others=>'0'), -- std_logic_vector(8 downto 0) := "000000000";
     IS_OPMODE_RE_INVERTED        => (others=>'0'), -- std_logic_vector(8 downto 0) := "000000000";
     IS_RSTAD_INVERTED            => '0', -- bit := '0';
     IS_RSTALLCARRYIN_IM_INVERTED => '0', -- bit := '0';
     IS_RSTALLCARRYIN_RE_INVERTED => '0', -- bit := '0';
     IS_RSTALUMODE_IM_INVERTED    => '0', -- bit := '0';
     IS_RSTALUMODE_RE_INVERTED    => '0', -- bit := '0';
     IS_RSTA_IM_INVERTED          => '0', -- bit := '0';
     IS_RSTA_RE_INVERTED          => '0', -- bit := '0';
     IS_RSTB_IM_INVERTED          => '0', -- bit := '0';
     IS_RSTB_RE_INVERTED          => '0', -- bit := '0';
     IS_RSTCONJUGATE_A_INVERTED   => '0', -- bit := '0';
     IS_RSTCONJUGATE_B_INVERTED   => '0', -- bit := '0';
     IS_RSTCTRL_IM_INVERTED       => '0', -- bit := '0';
     IS_RSTCTRL_RE_INVERTED       => '0', -- bit := '0';
     IS_RSTC_IM_INVERTED          => '0', -- bit := '0';
     IS_RSTC_RE_INVERTED          => '0', -- bit := '0';
     IS_RSTM_IM_INVERTED          => '0', -- bit := '0';
     IS_RSTM_RE_INVERTED          => '0', -- bit := '0';
     IS_RSTP_IM_INVERTED          => '0', -- bit := '0';
     IS_RSTP_RE_INVERTED          => '0', -- bit := '0';
     MASK_IM                      => (others=>'0'), -- std_logic_vector(57 downto 0) := "00" & X"FFFFFFFFFFFFFF";
     MASK_RE                      => (others=>'0'), -- std_logic_vector(57 downto 0) := "00" & X"FFFFFFFFFFFFFF";
     MREG_IM                      => DSPREG.M,
     MREG_RE                      => DSPREG.M,
     OPMODEREG_IM                 => DSPREG.OPMODE,
     OPMODEREG_RE                 => DSPREG.OPMODE,
     PATTERN_IM                   => (others=>'0'), -- std_logic_vector(57 downto 0) := "00" & X"00000000000000";
     PATTERN_RE                   => (others=>'0'), -- std_logic_vector(57 downto 0) := "00" & X"00000000000000";
     PREG_IM                      => 1, -- always used
     PREG_RE                      => 1, -- always used
     RESET_MODE                   => "SYNC", -- string := "SYNC";
     RND_IM                       => RND(ROUND_ENABLE,OUTPUT_SHIFT_RIGHT), -- Rounding Constant
     RND_RE                       => RND(ROUND_ENABLE,OUTPUT_SHIFT_RIGHT), -- Rounding Constant
     SEL_MASK_IM                  => "MASK", -- string := "MASK";
     SEL_MASK_RE                  => "MASK", -- string := "MASK";
     SEL_PATTERN_IM               => "PATTERN", -- string := "PATTERN";
     SEL_PATTERN_RE               => "PATTERN", -- string := "PATTERN";
     USE_PATTERN_DETECT_IM        => "NO_PATDET", -- string := "NO_PATDET";
     USE_PATTERN_DETECT_RE        => "NO_PATDET"  -- string := "NO_PATDET"
  )
  port map(
     ACOUT_IM          => open, -- out std_logic_vector(17 downto 0);
     ACOUT_RE          => open, -- out std_logic_vector(17 downto 0);
     BCOUT_IM          => open, -- out std_logic_vector(17 downto 0);
     BCOUT_RE          => open, -- out std_logic_vector(17 downto 0);
     CARRYCASCOUT_IM   => open, -- out std_ulogic;
     CARRYCASCOUT_RE   => open, -- out std_ulogic;
     CARRYOUT_IM       => open, -- out std_ulogic;
     CARRYOUT_RE       => open, -- out std_ulogic;
     MULTSIGNOUT_IM    => open, -- out std_ulogic;
     MULTSIGNOUT_RE    => open, -- out std_ulogic;
     OVERFLOW_IM       => dsp_ofl_im, -- out std_ulogic;
     OVERFLOW_RE       => dsp_ofl_re, -- out std_ulogic;
     PATTERNBDETECT_IM => open, -- out std_ulogic;
     PATTERNBDETECT_RE => open, -- out std_ulogic;
     PATTERNDETECT_IM  => open, -- out std_ulogic;
     PATTERNDETECT_RE  => open, -- out std_ulogic;
     PCOUT_IM          => chainout_im_i, -- out std_logic_vector(57 downto 0);
     PCOUT_RE          => chainout_re_i, -- out std_logic_vector(57 downto 0);
     P_IM              => accu_im, -- out std_logic_vector(57 downto 0);
     P_RE              => accu_re, -- out std_logic_vector(57 downto 0);
     UNDERFLOW_IM      => dsp_ufl_im, -- out std_ulogic;
     UNDERFLOW_RE      => dsp_ufl_re, -- out std_ulogic;
     ACIN_IM           => (others=>'0'), -- unused;
     ACIN_RE           => (others=>'0'), -- unused;
     ALUMODE_IM        => alumode, -- in std_logic_vector(3 downto 0);
     ALUMODE_RE        => alumode, -- in std_logic_vector(3 downto 0);
     ASYNC_RST         => '0', -- unused
     A_IM              => std_logic_vector(resize(dsp_a_im,INPUT_WIDTH)),
     A_RE              => std_logic_vector(resize(dsp_a_re,INPUT_WIDTH)),
     BCIN_IM           => (others=>'0'), -- unused
     BCIN_RE           => (others=>'0'), -- unused
     B_IM              => std_logic_vector(resize(dsp_b_im,INPUT_WIDTH)),
     B_RE              => std_logic_vector(resize(dsp_b_re,INPUT_WIDTH)),
     CARRYCASCIN_IM    => '0', -- unused
     CARRYCASCIN_RE    => '0', -- unused
     CARRYINSEL_IM     => (others=>'0'), -- unused
     CARRYINSEL_RE     => (others=>'0'), -- unused
     CARRYIN_IM        => '0', -- unused
     CARRYIN_RE        => '0', -- unused
     CEA1_IM           => CE(clkena,DSPREG.A),
     CEA1_RE           => CE(clkena,DSPREG.A),
     CEA2_IM           => CE(clkena,DSPREG.A),
     CEA2_RE           => CE(clkena,DSPREG.A),
     CEAD              => CE(clkena,DSPREG.AD),
     CEALUMODE_IM      => CE(clkena,DSPREG.ALUMODE),
     CEALUMODE_RE      => CE(clkena,DSPREG.ALUMODE),
     CEB1_IM           => CE(clkena,DSPREG.B),
     CEB1_RE           => CE(clkena,DSPREG.B),
     CEB2_IM           => CE(clkena,DSPREG.B),
     CEB2_RE           => CE(clkena,DSPREG.B),
     CECARRYIN_IM      => '0', -- unused
     CECARRYIN_RE      => '0', -- unused
     CECONJUGATE_A     => CE(clkena,DSPREG.INMODE),
     CECONJUGATE_B     => CE(clkena,DSPREG.INMODE),
     CECTRL_IM         => CE(clkena,DSPREG.OPMODE),
     CECTRL_RE         => CE(clkena,DSPREG.OPMODE),
     CEC_IM            => CE(clkena,DSPREG.C),
     CEC_RE            => CE(clkena,DSPREG.C),
     CEM_IM            => CE(clkena,DSPREG.M),
     CEM_RE            => CE(clkena,DSPREG.M),
     CEP_IM            => CE(clkena and p_change,1), -- accumulate/output only valid values
     CEP_RE            => CE(clkena and p_change,1), -- accumulate/output only valid values
     CLK               => clk,
     CONJUGATE_A       => dsp_a_conj,
     CONJUGATE_B       => dsp_b_conj,
     C_IM              => std_logic_vector(resize(dsp_c_im,MAX_WIDTH_C)),
     C_RE              => std_logic_vector(resize(dsp_c_re,MAX_WIDTH_C)),
     MULTSIGNIN_IM     => '0', -- unused
     MULTSIGNIN_RE     => '0', -- unused
     OPMODE_IM         => opmode,
     OPMODE_RE         => opmode,
     PCIN_IM           => chainin_im_i, -- in std_logic_vector(57 downto 0);
     PCIN_RE           => chainin_re_i, -- in std_logic_vector(57 downto 0);
     RSTAD             => dsp_rst,
     RSTALLCARRYIN_IM  => '1', -- unused
     RSTALLCARRYIN_RE  => '1', -- unused
     RSTALUMODE_IM     => dsp_rst,
     RSTALUMODE_RE     => dsp_rst,
     RSTA_IM           => dsp_rst,
     RSTA_RE           => dsp_rst,
     RSTB_IM           => dsp_rst,
     RSTB_RE           => dsp_rst,
     RSTCONJUGATE_A    => dsp_rst,
     RSTCONJUGATE_B    => dsp_rst,
     RSTCTRL_IM        => dsp_rst,
     RSTCTRL_RE        => dsp_rst,
     RSTC_IM           => dsp_rst,
     RSTC_RE           => dsp_rst,
     RSTM_IM           => dsp_rst,
     RSTM_RE           => dsp_rst,
     RSTP_IM           => dsp_rst,
     RSTP_RE           => dsp_rst 
  );

  chainout_re<= resize(signed(chainout_re_i),chainout_re'length);
  chainout_im<= resize(signed(chainout_im_i),chainout_im'length);
  chainout_re_vld <= pcout_vld; -- TODO: chainout_valid
  chainout_im_vld <= pcout_vld; -- TODO: chainout_valid

  -- pipelined output valid signal
  p_clk : process(clk)
  begin
    if rising_edge(clk) then
      if dsp_rst/='0' then
        accu_vld <= '0';
        accu_rnd <= '0';
      elsif clkena='1' then
        accu_vld <= pcout_vld;
        accu_rnd <= p_round;
      end if; --reset
      accu_rst <= dsp_rst;
    end if; --clock
  end process;

  -- cut off unused sign extension bits
  -- (This reduces the logic consumption in the following steps when rounding,
  --  saturation and/or overflow detection is enabled.)
  accu_used_re <= signed(accu_re(ACCU_USED_WIDTH-1 downto 0));
  accu_used_im <= signed(accu_im(ACCU_USED_WIDTH-1 downto 0));

  -- Right-shift and clipping
  -- Rounding is also done here when not possible within DSP cell.
  i_out_re : entity work.xilinx_output_logic
  generic map(
    PIPELINE_STAGES    => NUM_OUTPUT_REG-1,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_CLIP        => OUTPUT_CLIP,
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
  )
  port map (
    clk         => clk,
    rst         => accu_rst,
    clkena      => clkena,
    dsp_out     => accu_used_re,
    dsp_out_vld => accu_vld,
    dsp_out_ovf => (dsp_ufl_re or dsp_ofl_re),
    dsp_out_rnd => accu_rnd,
    result      => result_re,
    result_vld  => result_vld,
    result_ovf  => result_ovf_re,
    result_rst  => result_rst
  );

  -- Right-shift and clipping
  -- Rounding is also done here when not possible within DSP cell.
  i_out_im : entity work.xilinx_output_logic
  generic map(
    PIPELINE_STAGES    => NUM_OUTPUT_REG-1,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_CLIP        => OUTPUT_CLIP,
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
  )
  port map (
    clk         => clk,
    rst         => accu_rst,
    clkena      => clkena,
    dsp_out     => accu_used_im,
    dsp_out_vld => accu_vld,
    dsp_out_ovf => (dsp_ufl_im or dsp_ofl_im),
    dsp_out_rnd => accu_rnd,
    result      => result_im,
    result_vld  => open, -- same as real
    result_ovf  => result_ovf_im,
    result_rst  => open  -- same as real
  );

  -- report constant number of pipeline register stages
  PIPESTAGES <= NUM_INPUT_REG_X + NUM_OUTPUT_REG;

 end generate G2DSP;

end architecture;
