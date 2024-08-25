-------------------------------------------------------------------------------
--! @file       signed_preadd_multadd_sum.vhdl
--! @author     Fixitfetish
--! @date       29/Jan/2022
--! @version    0.10
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;

--! @brief N complex multiplications and sum of all product results.
--!
--! This entity can be used for example
--! * for complex multiplication and scalar products
--!
--! The first operation mode is:
--! * VLD=0  then  r = r
--! * VLD=1  then  r = +/-(x0*y0) +/-(x1*y1) +/-...
--!
--! The second operation mode is (single y factor):
--! * VLD=0  then  r = r
--! * VLD=1  then  r = +/-(x0*y0) +/-(x1*y0) +/-...
--!
--! Note that for the second mode a more efficient implementation might be possible
--! because only one multiplication after summation is required.
--!
--! The length of the input factors is flexible.
--! The input factors are automatically resized with sign extensions bits to the
--! maximum possible factor length.
--! The maximum length of the input factors is device and implementation specific.
--! The resulting length of all products (x(n)'length + y(n)'length) must be the same.
--!
--! The delay depends on the configuration and the underlying hardware.
--! The number pipeline stages is reported as constant at output port @link PIPESTAGES PIPESTAGES @endlink.
--!
--! @image html complex_mult_sum.svg "" width=600px
--!
--! Also available are the following entities:
--! * complex_mult
--! * signed_mult
--! * signed_mult_sum
--!
--! VHDL Instantiation Template:
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
--! I1 : entity work.signed_preadd_multadd_sum
--! generic map(
--!   IMPLEMENTATION     => string,   -- default is "AUTO"
--!   NUM_MULT           => positive, -- number of parallel multiplications
--!   USE_ACCU           => boolean,  -- enable accumulation
--!   USE_XB_INPUT       => boolean,  -- enable second preadder input
--!   USE_NEGATION       => boolean,  -- enable negation port
--!   USE_XA_NEGATION    => boolean,  -- enable XA negation
--!   USE_XB_NEGATION    => boolean,  -- enable XB negation
--!   NUM_INPUT_REG_XY   => natural,  -- number of input registers
--!   NUM_INPUT_REG_Z    => natural,  -- number of input registers
--!   NUM_OUTPUT_REG     => natural,  -- number of output registers
--!   OUTPUT_SHIFT_RIGHT => natural,  -- number of right shifts
--!   OUTPUT_ROUND       => boolean,  -- enable rounding half-up
--!   OUTPUT_CLIP        => boolean,  -- enable clipping
--!   OUTPUT_OVERFLOW    => boolean   -- enable overflow detection
--! )
--! port map(
--!   clk        => in  std_logic, -- clock
--!   rst        => in  std_logic, -- reset
--!   clkena     => in  std_logic, -- clock enable
--!   clr        => in  std_logic, -- clear
--!   neg        => in  std_logic_vector(0 to NUM_MULT-1), -- negation
--!   xa         => in  signed_vector(0 to NUM_MULT-1), -- preadder input XA
--!   xa_vld     => in  std_logic_vector(0 to NUM_MULT-1), -- XA valid
--!   xa_neg     => in  std_logic_vector(0 to NUM_MULT-1), -- XA negation
--!   xb         => in  signed_vector(0 to NUM_MULT-1), -- preadder input XB
--!   xb_vld     => in  std_logic_vector(0 to NUM_MULT-1), -- XB valid
--!   xb_neg     => in  std_logic_vector(0 to NUM_MULT-1), -- XB negation
--!   y          => in  signed_vector, -- second factor(s)
--!   z          => in  signed_vector, -- additional summand(s)
--!   z_vld      => in  std_logic_vector(0 to NUM_MULT-1), -- Z valid
--!   result     => out signed, -- result
--!   result_vld => out std_logic, -- output valid
--!   result_ovf => out std_logic, -- output overflow
--!   PIPESTAGES => out integer -- constant number of pipeline stages
--! );
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--!
entity signed_preadd_multadd_sum is
generic (
  --! Device specific implementation selection. AUTO = last compiled COMPLEX_MACC_CHAIN architecture .
  IMPLEMENTATION : string := "AUTO";
  --! Number of parallel multiplications - mandatory generic!
  NUM_MULT : positive;
  --! Enable feedback of accumulator register P into DSP ALU when input port CLR=0
  USE_ACCU : boolean := false;
  --! Enable additional XB preadder input. Might require more resources and power.
  USE_XB_INPUT : boolean := false;
  --! @brief Enable NEG input port and allow product negation. Might require more resources and power.
  --! Can be also used for input port B negation.
  USE_NEGATION : boolean := false;
  --! @brief Enable XA_NEG input port and allow separate negation of preadder input port XA.
  --! Might require more resources and power. Typically only relevant when USE_XB_INPUT=true
  --! because otherwise preferably the product negation should be used.
  USE_XA_NEGATION : boolean := false;
  --! @brief Enable XB_NEG input port and allow separate negation of preadder input port XB.
  --! Might require more resources and power. Only relevant when USE_XB_INPUT=true.
  USE_XB_NEGATION : boolean := false;
  --! @brief Number of additional X and Y input registers - in general registers in logic but
  --! if available input registers within the DSP cell are used.
  NUM_INPUT_REG_XY : natural := 0;
  --! @brief Number of additional Z input registers - in general registers in logic but
  --! if available input registers within the DSP cell are used.
  NUM_INPUT_REG_Z : natural := 0;
  --! @brief Number of additional result output registers. At least one is recommended
  --! when logic for rounding, clipping and/or overflow detection is enabled.
  --! Typically all output registers are implemented in logic.
  NUM_OUTPUT_REG : natural := 0;
  --! Number of bits by which the accumulator result output is shifted right
  OUTPUT_SHIFT_RIGHT : natural := 0;
  --! @brief Round 'nearest' (half-up) of result output.
  --! This flag is only relevant when OUTPUT_SHIFT_RIGHT>0.
  --! If the device specific DSP cell supports rounding then rounding is done
  --! within the DSP cell. If rounding in logic is necessary then it is recommended
  --! to use an additional output register.
  OUTPUT_ROUND : boolean := true;
  --! Enable clipping when right shifted result exceeds output range.
  OUTPUT_CLIP : boolean := true;
  --! Enable overflow/clipping detection 
  OUTPUT_OVERFLOW : boolean := true
);
port (
  --! Standard system clock
  clk          : in  std_logic;
  --! Global pipeline reset (optional, only connect if really required!)
  rst          : in  std_logic := '0';
  --! Clock enable (optional)
  clkena       : in  std_logic := '1';
  --! @brief Clear accumulator (mark first valid input factors of accumulation sequence).
  --! If accumulation is not wanted then set constant '1'.
  clr          : in  std_logic := '1';
  --! Negation of product , '0'->+(+-xa+-xb)*y, '1'->-(+-xa+-xb)*y . Only relevant when USE_NEGATION=true.
  neg          : in  std_logic_vector(0 to NUM_MULT-1) := (others=>'0');
  --! 1st factor input (also 1st preadder input). Set (0 to NUM_MULT-1=>"00") if unused.
  xa           : in  signed_vector(0 to NUM_MULT-1);
  --! Valid signal synchronous to input XA, high-active. Leave OPEN if input XA is unused.
  xa_vld       : in  std_logic_vector(0 to NUM_MULT-1) := (others=>'0');
  --! Negation of XA synchronous to input XA, '0'=+xa, '1'=-xa . Only relevant when USE_XA_NEGATION=true.
  xa_neg       : in  std_logic_vector(0 to NUM_MULT-1) := (others=>'0');
  --! 1st factor input (2nd preadder input).  Set (0 to NUM_MULT-1=>"00") if unused (USE_XB_INPUT=false).
  xb           : in  signed_vector(0 to NUM_MULT-1);
  --! Valid signal synchronous to input XB, high-active. Leave OPEN if input XB is unused.
  xb_vld       : in  std_logic_vector(0 to NUM_MULT-1) := (others=>'0');
  --! Negation of XB synchronous to input XB, '0'=+xb, '1'=-xb . Only relevant when USE_XB_NEGATION=true.
  xb_neg       : in  std_logic_vector(0 to NUM_MULT-1) := (others=>'0');
  --! 2nd factor input
  y            : in  signed_vector(0 to NUM_MULT-1);
  --! @brief Additional summand after multiplication. Set (0 to NUM_MULT-1=>"00") if unused.
  --! Z is LSB bound to the LSB of the product x*y before shift right, i.e. similar to chain input.
  z            : in  signed_vector(0 to NUM_MULT-1);
  --! Valid signal synchronous to input Z, high-active. Leave OPEN if input Z is unused.
  z_vld        : in  std_logic_vector(0 to NUM_MULT-1) := (others=>'0');
  --! @brief Resulting product/accumulator output (optionally rounded and clipped).
  --! The standard result output might be unused when chain output is used instead.
  result     : out signed;
  --! Valid signal for result output, high-active
  result_vld : out std_logic;
  --! Result output overflow/clipping detection
  result_ovf : out std_logic;
  --! @brief Input from other chained DSP cell (optional, only used when input enabled and connected).
  --! The chain width is device specific. A maximum width of 80 bits is supported.
  --! If the device specific chain width is smaller then only the LSBs are used.
--  chainin      : in  signed(79 downto 0) := (others=>'0');
  --! Valid signal of chain input one cycle ahead of PCIN, high-active. Set '0' if chain input is unused.
--  chainin_vld  : in  std_logic := '0';
  --! @brief Result output to other chained DSP cell (optional)
  --! The chain width is device specific. A maximum width of 80 bits is supported.
  --! If the device specific chain width is smaller then only the LSBs are used.
  chainout     : out signed(79 downto 0) := (others=>'0');
  --! Valid signal of chain output one cycle ahead of PCOUT, high-active.
  chainout_vld : out std_logic;
  --! Number of pipeline stages in X path, constant, depends on configuration and device specific implementation
  PIPESTAGES   : out integer := 1
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (IMPLEMENTATION="AUTO" or IMPLEMENTATION="BEHAVE" or IMPLEMENTATION="DSP48E2")
    report "ERROR in " & signed_preadd_multadd_sum'INSTANCE_NAME & 
           " Supported values for IMPLEMENTATION are: AUTO, BEHAVE, DSP48E2 ."
    severity failure;

  assert (not OUTPUT_ROUND) or (OUTPUT_SHIFT_RIGHT/=0)
    report "WARNING in " & signed_preadd_multadd_sum'INSTANCE_NAME &
           " Disabled rounding because OUTPUT_SHIFT_RIGHT is 0."
    severity warning;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;

-------------------------------------------------------------------------------

architecture rtl of signed_preadd_multadd_sum is

  -- Currently only maximum 3 chain links supported!
  constant MAX_CHAIN_LENGTH : positive := 3;

  -- number Y vector input elements
  constant NY : integer := y'length;

  signal y_i : signed_vector(0 to NUM_MULT-1)(y(y'left)'length-1 downto 0);

begin

 -- Map Y input to internal vector
 gy: if NY=1 generate
   -- same factor y for all vector elements of x
   gn: for n in 0 to (NUM_MULT-1) generate
     y_i(n) <= y(y'left); -- duplication !
   end generate;
 else generate
   -- separate factor y for each vector element of x
   y_i <= y; -- range conversion !
 end generate;


 gchain : if NUM_MULT<=MAX_CHAIN_LENGTH generate
  signal result_i : signed_vector(0 to NUM_MULT-1)(result'length-1 downto 0);
  signal result_vld_i : std_logic_vector(0 to NUM_MULT-1);
  signal result_ovf_i : std_logic_vector(0 to NUM_MULT-1);
  signal pipestages_i : integer_vector(0 to NUM_MULT-1);

  signal chainin  : signed_vector(0 to NUM_MULT)(79 downto 0);
  signal chainin_vld : std_logic_vector(0 to NUM_MULT);

 begin

  -- dummy chain input
  chainin(0) <= (others=>'0');
  chainin_vld(0) <= '0';

  -- TODO : move high-speed option further down? How to distinguish different delays in impl. in AUTO mode ?

  gn : for n in 0 to NUM_MULT-1 generate
    signal clr_i : std_logic;
  begin
    clr_i <= clr when (USE_ACCU and (n=(NUM_MULT-1))) else '0';

    -- last compiled architecture
    auto : if IMPLEMENTATION="AUTO" generate
    idsp : entity work.signed_preadd_mult1add1
    generic map(
      USE_ACCU           => (USE_ACCU and n=(NUM_MULT-1)),
      NUM_SUMMAND        => NUM_MULT, -- TODO
      USE_XB_INPUT       => USE_XB_INPUT,
      USE_NEGATION       => USE_NEGATION,
      USE_XA_NEGATION    => USE_XA_NEGATION,
      USE_XB_NEGATION    => USE_XB_NEGATION,
      NUM_INPUT_REG_X    => 2 + NUM_INPUT_REG_XY + n, -- high-speed requires at least two XY input registers
      NUM_INPUT_REG_Y    => 2 + NUM_INPUT_REG_XY + n, -- high-speed requires at least two XY input registers
      NUM_INPUT_REG_Z    => 1 + NUM_INPUT_REG_Z + n, -- Z input requires at least one input register
      RELATION_CLR       => open,
      RELATION_NEG       => open,
      NUM_OUTPUT_REG     => NUM_OUTPUT_REG + 1, -- always at least one output register
      OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
      OUTPUT_ROUND       => (OUTPUT_ROUND and n=(NUM_MULT-1)),
      OUTPUT_CLIP        => (OUTPUT_CLIP and n=(NUM_MULT-1)),
      OUTPUT_OVERFLOW    => (OUTPUT_OVERFLOW and n=(NUM_MULT-1))
    )
    port map(
      clk           => clk,
      rst           => rst,
      clkena        => clkena,
      clr           => clr_i,
      neg           => neg(n),
      xa            => xa(n),
      xa_vld        => xa_vld(n),
      xa_neg        => xa_neg(n),
      xb            => xb(n),
      xb_vld        => xb_vld(n),
      xb_neg        => xb_neg(n),
      y             => y_i(n),
      z             => z(n),
      z_vld         => z_vld(n),
      result        => result_i(n),
      result_vld    => result_vld_i(n),
      result_ovf    => result_ovf_i(n),
      chainin       => chainin(n),
      chainin_vld   => chainin_vld(n),
      chainout      => chainin(n+1),
      chainout_vld  => chainin_vld(n+1),
      PIPESTAGES    => pipestages_i(n)
    );
    end generate auto;

    -- behavioral model
    behave : if IMPLEMENTATION="BEHAVE" generate

    end generate behave;

    -- Xilinx Ultrascale+
    dsp48e2 : if IMPLEMENTATION="DSP48E2" generate

    end generate dsp48e2;

  end generate gn;

  result <= result_i(NUM_MULT-1);
  result_vld <= result_vld_i(NUM_MULT-1);
  result_ovf <= result_ovf_i(NUM_MULT-1);
  PIPESTAGES <= pipestages_i(NUM_MULT-1);

 end generate gchain;

 ------------------------------------------------------------------------------

 -- recursive tree
 gtree : if NUM_MULT>MAX_CHAIN_LENGTH generate

  -- here always NUM_MULT_0 >= NUM_MULT_1
  constant NUM_MULT_1 : positive := NUM_MULT/2; -- floor(NUM_MULT/2)
  constant NUM_MULT_0 : positive := NUM_MULT - NUM_MULT_1;

--  constant ADDER_STAGES : positive := LOG2CEIL(NUM_MULT)-1;
--
--  function PIPEREG return natural is begin
--    if NUM_MULT=(2**ADDER_STAGES+1) then return 1; else return 0; end if;
--  end function;

  -- LSB extension
  function LSBEXT return natural is begin
    if OUTPUT_SHIFT_RIGHT=0 then return 0; else return 1; end if;
  end function;

  signal result0 : signed(result'length-1 downto 0);
  signal result0_vld : std_logic;
  signal result0_ovf : std_logic;
  signal pipestages0 : integer;

  -- maximum difference between pipestages
  constant MAX_DIFF : positive := 2;

  signal result1_q : signed_vector(0 to MAX_DIFF)(result'length-1 downto 0);
  signal result1_vld_q : std_logic_vector(0 to MAX_DIFF);
  signal result1_ovf_q : std_logic_vector(0 to MAX_DIFF);
  signal pipestages1 : integer;

  signal r : signed(result'length downto 0);
  signal r_ovf : std_logic;

 begin

  i0 : entity work.signed_preadd_multadd_sum(rtl)
  generic map(
    IMPLEMENTATION     => IMPLEMENTATION,
    NUM_MULT           => NUM_MULT_0,
    USE_ACCU           => USE_ACCU,
    USE_XB_INPUT       => USE_XB_INPUT,
    USE_NEGATION       => USE_NEGATION,
    USE_XA_NEGATION    => USE_XA_NEGATION,
    USE_XB_NEGATION    => USE_XB_NEGATION,
    NUM_INPUT_REG_XY   => NUM_INPUT_REG_XY,
    NUM_INPUT_REG_Z    => NUM_INPUT_REG_Z,
    NUM_OUTPUT_REG     => 0, -- additional output registers are always implemented at the end of the adder tree
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT-LSBEXT,
    OUTPUT_ROUND       => false,
    OUTPUT_CLIP        => false,
    OUTPUT_OVERFLOW    => false
  )
  port map(
      clk           => clk,
      rst           => rst,
      clkena        => clkena,
      clr           => clr,
      neg           => neg(0 to NUM_MULT_0-1),
      xa            => xa(0 to NUM_MULT_0-1),
      xa_vld        => xa_vld(0 to NUM_MULT_0-1),
      xa_neg        => xa_neg(0 to NUM_MULT_0-1),
      xb            => xb(0 to NUM_MULT_0-1),
      xb_vld        => xb_vld(0 to NUM_MULT_0-1),
      xb_neg        => xb_neg(0 to NUM_MULT_0-1),
      y             => y_i(0 to NUM_MULT_0-1),
      z             => z(0 to NUM_MULT_0-1),
      z_vld         => z_vld(0 to NUM_MULT_0-1),
      result        => result0,
      result_vld    => result0_vld,
      result_ovf    => result0_ovf,
      chainout      => open,
      chainout_vld  => open,
      PIPESTAGES    => pipestages0
    );

  i1 : entity work.signed_preadd_multadd_sum(rtl)
  generic map(
    IMPLEMENTATION     => IMPLEMENTATION,
    NUM_MULT           => NUM_MULT_1,
    USE_ACCU           => USE_ACCU,
    USE_XB_INPUT       => USE_XB_INPUT,
    USE_NEGATION       => USE_NEGATION,
    USE_XA_NEGATION    => USE_XA_NEGATION,
    USE_XB_NEGATION    => USE_XB_NEGATION,
    NUM_INPUT_REG_XY   => NUM_INPUT_REG_XY,
    NUM_INPUT_REG_Z    => NUM_INPUT_REG_Z,
    NUM_OUTPUT_REG     => 0, -- additional output registers are always implemented at the end of the adder tree
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT-LSBEXT,
    OUTPUT_ROUND       => false,
    OUTPUT_CLIP        => false,
    OUTPUT_OVERFLOW    => false
  )
  port map(
      clk           => clk,
      rst           => rst,
      clkena        => clkena,
      clr           => clr,
      neg           => neg(NUM_MULT_0 to NUM_MULT-1),
      xa            => xa(NUM_MULT_0 to NUM_MULT-1),
      xa_vld        => xa_vld(NUM_MULT_0 to NUM_MULT-1),
      xa_neg        => xa_neg(NUM_MULT_0 to NUM_MULT-1),
      xb            => xb(NUM_MULT_0 to NUM_MULT-1),
      xb_vld        => xb_vld(NUM_MULT_0 to NUM_MULT-1),
      xb_neg        => xb_neg(NUM_MULT_0 to NUM_MULT-1),
      y             => y_i(NUM_MULT_0 to NUM_MULT-1),
      z             => z(NUM_MULT_0 to NUM_MULT-1),
      z_vld         => z_vld(NUM_MULT_0 to NUM_MULT-1),
      result        => result1_q(0),
      result_vld    => result1_vld_q(0),
      result_ovf    => result1_ovf_q(0),
      chainout      => open,
      chainout_vld  => open,
      PIPESTAGES    => pipestages1
    );

  -- pipeline to compensate different number of pipestages
  comp : process(clk) begin
    if rising_edge(clk) then
      if rst/='0' then
        result1_vld_q(1 to MAX_DIFF) <= (others=>'0');
        result1_ovf_q(1 to MAX_DIFF) <= (others=>'0');
        result1_q(1 to MAX_DIFF) <= (others=>(others=>'-'));
      elsif clkena='1' then
        result1_vld_q(1 to MAX_DIFF) <= result1_vld_q(0 to MAX_DIFF-1);
        result1_ovf_q(1 to MAX_DIFF) <= result1_ovf_q(0 to MAX_DIFF-1);
        result1_q(1 to MAX_DIFF) <= result1_q(0 to MAX_DIFF-1);
      end if;
    end if;
  end process;

  -- here always pipestages0 >= pipestages1
  r <= resize(result0,r'length) + resize(result1_q(pipestages0-pipestages1),r'length);
  r_ovf <= result0_ovf or result1_ovf_q(pipestages0-pipestages1);

  i_out : entity work.xilinx_output_logic
  generic map(
    PIPELINE_STAGES    => 1 + NUM_OUTPUT_REG,
    OUTPUT_SHIFT_RIGHT => LSBEXT,
    OUTPUT_CLIP        => OUTPUT_CLIP,
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
  )
  port map (
    clk         => clk,
    rst         => rst,
    clkena      => clkena,
    dsp_out     => r,
    dsp_out_vld => result0_vld,
    dsp_out_ovf => r_ovf,
    dsp_out_rnd => to_01(OUTPUT_ROUND),
    result      => result,
    result_vld  => result_vld,
    result_ovf  => result_ovf
  );

  PIPESTAGES <= pipestages0 + 1 + NUM_OUTPUT_REG;

 end generate; --tree

end architecture;
