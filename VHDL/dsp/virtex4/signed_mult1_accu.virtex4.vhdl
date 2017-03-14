-------------------------------------------------------------------------------
--! @file       signed_mult1_accu.virtex4.vhdl
--! @author     Fixitfetish
--! @date       23/Feb/2017
--! @version    0.81
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

library unisim;
 use unisim.vcomponents.all;

-- synopsys translate_off
library XilinxCoreLib;
-- synopsys translate_on

--! @brief This is an implementation of the entity 
--! @link signed_mult1_accu signed_mult1_accu @endlink
--! for Xilinx Virtex-4.
--! One signed multiplication is performed and results are accumulated.
--!
--! This implementation requires a single DSP48 Slice.
--! Refer to Xilinx XtremeDSP User Guide, UG073 (v2.7) May 15, 2008
--!
--! * Input Data      : 2 signed values, each max 18 bits
--! * Input Register  : optional, at least one is strongly recommended
--! * Input Chain     : optional, 48 bits
--! * Accu Register   : 48 bits, first output register (strongly recommended in most cases)
--! * Rounding        : optional half-up, within DSP cell
--! * Output Data     : 1x signed value, max 48 bits
--! * Output Register : optional, after shift-right and saturation
--! * Output Chain    : optional, 48 bits
--! * Pipeline stages : NUM_INPUT_REG + NUM_OUTPUT_REG
--!
--! If NUM_OUTPUT_REG=0 then the accumulator register P is disabled. 
--! This configuration might be useful when DSP cells are chained.
--!
--! +++ TODO +++ his implementation can be chained multiple times.
--! @image html signed_mult1_accu.virtex4" width=800px

architecture virtex4 of signed_mult1_accu is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "signed_mult1_accu(virtex4)";

  -- local auxiliary
  -- determine number of required additional guard bits (MSBs)
  function guard_bits(num_summand, dflt:natural) return integer is
    variable res : integer;
  begin
    if num_summand=0 then
      res := dflt; -- maximum possible (default)
    else
      res := LOG2CEIL(num_summand);
      if res>dflt then 
        report "WARNING " & IMPLEMENTATION & ": Too many summands. " & 
           "Maximum number of " & integer'image(dflt) & " guard bits reached."
           severity warning;
        res:=dflt;
      end if;
    end if;
    return res; 
  end function;

  -- two data input registers are supported, the first and the third stage
  function INREG(n:natural) return natural is
  begin 
    if    n<=1 then return n;
    elsif n=2  then return 1; -- second input register uses MREG
    else            return 2;
    end if;
  end function;

  -- MREG is used as second input register when NUM_INPUT_REG>=2
  function MREG(n:natural) return natural is
  begin if n>=2 then return 1; else return 0; end if; end function;

  function LEGACY_MODE(n:natural) return string is
  begin if n>=2 then return "MULT18X18S"; else return "MULT18X18"; end if; end function;

  function CTRLREG(n:integer) return integer is
  begin if n>=1 then return 1; else return 0; end if; end function;

  -- PREG is the first output register when NUM_OUTPUT_REG=>1 (strongly recommended!)
  function PREG(n:natural) return natural is
  begin if n>=1 then return 1; else return 0; end if; end function;

  constant MAX_WIDTH_A : positive := 18;
  constant MAX_WIDTH_B : positive := 18;

  -- accumulator width in bits
  constant ACCU_WIDTH : positive := 48;

  -- derived constants
  constant ROUND_ENABLE : boolean := OUTPUT_ROUND and (OUTPUT_SHIFT_RIGHT/=0);
  constant PRODUCT_WIDTH : natural := x'length + y'length;
  constant MAX_GUARD_BITS : natural := ACCU_WIDTH - PRODUCT_WIDTH;
  constant GUARD_BITS_EVAL : natural := guard_bits(NUM_SUMMAND,MAX_GUARD_BITS);
  constant ACCU_USED_WIDTH : natural := PRODUCT_WIDTH + GUARD_BITS_EVAL;
  constant ACCU_USED_SHIFTED_WIDTH : natural := ACCU_USED_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result'length;

  -- rounding bit generation (+0.5)
  function RND(ena:boolean; shift:natural) return std_logic_vector is
    variable res : std_logic_vector(ACCU_WIDTH-1 downto 0) := (others=>'0');
  begin 
    if ena and (shift>=1) then res(shift-1):='1'; end if;
    return res;
  end function;

  -- input register pipeline
  type r_ireg is
  record
    rst, vld : std_logic;
    sub : std_logic;
    opmode_xy : std_logic_vector(3 downto 0);
    opmode_z : std_logic_vector(2 downto 0);
    a : signed(MAX_WIDTH_A-1 downto 0);
    b : signed(MAX_WIDTH_B-1 downto 0);
  end record;
  type array_ireg is array(integer range <>) of r_ireg;
  signal ireg : array_ireg(NUM_INPUT_REG downto 0)
    := (others=>(rst=>'1',vld=>'0',sub=>'0',opmode_xy=>"0000",opmode_z=>"000",a|b=>(others=>'0')));

  -- output register pipeline
  type r_oreg is
  record
    dat : signed(OUTPUT_WIDTH-1 downto 0);
    vld : std_logic;
    ovf : std_logic;
  end record;
  type array_oreg is array(integer range <>) of r_oreg;
  signal rslt : array_oreg(0 to NUM_OUTPUT_REG);

  constant clkena : std_logic := '1'; -- clock enable
  constant reset : std_logic := '0';

  signal chainin_i, chainout_i : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal accu : std_logic_vector(ACCU_WIDTH-1 downto 0);
  signal accu_used_shifted : signed(ACCU_USED_SHIFTED_WIDTH-1 downto 0);

