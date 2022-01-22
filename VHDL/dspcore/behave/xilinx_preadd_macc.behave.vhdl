-------------------------------------------------------------------------------
--! @file       xilinx_preadd_macc.behave.vhdl
--! @author     Fixitfetish
--! @date       15/Jan/2022
--! @version    0.10
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Code comments are optimized for SIGASI and DOXYGEN.
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension.all;

use work.xilinx_dsp_pkg_behave.all;

--! @brief Behavioral model of xilinx_preadd_macc.
--!
--! This implementation is a model without bit width limitation as simple reference for simulation.
--!
architecture behave of xilinx_preadd_macc is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "xilinx_preadd_macc(behave)";

  --! rounding bit generation (+0.5)
  function gRND(clear:std_logic) return signed is
    variable res : signed(ACCU_WIDTH-1 downto 0) := (others=>'0');
  begin 
    if ROUND_ENABLE and clear/='0' then res(ROUND_BIT):='1'; end if;
    return res;
  end function;

  function nof_regs_clr return natural is
  begin 
    if    RELATION_CLR="AD" then return NUM_INPUT_REG_AD;
    elsif RELATION_CLR="B"  then return NUM_INPUT_REG_B;
    elsif RELATION_CLR="C"  then return NUM_INPUT_REG_C;
    else
      report "ERROR: CLR input port must be related to AD, B or C."
        severity failure;
      return integer'high;
    end if;
  end function;

  constant NUM_INPUT_REG_CLR : natural := nof_regs_clr;
  constant NUM_INPUT_REG_VLD : natural := NUM_INPUT_REG_AD;

  signal pipe_clr : std_logic_vector(NUM_INPUT_REG_CLR downto 0);
  signal pipe_vld : std_logic_vector(NUM_INPUT_REG_VLD downto 0);

  type r_pipe_ad is
  record
    neg_a : std_logic;
    neg_d : std_logic;
    a : a'subtype;
    d : d'subtype;
  end record;
  constant RESET_PIPE_AD : r_pipe_ad := (
    neg_a => '0',
    neg_d => '0',
    a     => (others=>'0'),
    d     => (others=>'0')
  );
  type a_pipe_ad is array(integer range <>) of r_pipe_ad;
  signal pipe_ad : a_pipe_ad(NUM_INPUT_REG_AD downto 0);

  type r_pipe_b is
  record
    neg_b : std_logic;
    b : b'subtype;
  end record;
  constant RESET_PIPE_B : r_pipe_b := (
    neg_b => '0',
    b     => (others=>'0')
  );
  type a_pipe_b is array(integer range <>) of r_pipe_b;
  signal pipe_b : a_pipe_b(NUM_INPUT_REG_B downto 0);

  type a_pipe_c is array(integer range <>) of c'subtype;
  signal pipe_c : a_pipe_c(NUM_INPUT_REG_C downto 0);

  signal a_i : signed(MAX_WIDTH_A-1 downto 0);
  signal b_i : signed(MAX_WIDTH_B-1 downto 0);
  signal c_i : signed(MAX_WIDTH_C-1 downto 0);
  signal d_i : signed(MAX_WIDTH_D-1 downto 0);
  signal p_i, p_q : signed(ACCU_WIDTH-1 downto 0);
  signal chainin_i : signed(ACCU_WIDTH-1 downto 0);

