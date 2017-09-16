-------------------------------------------------------------------------------
--! @file       signed_mult2_sum.behave.vhdl
--! @author     Fixitfetish
--! @date       16/Sep/2017
--! @version    0.80
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

--! @brief This implementation is a behavioral model of the entity signed_mult2_sum
--! for simulation.
--! Two signed multiplications are performed and the results are summed.
--! 
--! * Input Data      : 2x2 signed values, each max 27 bits
--! * Input Register  : optional, at least one is strongly recommended
--! * Input Chain     : optional, 64 bits
--! * Output Register : 64 bits, first output register (strongly recommended in most cases)
--! * Rounding        : optional half-up
--! * Output Data     : 1x signed value, max 64 bits
--! * Output Register : optional, after rounding, shift-right and saturation
--! * Pipeline stages : NUM_INPUT_REG + NUM_OUTPUT_REG

architecture behave of signed_mult2_sum is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "signed_mult2_sum(behave)";

  -- local auxiliary
  -- determine number of required additional guard bits (MSBs)
  function guard_bits(num_summand, dflt:natural) return integer is
    variable res : integer;
  begin
    if num_summand=0 then
      res := dflt; -- maximum possible (default)
    else
      res := LOG2CEIL(num_summand);
      if res>dflt then 
        report "WARNING " & IMPLEMENTATION & ": Too many summands. " & 
           "Maximum number of " & integer'image(dflt) & " guard bits reached."
           severity warning;
        res:=dflt;
      end if;
    end if;
    return res; 
  end function;

  constant MAX_WIDTH_X : positive := 27;
  constant MAX_WIDTH_Y : positive := 27;

  -- accumulator width in bits
  constant ACCU_WIDTH : positive := 64;

  -- derived constants
  constant ROUND_ENABLE : boolean := OUTPUT_ROUND and (OUTPUT_SHIFT_RIGHT/=0);
  constant PRODUCT_WIDTH : natural := x0'length + y0'length;
  constant MAX_GUARD_BITS : natural := ACCU_WIDTH - PRODUCT_WIDTH;
  constant GUARD_BITS_EVAL : natural := guard_bits(NUM_SUMMAND,MAX_GUARD_BITS);
  constant ACCU_USED_WIDTH : natural := PRODUCT_WIDTH + GUARD_BITS_EVAL;
  constant ACCU_USED_SHIFTED_WIDTH : natural := ACCU_USED_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result'length;

  -- input register pipeline
  type r_ireg is
  record
    rst, vld : std_logic;
    sub : std_logic_vector(sub'range);
    x0, x1 : signed(MAX_WIDTH_X-1 downto 0);
    y0, y1 : signed(MAX_WIDTH_Y-1 downto 0);
  end record;
  type array_ireg is array(integer range <>) of r_ireg;
  signal ireg : array_ireg(NUM_INPUT_REG downto 0);

  -- output register pipeline
  type r_oreg is
  record
    dat : signed(OUTPUT_WIDTH-1 downto 0);
    vld : std_logic;
    ovf : std_logic;
  end record;
  type array_oreg is array(integer range <>) of r_oreg;
  signal rslt : array_oreg(0 to NUM_OUTPUT_REG);

  signal p0, p1 : signed(PRODUCT_WIDTH downto 0);
  signal sum, chainin_i : signed(ACCU_WIDTH-1 downto 0) := (others=>'0');
  signal accu : signed(ACCU_WIDTH-1 downto 0);
  signal accu_vld : std_logic := '0';
  signal accu_used : signed(ACCU_USED_WIDTH-1 downto 0);

  -- clock enable +++ TODO
  constant clkena : std_logic := '1';

begin

  -- check chain in/out length
  assert (chainin'length>=ACCU_WIDTH or (not USE_CHAIN_INPUT))
    report "ERROR " & IMPLEMENTATION & ": " &
           "Chain input width must have at least " & integer'image(ACCU_WIDTH) & " bits."
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
  ireg(NUM_INPUT_REG).sub <= sub;

  -- LSB bound data inputs
  ireg(NUM_INPUT_REG).x0 <= resize(x0,MAX_WIDTH_X);
  ireg(NUM_INPUT_REG).y0 <= resize(y0,MAX_WIDTH_Y);
  ireg(NUM_INPUT_REG).x1 <= resize(x1,MAX_WIDTH_X);
  ireg(NUM_INPUT_REG).y1 <= resize(y1,MAX_WIDTH_Y);

  g_in : if NUM_INPUT_REG>=1 generate
  begin
    g_1 : for n in 1 to NUM_INPUT_REG generate
    begin
      ireg(n-1) <= ireg(n) when (rising_edge(clk) and clkena='1');
    end generate;
  end generate;

  -- multiplier result
  p0 <= resize(ireg(0).x0 * ireg(0).y0, PRODUCT_WIDTH+1);
  p1 <= resize(ireg(0).x1 * ireg(0).y1, PRODUCT_WIDTH+1);

  -- chain input
  g_chain : if USE_CHAIN_INPUT generate
    chainin_i <= chainin(ACCU_WIDTH-1 downto 0);
  end generate;

  -- temporary sum of multiplier result and chain input
  sum <= chainin_i+p0+p1 when (ireg(0).sub="00") else
         chainin_i+p0-p1 when (ireg(0).sub="01") else
         chainin_i-p0+p1 when (ireg(0).sub="10") else
         chainin_i-p0-p1;

  g_accu_off : if NUM_OUTPUT_REG=0 generate
    accu <= sum;
  end generate;
  
  g_accu_on : if NUM_OUTPUT_REG>0 generate
  begin
  p_accu : process(clk)
  begin
    if rising_edge(clk) then
      if clkena='1' then
        if ireg(0).rst='1' then
          accu <= (others=>'0');
        else
          if ireg(0).vld='1' then
            accu <= sum;
          end if;
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
  i_out : entity dsplib.dsp_output_logic
  generic map(
    PIPELINE_STAGES    => NUM_OUTPUT_REG-1,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => ROUND_ENABLE,
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

