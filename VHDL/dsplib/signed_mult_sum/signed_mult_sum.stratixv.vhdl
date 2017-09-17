-------------------------------------------------------------------------------
--! @file       signed_mult_sum.stratixv.vhdl
--! @author     Fixitfetish
--! @date       28/Mar/2017
--! @version    0.20
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
  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;
library dsplib;

--! @brief This is an implementation of the entity signed_mult_sum
--! for Altera Stratix-V.
--! N signed multiplications are performed and all results are summed.
--!
--! This implementation uses N4 = floor((N+1)/4) instances of signed_mult4_sum
--! and N2 = ceil(N/2)-2*N4 instances of signed_mult2_accu
--! Overall 2*N4 + N2 Altera Stratix-V DSP blocks are required.
--!
--! * Input Data      : Nx2 signed values, each max 18 bits
--! * Input Register  : optional, at least one is strongly recommended
--! * Accu Register   : just pipeline register, accumulation not supported
--! * Rounding        : optional half-up, only possible in logic!
--! * Output Data     : 1x signed value, max 64 bits
--! * Output Register : optional, at least one strongly recommend, another after shift-right and saturation
--! * Pipeline stages : NUM_INPUT_REG + NUM_PIPELINE_REG + NUM_OUTPUT_REG
--!
--! @image html signed_mult_sum.stratixv.svg "" width=1000px

