-------------------------------------------------------------------------------
--! @file       signed_mult_accu.behave.vhdl
--! @author     Fixitfetish
--! @date       02/Jul/2017
--! @version    0.30
--! @note       VHDL-1993, VHDL-2008
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

--! @brief This implementation is a behavioral model of the entity signed_mult_accu
--! for simulation.
--! N signed multiplications are performed and the results are accumulated.
--! 
--! * Input Data      : Nx2 signed values, each max 18 bits
--! * Input Register  : optional, at least one is strongly recommended
--! * Output Register : 64 bits, first output register (strongly recommended in most cases)
--! * Rounding        : optional half-up
--! * Output Data     : 1x signed value, max 64 bits
--! * Output Register : optional, after rounding, shift-right and saturation
--! * Pipeline stages : NUM_INPUT_REG + NUM_OUTPUT_REG + PIPELINE_REG

architecture behave of signed_mult_accu is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := signed_mult_accu'INSTANCE_NAME;

  -- bit resolution of input data
  constant WIDTH_X : positive := x(x'left)'length;
  constant WIDTH_Y : positive := y(y'left)'length;

  -- number of elements of complex factor vector y
  -- (must be either 1 or the same length as x)
  constant NUM_FACTOR : positive := y'length;

  -- local auxiliary
  -- determine number of required additional guard bits (MSBs)
  function guard_bits(num_summand, dflt:natural) return integer is
    variable res : integer;
  begin
    if num_summand=0 then
      res := dflt; -- maximum possible (default)
    else
      res := LOG2CEIL(num_summand);
    end if;
    return res; 
  end function;

  -- accumulator width in bits
  constant ACCU_WIDTH : positive := 64;

  -- derived constants
  constant PRODUCT_WIDTH : natural := WIDTH_X + WIDTH_Y;
  constant MAX_GUARD_BITS : natural := ACCU_WIDTH - PRODUCT_WIDTH;
  constant GUARD_BITS_EVAL : natural := guard_bits(NUM_MULT,MAX_GUARD_BITS);
  constant ACCU_USED_WIDTH : natural := PRODUCT_WIDTH + GUARD_BITS_EVAL;
  constant OUTPUT_WIDTH : positive := result'length;

  -- pipeline registers (plus some dummy ones for non-existent adder tree)
  constant NUM_DELAY_REG : natural := NUM_INPUT_REG + NUM_OUTPUT_REG + GUARD_BITS_EVAL;

  signal accu_vld : std_logic := '0';
  signal accu_used : signed(ACCU_USED_WIDTH-1 downto 0) := (others=>'0');

begin

  -- !Caution!
  --  - consider VHDL 1993 and 2008 compatibility
  --  - consider y range NOT starting with 0

  -- same factor y for all vector elements of x
  gin_1 : if NUM_FACTOR=1 generate
  begin
   p_sum : process(clk)
    variable v_accu_used : signed(ACCU_USED_WIDTH-1 downto 0);
   begin
    if rising_edge(clk) then
      if clr='1' then
        v_accu_used := (others=>'0');
      else
        v_accu_used := accu_used;
      end if;
      if vld='1' then
        for n in 0 to NUM_MULT-1 loop
          if neg(n)='1' then
            v_accu_used := v_accu_used - ( x(n) * y(y'left) ); -- y duplication!
          else
            v_accu_used := v_accu_used + ( x(n) * y(y'left) ); -- y duplication!
          end if;
        end loop;
      end if;
      accu_used <= v_accu_used;
      accu_vld <= vld; -- same for all
    end if;
   end process;
  end generate;

  -- separate factor y for each vector element of x
  gin_n : if (NUM_MULT>=2 and NUM_FACTOR=NUM_MULT) generate
  begin
   p_sum : process(clk)
    variable v_accu_used : signed(ACCU_USED_WIDTH-1 downto 0);
   begin
    if rising_edge(clk) then
      if clr='1' then
        v_accu_used := (others=>'0');
      else
        v_accu_used := accu_used;
      end if;
      if vld='1' then
        for n in 0 to NUM_MULT-1 loop
          if neg(n)='1' then
            v_accu_used := v_accu_used - ( x(n) * y(y'left+n) );
          else
            v_accu_used := v_accu_used + ( x(n) * y(y'left+n) );
          end if;
        end loop;
      end if;
      accu_used <= v_accu_used;
      accu_vld <= vld; -- same for all
    end if;
   end process;
  end generate;

  -- right-shift, rounding and clipping
  i_out : entity dsplib.dsp_output_logic
  generic map(
    PIPELINE_STAGES    => NUM_DELAY_REG-1,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => OUTPUT_ROUND,
    OUTPUT_CLIP        => OUTPUT_CLIP,
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
  )
  port map (
    clk         => clk,
    rst         => rst,
    dsp_out     => accu_used,
    dsp_out_vld => accu_vld,
    result      => result,
    result_vld  => result_vld,
    result_ovf  => result_ovf
  );

  PIPESTAGES <= NUM_DELAY_REG;

end architecture;