begin

  assert (a'length<=MAX_WIDTH_A)
    report "ERROR " & IMPLEMENTATION & ": " & 
           "Preadder and Multiplier input A width cannot exceed " & integer'image(MAX_WIDTH_A)
    severity failure;

  assert (b'length<=MAX_WIDTH_B)
    report "ERROR " & IMPLEMENTATION & ": " & 
           "Multiplier input B width cannot exceed " & integer'image(MAX_WIDTH_B)
    severity failure;

  assert (c'length<=MAX_WIDTH_C)
    report "ERROR " & IMPLEMENTATION & ": " & 
           "Summand input C width cannot exceed " & integer'image(MAX_WIDTH_C)
    severity failure;

  assert (d'length<=MAX_WIDTH_D)
    report "ERROR " & IMPLEMENTATION & ": " & 
           "Preadder and Multiplier input D width cannot exceed " & integer'image(MAX_WIDTH_D)
    severity failure;

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

  pipe_vld(NUM_INPUT_REG_VLD) <= vld;
  g_vld : if NUM_INPUT_REG_VLD>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if rst/='0' then
          pipe_vld(NUM_INPUT_REG_VLD-1 downto 0) <= (others=>'0');
        elsif clkena='1' then
          pipe_vld(NUM_INPUT_REG_VLD-1 downto 0) <= pipe_vld(NUM_INPUT_REG_VLD downto 1);
        end if;
      end if;
    end process;
  end generate;

  pipe_ad(NUM_INPUT_REG_AD).neg_a <= neg_a when USE_A_NEGATION else '0';
  pipe_ad(NUM_INPUT_REG_AD).neg_d <= neg_d when USE_D_NEGATION else '0';
  pipe_ad(NUM_INPUT_REG_AD).a <= a;
  pipe_ad(NUM_INPUT_REG_AD).d <= d when USE_D_INPUT else (others=>'0');
  g_ad : if NUM_INPUT_REG_AD>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if rst/='0' then
          pipe_ad(NUM_INPUT_REG_AD-1 downto 0) <= (others=>RESET_PIPE_AD);
        elsif clkena='1' then
          pipe_ad(NUM_INPUT_REG_AD-1 downto 0) <= pipe_ad(NUM_INPUT_REG_AD downto 1);
        end if;
      end if;
    end process;
  end generate;

  pipe_b(NUM_INPUT_REG_B).neg_b <= neg when USE_NEGATION else '0';
  pipe_b(NUM_INPUT_REG_B).b <= b;
  g_b : if NUM_INPUT_REG_B>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if rst/='0' then
          pipe_b(NUM_INPUT_REG_B-1 downto 0) <= (others=>RESET_PIPE_B);
        elsif clkena='1' then
          pipe_b(NUM_INPUT_REG_B-1 downto 0) <= pipe_b(NUM_INPUT_REG_B downto 1);
        end if;
      end if;
    end process;
  end generate;

  pipe_c(NUM_INPUT_REG_C) <= c;
  g_c : if NUM_INPUT_REG_C>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if rst/='0' then
          pipe_c(NUM_INPUT_REG_C-1 downto 0) <= (others=>(others=>'0'));
        elsif clkena='1' then
          pipe_c(NUM_INPUT_REG_C-1 downto 0) <= pipe_c(NUM_INPUT_REG_C downto 1);
        end if;
      end if;
    end process;
  end generate;

  a_i <= resize(pipe_ad(0).a, a_i'length) when pipe_ad(0).neg_a/='1' else -resize(pipe_ad(0).a, a_i'length);
  b_i <= resize( pipe_b(0).b, b_i'length) when  pipe_b(0).neg_b/='1' else -resize( pipe_b(0).b, b_i'length);
  d_i <= resize(pipe_ad(0).d, d_i'length) when pipe_ad(0).neg_d/='1' else -resize(pipe_ad(0).d, d_i'length);
  c_i <= resize( pipe_c(0)  , c_i'length) when USE_C_INPUT else (others=>'0');

  -- use only LSBs of chain input
  chainin_i <= resize(chainin,ACCU_WIDTH) when USE_CHAIN_INPUT else (others=>'0');

  -- Operation
  p_i <= (a_i + d_i) * b_i + c_i + chainin_i + gRND(pipe_clr(0));

  -- pipelined output valid signal
  g_dspreg_on : if NUM_OUTPUT_REG=1 generate
  begin
    process(clk)
    begin
      if rising_edge(clk) then
        if rst/='0' then
          p_vld <= '0';
          p_q <= (others=>'0');
        else
          if clkena='1' then
            p_vld <= pipe_vld(0);
            -- Update and accumulate only valid values
            -- Clear also when invalid
            if pipe_clr(0)='1' then
              p_q <= p_i;
            elsif pipe_vld(0)='1' then
              p_q <= p_i + p_q;
            end if;
          end if;
        end if;
      end if;
    end process;
  end generate;
  g_dspreg_off : if NUM_OUTPUT_REG=0 generate
    p_vld <= pipe_vld(0);
    p_q <= p_i;
  end generate;

  chainout<= resize(p_q,chainout'length);
  p <= p_q;

  PIPESTAGES <= NUM_INPUT_REG_AD + NUM_OUTPUT_REG;

end architecture;
