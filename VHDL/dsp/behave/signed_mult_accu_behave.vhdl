-------------------------------------------------------------------------------
-- FILE    : signed_mult_accu_behave.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 17/Dec/2016
-- VERSION : 0.60
-- VHDL    : 1993
-- LICENSE : MIT License
-------------------------------------------------------------------------------
-- Copyright (c) 2016 Fixitfetish
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library fixitfetish;
 use fixitfetish.ieee_extension.all;

architecture behave of signed_mult_accu is

 -- local auxiliary
 function default_if_negative (x:integer; dflt: natural) return natural is
 begin
   if x<0 then return dflt; else return x; end if;
 end function;

  -- accumulator width in bits
  constant ACCU_WIDTH : positive := 64;

  -- derived constants
  constant PRODUCT_WIDTH : natural := x'length + y'length;
  constant MAX_GUARD_BITS : natural := ACCU_WIDTH - PRODUCT_WIDTH;
  constant GUARD_BITS_EVAL : natural := default_if_negative(GUARD_BITS,MAX_GUARD_BITS);
  constant ACCU_USED_WIDTH : natural := PRODUCT_WIDTH + GUARD_BITS_EVAL;
  constant ACCU_USED_SHIFTED_WIDTH : natural := ACCU_USED_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := r_out'length;

  signal vld_i, vld_q : std_logic := '0';
  signal clr_i, sub_i : std_logic;
  signal x_i : signed(x'length-1 downto 0);
  signal y_i : signed(y'length-1 downto 0);
  signal p, temp : signed(PRODUCT_WIDTH-1 downto 0);
  signal accu : signed(ACCU_WIDTH-1 downto 0);
  signal accu_used : signed(ACCU_USED_WIDTH-1 downto 0);
  signal accu_used_shifted : signed(ACCU_USED_SHIFTED_WIDTH-1 downto 0);

begin

  assert PRODUCT_WIDTH<=ACCU_WIDTH
    report "ERROR signed_mult_accu(behave) : " & 
           "Resulting product width exceeds accumulator width of " & integer'image(ACCU_WIDTH)
    severity failure;

  assert GUARD_BITS_EVAL<=MAX_GUARD_BITS
    report "ERROR signed_mult_accu(behave) : " & 
           "Maximum number of accumulator bits is " & integer'image(ACCU_WIDTH) & " ." &
           "Input bit widths allow only maximum number of guard bits = " & integer'image(MAX_GUARD_BITS)
    severity failure;

  assert OUTPUT_WIDTH<ACCU_USED_SHIFTED_WIDTH or not(OUTPUT_CLIP or OUTPUT_OVERFLOW)
    report "ERROR signed_mult_accu(behave) : " & 
           "More guard bits required for saturation/clipping and/or overflow detection."
    severity failure;

  g_din : if not INPUT_REG generate
    vld_i  <= vld;
    clr_i  <= clr;
    sub_i  <= sub;
    x_i    <= x; 
    y_i    <= y;
  end generate;

  g_din_reg : if INPUT_REG generate
    vld_i  <= vld when rising_edge(clk);
    clr_i  <= clr when rising_edge(clk);
    sub_i  <= sub when rising_edge(clk);
    x_i    <= x   when rising_edge(clk); 
    y_i    <= y   when rising_edge(clk);
  end generate;

  p <= x_i * y_i;
  temp <= -p when sub_i='1' else p;

  p_accu : process(clk)
  begin
    if rising_edge(clk) then
      if clr_i='1' then
        if vld_i='1' then
          accu <= resize(temp, ACCU_WIDTH);
        else
          accu <= (others=>'0');
        end if;
      else  
        if vld_i='1' then
          accu <= accu + resize(temp, ACCU_WIDTH);
        end if;
      end if;
      vld_q <= vld_i;
    end if;
  end process;

  -- cut off unused sign extension bits
  -- (This reduces the logic consumption in the following steps when rounding,
  --  saturation and/or overflow detection is enabled.)
  accu_used <= accu(ACCU_USED_WIDTH-1 downto 0);

  -- shift right and round 
  g_rnd_off : if ((not OUTPUT_ROUND) or OUTPUT_SHIFT_RIGHT=0) generate
    accu_used_shifted <= RESIZE(SHIFT_RIGHT_ROUND(accu_used, OUTPUT_SHIFT_RIGHT),ACCU_USED_SHIFTED_WIDTH);
  end generate;
  g_rnd_on : if (OUTPUT_ROUND and OUTPUT_SHIFT_RIGHT>0) generate
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
        RESIZE_CLIP(din=>accu_used_shifted, dout=>v_dout, ovfl=>v_ovfl, clip=>OUTPUT_CLIP);
        r_vld <= vld_q; 
        r_out <= v_dout; 
        if OUTPUT_OVERFLOW then r_ovf<=v_ovfl; else r_ovf<='0'; end if;
      end if;
    end process;
  end generate;

  -- report constant number of pipeline register stages
  PIPE <= 3 when (INPUT_REG and OUTPUT_REG) else
          2 when (INPUT_REG or OUTPUT_REG) else
          1;

end architecture;

