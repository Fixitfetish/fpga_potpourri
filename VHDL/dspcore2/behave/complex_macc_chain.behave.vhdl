-------------------------------------------------------------------------------
--! @file       complex_macc_chain.behave.vhdl
--! @author     Fixitfetish
--! @date       05/Sep/2024
--! @version    0.21
--! @note       VHDL-1993
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

--! N complex multiplications and sum of all product results.
--!
architecture behave of complex_macc_chain is

  function OUTREGS(i:natural) return natural is begin
    if i<(NUM_MULT-1) then return 1; else return NUM_OUTPUT_REG; end if;
  end function;

  signal result_re_i : signed_vector(0 to NUM_MULT-1)(result_re'length-1 downto 0);
  signal result_im_i : signed_vector(0 to NUM_MULT-1)(result_im'length-1 downto 0);
  signal result_vld_i : std_logic_vector(0 to NUM_MULT-1);
  signal result_ovf_re_i : std_logic_vector(0 to NUM_MULT-1);
  signal result_ovf_im_i : std_logic_vector(0 to NUM_MULT-1);
  signal pipestages_i : integer_vector(0 to NUM_MULT-1);

  signal chainin_re  : signed_vector(0 to NUM_MULT)(79 downto 0);
  signal chainin_im  : signed_vector(0 to NUM_MULT)(79 downto 0);
  signal chainin_vld : std_logic_vector(0 to NUM_MULT);

 begin

  -- dummy chain input
  chainin_re(0) <= (others=>'0');
  chainin_im(0) <= (others=>'0');
  chainin_vld(0) <= '0';

  -- Only the last DSP chain link requires ACCU, output registers, rounding, clipping and overflow detection.
  -- All other DSP chain links do not output anything.
  gn : for n in 0 to NUM_MULT-1 generate
    signal clr_i : std_logic;
  begin

    clr_i <= clr when (USE_ACCU and (n=(NUM_MULT-1))) else '0';

    i_cmacc : entity work.complex_mult1add1(behave)
    generic map(
      USE_ACCU           => (USE_ACCU and (n=(NUM_MULT-1))),
      NUM_SUMMAND        => 2 * NUM_MULT, -- TODO
      USE_NEGATION       => USE_NEGATION,
      USE_CONJUGATE_X    => USE_CONJUGATE_X,
      USE_CONJUGATE_Y    => USE_CONJUGATE_Y,
      NUM_INPUT_REG_XY   => 1 + NUM_INPUT_REG_XY + n, -- minimum one input register
      NUM_INPUT_REG_Z    => 1 + NUM_INPUT_REG_Z  + n, -- minimum one input register
      NUM_OUTPUT_REG     => OUTREGS(n),
      OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
      OUTPUT_ROUND       => (OUTPUT_ROUND and (n=(NUM_MULT-1))),
      OUTPUT_CLIP        => (OUTPUT_CLIP and (n=(NUM_MULT-1))),
      OUTPUT_OVERFLOW    => (OUTPUT_OVERFLOW and (n=(NUM_MULT-1)))
    )
    port map(
      clk           => clk,
      rst           => rst,
      clkena        => clkena,
      clr           => clr_i,
      neg           => neg(n),
      x_re          => x_re(n),
      x_im          => x_im(n),
      x_vld         => x_vld(n),
      x_conj        => x_conj(n),
      y_re          => y_re(n),
      y_im          => y_im(n),
      y_vld         => y_vld(n),
      y_conj        => y_conj(n),
      z_re          => z_re(n),
      z_im          => z_im(n),
      z_vld         => z_vld(n),
      result_re     => result_re_i(n),
      result_im     => result_im_i(n),
      result_vld    => result_vld_i(n),
      result_ovf_re => result_ovf_re_i(n),
      result_ovf_im => result_ovf_im_i(n),
      chainin_re    => chainin_re(n),
      chainin_im    => chainin_im(n),
      chainin_vld   => chainin_vld(n),
      chainout_re   => chainin_re(n+1),
      chainout_im   => chainin_im(n+1),
      chainout_vld  => chainin_vld(n+1),
      PIPESTAGES    => pipestages_i(n)
    );
  end generate;

  result_re <= result_re_i(NUM_MULT-1);
  result_im <= result_im_i(NUM_MULT-1);
  result_vld <= result_vld_i(NUM_MULT-1);
  result_ovf <= result_ovf_re_i(NUM_MULT-1) or result_ovf_im_i(NUM_MULT-1);
  PIPESTAGES <= pipestages_i(NUM_MULT-1);

end architecture;
