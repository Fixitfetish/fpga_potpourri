-------------------------------------------------------------------------------
--! @file       signed_mult.behave.vhdl
--! @author     Fixitfetish
--! @date       05/Jun/2017
--! @version    0.10
--! @copyright  MIT License
--! @note       VHDL-1993
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;

--! @brief This implementation is a behavioral model of the entity 
--! @link signed_mult signed_mult @endlink for simulation.
--! N signed multiplications are performed.
--! 
--! * Input Data      : Nx2 signed values, each max 18 bits
--! * Input Register  : optional, at least one is strongly recommended
--! * Output Register : 64 bits, first output register (strongly recommended in most cases)
--! * Rounding        : optional half-up
--! * Output Data     : N signed values, max 64 bits
--! * Output Register : optional, after rounding, shift-right and saturation
--! * Pipeline stages : NUM_INPUT_REG + NUM_OUTPUT_REG

architecture behave of signed_mult is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := signed_mult'INSTANCE_NAME;

  -- number of elements of complex factor vector y
  -- (must be either 1 or the same length as x)
  constant NUM_FACTOR : positive := y'length;

  -- convert to default range
  signal y_i : signed_vector(0 to NUM_MULT-1);
 
  -- derived constants
  constant ROUND_ENABLE : boolean := OUTPUT_ROUND and (OUTPUT_SHIFT_RIGHT/=0);
  constant PRODUCT_WIDTH : natural := x(x'left)'length + y(y'left)'length;
  constant PRODUCT_SHIFTED_WIDTH : natural := PRODUCT_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result(result'left)'length;

  -- pipeline registers (plus some dummy ones for non-existent adder tree)
  constant NUM_DELAY_REG : natural := NUM_INPUT_REG + NUM_OUTPUT_REG;

  -- output register pipeline
  type r_oreg is
  record
    dat : signed(OUTPUT_WIDTH-1 downto 0);
    vld : std_logic;
    ovf : std_logic;
  end record;
  type array_oreg is array(integer range <>) of r_oreg;
  type matrix_oreg is array(integer range <>) of array_oreg(0 to NUM_MULT-1);
  signal rslt : matrix_oreg(1 to NUM_DELAY_REG) := (others=>(others=>(dat=>(others=>'0'),vld|ovf=>'0')));

  type t_prod is array(integer range <>) of signed(PRODUCT_WIDTH-1 downto 0);
  type t_prod_shifted is array(integer range <>) of signed(PRODUCT_SHIFTED_WIDTH-1 downto 0);
  signal prod : t_prod(0 to NUM_MULT-1);
  signal prod_shifted : t_prod_shifted(0 to NUM_MULT-1);

  signal vld_q : std_logic;

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
  begin
    if rising_edge(clk) then
      if vld='1' then
        for n in 0 to NUM_MULT-1 loop
          if neg(n)='1' then
            prod(n) <= -( x(n) * y_i(n) );
          else
            prod(n) <=  ( x(n) * y_i(n) );
          end if;
        end loop;
      end if;
      -- valid is the same for all
      vld_q <= vld;
    end if;
  end process;

  g_shift : for n in 0 to (NUM_MULT-1) generate
    -- shift right and round
    g_rnd_off : if (not ROUND_ENABLE) generate
      prod_shifted(n) <= RESIZE(SHIFT_RIGHT_ROUND(prod(n), OUTPUT_SHIFT_RIGHT),PRODUCT_SHIFTED_WIDTH);
    end generate;
    g_rnd_on : if (ROUND_ENABLE) generate
      prod_shifted(n) <= RESIZE(SHIFT_RIGHT_ROUND(prod(n), OUTPUT_SHIFT_RIGHT, nearest),PRODUCT_SHIFTED_WIDTH);
    end generate;
    -- resize and clip
    p_out : process(prod_shifted(n),vld_q)
      variable v_dat : signed(OUTPUT_WIDTH-1 downto 0);
      variable v_ovf : std_logic;
    begin
      RESIZE_CLIP(din=>prod_shifted(n), dout=>v_dat, ovfl=>v_ovf, clip=>OUTPUT_CLIP);
      rslt(1)(n).dat <= v_dat;
      rslt(1)(n).vld <= vld_q;
      if OUTPUT_OVERFLOW then rslt(1)(n).ovf<=v_ovf; else rslt(1)(n).ovf<='0'; end if;
    end process;
  end generate;

  -- additional output registers always in logic
  g_oreg : if NUM_DELAY_REG>=2 generate
    g_loop : for d in 2 to NUM_DELAY_REG generate
      rslt(d) <= rslt(d-1) when rising_edge(clk);
    end generate;
  end generate;

  -- map result to output port
  g_out : for n in 0 to NUM_MULT-1 generate
    result(n) <= rslt(NUM_DELAY_REG)(n).dat;
    result_vld(n) <= rslt(NUM_DELAY_REG)(n).vld;
    result_ovf(n) <= rslt(NUM_DELAY_REG)(n).ovf;
  end generate;

  PIPESTAGES <= NUM_DELAY_REG;

end architecture;

