-------------------------------------------------------------------------------
-- FILE    : signed_mult_accu_virtex4.vhdl
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

-- synopsys translate_off
library XilinxCoreLib;
-- synopsys translate_on

library unisim;
 use unisim.vcomponents.all;

-- This implementation requires a single DSP48 Slice.
-- Refer to Xilinx XtremeDSP User Guide, UG073 (v2.7) May 15, 2008

architecture virtex4 of signed_mult_accu is

  -- accumulator width in bits
  constant ACCU_WIDTH : positive := 48;
  constant ACCU_SHIFTED_WIDTH : positive := ACCU_WIDTH-OUTPUT_SHIFT_RIGHT;

  constant CLKENA : std_logic := '1'; -- clock enable
  constant RESET : std_logic := '0';
  constant LOUT : positive := r_out'length;

  signal vld_i, vld_q : std_logic := '0';
  signal a, b : signed(17 downto 0);
  signal accu : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal accu_shifted : signed(ACCU_SHIFTED_WIDTH-1 downto 0);

  signal opmode_xy : std_logic_vector(3 downto 0);
  signal opmode_z : std_logic_vector(2 downto 0);

  -- auxiliary function
  function to_integer(b:boolean) return integer is
  begin
    if b then return 1; else return 0; end if;
  end function;

begin

  -- check input/output length
  assert (x'length<=18 and y'length<=18)
    report "ERROR signed_mult_accu(virtex4): Multiplier input width cannot exceed 18 bits."
    severity failure;

  -- input register delay compensation
  g_din : if not INPUT_REG generate
    vld_i  <= vld;
  end generate;
  g_din_reg : if INPUT_REG generate
    vld_i  <= vld when rising_edge(clk);
  end generate;

  -- LSB bound inputs
  a <= resize(x,18);
  b <= resize(y,18);

  -- 0000 => P = P +/- CIN  ... hold current accumulator value
  -- 0101 => P = P +/- (AxB+CIN)  ... enable accumulation
  -- Note that the carry CIN is 0 and not used here. 
  opmode_xy <= "0101" when vld='1' else "0000";

  -- 000 => clear accumulator
  -- 010 => accumulate
  opmode_z <= "000" when clr='1' else "010";

  I_DSP48 : DSP48
  generic map(
    AREG          => to_integer(INPUT_REG),
    BREG          => to_integer(INPUT_REG),
    CREG          => 0, -- C is unused here
    PREG          => 1, -- accumulation/output register always enabled
    MREG          => 0, -- unused here
    OPMODEREG     => to_integer(INPUT_REG),
    SUBTRACTREG   => to_integer(INPUT_REG),
    CARRYINSELREG => 0,
    CARRYINREG    => 0,
    B_INPUT       => "DIRECT",
    LEGACY_MODE   => "MULT18X18"
  )
  port map(
    A(17 downto 0)         => std_logic_vector(a),
    B(17 downto 0)         => std_logic_vector(b),
    BCIN(17 downto 0)      => (others=>'0'),
    C(47 downto 0)         => (others=>'0'),
    CARRYIN                => '0',
    CARRYINSEL(1 downto 0) => (others=>'0'),
    CEA                    => CLKENA,
    CEB                    => CLKENA,
    CEC                    => CLKENA,
    CECARRYIN              => '0',
    CECINSUB               => CLKENA,
    CECTRL                 => CLKENA,
    CEM                    => CLKENA,
    CEP                    => CLKENA,
    CLK                    => clk,
    OPMODE(3 downto 0)     => opmode_xy,
    OPMODE(6 downto 4)     => opmode_z,
    PCIN                   => (others=>'0'),
    RSTA                   => RESET,
    RSTB                   => RESET,
    RSTC                   => RESET,
    RSTCARRYIN             => RESET,
    RSTCTRL                => RESET,
    RSTM                   => RESET,
    RSTP                   => RESET,
    SUBTRACT               => sub,
    BCOUT                  => open,
    P(47 downto 0)         => accu,
    PCOUT                  => open
  );

  -- accumulator delay compensation
  vld_q <= vld_i when rising_edge(clk);

  -- shift right and round 
  g_rnd_off : if ((not OUTPUT_ROUND) or OUTPUT_SHIFT_RIGHT=0) generate
    accu_shifted <= RESIZE(SHIFT_RIGHT_ROUND(signed(accu), OUTPUT_SHIFT_RIGHT),ACCU_SHIFTED_WIDTH);
  end generate;
  g_rnd_on : if (OUTPUT_ROUND and OUTPUT_SHIFT_RIGHT>0) generate
    accu_shifted <= RESIZE(SHIFT_RIGHT_ROUND(signed(accu), OUTPUT_SHIFT_RIGHT, nearest),ACCU_SHIFTED_WIDTH);
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
