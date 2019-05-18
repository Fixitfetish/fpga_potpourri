-------------------------------------------------------------------------------
--! @file       signed_mult1_accu.behave.vhdl
--! @author     Fixitfetish
--! @date       05/Feb/2018
--! @version    0.95
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
  use dsplib.dsp_pkg_behave.all;

--! @brief This implementation is a behavioral model of the entity signed_mult1_accu
--! for simulation.
--! One signed multiplication is performed and results are accumulated.
--! 
--! * Input Data      : 2 signed values, each max 27 bits
--! * Input Register  : optional, at least one is strongly recommended
--! * Input Chain     : optional, 64 bits
--! * Accu Register   : 64 bits, first output register (strongly recommended in most cases)
--! * Rounding        : optional half-up
--! * Output Data     : 1x signed value, max 64 bits
--! * Output Register : optional, after rounding, shift-right and saturation
--! * Pipeline stages : NUM_INPUT_REG + NUM_OUTPUT_REG

architecture behave of signed_mult1_accu is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "signed_mult1_accu(behave)";

  constant MAX_WIDTH_X : positive := 27;
  constant MAX_WIDTH_Y : positive := 27;

  -- derived constants
  constant PRODUCT_WIDTH : natural := x'length + y'length;
  constant MAX_GUARD_BITS : natural := ACCU_WIDTH - PRODUCT_WIDTH;
  constant GUARD_BITS_EVAL : natural := accu_guard_bits(NUM_SUMMAND,MAX_GUARD_BITS,IMPLEMENTATION);
  constant ACCU_USED_WIDTH : natural := PRODUCT_WIDTH + GUARD_BITS_EVAL;
  constant ACCU_USED_SHIFTED_WIDTH : natural := ACCU_USED_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result'length;

  -- input register pipeline
  type r_ireg is
  record
    rst, vld : std_logic;
    clr : std_logic;
    sub : std_logic;
    x   : signed(MAX_WIDTH_X-1 downto 0);
    y   : signed(MAX_WIDTH_Y-1 downto 0);
  end record;
  type array_ireg is array(integer range <>) of r_ireg;
  signal ireg : array_ireg(NUM_INPUT_REG downto 0);

  signal p : signed(PRODUCT_WIDTH-1 downto 0);
  signal sum, chainin_i : signed(ACCU_WIDTH-1 downto 0) := (others=>'0');
  signal accu : signed(ACCU_WIDTH-1 downto 0);
  signal accu_vld : std_logic := '0';
  signal accu_used : signed(ACCU_USED_WIDTH-1 downto 0);

begin

  -- check chain in/out length
  assert (chainin'length>=ACCU_WIDTH or (not USE_CHAIN_INPUT))
    report "ERROR " & IMPLEMENTATION & ": " &
           "Chain input width must be at least " & integer'image(ACCU_WIDTH) & " bits."
    severity failure;

  assert PRODUCT_WIDTH<=ACCU_WIDTH
    report "ERROR " & IMPLEMENTATION & ": " &
           "Resulting product width exceeds accumulator width of " & integer'image(ACCU_WIDTH)
    severity failure;

  assert GUARD_BITS_EVAL<=MAX_GUARD_BITS
    report "ERROR " & IMPLEMENTATION & ": " &
           "Maximum number of accumulator bits is " & integer'image(ACCU_WIDTH) & " ." &
           "Input bit widths allow only maximum number of guard bits = " & integer'image(MAX_GUARD_BITS)
    severity failure;

  assert OUTPUT_WIDTH<ACCU_USED_SHIFTED_WIDTH or not(OUTPUT_CLIP or OUTPUT_OVERFLOW)
    report "ERROR " & IMPLEMENTATION & ": " &
           "More guard bits required for saturation/clipping and/or overflow detection."
    severity failure;

  -- control signal inputs
  ireg(NUM_INPUT_REG).rst <= rst;
  ireg(NUM_INPUT_REG).vld <= vld;
  ireg(NUM_INPUT_REG).clr <= clr;
  ireg(NUM_INPUT_REG).sub <= neg;

  -- LSB bound data inputs
  ireg(NUM_INPUT_REG).x <= resize(x,MAX_WIDTH_X);
  ireg(NUM_INPUT_REG).y <= resize(y,MAX_WIDTH_Y);

  g_in : if NUM_INPUT_REG>=1 generate
  begin
    g_1 : for n in 1 to NUM_INPUT_REG generate
    begin
      ireg(n-1) <= ireg(n) when (rising_edge(clk) and clkena='1');
    end generate;
  end generate;

  -- multiplier result
  p <= resize(ireg(0).x * ireg(0).y, PRODUCT_WIDTH);

  -- chain input
  g_chain : if USE_CHAIN_INPUT generate
    chainin_i <= chainin(ACCU_WIDTH-1 downto 0);
  end generate;

  -- temporary sum of multiplier result and chain input
  sum <= chainin_i - p when ireg(0).sub='1' else
         chainin_i + p;

  g_accu_off : if NUM_OUTPUT_REG=0 generate
    accu <= sum;
  end generate;
  
  g_accu_on : if NUM_OUTPUT_REG>0 generate
  begin
  p_accu : process(clk)
  begin
    if rising_edge(clk) then
      if ireg(0).clr='1' then
        if ireg(0).vld='1' then
          accu <= sum;
        else
          accu <= (others=>'0');
        end if;
      else  
        if ireg(0).vld='1' then
          accu <= accu + sum;
        end if;
      end if;
    end if;
  end process;
  end generate;

  chainout(ACCU_WIDTH-1 downto 0) <= accu;
  g_chainout : for n in ACCU_WIDTH to (chainout'length-1) generate
    -- sign extension (for simulation and to avoid warnings)
    chainout(n) <= accu(ACCU_WIDTH-1);
  end generate;

  -- pipelined valid signal
  g_dspreg_on : if NUM_OUTPUT_REG>=1 generate
    accu_vld <= ireg(0).vld when rising_edge(clk);
  end generate;
  g_dspreg_off : if NUM_OUTPUT_REG<=0 generate
    accu_vld <= ireg(0).vld;
  end generate;

  -- cut off unused sign extension bits
  -- (This reduces the logic consumption in the following steps when rounding,
  --  saturation and/or overflow detection is enabled.)
  accu_used <= accu(ACCU_USED_WIDTH-1 downto 0);

  -- right-shift, round and clipping
  i_out : entity dsplib.signed_output_logic
  generic map(
    PIPELINE_STAGES    => NUM_OUTPUT_REG-1,
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

  -- report constant number of pipeline register stages
  PIPESTAGES <= NUM_INPUT_REG + NUM_OUTPUT_REG;

end architecture;
