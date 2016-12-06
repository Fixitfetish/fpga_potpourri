-------------------------------------------------------------------------------
-- FILE    : signed_mult_accu_behave.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 03/Dec/2016
-- VERSION : 0.40
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

  -- accumulator width in bits
  constant ACCU_WIDTH : positive := 64;
  constant ACCU_SHIFTED_WIDTH : positive := ACCU_WIDTH-OUTPUT_SHIFT_RIGHT;

  constant LP : positive := x'length+y'length; -- product length
  constant LOUT : positive := r_out'length;

  signal vld_i, vld_q : std_logic := '0';
  signal clr_i, sub_i : std_logic;
  signal x_i : signed(x'length-1 downto 0);
  signal y_i : signed(y'length-1 downto 0);
  signal p, temp : signed(LP-1 downto 0);
  signal accu : signed(ACCU_WIDTH-1 downto 0);
  signal accu_shifted : signed(ACCU_SHIFTED_WIDTH-1 downto 0);

begin

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

  -- shift right and round 
  g_rnd_off : if ((not OUTPUT_ROUND) or OUTPUT_SHIFT_RIGHT=0) generate
    accu_shifted <= RESIZE(SHIFT_RIGHT_ROUND(accu, OUTPUT_SHIFT_RIGHT),ACCU_SHIFTED_WIDTH);
  end generate;
  g_rnd_on : if (OUTPUT_ROUND and OUTPUT_SHIFT_RIGHT>0) generate
    accu_shifted <= RESIZE(SHIFT_RIGHT_ROUND(accu, OUTPUT_SHIFT_RIGHT, nearest),ACCU_SHIFTED_WIDTH);
  end generate;

  g_dout : if not OUTPUT_REG generate
    process(accu_shifted, vld_q)
      variable v_dout : signed(LOUT-1 downto 0);
      variable v_ovfl : std_logic;
    begin
      RESIZE_CLIP(din=>accu_shifted, dout=>v_dout, ovfl=>v_ovfl, clip=>OUTPUT_CLIP);
      r_vld <= vld_q;
      r_out <= v_dout;
      if OUTPUT_OVERFLOW then r_ovf<=v_ovfl; else r_ovf<='0'; end if;
    end process;
  end generate;

  g_dout_reg : if OUTPUT_REG generate
    process(clk)
      variable v_dout : signed(LOUT-1 downto 0);
      variable v_ovfl : std_logic;
    begin
      if rising_edge(clk) then
        RESIZE_CLIP(din=>accu_shifted, dout=>v_dout, ovfl=>v_ovfl, clip=>OUTPUT_CLIP);
        r_vld <= vld_q;
        r_out <= v_dout;
        if OUTPUT_OVERFLOW then r_ovf<=v_ovfl; else r_ovf<='0'; end if;
      end if;
    end process;
  end generate;

end architecture;

