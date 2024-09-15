-------------------------------------------------------------------------------
--! @file       complex_macc_chain.dsp58.vhdl
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
library baselib;
  use baselib.ieee_extension_types.all;

use work.xilinx_dsp_pkg_dsp58.all;

-- N complex multiplications and sum of all product results.
--
architecture dsp58 of complex_macc_chain is

  constant X_INPUT_WIDTH   : positive := maximum(x_re(0)'length,x_im(0)'length);
  constant Y_INPUT_WIDTH   : positive := maximum(y_re(0)'length,y_im(0)'length);
  constant MAX_INPUT_WIDTH : positive := maximum(X_INPUT_WIDTH,Y_INPUT_WIDTH);

  constant RELATION_RST : string := "X"; -- TODO : RELATION_RST
  constant RELATION_CLR : string := "X"; -- TODO : RELATION_CLR
  constant RELATION_NEG : string := "X"; -- TODO : RELATION_NEG

  constant NUM_INPUT_REG_X : natural := NUM_INPUT_REG_XY;
  constant NUM_INPUT_REG_Y : natural := NUM_INPUT_REG_XY;

  function OUTREGS(i:natural) return natural is begin
    if i<(NUM_MULT-1) then return 0; else return NUM_OUTPUT_REG; end if;
  end function;

  signal result_re_i : signed_vector(0 to NUM_MULT-1)(result_re'length-1 downto 0);
  signal result_im_i : signed_vector(0 to NUM_MULT-1)(result_im'length-1 downto 0);
  signal result_vld_i : std_logic_vector(0 to NUM_MULT-1);
  signal result_rst_i : std_logic_vector(0 to NUM_MULT-1);
  signal result_ovf_re_i : std_logic_vector(0 to NUM_MULT-1);
  signal result_ovf_im_i : std_logic_vector(0 to NUM_MULT-1);
  signal pipestages_i : integer_vector(0 to NUM_MULT-1);

  signal chainin_re  : signed_vector(0 to NUM_MULT)(79 downto 0);
  signal chainin_im  : signed_vector(0 to NUM_MULT)(79 downto 0);
  signal chainin_re_vld : std_logic_vector(0 to NUM_MULT);
  signal chainin_im_vld : std_logic_vector(0 to NUM_MULT);

 begin

  -- dummy chain input
  chainin_re(0) <= (others=>'0');
  chainin_im(0) <= (others=>'0');
  chainin_re_vld(0) <= '0';
  chainin_im_vld(0) <= '0';


 --------------------------------------------------------------------------------------------------
 -- Complex multiplier chain with with 4 DSP cells per complex multiplication
 --
 -- Notes
 -- * Z input is always possible
 -- * Chain input is always possible
 -- * round bit and accumulate in addition to Z and chain input is possible
 -- * TODO : also allows complex preadder => different entity complex_preadd_macc !?
 --------------------------------------------------------------------------------------------------
 CPLX4DSP_CHAIN : if OPTIMIZATION="PERFORMANCE" or OPTIMIZATION="CPLX4DSP" generate
  -- identifier for reports of warnings and errors
  constant CHOICE : string := "(optimization=PERFORMANCE, N*4 DSPs):: ";
 begin

  assert (NUM_INPUT_REG_X>=1 and NUM_INPUT_REG_Y>=1)
    report complex_macc_chain'instance_name & CHOICE &
           "For high-speed the X and Y paths should have at least one additional input register."
    severity warning;

  LINK : for n in 0 to NUM_MULT-1 generate
    -- Round bit addition is only required when rounding is enabled.
    -- * USE_ACCU=false : add round bit (every cycle) in first chain link where chain input is unused
    -- * USE_ACCU=true  : add round bit (with clr=1) in last chain link where the accumulator register is located
    constant ADD_ROUND_BIT : boolean := OUTPUT_ROUND and 
                                      ( (n=(NUM_MULT-1) and USE_ACCU) or (n=0 and not USE_ACCU) );
  begin

    cmacc : entity work.complex_mult1add1(dsp58)
    generic map(
      OPTIMIZATION       => "PERFORMANCE",
      USE_ACCU           => (USE_ACCU and (n=(NUM_MULT-1))),
      NUM_SUMMAND        => 2*NUM_MULT, -- TODO : NUM_SUMMAND
      USE_NEGATION       => USE_NEGATION,
      USE_CONJUGATE_X    => USE_CONJUGATE_X,
      USE_CONJUGATE_Y    => USE_CONJUGATE_Y,
      NUM_INPUT_REG_XY   => 1 + NUM_INPUT_REG_XY + 2*n, -- minimum one input register
      NUM_INPUT_REG_Z    => 1 + NUM_INPUT_REG_Z  + 2*n, -- minimum one input register
      RELATION_RST       => RELATION_RST,
      RELATION_CLR       => RELATION_CLR,
      RELATION_NEG       => RELATION_NEG,
      NUM_OUTPUT_REG     => 1 + OUTREGS(n), -- at least the DSP internal output register
      OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
      OUTPUT_ROUND       => ADD_ROUND_BIT,
      OUTPUT_CLIP        => (OUTPUT_CLIP and (n=(NUM_MULT-1))),
      OUTPUT_OVERFLOW    => (OUTPUT_OVERFLOW and (n=(NUM_MULT-1)))
    )
    port map(
      clk             => clk,
      rst             => rst,
      clkena          => clkena,
      clr             => clr,
      neg             => neg(n),
      x_re            => x_re(n),
      x_im            => x_im(n),
      x_vld           => x_vld(n),
      x_conj          => x_conj(n),
      y_re            => y_re(n),
      y_im            => y_im(n),
      y_vld           => y_vld(n),
      y_conj          => y_conj(n),
      z_re            => z_re(n),
      z_im            => z_im(n),
      z_vld           => z_vld(n),
      result_re       => result_re_i(n),
      result_im       => result_im_i(n),
      result_vld      => result_vld_i(n),
      result_ovf_re   => result_ovf_re_i(n),
      result_ovf_im   => result_ovf_im_i(n),
      result_rst      => result_rst_i(n),
      chainin_re      => chainin_re(n),
      chainin_im      => chainin_im(n),
      chainin_re_vld  => chainin_re_vld(n),
      chainin_im_vld  => chainin_im_vld(n),
      chainout_re     => chainin_re(n+1),
      chainout_im     => chainin_im(n+1),
      chainout_re_vld => chainin_re_vld(n+1),
      chainout_im_vld => chainin_im_vld(n+1),
      PIPESTAGES      => pipestages_i(n)
    );

  end generate LINK;
 end generate CPLX4DSP_CHAIN;

 --------------------------------------------------------------------------------------------------
 -- Complex multiplier chain with with 3 DSP cells per complex multiplication
 --
 -- Notes
 -- * Z input not supported !
 -- * accumulation only supported when NUM_MULT=1 !
 --
 -- If the chain input is used, i.e. when the chainin_vld is connected and not static, then
 -- * accumulation not possible because P feedback must be disabled
 -- * The rounding (i.e. +0.5) not possible within DSP.
 --   But rounding bit can be injected at the first chain link where the chain input is unused.
 --------------------------------------------------------------------------------------------------
 CPLX3DSP_CHAIN : if (OPTIMIZATION="RESOURCES" and MAX_INPUT_WIDTH>18) or OPTIMIZATION="CPLX3DSP" generate
  -- identifier for reports of warnings and errors
  constant CHOICE : string := "(optimization=RESOURCES, N*3 DSPs):: ";
 begin

  assert (NUM_INPUT_REG_X>=1 and NUM_INPUT_REG_Y>=1)
    report complex_macc_chain'instance_name & CHOICE &
           "For high-speed the X and Y paths should have at least one additional input register."
    severity warning;

  assert (NUM_MULT=1 or not USE_ACCU)
    report complex_macc_chain'instance_name & CHOICE &
           "Selected optimization with NUM_MULT>=2 does not allow accumulation. Ignoring CLR input port."
    severity warning;

  LINK : for n in 0 to NUM_MULT-1 generate
    -- Round bit addition is only required when rounding is enabled.
    -- * USE_ACCU=false : add round bit (every cycle) in first chain link where chain input is unused
    -- * USE_ACCU=true  : add round bit (with clr=1) only possible when NUM_MULT=1
    constant ADD_ROUND_BIT : boolean := OUTPUT_ROUND and 
                                      ( (NUM_MULT=1 and USE_ACCU) or (n=0 and not USE_ACCU) );
  begin

    cmacc : entity work.complex_mult1add1(dsp58)
    generic map(
      OPTIMIZATION       => "RESOURCES",
      USE_ACCU           => (USE_ACCU and NUM_MULT=1),
      NUM_SUMMAND        => 2*NUM_MULT, -- TODO : NUM_SUMMAND
      USE_NEGATION       => USE_NEGATION,
      USE_CONJUGATE_X    => USE_CONJUGATE_X,
      USE_CONJUGATE_Y    => USE_CONJUGATE_Y,
      NUM_INPUT_REG_XY   => 1 + NUM_INPUT_REG_XY + n, -- minimum one input register
      NUM_INPUT_REG_Z    => 1 + NUM_INPUT_REG_Z, -- here to configure internal pipeline register, minimum one register required
      RELATION_RST       => RELATION_RST,
      RELATION_CLR       => RELATION_CLR,
      RELATION_NEG       => RELATION_NEG,
      NUM_OUTPUT_REG     => 1 + OUTREGS(n), -- at least the DSP internal output register
      OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
      OUTPUT_ROUND       => ADD_ROUND_BIT,
      OUTPUT_CLIP        => (OUTPUT_CLIP and (n=(NUM_MULT-1))),
      OUTPUT_OVERFLOW    => (OUTPUT_OVERFLOW and (n=(NUM_MULT-1)))
    )
    port map(
      clk             => clk,
      rst             => rst,
      clkena          => clkena,
      clr             => clr,
      neg             => neg(n),
      x_re            => x_re(n),
      x_im            => x_im(n),
      x_vld           => x_vld(n),
      x_conj          => x_conj(n),
      y_re            => y_re(n),
      y_im            => y_im(n),
      y_vld           => y_vld(n),
      y_conj          => y_conj(n),
      z_re            => z_re(n),
      z_im            => z_im(n),
      z_vld           => z_vld(n),
      result_re       => result_re_i(n),
      result_im       => result_im_i(n),
      result_vld      => result_vld_i(n),
      result_ovf_re   => result_ovf_re_i(n),
      result_ovf_im   => result_ovf_im_i(n),
      result_rst      => result_rst_i(n),
      chainin_re      => chainin_re(n),
      chainin_im      => chainin_im(n),
      chainin_re_vld  => chainin_re_vld(n),
      chainin_im_vld  => chainin_im_vld(n),
      chainout_re     => chainin_re(n+1),
      chainout_im     => chainin_im(n+1),
      chainout_re_vld => chainin_re_vld(n+1),
      chainout_im_vld => chainin_im_vld(n+1),
      PIPESTAGES      => pipestages_i(n)
    );

  end generate LINK;
 end generate CPLX3DSP_CHAIN;


 --------------------------------------------------------------------------------------------------
 -- Complex multiplier chain with with 2 DSP cells per complex multiplication
 --
 -- Notes
 -- * last Z input in chain not supported, when accumulation is required !
 -- * factor inputs X and Y are limited to 2x18 bits
 --------------------------------------------------------------------------------------------------
 CPLX2DSP_CHAIN : if (OPTIMIZATION="RESOURCES" and MAX_INPUT_WIDTH<=18) or OPTIMIZATION="CPLX2DSP" generate
  -- identifier for reports of warnings and errors
  constant CHOICE : string := "(optimization=RESOURCES, N*2 DSPs):: ";
 begin

  assert (NUM_INPUT_REG_X>=1 and NUM_INPUT_REG_Y>=1)
    report complex_macc_chain'instance_name & CHOICE &
           "For high-speed the X and Y paths should have at least one additional input register."
    severity warning;

  assert (MAX_INPUT_WIDTH<=18)
    report complex_macc_chain'instance_name & CHOICE &
           "Multiplier input X and Y width cannot exceed 18 bits."
    severity failure;

  LINK : for n in 0 to NUM_MULT-1 generate
    -- Round bit addition is only required when rounding is enabled.
    -- * USE_ACCU=false : add round bit (every cycle) in first chain link where chain input is unused
    -- * USE_ACCU=true  : add round bit (with clr=1) in last chain link where the accumulator register is located
    constant ADD_ROUND_BIT : boolean := OUTPUT_ROUND and 
                                      ( (n=(NUM_MULT-1) and USE_ACCU) or (n=0 and not USE_ACCU) );
  begin

  cmacc : entity work.complex_mult1add1(dsp58)
  generic map(
    OPTIMIZATION       => "RESOURCES",
    USE_ACCU           => (USE_ACCU and (n=(NUM_MULT-1))),
    NUM_SUMMAND        => 2*NUM_MULT, -- TODO : NUM_SUMMAND
    USE_NEGATION       => USE_NEGATION,
    USE_CONJUGATE_X    => USE_CONJUGATE_X,
    USE_CONJUGATE_Y    => USE_CONJUGATE_Y,
    NUM_INPUT_REG_XY   => 1 + NUM_INPUT_REG_XY + n, -- minimum one input register
    NUM_INPUT_REG_Z    => 1 + NUM_INPUT_REG_Z  + n, -- minimum one input register
    RELATION_RST       => RELATION_RST,
    RELATION_CLR       => RELATION_CLR,
    RELATION_NEG       => RELATION_NEG,
    NUM_OUTPUT_REG     => 1 + OUTREGS(n), -- at least the DSP internal output register
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => ADD_ROUND_BIT,
    OUTPUT_CLIP        => (OUTPUT_CLIP and (n=(NUM_MULT-1))),
    OUTPUT_OVERFLOW    => (OUTPUT_OVERFLOW and (n=(NUM_MULT-1)))
  )
  port map(
    clk             => clk,
    rst             => rst,
    clkena          => clkena,
    clr             => clr,
    neg             => neg(n),
    x_re            => x_re(n),
    x_im            => x_im(n),
    x_vld           => x_vld(n),
    x_conj          => x_conj(n),
    y_re            => y_re(n),
    y_im            => y_im(n),
    y_vld           => y_vld(n),
    y_conj          => y_conj(n),
    z_re            => z_re(n),
    z_im            => z_im(n),
    z_vld           => z_vld(n),
    result_re       => result_re_i(n),
    result_im       => result_im_i(n),
    result_vld      => result_vld_i(n),
    result_ovf_re   => result_ovf_re_i(n),
    result_ovf_im   => result_ovf_im_i(n),
    result_rst      => result_rst_i(n),
    chainin_re      => chainin_re(n),
    chainin_im      => chainin_im(n),
    chainin_re_vld  => chainin_re_vld(n),
    chainin_im_vld  => chainin_im_vld(n),
    chainout_re     => chainin_re(n+1),
    chainout_im     => chainin_im(n+1),
    chainout_re_vld => chainin_re_vld(n+1),
    chainout_im_vld => chainin_im_vld(n+1),
    PIPESTAGES      => pipestages_i(n)
  );

  end generate LINK;
 end generate CPLX2DSP_CHAIN;


  result_re <= result_re_i(NUM_MULT-1);
  result_im <= result_im_i(NUM_MULT-1);
  result_vld <= result_vld_i(NUM_MULT-1);
  result_ovf <= result_ovf_re_i(NUM_MULT-1) or result_ovf_im_i(NUM_MULT-1);
  result_rst <= result_rst_i(NUM_MULT-1);
  PIPESTAGES <= pipestages_i(NUM_MULT-1);

end architecture;

