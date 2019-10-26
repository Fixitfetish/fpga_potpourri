-------------------------------------------------------------------------------
--! @file       signed_mult.behave.vhdl
--! @author     Fixitfetish
--! @date       26/Oct/2019
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

--! @brief This implementation is a behavioral model of the entity signed_mult .
--! N signed multiplications are performed.
--! 
--! * Input Data      : Nx2 signed values, each max 18 bits
--! * Input Register  : optional, at least one is strongly recommended
--! * Output Register : 64 bits, first output register (strongly recommended in most cases)
--! * Rounding        : optional half-up
--! * Output Data     : N signed values, max 64 bits
--! * Output Register : optional, after rounding, shift-right and saturation
--! * Pipeline stages : NUM_INPUT_REG + NUM_OUTPUT_REG
--!
architecture behave of signed_mult is

  -- bit resolution of input data
  constant WIDTH_X : positive := x(x'left)'length;
  constant WIDTH_Y : positive := y(y'left)'length;

  -- number of elements of complex factor vector y
  -- (must be either 1 or the same length as x)
  constant NUM_FACTOR : positive := y'length;

  -- derived constants
  constant PRODUCT_WIDTH : natural := WIDTH_X + WIDTH_Y;

  -- pipeline registers (plus some dummy ones for non-existent adder tree)
  constant NUM_DELAY_REG : natural := NUM_INPUT_REG + NUM_OUTPUT_REG;

  type t_prod is array(integer range <>) of signed(PRODUCT_WIDTH-1 downto 0);
  signal prod : t_prod(0 to NUM_MULT-1) := (others=>(others=>'0'));

  signal vld_q : std_logic;

begin

  -- !Caution!
  --  a) consider VHDL 1993 and 2008 compatibility
  --  b) consider y range NOT starting with 0

  -- same factor y for all vector elements of x
  gin_1 : if NUM_FACTOR=1 generate
  begin
   p_sum : process(clk)
   begin
    if rising_edge(clk) then
     if clkena='1' then
      if vld='1' then
        for n in 0 to NUM_MULT-1 loop
          if neg(n)='1' and USE_NEGATION then
            prod(n) <= -( x(n) * y(y'left) ); -- y duplication!
          else
            prod(n) <=  ( x(n) * y(y'left) ); -- y duplication!
          end if;
        end loop;
      end if;
      -- valid is the same for all
      vld_q <= vld;
     end if; -- clock enable
    end if; -- clock
   end process;
  end generate;

  -- separate factor y for each vector element of x
  gin_n : if (NUM_MULT>=2 and NUM_FACTOR=NUM_MULT) generate
  begin
   p_sum : process(clk)
   begin
    if rising_edge(clk) then
     if clkena='1' then
      if vld='1' then
        for n in 0 to NUM_MULT-1 loop
          if neg(n)='1' and USE_NEGATION then
            prod(n) <= -( x(n) * y(y'left+n) );
          else
            prod(n) <=  ( x(n) * y(y'left+n) );
          end if;
        end loop;
      end if;
      -- valid is the same for all
      vld_q <= vld;
     end if; -- clock enable
    end if; -- clock
   end process;
  end generate;

  g_shift : for n in 0 to (NUM_MULT-1) generate
    -- right-shift, rounding and clipping
    i_out : entity dsplib.signed_output_logic
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
      clkena      => clkena,
      dsp_out     => prod(n),
      dsp_out_vld => vld_q,
      result      => result(n),
      result_vld  => result_vld(n),
      result_ovf  => result_ovf(n)
    );
  end generate;

  PIPESTAGES <= NUM_DELAY_REG;

end architecture;