begin

  -- check chain in/out length
  assert (chainin'length>=ACCU_WIDTH or (not USE_CHAIN_INPUT))
    report "ERROR " & IMPLEMENTATION & ": " &
           "Chain input width must be " & integer'image(ACCU_WIDTH) & " bits."
    severity failure;

  -- check input/output length
  assert (x'length<=MAX_WIDTH_A)
    report "ERROR " & IMPLEMENTATION & ": Multiplier input X width cannot exceed " & integer'image(MAX_WIDTH_A)
    severity failure;
  assert (y'length<=MAX_WIDTH_B)
    report "ERROR " & IMPLEMENTATION & ": Multiplier input Y width cannot exceed " & integer'image(MAX_WIDTH_B)
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

  -- control signal inputs
  ireg(NUM_INPUT_REG).rst <= rst;
  ireg(NUM_INPUT_REG).vld <= vld;
  ireg(NUM_INPUT_REG).sub <= sub;

  -- 0000 =>  XY = +/- CIN  ... hold current accumulator value
  -- 0101 =>  XY = +/- (AxB+CIN) ... enable product accumulation
  -- Note that the carry CIN is 0 and not used here. 
  ireg(NUM_INPUT_REG).opmode_xy <= "0101" when vld='1' else "0000";

  -- 011 => P = C +/- XY   ... clear accumulator (with initial rounding bit)
  -- 010 => P = P +/- XY   ... accumulate
  ireg(NUM_INPUT_REG).opmode_z <= "011" when clr='1' else "010";

  -- LSB bound data inputs
  ireg(NUM_INPUT_REG).a <= resize(x,MAX_WIDTH_A);
  ireg(NUM_INPUT_REG).b <= resize(y,MAX_WIDTH_B);

  g_reg : if NUM_INPUT_REG>=4 generate
  begin
    g_1 : for n in 4 to NUM_INPUT_REG generate
    begin
      ireg(n-1) <= ireg(n) when rising_edge(clk);
    end generate;
  end generate;

  -- DSP cell data input registers A1/B1 are used as third input register stage.
  g_in3 : if NUM_INPUT_REG>=3 generate
  begin
    ireg(2).rst <= ireg(3).rst when rising_edge(clk);
    ireg(2).vld <= ireg(3).vld when rising_edge(clk);
    ireg(2).sub <= ireg(3).sub when rising_edge(clk);
    ireg(2).opmode_xy <= ireg(3).opmode_xy when rising_edge(clk);
    ireg(2).opmode_z <= ireg(3).opmode_z when rising_edge(clk);
    -- the following register are located within the DSP cell
    ireg(2).a <= ireg(3).a;
    ireg(2).b <= ireg(3).b;
  end generate;

  -- DSP cell MREG register is used as third data input register stage
  g_in2 : if NUM_INPUT_REG>=2 generate
  begin
    ireg(1).rst <= ireg(2).rst when rising_edge(clk);
    ireg(1).vld <= ireg(2).vld when rising_edge(clk);
    ireg(1).sub <= ireg(2).sub when rising_edge(clk);
    ireg(1).opmode_xy <= ireg(2).opmode_xy when rising_edge(clk);
    ireg(1).opmode_z <= ireg(2).opmode_z when rising_edge(clk);
    -- the following register are located within the DSP cell
    ireg(1).a <= ireg(2).a;
    ireg(1).b <= ireg(2).b;
  end generate;

  -- DSP cell data input registers A2/B2 are used as first input register stage.
  g_in1 : if NUM_INPUT_REG>=1 generate
  begin
    ireg(0).rst <= ireg(1).rst when rising_edge(clk);
    ireg(0).vld <= ireg(1).vld when rising_edge(clk);
    -- the following register are located within the DSP cell
    ireg(0).sub <= ireg(1).sub;
    ireg(0).opmode_xy <= ireg(1).opmode_xy;
    ireg(0).opmode_z <= ireg(1).opmode_z;
    ireg(0).a <= ireg(1).a;
    ireg(0).b <= ireg(1).b;
  end generate;

  -- use only LSBs of chain input
  chainin_i <= std_logic_vector(chainin(ACCU_WIDTH-1 downto 0));

  dsp : DSP48
  generic map(
    AREG          => INREG(NUM_INPUT_REG),
    BREG          => INREG(NUM_INPUT_REG),
    CREG          => 1,
    PREG          => PREG(NUM_OUTPUT_REG),
    MREG          => MREG(NUM_INPUT_REG),
    OPMODEREG     => CTRLREG(NUM_INPUT_REG),
    SUBTRACTREG   => CTRLREG(NUM_INPUT_REG),
    CARRYINSELREG => 0,
    CARRYINREG    => 0,
    B_INPUT       => "DIRECT",
    LEGACY_MODE   => LEGACY_MODE(NUM_INPUT_REG)
  )
  port map(
    A(17 downto 0)         => std_logic_vector(ireg(0).a),
    B(17 downto 0)         => std_logic_vector(ireg(0).b),
    BCIN(17 downto 0)      => (others=>'0'),
    C(47 downto 0)         => RND(ROUND_ENABLE,OUTPUT_SHIFT_RIGHT),
    CARRYIN                => '0',
    CARRYINSEL(1 downto 0) => (others=>'0'),
    CEA                    => clkena,
    CEB                    => clkena,
    CEC                    => clkena,
    CECARRYIN              => '0',
    CECINSUB               => clkena,
    CECTRL                 => clkena,
    CEM                    => clkena,
    CEP                    => clkena,
    CLK                    => clk,
    OPMODE(3 downto 0)     => ireg(0).opmode_xy,
    OPMODE(6 downto 4)     => ireg(0).opmode_z,
    PCIN                   => chainin_i,
    RSTA                   => reset,
    RSTB                   => reset,
    RSTC                   => reset,
    RSTCARRYIN             => reset,
    RSTCTRL                => reset,
    RSTM                   => reset,
    RSTP                   => reset,
    SUBTRACT               => ireg(0).sub,
    BCOUT                  => open,
    P(47 downto 0)         => accu,
    PCOUT                  => chainout_i
  );

  chainout(ACCU_WIDTH-1 downto 0) <= signed(chainout_i);
  g_chainout : for n in ACCU_WIDTH to (chainout'length-1) generate
    -- sign extension (for simulation and to avoid warnings)
    chainout(n) <= chainout_i(ACCU_WIDTH-1);
  end generate;

  -- a.) just shift right without rounding because rounding bit is has been added 
  --     within the DSP cell already.
  -- b.) cut off unused sign extension bits
  --    (This reduces the logic consumption in the following steps when rounding,
  --     saturation and/or overflow detection is enabled.)
  accu_used_shifted <= signed(accu(ACCU_USED_WIDTH-1 downto OUTPUT_SHIFT_RIGHT));

--  -- shift right and round
--  g_rnd_off : if (not ROUND_ENABLE) generate
--    accu_used_shifted <= RESIZE(SHIFT_RIGHT_ROUND(accu_used, OUTPUT_SHIFT_RIGHT),ACCU_USED_SHIFTED_WIDTH);
--  end generate;
--  g_rnd_on : if (ROUND_ENABLE) generate
--    accu_used_shifted <= RESIZE(SHIFT_RIGHT_ROUND(accu_used, OUTPUT_SHIFT_RIGHT, nearest),ACCU_USED_SHIFTED_WIDTH);
--  end generate;

  p_out : process(accu_used_shifted, ireg(0).vld)
    variable v_dat : signed(OUTPUT_WIDTH-1 downto 0);
    variable v_ovf : std_logic;
  begin
    RESIZE_CLIP(din=>accu_used_shifted, dout=>v_dat, ovfl=>v_ovf, clip=>OUTPUT_CLIP);
    rslt(0).vld <= ireg(0).vld;
    rslt(0).dat <= v_dat;
    if OUTPUT_OVERFLOW then rslt(0).ovf<=v_ovf; else rslt(0).ovf<='0'; end if;
  end process;

  g_oreg1 : if NUM_OUTPUT_REG>=1 generate
  begin
    rslt(1).vld <= rslt(0).vld when rising_edge(clk); -- VLD bypass
    -- DSP cell result/accumulator register is always used as first output register stage
    rslt(1).dat <= rslt(0).dat;
    rslt(1).ovf <= rslt(0).ovf;
  end generate;

  -- additional output registers always in logic
  g_oreg2 : if NUM_OUTPUT_REG>=2 generate
    g_loop : for n in 2 to NUM_OUTPUT_REG generate
      rslt(n) <= rslt(n-1) when rising_edge(clk);
    end generate;
  end generate;

  -- map result to output port
  result <= rslt(NUM_OUTPUT_REG).dat;
  result_vld <= rslt(NUM_OUTPUT_REG).vld;
  result_ovf <= rslt(NUM_OUTPUT_REG).ovf;

  -- report constant number of pipeline register stages
  PIPESTAGES <= NUM_INPUT_REG + NUM_OUTPUT_REG;

end architecture;

