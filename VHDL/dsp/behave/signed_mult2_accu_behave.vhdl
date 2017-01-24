-------------------------------------------------------------------------------
-- FILE    : signed_mult2_accu_behave.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 24/Jan/2017
-- VERSION : 0.85
-- VHDL    : 1993
-- LICENSE : MIT License
-------------------------------------------------------------------------------
-- Copyright (c) 2016-2017 Fixitfetish
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library fixitfetish;
 use fixitfetish.ieee_extension.all;

-- This implementation is a behavioral model for simulation.
--
-- Input Data      : 2x2 signed values
-- Input Register  : optional, strongly recommended
-- Accu Register   : 64 bits, always enabled
-- Rounding        : optional half-up
-- Output Data     : 1x signed value, max 64 bits
-- Output Register : optional, after rounding, shift-right and saturation
-- Overall pipeline stages : 1,2,3,.. dependent on configuration

architecture behave of signed_mult2_accu is

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
  constant ROUND_ENABLE : boolean := OUTPUT_ROUND and (OUTPUT_SHIFT_RIGHT>0);
  constant PRODUCT_WIDTH : natural := x0'length + y0'length;
  constant MAX_GUARD_BITS : natural := ACCU_WIDTH - PRODUCT_WIDTH;
  constant GUARD_BITS_EVAL : natural := guard_bits(NUM_SUMMAND,MAX_GUARD_BITS);
  constant ACCU_USED_WIDTH : natural := PRODUCT_WIDTH + GUARD_BITS_EVAL;
  constant ACCU_USED_SHIFTED_WIDTH : natural := ACCU_USED_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := r_out'length;

  -- input register pipeline
  type t_ireg is
  record
    rst, vld : std_logic;
    clr : std_logic;
    sub : std_logic_vector(sub'range);
    x0, y0 : signed(17 downto 0);
    x1, y1 : signed(17 downto 0);
  end record;
  type array_ireg is array(integer range <>) of t_ireg;
  signal ireg : array_ireg(NUM_INPUT_REG downto 0);

  signal vld_q : std_logic;
  signal p0, p1, sum : signed(PRODUCT_WIDTH downto 0);
  signal accu : signed(ACCU_WIDTH-1 downto 0);
  signal chainin_i : signed(ACCU_WIDTH-1 downto 0) := (others=>'0');
  signal accu_used : signed(ACCU_USED_WIDTH-1 downto 0);
  signal accu_used_shifted : signed(ACCU_USED_SHIFTED_WIDTH-1 downto 0);

  -- clock enable
  signal clkena : std_logic := '1';

begin

  -- check chain in/out length
  assert (chainin'length=ACCU_WIDTH or (not USE_CHAININ))
    report "ERROR signed_mult2_accu(behave) : " & 
           "Chain input width must be " & integer'image(ACCU_WIDTH) & " bits."
    severity failure;

  assert PRODUCT_WIDTH<=ACCU_WIDTH
    report "ERROR signed_mult2_accu(behave) : " & 
           "Resulting product width exceeds accumulator width of " & integer'image(ACCU_WIDTH)
    severity failure;

  assert GUARD_BITS_EVAL<=MAX_GUARD_BITS
    report "ERROR signed_mult2_accu(behave) : " & 
           "Maximum number of accumulator bits is " & integer'image(ACCU_WIDTH) & " ." &
           "Input bit widths allow only maximum number of guard bits = " & integer'image(MAX_GUARD_BITS)
    severity failure;

  assert OUTPUT_WIDTH<ACCU_USED_SHIFTED_WIDTH or not(OUTPUT_CLIP or OUTPUT_OVERFLOW)
    report "ERROR signed_mult2_accu(behave) : " & 
           "More guard bits required for saturation/clipping and/or overflow detection."
    severity failure;

  -- pipeline inputs
  ireg(NUM_INPUT_REG).rst <= rst;
  ireg(NUM_INPUT_REG).clr <= clr;
  ireg(NUM_INPUT_REG).vld <= vld;
  ireg(NUM_INPUT_REG).sub <= sub;

  -- LSB bound data inputs
  ireg(NUM_INPUT_REG).x0 <= resize(x0,18);
  ireg(NUM_INPUT_REG).y0 <= resize(y0,18);
  ireg(NUM_INPUT_REG).x1 <= resize(x1,18);
  ireg(NUM_INPUT_REG).y1 <= resize(y1,18);

  g_in : if NUM_INPUT_REG>=1 generate
  begin
    p1 : process(clk)
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

  p0 <= resize(ireg(0).x0 * ireg(0).y0, PRODUCT_WIDTH+1);
  p1 <= resize(ireg(0).x1 * ireg(0).y1, PRODUCT_WIDTH+1);

  sum <=  p0+p1 when (ireg(0).sub="00") else
          p0-p1 when (ireg(0).sub="01") else
         -p0+p1 when (ireg(0).sub="10") else
         -p0-p1;

  g_chain : if USE_CHAININ generate
    chainin_i <= chainin(ACCU_WIDTH-1 downto 0);
  end generate;

  p_accu : process(clk)
  begin
    if rising_edge(clk) then
      if clkena='1' then
        if ireg(0).rst='1' then
          accu <= (others=>'0');
        else
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
        end if;
        vld_q <= ireg(0).vld;
      end if;
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
  
  g_dout : if not OUTPUT_REG generate
    process(accu_used_shifted, vld_q)
      variable v_dout : signed(OUTPUT_WIDTH-1 downto 0);
      variable v_ovfl : std_logic;
    begin
      RESIZE_CLIP(din=>accu_used_shifted, dout=>v_dout, ovfl=>v_ovfl, clip=>OUTPUT_CLIP);
      r_vld <= vld_q; 
      r_out <= v_dout; 
      if OUTPUT_OVERFLOW then r_ovf<=v_ovfl; else r_ovf<='0'; end if;
    end process;
  end generate;

  g_dout_reg : if OUTPUT_REG generate
    process(clk)
      variable v_dout : signed(OUTPUT_WIDTH-1 downto 0);
      variable v_ovfl : std_logic;
    begin
      if rising_edge(clk) then
        if clkena='1' then
          RESIZE_CLIP(din=>accu_used_shifted, dout=>v_dout, ovfl=>v_ovfl, clip=>OUTPUT_CLIP);
          r_vld <= vld_q;
          r_out <= v_dout;
          if OUTPUT_OVERFLOW then r_ovf<=v_ovfl; else r_ovf<='0'; end if;
        end if;
      end if;
    end process;
  end generate;

  -- report constant number of pipeline register stages
  PIPE <= NUM_INPUT_REG+2 when OUTPUT_REG else NUM_INPUT_REG+1;

end architecture;

