-------------------------------------------------------------------------------
--! @file       signed_mult.ultrascale.vhdl
--! @author     Fixitfetish
--! @date       01/Jul/2017
--! @version    0.40
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension.all;
library dsplib;

--! @brief This is an implementation of the entity 
--! @link signed_mult signed_mult @endlink
--! for Xilinx UltraScale.
--! N parallel and synchronous signed multiplications are performed.
--!
--! Currently, this implementation supports these modes:
--! * N x 27x18 FULL    (1 multiplication within 1 DSP block)  with x'length<=27, y'length<=18
--!
--! This implementation does not instantiate primitives directly but uses UltraScale specific architectures instead.
--!
--! | X Len | Y Len | X+Y Len | DSP Slices | Entity Used           | Comment
--! |:-----:|:-----:|:-------:|:----------:|-----------------------|-----------
--! | <=27  | <=18  | <=45    | N          | signed_mult1_accu  | 27x18 Full
--!

architecture ultrascale of signed_mult is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := signed_mult'INSTANCE_NAME;

  -- determine number of multiplications per entity
  function mult_per_entity(lx,ly:integer) return natural is
  begin
    if lx<=27 and ly<=18 then
      return 1; -- 27x18
    else 
      report "ERROR " & IMPLEMENTATION & 
        " Data input length not supported. These modes of input length are possible: " &
        "1.) 27x18 with LX<=27, LY<=18 and LX+LY<=45"
        severity failure;
      return 0; -- invalid
    end if;
  end function;

  -- derived constants
  constant NUM_MULT_PER_ENTITY : natural := mult_per_entity(x(0)'length,y(0)'length);
  constant NUM_ENTITY : natural := (NUM_MULT+NUM_MULT_PER_ENTITY-1)/NUM_MULT_PER_ENTITY;

  -- Internal copy of inputs required because some multipliers of an entity might
  -- be unused and need to be set to zero.
  type t_x is array(integer range <>) of signed(x(0)'length-1 downto 0);
  type t_y is array(integer range <>) of signed(y(0)'length-1 downto 0);
  signal x_i : t_x(0 to NUM_ENTITY*NUM_MULT_PER_ENTITY-1) := (others=>(others=>'0'));
  signal y_i : t_y(0 to NUM_ENTITY*NUM_MULT_PER_ENTITY-1) := (others=>(others=>'0'));
  signal neg_i : std_logic_vector(0 to NUM_ENTITY*NUM_MULT_PER_ENTITY-1) := (others=>'0');

  -- Internal copy of outputs required because some multipliers of an entity might
  -- be unused and need to be ignored.
  type t_r is array(integer range <>) of signed(result(0)'length-1 downto 0);
  signal r_i : t_r(0 to NUM_ENTITY*NUM_MULT_PER_ENTITY-1);
  signal r_vld_i : std_logic_vector(0 to NUM_ENTITY*NUM_MULT_PER_ENTITY-1);
  signal r_ovf_i : std_logic_vector(0 to NUM_ENTITY*NUM_MULT_PER_ENTITY-1);
  type integer_vector is array(integer range <>) of integer;
  signal pipe : integer_vector(0 to NUM_ENTITY-1);

begin

  -- Map inputs to internal signals.
  g_in: for n in 0 to (NUM_MULT-1) generate
    x_i(n) <= x(n);
    y_i(n) <= y(n);
    neg_i(n) <= neg(n);
  end generate;

  -----------------------------------------------------------------------------

  -- use mode "27x18" (one multiplications within one DSP block)
  g_full : if NUM_MULT_PER_ENTITY=1 generate

   g_n: for n in 0 to (NUM_ENTITY-1) generate

    mult1 : entity dsplib.signed_mult1_accu
    generic map(
      NUM_SUMMAND        => 1,
      USE_CHAIN_INPUT    => false,
      NUM_INPUT_REG      => NUM_INPUT_REG,
      NUM_OUTPUT_REG     => NUM_OUTPUT_REG,
      OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
      OUTPUT_ROUND       => OUTPUT_ROUND,
      OUTPUT_CLIP        => OUTPUT_CLIP,
      OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
    )
    port map (
      clk        => clk,
      rst        => rst,
      clr        => '1', -- disable accumulation
      vld        => vld,
      sub        => neg_i(n),
      x          => x_i(n),
      y          => y_i(n),
      result     => r_i(n),
      result_vld => r_vld_i(n),
      result_ovf => r_ovf_i(n),
      chainin    => open,
      chainout   => open,
      PIPESTAGES => pipe(n)
    );
   end generate;

  end generate;

  -----------------------------------------------------------------------------

  -- Map internal signals to output ports
  g_out: for n in 0 to (NUM_MULT-1) generate
    result(n) <= r_i(n);
    result_vld(n) <= r_vld_i(n);
    result_ovf(n) <= r_ovf_i(n);
  end generate;

  -- number of pipeline stages is the same for all entities - use from first entity
  PIPESTAGES <= pipe(0);

end architecture;

