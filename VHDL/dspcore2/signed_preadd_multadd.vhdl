-------------------------------------------------------------------------------
--! @file       signed_preadd_multadd.vhdl
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
--! @image html signed_preadd_multadd.svg "" width=600px
--!
--! Also available are the following entities:
--! * complex_mult
--! * signed_mult
--! * signed_preadd_multadd_sum
--!
--! VHDL Instantiation Template:
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
--! I1 : entity work.signed_preadd_multadd
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
--!   z_vld      => in  std_logic_vector, -- Z valid
--!   result     => out signed_vector(0 to NUM_MULT-1), -- result
--!   result_vld => out std_logic_vector(0 to NUM_MULT-1), -- output valid
--!   result_ovf => out std_logic_vector(0 to NUM_MULT-1), -- output overflow
--!   PIPESTAGES => out integer -- constant number of pipeline stages
--! );
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--!
entity signed_preadd_multadd is
generic (
  --! Device specific implementation selection. AUTO = last compiled COMPLEX_MACC_CHAIN architecture .
  IMPLEMENTATION : string := "AUTO";
  --! Number of parallel multiplications - mandatory generic!
  NUM_MULT : positive;
  --! Enable accumulation when input port CLR=0
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
  --! Note that by default the Z input path has one internal pipeline register less than the XY path.
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
  --! 2nd factor input. Vector requires TO range with length of either NUM_MULT or 1 (same factor for all).
  y            : in  signed_vector;
  --! @brief Additional summand after multiplication. Z is LSB bound to the LSB of the product x*y before shift right.
  --! Vector requires TO range with length of either NUM_MULT or 1 (same summand for all).
  --! Set (0 to 0 =>"00") if unused.
  z            : in  signed_vector;
  --! @brief Valid signal synchronous to input Z, high-active.
  --! Vector requires TO range with length of either NUM_MULT or 1 (same valid for all Z).
  --! Set "0" if input Z is unused.
  z_vld        : in  std_logic_vector;
  --! Resulting product/accumulator outputs (optionally rounded and clipped).
  result       : out signed_vector(0 to NUM_MULT-1);
  --! Valid signal for result output, high-active
  result_vld   : out std_logic_vector(0 to NUM_MULT-1);
  --! Result output overflow/clipping detection
  result_ovf   : out std_logic_vector(0 to NUM_MULT-1);
  --! Number of pipeline stages in X path, constant, depends on configuration and device specific implementation
  PIPESTAGES   : out integer := 1
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (IMPLEMENTATION="AUTO" or IMPLEMENTATION="BEHAVE" or IMPLEMENTATION="DSP48E2" or IMPLEMENTATION="DSP58")
    report "ERROR in " & signed_preadd_multadd'INSTANCE_NAME & 
           " Supported values for IMPLEMENTATION are: AUTO, BEHAVE, DSP48E2, DSP58 ."
    severity failure;

  assert ((y'length=1 or y'length=NUM_MULT) and y'ascending)
    report "ERROR in " & signed_preadd_multadd'INSTANCE_NAME & 
           " Input vector Y must have 'TO' range of length 1 or NUM_MULT."
    severity failure;

  assert ((z'length=1 or z'length=NUM_MULT) and z'ascending)
    report "ERROR in " & signed_preadd_multadd'INSTANCE_NAME & 
           " Input vector Z must have 'TO' range of length 1 or NUM_MULT."
    severity failure;

  assert ((z_vld'length=1 or z_vld'length=NUM_MULT) and z_vld'ascending)
    report "ERROR in " & signed_preadd_multadd'INSTANCE_NAME & 
           " Input vector Z_VLD must have 'TO' range of length 1 or NUM_MULT."
    severity failure;

  assert (not OUTPUT_ROUND) or (OUTPUT_SHIFT_RIGHT/=0)
    report "WARNING in " & signed_preadd_multadd'INSTANCE_NAME &
           " Disabled rounding because OUTPUT_SHIFT_RIGHT is 0."
    severity warning;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;

-------------------------------------------------------------------------------

architecture rtl of signed_preadd_multadd is

  -- number Y vector input elements
  constant NY : integer := y'length;
  constant NZ : integer := z'length;
  constant NZVLD : integer := z_vld'length;

  signal y_i : signed_vector(0 to NUM_MULT-1)(y(y'left)'length-1 downto 0);
  signal z_i : signed_vector(0 to NUM_MULT-1)(z(z'left)'length-1 downto 0);
  signal z_vld_i : std_logic_vector(0 to NUM_MULT-1);

  signal pipestages_i : integer_vector(0 to NUM_MULT-1);

begin

 -- Map Y input to internal vector
 gy: if NY=1 generate
   -- same factor y for all vector elements of y_i
   gn: for n in 0 to (NUM_MULT-1) generate
     y_i(n) <= y(y'left); -- duplication !
   end generate;
 else generate
   -- separate factor y for each vector element of y_i
   y_i <= y; -- range conversion !
 end generate;

 -- Map Z input to internal vector
 gz: if NZ=1 generate
   -- same summand z for all vector elements of z_i
   gn: for n in 0 to (NUM_MULT-1) generate
     z_i(n) <= z(z'left); -- duplication !
   end generate;
 else generate
   -- separate summand z for each vector element of z_i
   z_i <= z; -- range conversion !
 end generate;

 -- Map Z valid to internal vector
 gzvld: if NZVLD=1 generate
   -- same z_vld for all vector elements of z_vld_i
   gn: for n in 0 to (NUM_MULT-1) generate
     z_vld_i(n) <= z_vld(z_vld'left); -- duplication !
   end generate;
 else generate
   -- separate z_vld for each vector element of z_vld_i
   z_vld_i <= z_vld; -- range conversion !
 end generate;


  -- TODO : move high-speed option further down? How to distinguish different delays in impl. in AUTO mode ?

  gn : for n in 0 to NUM_MULT-1 generate
    signal clr_i : std_logic;
  begin
    clr_i <= clr when USE_ACCU else '0';

    -- last compiled architecture
    auto : if IMPLEMENTATION="AUTO" generate
    idsp : entity work.signed_preadd_mult1add1
    generic map(
      USE_ACCU           => USE_ACCU,
      NUM_SUMMAND        => NUM_MULT, -- TODO
      USE_XB_INPUT       => USE_XB_INPUT,
      USE_NEGATION       => USE_NEGATION,
      USE_XA_NEGATION    => USE_XA_NEGATION,
      USE_XB_NEGATION    => USE_XB_NEGATION,
      NUM_INPUT_REG_X    => 2 + NUM_INPUT_REG_XY, -- high-speed requires at least two XY input registers
      NUM_INPUT_REG_Y    => 2 + NUM_INPUT_REG_XY, -- high-speed requires at least two XY input registers
      NUM_INPUT_REG_Z    => 1 + NUM_INPUT_REG_Z,  -- Z input requires at least one input register
      RELATION_CLR       => open,
      RELATION_NEG       => open,
      NUM_OUTPUT_REG     => NUM_OUTPUT_REG + 1, -- always at least one output register
      OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
      OUTPUT_ROUND       => OUTPUT_ROUND,
      OUTPUT_CLIP        => OUTPUT_CLIP,
      OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
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
      z             => z_i(n),
      z_vld         => z_vld_i(n),
      result        => result(n),
      result_vld    => result_vld(n),
      result_ovf    => result_ovf(n),
      chainin       => open, -- unused
      chainin_vld   => open, -- unused
      chainout      => open, -- unused
      chainout_vld  => open, -- unused
      PIPESTAGES    => pipestages_i(n)
    );
    end generate auto;

    -- behavioral model
    behave : if IMPLEMENTATION="BEHAVE" generate

    end generate behave;

    -- Xilinx Ultrascale+
    dsp48e2 : if IMPLEMENTATION="DSP48E2" generate

    end generate dsp48e2;

    -- Xilinx Versal
    dsp58 : if IMPLEMENTATION="DSP58" generate

    end generate dsp58;

  end generate gn;

  PIPESTAGES <= pipestages_i(0);

end architecture;
