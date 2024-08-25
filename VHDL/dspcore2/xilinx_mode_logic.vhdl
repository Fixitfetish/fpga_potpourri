----------------------------------------------------------------------------
-- @file       xilinx_mode_logic.vhdl
-- @author     Fixitfetish
-- @date       25/Aug/2024
-- @version    0.20
-- @note       VHDL-2008
-- @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Code comments are optimized for SIGASI.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
--  use baselib.ieee_extension.all;
  use baselib.pipereg_pkg.all;

-- This entity implements a generic inmode, opmode and alumode logic for Xilinx Devices.
--
-- Special handling of CLR=1 and VLD=0
--
-- The P accumulator register will not be cleared and/or preset with the rounding bit immediately.
-- Instead the clear operation will be postponed to the next valid cycle.
-- This can save power because unnecessary toggling of the P register is avoided,
-- especially when accumulation is not needed and CLR is constant 1.
--
-- | USE_PREADDER | A_VLD | A_NEG | AA | Comment                                                   |
-- |:------------:|:-----:|:-----:|:--:|:----------------------------------------------------------|
-- |      0/1     |   0   |  0/1  |  0 | invalid input will never contribute to output             |
-- |       0      |   1   |  0/1  |  A | Negation feature disabled because preadder is bypassed    |
-- |       1      |   1   |   0   |  A |                                                           |
-- |       1      |   1   |   1   | -A |                                                           |
--
-- The D input shall only be used in addition to the A INPUT, hence preferably use A input.
--
-- | USE_PREADDER | D_VLD | D_NEG | DD | Comment                                                    |
-- |:------------:|:-----:|:-----:|:--:|:-----------------------------------------------------------|
-- |      0/1     |   0   |  0/1  |  0 | invalid input will never contribute to output              |
-- |       0      |   1   |  0/1  |  0 | preadder and second preadder input disabled                |
-- |       1      |   1   |   0   |  D |                                                            |
-- |       1      |   1   |   1   | -D |                                                            |
--
-- | C_VLD | CC | Comment                                        |
-- |:-----:|:--:|:-----------------------------------------------|
-- |   0   |  0 | invalid input will never contribute to output  |
-- |   1   |  C |                                                |
--
--  M_VLD = A_VLD or D_VLD
--
-- | USE_PREADDER | A_VLD | D_VLD | M_VLD | Product       | Comment                                    |
-- |:------------:|:-----:|:-----:|:-----:|:--------------|:-------------------------------------------|
-- |      0/1     |   0   |   0   |   0   | M = 0         | without valid inputs the product is zero   |
-- |      0/1     |   1   |   0   |   1   | M = AA*B      | just A contributes to product              |
-- |       1      |   0   |   1   |   1   | M = DD*B      | just D contributes to product              |
-- |       1      |   1   |   1   |   1   | M = (AA+DD)*B | full preadder and product                  |
--
-- **ACCU Mode**
-- * Simultaneous accumulation of up to two out of the three possible summands: M, PCIN, CC . Third summand is the P feedback.
-- * Optional round bit addition at accumulator reset/clear .
-- * Clearing (CLR=1) with simultaneously up to three out of the four possible summands: M, PCIN, CC, RND .
--
-- | ROUND | M_VLD | PCIN_VLD | C_VLD | CLEAR | Operation P              | Comment                                             |
-- |:-----:|:-----:|:--------:|:-----:|:-----:|:-------------------------|:----------------------------------------------------|
-- |  ---  |   0   |     0    |   0   |   1   | P = RND                  | Reset Accumulator                                   |
-- |   --- |  0/1  |     1    |   0   |   1   | P = RND +  M + PCIN      | Restart Accumulation                                |
-- |   --- |  0/1  |     0    |  0/1  |   1   | P = RND +  M +   CC      | Restart Accumulation                                |
-- |   --- |   0   |     1    |  0/1  |   1   | P = RND + CC + PCIN      | Restart Accumulation (without product M)            |
-- | false |  0/1  |     1    |  0/1  |   1   | P =  CC +  M + PCIN      | Restart Accumulation (without rounding)             |
-- |  true |   1   |     1    |   1   |   1   | P =  CC +  M + PCIN      | Restart Accumulation (DSP external round required)  |
-- |   --- |  0/1  |     0    |  0/1  |   0   | P =   P +  M +   CC      | Proceed Accumulation                                |
-- |   --- |  0/1  |     1    |   0   |   0   | P =   P +  M + PCIN      | Proceed Accumulation                                |
-- |   --- |   0   |     1    |   1   |   0   | P =   P + CC + PCIN      | Proceed Accumulation (without product M)            |
-- |   --- |   1   |     1    |   1   |   0   | P =   P +  M + PCIN + CC | ERROR: not possible                                 |
--
-- **SUM Mode**
-- * Simultaneous addition of three out the four possible summands: M, PCIN, CC, RND .
-- * ROUND=OFF : round bit is not added, i.e. RND=0
-- * ROUND=ON : round bit is added by RND
-- * With CLR=1 even an invalid output will be updated in every cycle, otherwise only valid values are shown at the output.
--
-- | ROUND | M_VLD | PCIN_VLD | C_VLD | CLEAR | Operation P              | Comment                                               |
-- |:-----:|:-----:|:--------:|:-----:|:-----:|:-------------------------|:------------------------------------------------------|
-- |  ---  |   0   |     0    |   0   |   0   | P = P                    | Keep output, no change                                |
-- |  ---  |   0   |     0    |   0   |   1   | P = RND                  | Reset output                                          |
-- |  ---  |   0   |     1    |   1   |  0/1  | P = RND + CC + PCIN      | Sum without product but with optional round bit       |
-- |  ---  |  0/1  |     1    |   0   |  0/1  | P = RND +  M + PCIN      | Sum with two summands and optional round bit          |
-- |  ---  |  0/1  |     0    |   1   |  0/1  | P = RND +  M +   CC      | Sum with two summands and optional round bit          |
-- | false |   1   |     1    |   1   |  0/1  | P =  CC +  M + PCIN      | Sum with three summands but without rounding          |
-- |  true |   1   |     1    |   1   |  0/1  | P =  CC +  M + PCIN      | Sum with three summands (DSP external round required) |
--
-- Here assumption is the following:
-- * The DSP internal INMODE and OPMODE input register is always enabled.
-- * The DSP internal P output register is always enabled.
--
-- Refer to 
-- * Xilinx UltraScale Architecture DSP48E2 Slice, UG579 (v1.11) August 30, 2021
-- * Xilinx Versal ACAP DSP Engine, Architecture Manual, AM004 (v1.2.1) September 11, 2022
--
entity xilinx_mode_logic is
generic (
  -- Enable feedback of accumulator register P into DSP ALU when input port CLR=0
  USE_ACCU : boolean := false;
  -- Enable preadder with additional D input
  USE_PREADDER : boolean := false;
  -- Enable rounding and add rounding bit within DSP if possible.
  -- If not possible then use output P_ROUND signal to indicate that external rounding is required.
  ENABLE_ROUND : boolean := false;
  -- Port A DSP internal input registers, at least one expected
  NUM_AREG : positive range 1 to 2 := 1;
  -- Port B DSP internal input registers, at least one expected
  NUM_BREG : positive range 1 to 2 := 1;
  -- Port C DSP internal input registers, always one expected
  NUM_CREG : positive range 1 to 1 := 1;
  -- Port D DSP internal input registers, always one expected
  NUM_DREG : positive range 1 to 1 := 1;
  -- Additional DSP internal preadder pipeline registers
  NUM_ADREG : natural range 0 to 1 := 0;
  -- Enable M pipeline register after multiplication
  NUM_MREG : natural range 0 to 1 := 0;
  -- Defines if the CLR input port is synchronous to input signals
  -- * "A"    = A_VLD
  -- * "B"    = B_VLD
  -- * "C"    = C_VLD
  -- * "D"    = D_VLD
  -- * "PCIN" = PCIN_VLD
  RELATION_CLR : string := "A"
);
port (
  -- Clock
  clk       : in  std_logic;
  -- Synchronous reset
  rst       : in  std_logic := '0';
  -- Clock enable
  clkena    : in  std_logic := '1';
  -- Clear accu P, signal must be synchronous to either a_vld, c_vld, d_vld or pcin_vld (see generic RELATION_CLR)
  clr       : in  std_logic := '0';
  -- product negation, synchronous to A input data port of DSP cell. Set '0' if unused.
  neg       : in  std_logic := '0';
  -- A input negation, synchronous to A input data port of DSP cell. Set '0' if unused.
  a_neg     : in  std_logic := '0';
  -- A input valid, synchronous to A input data port of DSP cell. Set '0' if A is unused.
  a_vld     : in  std_logic := '0';
  -- B input valid, synchronous to B input data port of DSP cell. If invalid then multiplier output M will be ignored and not contribute to final sum or accu.
  b_vld     : in  std_logic := '1';
  -- C input valid, synchronous to C input data port of DSP cell. Set '0' if C is unused.
  c_vld     : in  std_logic := '0';
  -- D input valid, synchronous to D input data port of DSP cell. Set '0' if D is unused.
  d_vld     : in  std_logic := '0';
  -- Chainin valid, one cycle ahead of PCIN because of OPMODE input register! Set '0' if unused.
  pcin_vld  : in  std_logic := '0';
  -- Resulting OPMODE
  inmode    : out std_logic_vector(4 downto 0);
  -- Resulting NEGATE signal (since DSP58)
  negate    : out std_logic_vector(2 downto 0);
  -- Resulting OPMODE
  opmode    : out std_logic_vector(8 downto 0);
  -- Resulting ALUMODE
  alumode   : out std_logic_vector(3 downto 0);
  -- P output change indicator, one cycle ahead of P and PCOUT output.
  -- Indicates whether P has new data, has been reset or preloaded with RND.
  -- Thus it can be used for P clock enable control or as PCIN valid by next chain link if required.
  p_change  : out std_logic;
  -- external round bit addition required, one cycle ahead of P 
  p_round   : out std_logic;
  -- PCOUT output vld indicator, one cycle ahead of PCOUT output.
  -- Indicates whether PCOUT changed as a result of new valid input data.
  -- Thus it can be used as PCIN valid by next chain link if required.
  pcout_vld : out std_logic
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (RELATION_CLR="A" or RELATION_CLR="B" or RELATION_CLR="C" or RELATION_CLR="D" or RELATION_CLR="PCIN")
    report "ERROR " & xilinx_mode_logic'INSTANCE_NAME & ": " & 
           " Generic RELATION_CLR must be A, B, C, D or PCIN."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;

-------------------------------------------------------------------------------

architecture macc of xilinx_mode_logic is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "xilinx_mode_logic(macc)";

  attribute dont_touch : string;
  attribute dont_touch of pcout_vld : signal is "true";
  attribute dont_touch of p_change : signal is "true";

  -- Get number of required additional CLR registers in logic.
  -- Note: Longest possible internal data pipeline is 4 (AREG=2 + ADREG=1 + MREG=1)
  function get_NUM_CLR_REG return natural is
    variable n : natural range 0 to 4 := 1;
  begin
    if RELATION_CLR="A" then
      n := (NUM_AREG + NUM_ADREG + NUM_MREG);
    elsif RELATION_CLR="B" then
      n := (NUM_BREG + NUM_MREG);
    elsif RELATION_CLR="C" then
      n := (NUM_CREG);
    elsif RELATION_CLR="D" then -- "D" always requires preadder
      n := (NUM_DREG + NUM_ADREG + NUM_MREG);
    else -- for PCIN always one internal OPMODE input register must be considered
      n := 1;
    end if;
    return n-1; -- Consider the internal OPMODE input register here.
  end function;
  constant NUM_CLR_REG : natural := get_NUM_CLR_REG;
  signal clr_q : std_logic_vector(NUM_CLR_REG downto 0);

  alias inmode_a1sel is inmode(0); -- A1 select ('0'=A2)
  alias inmode_agate is inmode(1); -- A gate, assumes that PREADDINSEL=A and inmode(1) input is inverted by generic
  alias inmode_dgate is inmode(2); -- D gate
  alias inmode_aneg  is inmode(3); -- A negation in preadder
  alias inmode_b1sel is inmode(4); -- B1 select ('0'=B2)

  alias opmode_x is opmode(1 downto 0);
  alias opmode_y is opmode(3 downto 2);
  alias opmode_z is opmode(6 downto 4);
  alias opmode_w is opmode(8 downto 7);

  signal neg_i   : std_logic := '0';
  signal a_vld_i : std_logic := '0';
  signal a_neg_i : std_logic := '0';
  signal ad_vld_i: std_logic := '0';
  signal b_vld_i : std_logic := '0';

  -- OPMODE control signals
  signal add_select : std_logic_vector(3 downto 0) := (others=>'0');
  alias  add_m    is add_select(0);
  alias  add_p    is add_select(1);
  alias  add_c    is add_select(2);
  alias  add_pcin is add_select(3);
  signal add_rnd : std_logic := '0';
  signal clear_p : std_logic := '0';

begin

  -- Port A control signal delay compensation (because of inmode input register)
  g_areg : if NUM_AREG=1 generate
    a_vld_i <= a_vld;
    a_neg_i <= a_neg;
    neg_i   <= neg;
  else generate
    -- NUM_AREG=1
    pipereg(a_vld_i, a_vld, clk, clkena);
    pipereg(a_neg_i, a_neg, clk, clkena);
    pipereg(neg_i  , neg  , clk, clkena);
  end generate;

  -- Port B control signal delay compensation (because of inmode input register)
  g_breg : if NUM_BREG=1 generate
    b_vld_i <= b_vld;
  else generate
    pipereg(b_vld_i, b_vld, clk, clkena);
  end generate;

  inmode_a1sel <= '0'; -- always use A1 or A2 output according to generic AREG MUX control
  inmode_agate <= a_vld_i;
  inmode_dgate <= d_vld;
  inmode_aneg  <= a_neg_i;
  inmode_b1sel <= '0'; -- always use B1 or B2 output according to generic BREG MUX control

  g_adreg : if NUM_ADREG=0 generate
    ad_vld_i <= a_vld_i or d_vld;
    negate <= "00" & neg_i;
  else generate
    signal adv : std_logic;
    signal n : std_logic;
  begin
    adv <= a_vld_i or d_vld;
    pipereg(ad_vld_i, adv, clk, clkena);
    pipereg(n, neg_i, clk, clkena);
    negate <= "00" & n;
  end generate;

  -- The multiplier output only contributes to the final sum/accu when port A and B inputs are valid.
  g_mreg : if NUM_MREG=0 generate
    add_m <= (ad_vld_i and b_vld_i) when USE_PREADDER else (a_vld_i and b_vld_i);
  else generate
    signal mv : std_logic;
  begin
    mv <= (ad_vld_i and b_vld_i) when USE_PREADDER else (a_vld_i and b_vld_i);
    pipereg(add_m, mv, clk, clkena);
  end generate;

  clr_q(NUM_CLR_REG) <= clr;
  g_clrreg : if NUM_CLR_REG>=1 generate
    pipereg(clr_q(NUM_CLR_REG-1 downto 0), clr_q(NUM_CLR_REG downto 1), clk, clkena);
  end generate;

  add_pcin <= pcin_vld;
  add_c <= c_vld;
  add_p <= not clr_q(0) when USE_ACCU else '0';
  add_rnd <= clr_q(0) when (USE_ACCU and ENABLE_ROUND) else '1' when (ENABLE_ROUND) else '0';
  --  add_rnd <= (not add_p) when ENABLE_ROUND else '0';
  clear_p <= clr_q(0);

  -- pragma translate_off (Xilinx Vivado , Synopsys)
  process(add_select)
  begin
   assert (add_select/="1111")
   report "ERROR " & IMPLEMENTATION & " Too many simultaneous inputs to DSP internal ALU. " &
          "Probably you use accumulation simultaneously with C and CHAININ inputs which is not supported."
    severity failure;
  end process;
  -- pragma translate_on (Xilinx Vivado , Synopsys)

  opmode_w <= "01" when (add_m='1' and add_p='1') else -- P
              "11" when (add_m='1' and add_pcin='1' and add_c='1') else -- C
              "10" when (add_rnd='1') else -- RND
              "00";

  opmode_x <= "01" when (add_m='1') else -- M
              "10" when (add_p='1') else -- P
              "00";

  opmode_y <= "01" when (add_m='1') else -- M
              "11" when (add_c='1') else -- C
              "00";

  opmode_z <= "001" when (add_pcin='1') else -- PCIN
              "011" when (add_m='1' and add_c='1') else -- C
              "000";

  -- currently always P = Z + (W + X + Y + CIN)
  alumode <= "0000";

  -- Flag that external round required, one cycle ahead of P data.
  -- The register here just compensates for the DSP internal OPMODE input register.
  pround : process(clk) begin
    if rising_edge(clk) then
      if rst/='0' then
        p_round <= '0';
      elsif clkena='1' then
        p_round <= add_rnd when opmode_w/="10" else '0';
      end if;
    end if;
  end process;

  -- Provide P output valid one cycle ahead of P data.
  -- The register here just compensates for the DSP internal OPMODE input register.
  pchange : process(clk) begin
    if rising_edge(clk) then
      if rst/='0' then
        p_change <= '0';
      elsif clkena='1' then
        p_change <= add_c or add_pcin or add_m or clear_p;
--        p_change <= add_c or add_pcin or add_m or add_rnd or clear_p;
      end if;
    end if;
  end process;

  -- PCOUT becomes valid when at least one of the inputs (A+D)*B , C or PCIN is valid.
  -- The valid signal is one cycle ahead of PCOUT, thus it can be directly connected to the pcin_vld of the next chain link.
  -- The register here just compensates for the DSP internal OPMODE input register.
  pcout : process(clk)
  begin
    if rising_edge(clk) then
      if rst/='0' then
        pcout_vld <= '0';
      elsif clkena='1' then
        pcout_vld <= add_c or add_pcin or add_m;
      end if;
    end if;
  end process;

end architecture;
