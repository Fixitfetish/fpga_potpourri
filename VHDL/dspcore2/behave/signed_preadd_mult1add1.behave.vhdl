-------------------------------------------------------------------------------
-- @file       signed_preadd_mult1add1.behave.vhdl
-- @author     Fixitfetish
-- @date       15/Sep/2024
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
  use baselib.ieee_extension.all;
  use baselib.ieee_extension_types.all;

-- This is an behavioral implementation of the signed_preadd_mult1add1 for Xilinx Devices.
--
architecture behave of signed_preadd_mult1add1 is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "signed_preadd_mult1add1(behave)";

  constant ACCU_WIDTH : positive := 64;
  constant MAX_WIDTH_A : positive := 32;
  constant MAX_WIDTH_B : positive := 32;
  constant MAX_WIDTH_C : positive := ACCU_WIDTH;
  constant MAX_WIDTH_AD : positive := MAX_WIDTH_A;

  -- rounding bit generation (+0.5)
  function RND return signed is
    variable res : signed(ACCU_WIDTH-1 downto 0) := (others=>'0');
  begin 
    if OUTPUT_ROUND and (OUTPUT_SHIFT_RIGHT>=1) then 
      res(OUTPUT_SHIFT_RIGHT-1):='1';
    end if;
    return res;
  end function;

  constant USE_ACCU : boolean := (NUM_ACCU_CYCLES>=2);

  -- number of overall summands that contribute to the DSP internal accumulation register P
  function NUM_SUMMAND return natural is
  begin
    if USE_XB_INPUT then
      return (NUM_SUMMAND_CHAININ + NUM_SUMMAND_Z + 2) * NUM_ACCU_CYCLES;
    else
      return (NUM_SUMMAND_CHAININ + NUM_SUMMAND_Z + 1) * NUM_ACCU_CYCLES;
    end if;
  end function;

  -- determine number of required additional guard bits (MSBs)
  function accu_guard_bits(
    dflt : natural; -- default value when num_summand=0
    impl : string -- implementation identifier string for warnings and errors
  ) return integer is
    variable res : integer;
  begin
    if NUM_SUMMAND=0 then
      res := dflt; -- maximum possible (default)
    else
      res := LOG2CEIL(NUM_SUMMAND);
      if res>dflt then 
        report "WARNING " & impl & ": Too many summands. " & 
           "Maximum number of " & integer'image(dflt) & " guard bits reached."
           severity warning;
        res:=dflt;
      end if;
    end if;
    return res; 
  end function;

  function NEG_REGS return natural is
  begin
    if RELATION_NEG="Y" then
      return NUM_INPUT_REG_Y;
    else
      return NUM_INPUT_REG_X;
    end if;
  end function;

  function CLR_REGS return natural is
  begin
    if RELATION_CLR="Z" then
      return NUM_INPUT_REG_Z;
    elsif RELATION_CLR="Y" then
      return NUM_INPUT_REG_Y;
    else
      return NUM_INPUT_REG_X;
    end if;
  end function;

  -- derived constants
  constant PRODUCT_WIDTH : natural := MAXIMUM(xa'length,xb'length) + y'length;
  constant MAX_GUARD_BITS : natural := ACCU_WIDTH - PRODUCT_WIDTH;
  constant GUARD_BITS_EVAL : natural := accu_guard_bits(MAX_GUARD_BITS,IMPLEMENTATION);
  constant ACCU_USED_WIDTH : natural := PRODUCT_WIDTH + GUARD_BITS_EVAL;
  constant ACCU_USED_SHIFTED_WIDTH : natural := ACCU_USED_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result'length;

  constant NUM_INPUT_REG_RST : natural := NUM_INPUT_REG_X;
  signal pipe_rst : std_logic_vector(NUM_INPUT_REG_RST downto 0);

  constant NUM_INPUT_REG_NEG : natural := NEG_REGS;
  signal pipe_neg : std_logic_vector(NUM_INPUT_REG_NEG downto 0);

  constant NUM_INPUT_REG_CLR : natural := CLR_REGS;
  signal pipe_clr : std_logic_vector(NUM_INPUT_REG_CLR downto 0);

  signal pipe_xa : signed_vector(NUM_INPUT_REG_X downto 0)(xa'length-1 downto 0);
  signal pipe_xb : signed_vector(NUM_INPUT_REG_X downto 0)(xb'length-1 downto 0);
  signal pipe_xa_vld : std_logic_vector(NUM_INPUT_REG_X downto 0);
  signal pipe_xb_vld : std_logic_vector(NUM_INPUT_REG_X downto 0);
  signal pipe_xa_neg : std_logic_vector(NUM_INPUT_REG_X downto 0);
  signal pipe_xb_neg : std_logic_vector(NUM_INPUT_REG_X downto 0);

  signal pipe_y : signed_vector(NUM_INPUT_REG_Y downto 0)(y'length-1 downto 0);
  signal pipe_y_vld : std_logic_vector(NUM_INPUT_REG_Y downto 0);

  signal pipe_z : signed_vector(NUM_INPUT_REG_Z downto 0)(z'length-1 downto 0);
  signal pipe_z_vld : std_logic_vector(NUM_INPUT_REG_Z downto 0);

  signal a, d : signed(MAX_WIDTH_A-1 downto 0);
  signal b : signed(MAX_WIDTH_B-1 downto 0);
  signal c : signed(MAX_WIDTH_C-1 downto 0);

  signal ad_vld, b_vld, p_vld : std_logic;
  signal ad : signed(MAX_WIDTH_AD-1 downto 0);
  signal m : signed(ACCU_WIDTH-1 downto 0);
  signal p : signed(ACCU_WIDTH-1 downto 0);
  signal chainin_i : signed(ACCU_WIDTH-1 downto 0);

  signal accu : signed(ACCU_WIDTH-1 downto 0);
  signal accu_vld : std_logic := '0';
  signal accu_used : signed(ACCU_USED_WIDTH-1 downto 0);

  signal chainin_vld_q : std_logic;
 
begin

  assert OUTPUT_WIDTH<ACCU_USED_SHIFTED_WIDTH or not(OUTPUT_CLIP or OUTPUT_OVERFLOW)
    report IMPLEMENTATION & ": " &
           "More guard bits required for saturation/clipping and/or overflow detection."
    severity failure;

  pipe_rst(NUM_INPUT_REG_RST) <= rst;
  g_rst : if NUM_INPUT_REG_RST>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if rst/='0' then
          pipe_rst(NUM_INPUT_REG_RST-1 downto 0) <= (others=>'1');
        elsif clkena='1' then
          pipe_rst(NUM_INPUT_REG_RST-1 downto 0) <= pipe_rst(NUM_INPUT_REG_RST downto 1);
        end if;
      end if;
    end process;
  end generate;

  pipe_neg(NUM_INPUT_REG_NEG) <= neg when USE_NEGATION else '0';
  g_neg : if NUM_INPUT_REG_NEG>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if rst/='0' then
          pipe_neg(NUM_INPUT_REG_NEG-1 downto 0) <= (others=>'0');
        elsif clkena='1' then
          pipe_neg(NUM_INPUT_REG_NEG-1 downto 0) <= pipe_neg(NUM_INPUT_REG_NEG downto 1);
        end if;
      end if;
    end process;
  end generate;

  pipe_clr(NUM_INPUT_REG_CLR) <= clr;
  g_clr : if NUM_INPUT_REG_CLR>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if rst/='0' then
          pipe_clr(NUM_INPUT_REG_CLR-1 downto 0) <= (others=>'1');
        elsif clkena='1' then
          pipe_clr(NUM_INPUT_REG_CLR-1 downto 0) <= pipe_clr(NUM_INPUT_REG_CLR downto 1);
        end if;
      end if;
    end process;
  end generate;

  pipe_xa(NUM_INPUT_REG_X) <= xa;
  pipe_xb(NUM_INPUT_REG_X) <= xb;
  pipe_xa_vld(NUM_INPUT_REG_X) <= xa_vld;
  pipe_xb_vld(NUM_INPUT_REG_X) <= xb_vld when USE_XB_INPUT else '0';
  pipe_xa_neg(NUM_INPUT_REG_X) <= xa_neg when USE_XA_NEGATION else '0';
  pipe_xb_neg(NUM_INPUT_REG_X) <= xb_neg when USE_XB_NEGATION else '0';
  g_x : if NUM_INPUT_REG_X>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if rst/='0' then
          pipe_xa(NUM_INPUT_REG_X-1 downto 0) <= (others=>(others=>'-'));
          pipe_xb(NUM_INPUT_REG_X-1 downto 0) <= (others=>(others=>'-'));
          pipe_xa_vld(NUM_INPUT_REG_X-1 downto 0) <= (others=>'0');
          pipe_xb_vld(NUM_INPUT_REG_X-1 downto 0) <= (others=>'0');
          pipe_xa_neg(NUM_INPUT_REG_X-1 downto 0) <= (others=>'0');
          pipe_xb_neg(NUM_INPUT_REG_X-1 downto 0) <= (others=>'0');
        elsif clkena='1' then
          pipe_xa(NUM_INPUT_REG_X-1 downto 0) <= pipe_xa(NUM_INPUT_REG_X downto 1);
          pipe_xb(NUM_INPUT_REG_X-1 downto 0) <= pipe_xb(NUM_INPUT_REG_X downto 1);
          pipe_xa_vld(NUM_INPUT_REG_X-1 downto 0) <= pipe_xa_vld(NUM_INPUT_REG_X downto 1);
          pipe_xb_vld(NUM_INPUT_REG_X-1 downto 0) <= pipe_xb_vld(NUM_INPUT_REG_X downto 1);
          pipe_xa_neg(NUM_INPUT_REG_X-1 downto 0) <= pipe_xa_neg(NUM_INPUT_REG_X downto 1);
          pipe_xb_neg(NUM_INPUT_REG_X-1 downto 0) <= pipe_xb_neg(NUM_INPUT_REG_X downto 1);
        end if;
      end if;
    end process;
  end generate;

  pipe_y(NUM_INPUT_REG_Y) <= y;
  pipe_y_vld(NUM_INPUT_REG_Y) <= y_vld;
  g_y : if NUM_INPUT_REG_Y>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if rst/='0' then
          pipe_y(NUM_INPUT_REG_Y-1 downto 0) <= (others=>(others=>'-'));
          pipe_y_vld(NUM_INPUT_REG_Y-1 downto 0) <= (others=>'0');
        elsif clkena='1' then
          pipe_y(NUM_INPUT_REG_Y-1 downto 0) <= pipe_y(NUM_INPUT_REG_Y downto 1);
          pipe_y_vld(NUM_INPUT_REG_Y-1 downto 0) <= pipe_y_vld(NUM_INPUT_REG_Y downto 1);
        end if;
      end if;
    end process;
  end generate;

  pipe_z(NUM_INPUT_REG_Z) <= z;
  pipe_z_vld(NUM_INPUT_REG_Z) <= z_vld;
  g_z : if NUM_INPUT_REG_Z>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if rst/='0' then
          pipe_z(NUM_INPUT_REG_Z-1 downto 0) <= (others=>(others=>'-'));
          pipe_z_vld(NUM_INPUT_REG_Z-1 downto 0) <= (others=>'0');
        elsif clkena='1' then
          pipe_z(NUM_INPUT_REG_Z-1 downto 0) <= pipe_z(NUM_INPUT_REG_Z downto 1);
          pipe_z_vld(NUM_INPUT_REG_Z-1 downto 0) <= pipe_z_vld(NUM_INPUT_REG_Z downto 1);
        end if;
      end if;
    end process;
  end generate;

  process(clk) begin
    if rising_edge(clk) then
      if rst/='0' then
        chainin_vld_q <= '0';
      elsif clkena='1' then
        chainin_vld_q <= chainin_vld;
      end if;
    end if;
  end process;

  a <= (others=>'0') when pipe_xa_vld(0)/='1' else resize(pipe_xa(0), a'length) when pipe_xa_neg(0)/='1' else -resize(pipe_xa(0), a'length);
  d <= (others=>'0') when pipe_xb_vld(0)/='1' else resize(pipe_xb(0), d'length) when pipe_xb_neg(0)/='1' else -resize(pipe_xb(0), d'length);
  b <= (others=>'0') when pipe_y_vld(0)/='1'  else resize(pipe_y(0),  b'length) when pipe_neg(0)/='1'    else -resize(pipe_y(0),  b'length);
  c <= resize(pipe_z(0),  c'length) when pipe_z_vld(0)='1' else (others=>'0');

  ad_vld <= pipe_xa_vld(0) or pipe_xb_vld(0);
  ad <= resize(a+d, ad'length);
  b_vld <= pipe_y_vld(0);

  -- use only LSBs of chain input
  chainin_i <= resize(chainin,ACCU_WIDTH) when chainin_vld_q='1' else (others=>'0');

  -- Operation
  m <= (ad*b) when (ad_vld='1' and b_vld='1') else (others=>'0');
  p <= m + c + chainin_i;
  p_vld <= (ad_vld and b_vld) or pipe_z_vld(0) or chainin_vld_q;

  process(clk)
  begin
    if rising_edge(clk) then
      if rst/='0' then
        accu_vld <= '0';
        accu <= (others=>'0');
      elsif clkena='1' then
        accu_vld <= p_vld;
        if pipe_clr(0)='1' or (p_vld='1' and not USE_ACCU) then
          accu <= p + RND;
        elsif (p_vld='1' and USE_ACCU) then
          accu <= p + accu;
        end if;
      end if;
    end if;
  end process;

  chainout <= resize(accu,chainout'length);
  chainout_vld <= p_vld;

  -- cut off unused sign extension bits
  -- (This reduces the logic consumption in the following steps when rounding,
  --  saturation and/or overflow detection is enabled.)
  accu_used <= signed(accu(ACCU_USED_WIDTH-1 downto 0));

  -- Right-shift and clipping
  -- Enable rounding here when not possible within DSP cell.
  i_out : entity work.signed_output_logic
  generic map(
    PIPELINE_STAGES    => NUM_OUTPUT_REG-1,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => false,
    OUTPUT_CLIP        => OUTPUT_CLIP,
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
  )
  port map (
    clk         => clk,
    rst         => rst,
    clkena      => clkena,
    dsp_out     => accu_used,
    dsp_out_vld => accu_vld,
    result      => result,
    result_vld  => result_vld,
    result_ovf  => result_ovf
  );

  -- report constant number of pipeline register stages
  PIPESTAGES <= NUM_INPUT_REG_X + NUM_OUTPUT_REG;

end architecture;
