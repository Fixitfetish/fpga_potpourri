-------------------------------------------------------------------------------
--! @file       signed_add2_accu.behave.vhdl
--! @author     Fixitfetish
--! @date       10/Feb/2018
--! @version    0.10
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

--! @brief This implementation is a behavioral model of the entity signed_add2_accu
--! for simulation.
--! A two signed values are added with full precision.
--! The results of this operation can be accumulated over several cycles.
--! The addition and accumulation of all inputs is LSB bound.
--! 
--! * Input Data      : 2 signed values, each max 64 bits
--! * Input Register  : optional, at least one is strongly recommended
--! * Input Chain     : optional, 64 bits
--! * Accu Register   : 64 bits, first output register (strongly recommended in most cases)
--! * Rounding        : optional half-up
--! * Output Data     : 1x signed value, max 64 bits
--! * Output Register : optional, after rounding, shift-right and saturation
--! * Pipeline stages : NUM_INPUT_REG + NUM_OUTPUT_REG

architecture behave of signed_add2_accu is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "signed_add2_accu(behave)";

  -- derived constants
  constant INPUT_WIDTH : natural := MAXIMUM(a'length,z'length);
  constant MAX_GUARD_BITS : natural := ACCU_WIDTH - INPUT_WIDTH;
  constant GUARD_BITS_EVAL : natural := accu_guard_bits(NUM_SUMMAND,MAX_GUARD_BITS,IMPLEMENTATION);
  constant ACCU_USED_WIDTH : natural := INPUT_WIDTH + GUARD_BITS_EVAL;
  constant ACCU_USED_SHIFTED_WIDTH : natural := ACCU_USED_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result'length;

  -- A input register pipeline
  type r_a_ireg is
  record
    rst, vld, clr : std_logic;
    a   : signed(a'length-1 downto 0);
  end record;
  type array_a_ireg is array(integer range <>) of r_a_ireg;
  signal a_ireg : array_a_ireg(NUM_INPUT_REG_A downto 0);

  -- Z input register pipeline
  type array_z_ireg is array(integer range <>) of signed(z'length-1 downto 0);
  signal z_ireg : array_z_ireg(NUM_INPUT_REG_Z downto 0);

  signal sum, c : signed(ACCU_WIDTH-1 downto 0) := (others=>'0');
  signal accu : signed(ACCU_WIDTH-1 downto 0);
  signal accu_vld : std_logic := '0';
  signal accu_used : signed(ACCU_USED_WIDTH-1 downto 0);

  -- clock enable +++ TODO
  constant clkena : std_logic := '1';

begin

  assert a'length<=ACCU_WIDTH
    report "ERROR " & IMPLEMENTATION & ": " &
           "Input A width exceeds accumulator width of " & integer'image(ACCU_WIDTH)
    severity failure;

  assert z'length<=ACCU_WIDTH
    report "ERROR " & IMPLEMENTATION & ": " &
           "Input Z width exceeds accumulator width of " & integer'image(ACCU_WIDTH)
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

  -- A input pipeline
  a_ireg(NUM_INPUT_REG_A).rst <= rst;
  a_ireg(NUM_INPUT_REG_A).vld <= vld;
  a_ireg(NUM_INPUT_REG_A).clr <= clr;
  a_ireg(NUM_INPUT_REG_A).a   <= a;
  ga : if NUM_INPUT_REG_A>=1 generate
  begin
    gn : for n in 1 to NUM_INPUT_REG_A generate
    begin
      a_ireg(n-1) <= a_ireg(n) when (rising_edge(clk) and clkena='1');
    end generate;
  end generate;

  -- Z input pipeline
  z_ireg(NUM_INPUT_REG_Z) <= z;
  gz : if NUM_INPUT_REG_Z>=1 generate
  begin
    gn : for n in 1 to NUM_INPUT_REG_Z generate
    begin
      z_ireg(n-1) <= z_ireg(n) when (rising_edge(clk) and clkena='1');
    end generate;
  end generate;

  -- chain input
  g_chainin : if USE_CHAIN_INPUT generate
    c <= chainin(ACCU_WIDTH-1 downto 0);
  end generate;

  g_zin : if not USE_CHAIN_INPUT generate
    c <= resize(z_ireg(0),ACCU_WIDTH);
  end generate;

  -- temporary sum of a and Z/chainin
  sum <= resize(a_ireg(0).a,ACCU_WIDTH) + c ;

  g_accu_off : if NUM_OUTPUT_REG=0 generate
    accu <= sum;
  end generate;
  
  g_accu_on : if NUM_OUTPUT_REG>0 generate
  begin
  p_accu : process(clk)
  begin
    if rising_edge(clk) then
      if clkena='1' then
        if a_ireg(0).clr='1' then
          if a_ireg(0).vld='1' then
            accu <= sum;
          else
            accu <= (others=>'0');
          end if;
        else  
          if a_ireg(0).vld='1' then
            accu <= accu + sum;
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
    accu_vld <= a_ireg(0).vld when (rising_edge(clk) and clkena='1');
  end generate;
  g_dspreg_off : if NUM_OUTPUT_REG<=0 generate
    accu_vld <= a_ireg(0).vld;
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
  PIPESTAGES <= NUM_INPUT_REG_A + NUM_OUTPUT_REG;

end architecture;
