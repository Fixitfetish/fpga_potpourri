-------------------------------------------------------------------------------
--! @file       complex_macc_chain.behave.vhdl
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

-- N complex multiplications and sum of all product results.
--
architecture behave of complex_macc_chain is

  -- Accumulator is required in last chain link only
  function ACCU_CYCLES(n:natural) return natural is
  begin
    if n=(NUM_MULT-1) then return NUM_ACCU_CYCLES; else return 1; end if;
  end function;

  -- all Z summands need to be considered in last chain link only
  function SUMMAND_Z(n:natural) return natural is
  begin
    if n=(NUM_MULT-1) then return NUM_SUMMAND_Z; else return 0; end if;
  end function;

  -- Output registers are added in last chain link only
  function OUTREGS(n:natural) return natural is begin
    if n=(NUM_MULT-1) then return NUM_OUTPUT_REG; else return 0; end if;
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

  -- Only the last DSP chain link requires ACCU, output registers, rounding, clipping and overflow detection.
  -- All other DSP chain links do not output anything.
  gn : for n in 0 to NUM_MULT-1 generate
    signal clr_i : std_logic;
  begin

    clr_i <= clr when (NUM_ACCU_CYCLES>=2 and (n=(NUM_MULT-1))) else '0';

    i_cmacc : entity work.complex_mult1add1(behave)
    generic map(
      NUM_ACCU_CYCLES     => ACCU_CYCLES(n),
      NUM_SUMMAND_CHAININ => n,
      NUM_SUMMAND_Z       => SUMMAND_Z(n),
      USE_NEGATION        => USE_NEGATION,
      USE_CONJUGATE_X     => USE_CONJUGATE_X,
      USE_CONJUGATE_Y     => USE_CONJUGATE_Y,
      NUM_INPUT_REG_XY    => 1 + NUM_INPUT_REG_XY + n, -- minimum one input register
      NUM_INPUT_REG_Z     => 1 + NUM_INPUT_REG_Z  + n, -- minimum one input register
      NUM_OUTPUT_REG      => 1 + OUTREGS(n), -- at least the DSP internal output register
      OUTPUT_SHIFT_RIGHT  => OUTPUT_SHIFT_RIGHT,
      OUTPUT_ROUND        => (OUTPUT_ROUND and (n=(NUM_MULT-1))),
      OUTPUT_CLIP         => (OUTPUT_CLIP and (n=(NUM_MULT-1))),
      OUTPUT_OVERFLOW     => (OUTPUT_OVERFLOW and (n=(NUM_MULT-1)))
    )
    port map(
      clk             => clk,
      rst             => rst,
      clkena          => clkena,
      clr             => clr_i,
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
  end generate;

  result_re <= result_re_i(NUM_MULT-1);
  result_im <= result_im_i(NUM_MULT-1);
  result_vld <= result_vld_i(NUM_MULT-1);
  result_ovf <= result_ovf_re_i(NUM_MULT-1) or result_ovf_im_i(NUM_MULT-1);
  result_rst <= result_rst_i(NUM_MULT-1);
  PIPESTAGES <= pipestages_i(NUM_MULT-1);

end architecture;
