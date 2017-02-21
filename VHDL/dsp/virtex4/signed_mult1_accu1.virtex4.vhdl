-------------------------------------------------------------------------------
-- FILE    : signed_mult1_accu1.virtex4.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 20/Jan/2017
-- VERSION : 0.75
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

-- synopsys translate_off
library XilinxCoreLib;
-- synopsys translate_on

library unisim;
 use unisim.vcomponents.all;

-- This implementation requires a single DSP48 Slice.
-- Refer to Xilinx XtremeDSP User Guide, UG073 (v2.7) May 15, 2008

architecture virtex4 of signed_mult1_accu1 is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "signed_mult1_accu1(virtex4)";

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

  function to_integer(b:boolean) return integer is
  begin
    if b then return 1; else return 0; end if;
  end function;

  -- accumulator width in bits
  constant ACCU_WIDTH : positive := 48;

  -- derived constants
  constant PRODUCT_WIDTH : natural := x'length + y'length;
  constant MAX_GUARD_BITS : natural := ACCU_WIDTH - PRODUCT_WIDTH;
  constant GUARD_BITS_EVAL : natural := guard_bits(NUM_SUMMAND,MAX_GUARD_BITS);
  constant ACCU_USED_WIDTH : natural := PRODUCT_WIDTH + GUARD_BITS_EVAL;
  constant ACCU_USED_SHIFTED_WIDTH : natural := ACCU_USED_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := r_out'length;

  constant CLKENA : std_logic := '1'; -- clock enable
  constant RESET : std_logic := '0';

  signal vld_i, vld_q : std_logic := '0';
  signal a, b : signed(17 downto 0);
  signal accu : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal accu_used_shifted : signed(ACCU_USED_SHIFTED_WIDTH-1 downto 0);

  -- initial rounding
  signal c : std_logic_vector(ACCU_WIDTH-1 downto 0) := (others=>'0');

  signal opmode_xy : std_logic_vector(3 downto 0);
  signal opmode_z : std_logic_vector(2 downto 0);

begin

  -- check input/output length
  assert (x'length<=18 and y'length<=18)
    report "ERROR " & IMPLEMENTATION & ": Multiplier input width cannot exceed 18 bits."
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

  -- rounding bit generation
  g_rnd_on : if (OUTPUT_ROUND and OUTPUT_SHIFT_RIGHT>0) generate
    c(OUTPUT_SHIFT_RIGHT-1) <= '1';
  end generate;

  -- 0000 =>  XY = +/- CIN  ... hold current accumulator value
  -- 0101 =>  XY = +/- (AxB+CIN) ... enable product accumulation
  -- Note that the carry CIN is 0 and not used here. 
  opmode_xy <= "0101" when vld='1' else "0000";

  -- 011 => P = C +/- XY   ... clear accumulator (with initial rounding bit)
  -- 010 => P = P +/- XY   ... accumulate
  opmode_z <= "011" when clr='1' else "010";

  I_DSP48 : DSP48
  generic map(
    AREG          => to_integer(INPUT_REG),
    BREG          => to_integer(INPUT_REG),
    CREG          => 1,
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
    C(47 downto 0)         => c, -- C is used for initial rounding bit (static)
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

  -- a.) just shift right without rounding because rounding bit is has been added 
  --     within the DSP cell already.
  -- b.) cut off unused sign extension bits
  --    (This reduces the logic consumption in the following steps when rounding,
  --     saturation and/or overflow detection is enabled.)
  accu_used_shifted <= signed(accu(ACCU_USED_WIDTH-1 downto OUTPUT_SHIFT_RIGHT));

--  -- shift right and round 
--  g_rnd_off : if ((not OUTPUT_ROUND) or OUTPUT_SHIFT_RIGHT=0) generate
--    accu_used_shifted <= RESIZE(SHIFT_RIGHT_ROUND(accu_used, OUTPUT_SHIFT_RIGHT),ACCU_USED_SHIFTED_WIDTH);
--  end generate;
--  g_rnd_on : if (OUTPUT_ROUND and OUTPUT_SHIFT_RIGHT>0) generate
--    accu_used_shifted <= RESIZE(SHIFT_RIGHT_ROUND(accu_used, OUTPUT_SHIFT_RIGHT, nearest),ACCU_USED_SHIFTED_WIDTH);
--  end generate;

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

