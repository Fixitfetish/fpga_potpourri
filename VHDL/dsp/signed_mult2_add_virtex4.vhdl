-------------------------------------------------------------------------------
-- FILE    : signed_mult2_add_virtex4.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 03/Dec/2016
-- VERSION : 0.20
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

-- This implementation requires a two DSP48 Slices and the delay is two system
-- clock cycles when the additional input and output registers are disabled.
-- Refer to Xilinx XtremeDSP User Guide, UG073 (v2.7) May 15, 2008

architecture virtex4 of signed_mult2_add is

  -- accumulator width in bits
  constant ACCU_WIDTH : positive := 48;
  constant ACCU_SHIFTED_WIDTH : positive := ACCU_WIDTH-OUTPUT_SHIFT_RIGHT;

  constant CLKENA : std_logic := '1'; -- clock enable
  constant RESET : std_logic := '0';
  constant LOUT : positive := r_out'length;

  signal rst_i, b_sub_q: std_logic; 
  signal clr_q, clr_i : std_logic; 
  signal vld_i1, vld_i2, vld_q : std_logic;
  signal ax, ay : signed(17 downto 0);
  signal bx, by : signed(17 downto 0);
  signal accu : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal accu_shifted : signed(ACCU_SHIFTED_WIDTH-1 downto 0);
  signal pcout : std_logic_vector(ACCU_WIDTH-1 downto 0);

  signal opmode1_zyx : std_logic_vector(6 downto 0);
  signal opmode2_zyx : std_logic_vector(6 downto 0);
  signal opmode2_zyx_q : std_logic_vector(6 downto 0);

  -- auxiliary function
  function reg1(b:boolean) return integer is
  begin
    if b then return 1; else return 0; end if;
  end function;

  function reg2(b:boolean) return integer is
  begin
    if b then return 2; else return 1; end if;
  end function;

  function const(round: boolean; shifts:natural) return std_logic_vector is
    variable c : std_logic_vector(ACCU_WIDTH-1 downto 0) := (others=>'0'); 
  begin
    if round and shifts>0 and shifts<(ACCU_WIDTH) then
      c(shifts-1) := '1';
    end if;
    return c;
  end function;

begin

  -- check input/output length
  assert (a_x'length<=18 and a_y'length<=18 and b_x'length<=18 and b_y'length<=18)
    report "ERROR signed_mult2_add(virtex4): Multiplier input width cannot exceed 18 bits."
    severity failure;

  -- LSB bound inputs
  ax <= resize(a_x,18);
  ay <= resize(a_y,18);
  bx <= resize(b_x,18);
  by <= resize(b_y,18);

  -- 011 0101 => PCOUT = C +/- (AX*AY + CIN)  .. multiply + round bit
  -- Note that the carry CIN is 0 and not used here. 
  opmode1_zyx <= "0110101";

  -- 010 0000 => P = P +/- CIN  ... hold current accumulator value
  -- 001 0101 => P = PCIN +/- (BX*BY + CIN)  ... enable accumulation
  -- Note that the carry CIN is 0 and not used here. 
  opmode2_zyx <= "0010101" when vld='1' else "0100000";

  g_din : if not INPUT_REG generate
    vld_i1 <= vld;
    rst_i <= rst;
    b_sub_q <= b_sub;
    opmode2_zyx_q <= opmode2_zyx;
  end generate;

  g_din_reg : if INPUT_REG generate
    vld_i1 <= vld when rising_edge(clk);
    rst_i <= rst when rising_edge(clk);
    b_sub_q <= b_sub when rising_edge(clk);
    opmode2_zyx_q <= opmode2_zyx when rising_edge(clk);
  end generate;

  I_DSP48_1 : DSP48
  generic map(
    AREG          => reg1(INPUT_REG),
    BREG          => reg1(INPUT_REG),
    CREG          => 1, -- constant input for rounding
    PREG          => 1, -- output register before PCOUT
    MREG          => 0, -- unused here
    OPMODEREG     => reg1(INPUT_REG),
    SUBTRACTREG   => reg1(INPUT_REG),
    CARRYINSELREG => 0,
    CARRYINREG    => 0,
    B_INPUT       => "DIRECT",
    LEGACY_MODE   => "MULT18X18"
  )
  port map(
    A(17 downto 0)         => std_logic_vector(ax),
    B(17 downto 0)         => std_logic_vector(ay),
    BCIN(17 downto 0)      => (others=>'0'),
    C(47 downto 0)         => const(OUTPUT_ROUND, OUTPUT_SHIFT_RIGHT),
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
    OPMODE                 => opmode1_zyx,
    PCIN                   => (others=>'0'),
    RSTA                   => RESET,
    RSTB                   => RESET,
    RSTC                   => RESET,
    RSTCARRYIN             => RESET,
    RSTCTRL                => RESET,
    RSTM                   => RESET,
    RSTP                   => RESET,
    SUBTRACT               => a_sub,
    BCOUT                  => open,
    P(47 downto 0)         => open,
    PCOUT                  => pcout
  );

  I_DSP48_2 : DSP48
  generic map(
    AREG          => reg2(INPUT_REG),
    BREG          => reg2(INPUT_REG),
    CREG          => 0, -- C is unused here
    PREG          => 1, -- accumulation/output register always enabled
    MREG          => 0, -- unused here
    OPMODEREG     => 1,
    SUBTRACTREG   => 1,
    CARRYINSELREG => 0,
    CARRYINREG    => 0,
    B_INPUT       => "DIRECT",
    LEGACY_MODE   => "MULT18X18"
  )
  port map(
    A(17 downto 0)         => std_logic_vector(bx),
    B(17 downto 0)         => std_logic_vector(by),
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
    OPMODE                 => opmode2_zyx_q,
    PCIN                   => pcout,
    RSTA                   => RESET,
    RSTB                   => RESET,
    RSTC                   => RESET,
    RSTCARRYIN             => RESET,
    RSTCTRL                => RESET,
    RSTM                   => RESET,
    RSTP                   => RESET,
    SUBTRACT               => b_sub_q,
    BCOUT                  => open,
    P(47 downto 0)         => accu,
    PCOUT                  => open
  );

  -- accumulator delay compensation
  vld_i2 <= vld_i1 when rising_edge(clk);
  vld_q <= vld_i2 when rising_edge(clk);

  -- just shift right without rounding because rounding bit is has been added 
  -- within the DSP cell already.
  accu_shifted <= RESIZE(SHIFT_RIGHT(signed(accu),OUTPUT_SHIFT_RIGHT), ACCU_SHIFTED_WIDTH);

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
