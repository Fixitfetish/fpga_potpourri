-------------------------------------------------------------------------------
-- FILE    : signed_mult2_sum.virtex4.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 22/Jan/2017
-- VERSION : 0.40
-- VHDL    : 1993
-- LICENSE : MIT License
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension.all;

library unisim;
  use unisim.vcomponents.all;

-- synopsys translate_off
library XilinxCoreLib;
-- synopsys translate_on

-- This implementation requires a two DSP48 Slices and the delay is two system
-- clock cycles when the additional input and output registers are disabled.
-- Refer to Xilinx XtremeDSP User Guide, UG073 (v2.7) May 15, 2008

architecture virtex4 of signed_mult2_sum is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "signed_mult2_sum(virtex4)";

  -- accumulator width in bits
  constant ACCU_WIDTH : positive := 48;
  constant ACCU_SHIFTED_WIDTH : positive := ACCU_WIDTH-OUTPUT_SHIFT_RIGHT;

  constant CLKENA : std_logic := '1'; -- clock enable
  constant RESET : std_logic := '0';
  constant LOUT : positive := result'length;

  signal rst_i, b_sub: std_logic; 
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
  function num_in_regs(n:integer) return integer is
  begin
    if n>=2 then return 2;
    elsif n=1  then return 1;
    else return 0; end if;
  end function;

  function num_ctrl_regs(n:integer) return integer is
  begin
    if n>=1  then return 1;
    else return 0; end if;
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
  assert (x0'length<=18 and y0'length<=18 and x1'length<=18 and y1'length<=18)
    report "ERROR " & IMPLEMENTATION & ": Multiplier input width cannot exceed 18 bits."
    severity failure;

  -- LSB bound inputs
  ax <= resize(x0,18);
  ay <= resize(y0,18);
  bx <= resize(x1,18);
  by <= resize(y1,18);

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
    b_sub <= sub(1);
    opmode2_zyx_q <= opmode2_zyx;
  end generate;

  g_din_reg : if INPUT_REG generate
    vld_i1 <= vld when rising_edge(clk);
    rst_i <= rst when rising_edge(clk);
    b_sub <= sub(1) when rising_edge(clk);
    opmode2_zyx_q <= opmode2_zyx when rising_edge(clk);
  end generate;

  DSP48_1 : DSP48
  generic map(
    AREG          => num_in_regs(NUM_INPUT_REG),
    BREG          => num_in_regs(NUM_INPUT_REG),
    CREG          => 1, -- constant input for rounding
    PREG          => 1, -- output register before PCOUT
    MREG          => 0, -- unused here
    OPMODEREG     => num_ctrl_regs(NUM_INPUT_REG),
    SUBTRACTREG   => num_ctrl_regs(NUM_INPUT_REG),
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
    SUBTRACT               => sub(0),
    BCOUT                  => open,
    P(47 downto 0)         => open,
    PCOUT                  => pcout
  );

  DSP48_2 : DSP48
  generic map(
    AREG          => num_in_regs(NUM_INPUT_REG+1), -- additional pipeline register
    BREG          => num_in_regs(NUM_INPUT_REG+1), -- additional pipeline register
    CREG          => 0, -- C is unused here
    PREG          => 1, -- accumulation/output register always enabled
    MREG          => 0, -- unused here
    OPMODEREG     => 1, -- additional pipeline register
    SUBTRACTREG   => 1, -- additional pipeline register
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
    SUBTRACT               => b_sub,
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
      result_vld <= vld_q; 
      result <= v_dout; 
      if OUTPUT_OVERFLOW then result_ovf<=v_ovfl; else result_ovf<='0'; end if;
    end process;
  end generate;

  g_dout_reg : if OUTPUT_REG generate
    process(clk)
      variable v_dout : signed(LOUT-1 downto 0);
      variable v_ovfl : std_logic;
    begin
      if rising_edge(clk) then
        RESIZE_CLIP(din=>accu_shifted, dout=>v_dout, ovfl=>v_ovfl, clip=>OUTPUT_CLIP);
        result_vld <= vld_q; 
        result <= v_dout; 
        if OUTPUT_OVERFLOW then result_ovf<=v_ovfl; else result_ovf<='0'; end if;
      end if;
    end process;
  end generate;

  -- report constant number of pipeline register stages
  PIPESTAGES <= 4 when (INPUT_REG and OUTPUT_REG) else
                3 when (INPUT_REG or OUTPUT_REG) else
                2;

end architecture;
