-------------------------------------------------------------------------------
-- FILE    : signed_mult2_add_behave.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 03/Dec/2016
-- VERSION : 0.10
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


architecture behave of signed_mult2_add is

  -- accumulator width in bits
  constant ACCU_WIDTH : positive := 64;
  constant ACCU_SHIFTED_WIDTH : positive := ACCU_WIDTH-OUTPUT_SHIFT_RIGHT;
  constant LP : positive := a_x'length+a_y'length; -- product length
  constant LOUT : positive := r_out'length; -- output length

  signal vld_i, vld_q : std_logic;
  signal rst_i, asub_i, bsub_i : std_logic;
  signal ax_i : signed(a_x'length-1 downto 0);
  signal ay_i : signed(a_y'length-1 downto 0);
  signal bx_i : signed(b_x'length-1 downto 0);
  signal by_i : signed(b_y'length-1 downto 0);
  signal p1, p2, temp : signed(LP downto 0);
  signal accu : signed(ACCU_WIDTH-1 downto 0);
  signal accu_shifted : signed(ACCU_SHIFTED_WIDTH-1 downto 0);

begin

  g_din : if not INPUT_REG generate
    rst_i <= rst; vld_i <= vld;
    ax_i <= a_x; ay_i <= a_y; asub_i <= a_sub; 
    bx_i <= b_x; by_i <= b_y; bsub_i <= b_sub; 
  end generate;

  g_din_reg : if INPUT_REG generate
    process(clk)
    begin if rising_edge(clk) then
      rst_i <= rst; vld_i <= vld;
      ax_i <= a_x; ay_i <= a_y; asub_i <= a_sub; 
      bx_i <= b_x; by_i <= b_y; bsub_i <= b_sub; 
    end if; end process;
  end generate;

  p1 <= resize(ax_i*ay_i, LP+1);
  p2 <= resize(bx_i*by_i, LP+1);

  temp <=  p1+p2 when (asub_i='0' and bsub_i='0') else
           p1-p2 when (asub_i='0' and bsub_i='1') else
          -p1+p2 when (asub_i='1' and bsub_i='0') else
          -p1-p2;

  p_accu : process(clk)
  begin
    if rising_edge(clk) then
      if rst_i='1' then
        accu <= (others=>'0');
      else
        if vld_i='1' then
          accu <= resize(temp, ACCU_WIDTH);
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

