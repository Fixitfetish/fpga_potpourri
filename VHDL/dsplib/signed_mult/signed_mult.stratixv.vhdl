-------------------------------------------------------------------------------
--! @file       signed_mult.stratixv.vhdl
--! @author     Fixitfetish
--! @date       23/Feb/2017
--! @version    0.30
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
--! for Altera Stratix-V.
--! N parallel and synchronous signed multiplications are performed.
--!
--! This implementation supports four modes:
--! * N x 18x18 PARTIAL (2 multiplications within 1 DSP block)  with x'length<=18, y'length<=18 and x'length+y'length<=32
--! * N x 18x18 COMPACT (3 multiplications within 2 DSP blocks) with x'length<=18, y'length<=18
--! * N x 27x27 FULL    (1 multiplication  within 1 DSP block)  with x'length<=27, y'length<=27
--! * N x 36x18 FULL    (1 multiplication  within 1 DSP block)  with x'length<=36, y'length<=18
--!
--! This implementation does not instantiate primitives directly but uses Stratix-V specific architectures instead.
--!
--! | X Len | Y Len | X+Y Len | DSP Blocks  | Entity Type Used   | Comment
--! |:-----:|:-----:|:-------:|:-----------:|--------------------|-----------
--! | <=18  | <=18  | <=32    | ceil(N/2)   | signed_mult2       | 18x18 Partial
--! | <=18  | <=18  | <=36    | 2*ceil(N/3) | signed_mult3       | 18x18 Compact (only N>=2)
--! | <=27  | <=27  | <=54    | N           | signed_mult1_accu  | 27x27 Full
--! | <=36  | <=18  | <=54    | N           | signed_mult1_accu  | 36x18 Full
--!

architecture stratixv of signed_mult is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := signed_mult'INSTANCE_NAME;

  -- determine number of multiplications per entity
  function mult_per_entity(lx,ly:integer) return natural is
  begin
    if lx<=18 and ly<=18 then
      if (lx+ly<=32) then return 2; -- m18x18_partial
      elsif NUM_MULT>1 then return 3; -- m18x18_compact
      else return 1; -- full (saves one DSP Block when only single multiplication)
      end if; 
    elsif (lx<=36 and ly<=18) or (lx<=27 and ly<=27) then 
      return 1; -- m27x27 or m36x18
    else 
      report "ERROR " & IMPLEMENTATION & ": Data input length not supported. Three modes of input length are possible: " &
        "1.) PARTIAL with LX<=18, LY<=18 and LX+LY<=32  " &
        "2.) COMPACT with LX<=18, LY<=18 and LX+LY<=36  " &
        "3.) FULL with LX<=27 and LY<=27 or with LX<=36 and LY<=18"
        severity failure;
      return 0; -- invalid
    end if;
  end function;

  -- derived constants
  constant NUM_MULT_PER_ENTITY : natural := mult_per_entity(x(x'left)'length,y(y'left)'length);
  constant NUM_ENTITY : natural := (NUM_MULT+NUM_MULT_PER_ENTITY-1)/NUM_MULT_PER_ENTITY;

  -- Internal copy of inputs required because some multipliers of an entity might
  -- be unused and need to be set to zero.
  type t_x is array(integer range <>) of signed(x(x'left)'length-1 downto 0);
  type t_y is array(integer range <>) of signed(y(y'left)'length-1 downto 0);
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

  -- Map inputs to internal signals
  g_in: for n in 0 to (NUM_MULT-1) generate
    neg_i(n) <= neg(n);
    x_i(n) <= x(n);
    -- same factor y for all vector elements of x
    g1: if y'length=1 generate
      y_i(n) <= y(y'left); -- duplication !
    end generate;
    -- separate factor y for each vector element of x
    gin_n: if y'length>=2 generate
      y_i(n) <= y(y'left+n); -- range conversion !
    end generate;
  end generate;

  -----------------------------------------------------------------------------

  -- use mode "M18x18_PARTIAL" (two multiplications within one DSP block)
  g_partial : if NUM_MULT_PER_ENTITY=2 generate
   g_n: for n in 0 to (NUM_ENTITY-1) generate

    mult2 : entity dsplib.signed_mult2(stratixv_partial)
    generic map(
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
      vld        => vld,
      neg        => neg_i(2*n to 2*n+1),
      x0         => x_i(2*n),
      y0         => y_i(2*n),
      x1         => x_i(2*n+1),
      y1         => y_i(2*n+1),
      result0    => r_i(2*n),
      result1    => r_i(2*n+1),
      result_vld => r_vld_i(2*n to 2*n+1),
      result_ovf => r_ovf_i(2*n to 2*n+1),
      PIPESTAGES => pipe(n)
    );
   end generate;

  end generate; -- partial

  -----------------------------------------------------------------------------

  -- use mode "M18x18_COMPACT" (three multiplications within two DSP blocks)
  -- Efficient DSP usage only for 2 or more multiplications, otherwise use FULL mode.
  g_compact : if NUM_MULT_PER_ENTITY=3 generate
   g_n: for n in 0 to (NUM_ENTITY-1) generate

    mult3 : entity dsplib.signed_mult3(stratixv_compact)
    generic map(
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
      vld        => vld,
      neg        => neg_i(3*n to 3*n+2),
      x0         => x_i(3*n),
      y0         => y_i(3*n),
      x1         => x_i(3*n+1),
      y1         => y_i(3*n+1),
      x2         => x_i(3*n+2),
      y2         => y_i(3*n+2),
      result0    => r_i(3*n),
      result1    => r_i(3*n+1),
      result2    => r_i(3*n+2),
      result_vld => r_vld_i(3*n to 3*n+2),
      result_ovf => r_ovf_i(3*n to 3*n+2),
      PIPESTAGES => pipe(n)
    );
   end generate;

  end generate; -- compact

  -----------------------------------------------------------------------------

  -- use mode "M27x27" or "M36x18" (one multiplications within one DSP block)
  g_full : if NUM_MULT_PER_ENTITY=1 generate

   g_n: for n in 0 to (NUM_ENTITY-1) generate

    mult1 : entity dsplib.signed_mult1_accu(stratixv)
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

  end generate; -- full

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

