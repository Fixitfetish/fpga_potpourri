-------------------------------------------------------------------------------
--! @file       signed_mult2_accu_behave.vhdl
--! @author     Fixitfetish
--! @date       30/Jan/2017
--! @version    0.80
--! @copyright  MIT License
--! @note       VHDL-1993
-------------------------------------------------------------------------------
-- Copyright (c) 2016-2017 Fixitfetish
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library fixitfetish;
 use fixitfetish.ieee_extension.all;

--! @brief This implementation is a behavioral model of the entity 
--! @link signed_mult_accu signed_mult_accu @endlink for simulation.
--! One signed multiplication is performed and results are accumulated.
--! 
--! * Input Data      : 2 signed values
--! * Input Register  : optional, at least one is strongly recommended
--! * Accu Register   : 64 bits, always enabled
--! * Rounding        : optional half-up
--! * Output Data     : 1x signed value, max 64 bits
--! * Output Register : optional, after rounding, shift-right and saturation
--! * Pipeline stages : NUM_INPUT_REG + 1 + NUM_OUTPUT_REG

architecture behave of signed_mult_accu is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "signed_mult_accu(behave)";

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
  constant PRODUCT_WIDTH : natural := x'length + y'length;
  constant MAX_GUARD_BITS : natural := ACCU_WIDTH - PRODUCT_WIDTH;
  constant GUARD_BITS_EVAL : natural := guard_bits(NUM_SUMMAND,MAX_GUARD_BITS);
  constant ACCU_USED_WIDTH : natural := PRODUCT_WIDTH + GUARD_BITS_EVAL;
  constant ACCU_USED_SHIFTED_WIDTH : natural := ACCU_USED_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result'length;

  -- input register pipeline
  type r_ireg is
  record
    rst, vld : std_logic;
    clr : std_logic;
    sub : std_logic;
    x   : signed(17 downto 0);
    y   : signed(17 downto 0);
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
  signal rslt : array_oreg(NUM_OUTPUT_REG downto 0);

  signal vld_q : std_logic := '0';
  signal p, sum : signed(PRODUCT_WIDTH-1 downto 0);
  signal accu : signed(ACCU_WIDTH-1 downto 0);
  signal chainin_i : signed(ACCU_WIDTH-1 downto 0) := (others=>'0');
  signal accu_used : signed(ACCU_USED_WIDTH-1 downto 0);
  signal accu_used_shifted : signed(ACCU_USED_SHIFTED_WIDTH-1 downto 0);

  -- clock enable +++ TODO
  constant clkena : std_logic := '1';

begin

  -- check chain in/out length
  assert (chainin'length>=ACCU_WIDTH or (not USE_CHAIN_INPUT))
    report "ERROR " & IMPLEMENTATION & ": " &
           "Chain input width must be " & integer'image(ACCU_WIDTH) & " bits."
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

  -- pipeline inputs
  ireg(NUM_INPUT_REG).rst <= rst;
  ireg(NUM_INPUT_REG).clr <= clr;
  ireg(NUM_INPUT_REG).vld <= vld;
  ireg(NUM_INPUT_REG).sub <= sub;

  -- LSB bound data inputs
  ireg(NUM_INPUT_REG).x <= resize(x,18);
  ireg(NUM_INPUT_REG).y <= resize(y,18);

  g_in : if NUM_INPUT_REG>=1 generate
    p_in : process(clk)
    begin
     if rising_edge(clk) then
      if clkena='1' then
        for n in 1 to NUM_INPUT_REG loop
          ireg(n-1) <= ireg(n);
        end loop;
      end if;
     end if;
    end process;
  end generate;

  p <= ireg(0).x * ireg(0).y;
  sum <= -p when ireg(0).sub='1' else p;

  g_chain : if USE_CHAIN_INPUT generate
    chainin_i <= chainin(ACCU_WIDTH-1 downto 0);
  end generate;

  p_accu : process(clk)
  begin
    if rising_edge(clk) then
      if ireg(0).clr='1' then
        if ireg(0).vld='1' then
          accu <= chainin_i + resize(sum, ACCU_WIDTH);
        else
          accu <= (others=>'0');
        end if;
      else  
        if ireg(0).vld='1' then
          accu <= accu + chainin_i + resize(sum, ACCU_WIDTH);
        end if;
      end if;
      vld_q <= ireg(0).vld;
    end if;
  end process;

  chainout(ACCU_WIDTH-1 downto 0) <= accu;
  g_chainout : for n in ACCU_WIDTH to (chainout'length-1) generate
    -- sign extension (for simulation and to avoid warnings)
    chainout(n) <= accu(ACCU_WIDTH-1);
  end generate;

  -- cut off unused sign extension bits
  -- (This reduces the logic consumption in the following steps when rounding,
  --  saturation and/or overflow detection is enabled.)
  accu_used <= accu(ACCU_USED_WIDTH-1 downto 0);

  -- shift right and round 
  g_rnd_off : if (not ROUND_ENABLE) generate
    accu_used_shifted <= RESIZE(SHIFT_RIGHT_ROUND(accu_used, OUTPUT_SHIFT_RIGHT),ACCU_USED_SHIFTED_WIDTH);
  end generate;
  g_rnd_on : if (ROUND_ENABLE) generate
    accu_used_shifted <= RESIZE(SHIFT_RIGHT_ROUND(accu_used, OUTPUT_SHIFT_RIGHT, nearest),ACCU_USED_SHIFTED_WIDTH);
  end generate;
  
  p_out : process(accu_used_shifted, vld_q)
    variable v_dat : signed(OUTPUT_WIDTH-1 downto 0);
    variable v_ovf : std_logic;
  begin
    RESIZE_CLIP(din=>accu_used_shifted, dout=>v_dat, ovfl=>v_ovf, clip=>OUTPUT_CLIP);
    rslt(0).vld <= vld_q; 
    rslt(0).dat <= v_dat; 
    if OUTPUT_OVERFLOW then rslt(0).ovf<=v_ovf; else rslt(0).ovf<='0'; end if;
  end process;

  g_out_reg : if NUM_OUTPUT_REG>=1 generate
    g_loop : for n in 1 to NUM_OUTPUT_REG generate
      rslt(n) <= rslt(n-1) when rising_edge(clk);
    end generate;
  end generate;

  -- map result to output port
  result     <= rslt(NUM_OUTPUT_REG).dat;
  result_vld <= rslt(NUM_OUTPUT_REG).vld;
  result_ovf <= rslt(NUM_OUTPUT_REG).ovf;

  -- report constant number of pipeline register stages
  PIPESTAGES <= NUM_INPUT_REG + 1 + NUM_OUTPUT_REG;

end architecture;