architecture stratixv of signed_mult_sum is

  constant NY : integer := y'length; -- number vector elements

  -- number of required MULT2 blocks 
  constant NUM_MULT2 : natural := (NUM_MULT+1)/2; -- ceil(NUM_MULT/2)

  -- number of resulting MULT4 instances 
  constant NUM_MULT4 : natural := NUM_MULT2/2; -- floor(NUM_MULT2/2)

  -- Internal copy of inputs required because some multipliers of an entity might
  -- be unused and need to be set to zero.
  type t_x is array(integer range <>) of signed(x(x'left)'length-1 downto 0);
  type t_y is array(integer range <>) of signed(y(y'left)'length-1 downto 0);
  signal x_i : t_x(0 to 2*NUM_MULT2-1) := (others=>(others=>'0'));
  signal y_i : t_y(0 to 2*NUM_MULT2-1) := (others=>(others=>'0'));
  signal neg_i : std_logic_vector(0 to 2*NUM_MULT2-1) := (others=>'0');

  constant ROUND_ENABLE : boolean := OUTPUT_ROUND and (OUTPUT_SHIFT_RIGHT/=0);
  constant PRODUCT_WIDTH : natural := x(x'left)'length + y(y'left)'length;

begin

  -- Map inputs to internal signals
  g_in: for n in 0 to (NUM_MULT-1) generate
    neg_i(n) <= neg(n);
    x_i(n) <= x(n);
    -- same factor y for all vector elements of x
    g1: if NY=1 generate
      y_i(n) <= y(y'left); -- duplication !
    end generate;
    -- separate factor y for each vector element of x
    gin_n: if NY>=2 generate
      y_i(n) <= y(y'left+n); -- range conversion !
    end generate;
  end generate;


  -----------------------------------------------------------------------------
  -- when NUM_MULT <= 2  (no adder stage in logic required)
  g2: if NUM_MULT<=2 generate
    i4 : entity dsplib.signed_mult2_accu(stratixv)
    generic map(
      NUM_SUMMAND        => 2,
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
      clr        => '1', -- accumulator always disabled
      vld        => vld,
      neg        => neg_i(0 to 1),
      x0         => x_i(0),
      y0         => y_i(0),
      x1         => x_i(1),
      y1         => y_i(1),
      result     => result,
      result_vld => result_vld,
      result_ovf => result_ovf,
      chainin    => open,
      chainout   => open,
      PIPESTAGES => PIPESTAGES
    );
  end generate;

  -----------------------------------------------------------------------------

  -- when 3 <= NUM_MULT <= 4  (no adder stage in logic required)
  g4: if (NUM_MULT>=3 and NUM_MULT<=4) generate
    i4 : entity dsplib.signed_mult4_sum(stratixv)
    generic map(
      NUM_SUMMAND        => 4,
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
      vld        => vld,
      neg        => neg_i(0 to 3),
      x0         => x_i(0),
      y0         => y_i(0),
      x1         => x_i(1),
      y1         => y_i(1),
      x2         => x_i(2),
      y2         => y_i(2),
      x3         => x_i(3),
      y3         => y_i(3),
      result     => result,
      result_vld => result_vld,
      result_ovf => result_ovf,
      chainin    => open,
      chainout   => open,
      PIPESTAGES => PIPESTAGES
    );
  end generate;

  -----------------------------------------------------------------------------

  -- NUM_MULT>=5  (requires at least one adder stage in logic)
  gn: if NUM_MULT>=5 generate
    -- width of adder tree input (after MULT4) 
    constant ADDER_INPUT_WIDTH : positive := (PRODUCT_WIDTH+2) - OUTPUT_SHIFT_RIGHT;
    -- number of inputs into first adder stage = DSP entity outputs
    constant NUM_ADDER_INPUTS : natural := (NUM_MULT2+1)/2;
    -- outputs DSP MULT
    type t_dsp_out is array(integer range <>) of signed(ADDER_INPUT_WIDTH-1 downto 0);
    signal dsp_out : t_dsp_out(0 to NUM_ADDER_INPUTS-1);
    signal dsp_vld : std_logic_vector(0 to NUM_ADDER_INPUTS-1);
    type natural_vector is array(integer range <>) of natural;
    signal DSP_PIPESTAGES : natural_vector(0 to NUM_ADDER_INPUTS-1);
    -- inputs into first adder stage
    signal adder_in : signed48_vector(0 to NUM_ADDER_INPUTS-1);
    signal ADDER_PIPESTAGES : natural;
    -- adder tree input register when rounding is enabled
    function adder_input_reg(round:boolean) return natural is
    begin
      if round then return 1; else return 0; end if;
    end function;
  begin

    -- instantiate as many MULT4 instances as possible
    g4 : for n in 0 to NUM_MULT4-1 generate
    begin
      i4 : entity dsplib.signed_mult4_sum(stratixv)
      generic map(
        NUM_SUMMAND        => 4,
        USE_CHAIN_INPUT    => false,
        NUM_INPUT_REG      => NUM_INPUT_REG,
        NUM_OUTPUT_REG     => 1,
        OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
        OUTPUT_ROUND       => OUTPUT_ROUND,
        OUTPUT_CLIP        => false,
        OUTPUT_OVERFLOW    => false
      )
      port map (
        clk        => clk,
        rst        => rst,
        vld        => vld,
        neg        => neg_i(4*n+0 to 4*n+3),
        x0         => x_i(4*n+0),
        y0         => y_i(4*n+0),
        x1         => x_i(4*n+1),
        y1         => y_i(4*n+1),
        x2         => x_i(4*n+2),
        y2         => y_i(4*n+2),
        x3         => x_i(4*n+3),
        y3         => y_i(4*n+3),
        result     => dsp_out(n),
        result_vld => dsp_vld(n),
        result_ovf => open,
        chainin    => open,
        chainout   => open,
        PIPESTAGES => DSP_PIPESTAGES(n)
      );
    end generate;

    -- additional MULT2 instance required if the number of MULT2 blocks is odd
    g2: if NUM_MULT4<NUM_ADDER_INPUTS generate
    begin
      i2 : entity dsplib.signed_mult2_accu(stratixv)
      generic map(
        NUM_SUMMAND        => 2,
        USE_CHAIN_INPUT    => false,
        NUM_INPUT_REG      => NUM_INPUT_REG,
        NUM_OUTPUT_REG     => 1,
        OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
        OUTPUT_ROUND       => OUTPUT_ROUND,
        OUTPUT_CLIP        => false,
        OUTPUT_OVERFLOW    => false
      )
      port map (
        clk        => clk,
        rst        => rst,
        clr        => '1', -- accumulator always disabled
        vld        => vld,
        neg        => neg(4*NUM_MULT4 to 4*NUM_MULT4+1),
        x0         => x_i(4*NUM_MULT4),
        y0         => y_i(4*NUM_MULT4),
        x1         => x_i(4*NUM_MULT4+1),
        y1         => y_i(4*NUM_MULT4+1),
        result     => dsp_out(NUM_MULT4),
        result_vld => open,
        result_ovf => open,
        chainin    => open,
        chainout   => open,
        PIPESTAGES => open
      );
    end generate;

    -- for VHDL-1993 convert to fixed data width
    gadd : for n in 0 to NUM_ADDER_INPUTS-1 generate
      adder_in(n) <= resize(dsp_out(n), adder_in(0)'length);
    end generate;

    i_add : entity dsplib.signed_adder_tree
    generic map(
      HIGH_SPEED_MODE    => HIGH_SPEED_MODE,
      NUM_INPUT_REG      => adder_input_reg(ROUND_ENABLE),
      INPUT_WIDTH        => ADDER_INPUT_WIDTH,
      NUM_OUTPUT_REG     => NUM_OUTPUT_REG,
      OUTPUT_SHIFT_RIGHT => 0,
      OUTPUT_ROUND       => false,
      OUTPUT_CLIP        => OUTPUT_CLIP,
      OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
    )
    port map (
      clk        => clk,
      rst        => rst,
      vld        => dsp_vld(0),
      x          => adder_in,
      result     => result,
      result_vld => result_vld,
      result_ovf => result_ovf,
      PIPESTAGES => ADDER_PIPESTAGES
    );

   -- final number of pipeline stages 
   --     pipeline stages within MULT2/MULT4 (including input registers)
   --   + additional pipeline stages required for adder tree
   --   + all additional output registers (within adder tree)
   PIPESTAGES <= DSP_PIPESTAGES(0) + ADDER_PIPESTAGES;

  end generate;

end architecture;

