-------------------------------------------------------------------------------
--! @file       signed_mult_accu.behave.vhdl
--! @author     Fixitfetish
--! @date       11/Apr/2017
--! @version    0.20
--! @copyright  MIT License
--! @note       VHDL-1993
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension.all;

--! @brief This implementation is a behavioral model of the entity 
--! @link signed_mult_accu signed_mult_accu @endlink for simulation.
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

  -- number of elements of complex factor vector y
  -- (must be either 1 or the same length as x)
  constant NUM_FACTOR : positive := y'length;

  -- convert to default range
  signal y_i : signed_vector(0 to NUM_MULT-1);
 
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
  constant ROUND_ENABLE : boolean := OUTPUT_ROUND and (OUTPUT_SHIFT_RIGHT/=0);
  constant PRODUCT_WIDTH : natural := x(x'left)'length + y(y'left)'length;
  constant MAX_GUARD_BITS : natural := ACCU_WIDTH - PRODUCT_WIDTH;
  constant GUARD_BITS_EVAL : natural := guard_bits(NUM_MULT,MAX_GUARD_BITS);
  constant ACCU_USED_WIDTH : natural := PRODUCT_WIDTH + GUARD_BITS_EVAL;
  constant ACCU_USED_SHIFTED_WIDTH : natural := ACCU_USED_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result'length;

  -- pipeline registers (plus some dummy ones for non-existent adder tree)
  constant NUM_DELAY_REG : natural := NUM_INPUT_REG + NUM_OUTPUT_REG + GUARD_BITS_EVAL;

  -- output register pipeline
  type r_oreg is
  record
    dat : signed(OUTPUT_WIDTH-1 downto 0);
    vld : std_logic;
    ovf : std_logic;
  end record;
  type array_oreg is array(integer range <>) of r_oreg;
  signal rslt : array_oreg(1 to NUM_DELAY_REG) := (others=>(dat=>(others=>'0'),vld|ovf=>'0'));

  signal accu_used : signed(ACCU_USED_WIDTH-1 downto 0) := (others=>'0');
  signal accu_used_shifted : signed(ACCU_USED_SHIFTED_WIDTH-1 downto 0);

begin

  -- same factor y for all vector elements of x
  gin_1 : if NUM_FACTOR=1 generate
    g_1 : for n in 0 to NUM_MULT-1 generate
      y_i(n) <= y(y'left); -- duplication !
    end generate;
  end generate;

  -- separate factor y for each vector element of x
  gin_n : if (NUM_MULT>=2 and NUM_FACTOR=NUM_MULT) generate
    y_i <= y; -- same length and range conversion !
  end generate;

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
            v_accu_used := v_accu_used - ( x(n) * y_i(n) );
          else
            v_accu_used := v_accu_used + ( x(n) * y_i(n) );
          end if;
        end loop;
      end if;
      accu_used <= v_accu_used;
      rslt(1).vld <= vld; -- same for all
    end if;
  end process;

  -- shift right and round
  g_rnd_off : if (not ROUND_ENABLE) generate
    accu_used_shifted <= RESIZE(SHIFT_RIGHT_ROUND(accu_used, OUTPUT_SHIFT_RIGHT),ACCU_USED_SHIFTED_WIDTH);
  end generate;
  g_rnd_on : if (ROUND_ENABLE) generate
    accu_used_shifted <= RESIZE(SHIFT_RIGHT_ROUND(accu_used, OUTPUT_SHIFT_RIGHT, nearest),ACCU_USED_SHIFTED_WIDTH);
  end generate;

  p_out : process(accu_used_shifted)
    variable v_dat : signed(OUTPUT_WIDTH-1 downto 0);
    variable v_ovf : std_logic;
  begin
    RESIZE_CLIP(din=>accu_used_shifted, dout=>v_dat, ovfl=>v_ovf, clip=>OUTPUT_CLIP);
    rslt(1).dat <= v_dat;
    if OUTPUT_OVERFLOW then rslt(1).ovf<=v_ovf; else rslt(1).ovf<='0'; end if;
  end process;

  -- additional output registers always in logic
  g_oreg : if NUM_DELAY_REG>=2 generate
    g_loop : for n in 2 to NUM_DELAY_REG generate
      rslt(n) <= rslt(n-1) when rising_edge(clk);
    end generate;
  end generate;

  -- map result to output port
  result <= rslt(NUM_DELAY_REG).dat;
  result_vld <= rslt(NUM_DELAY_REG).vld;
  result_ovf <= rslt(NUM_DELAY_REG).ovf;

  PIPESTAGES <= NUM_DELAY_REG;

end architecture;

