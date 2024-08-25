-------------------------------------------------------------------------------
--! @file       complex_mult_sum.vhdl
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
--! I1 : entity work.complex_mult_sum
--! generic map(
--!   IMPLEMENTATION     => string,   -- default is "AUTO"
--!   OPTIMIZATION       => string,   -- "PERFORMANCE" or "RESOURCES"
--!   NUM_MULT           => positive, -- number of parallel multiplications
--!   USE_NEGATION       => boolean,  -- enable negation port
--!   USE_CONJUGATE_X    => boolean,  -- enable X complex conjugate port
--!   USE_CONJUGATE_Y    => boolean,  -- enable Y complex conjugate port
--!   NUM_INPUT_REG      => natural,  -- number of input registers
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
--!   vld        => in  std_logic, -- valid
--!   neg        => in  std_logic_vector(0 to NUM_MULT-1), -- negation
--!   x_re       => in  signed_vector(0 to NUM_MULT-1), -- first factors
--!   x_im       => in  signed_vector(0 to NUM_MULT-1), -- first factors
--!   x_conj     => in  std_logic_vector(0 to NUM_MULT-1), -- conjugate X
--!   y_re       => in  signed_vector, -- second factor(s)
--!   y_im       => in  signed_vector, -- second factor(s)
--!   y_conj     => in  std_logic_vector(0 to NUM_MULT-1), -- conjugate Y
--!   result_re  => out signed, -- result
--!   result_im  => out signed, -- result
--!   result_vld => out std_logic, -- output valid
--!   result_ovf => out std_logic, -- output overflow
--!   PIPESTAGES => out integer -- constant number of pipeline stages
--! );
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--!
entity complex_mult_sum is
generic (
  --! Device specific implementation selection. AUTO = last compiled COMPLEX_MACC_CHAIN architecture .
  IMPLEMENTATION : string := "AUTO";
  --! OPTIMIZATION can be either "PERFORMANCE" or "RESOURCES"
  OPTIMIZATION : string := "RESOURCES";
  --! Number of parallel multiplications - mandatory generic!
  NUM_MULT : positive;
  --! Enable feedback of accumulator register P into DSP ALU when input port CLR=0
  USE_ACCU : boolean := false;
  --! @brief Enable negation port. If enabled then dynamic negation of partial
  --! products is implemented (preferably within the DSP cells otherwise in logic). 
  --! Enabling the negation might have negative side effects on pipeline stages,
  --! input width limitations and timing.
  --! Disable negation if not needed and the negation port input is ignored.
  USE_NEGATION : boolean := false;
  --! Enable X_CONJ input port for complex conjugate X, i.e. negation of input port X_IM.
  USE_CONJUGATE_X : boolean := false;
  --! Enable Y_CONJ input port for complex conjugate Y, i.e. negation of input port Y_IM.
  USE_CONJUGATE_Y : boolean := false;
  --! @brief Number of additional input registers - in general registers in logic but
  --! if available input registers within the DSP cell are used.
  NUM_INPUT_REG : natural := 0;
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
  clk        : in  std_logic;
  --! Reset result output (optional)
  rst        : in  std_logic := '0';
  --! Clock enable (optional)
  clkena     : in  std_logic := '1';
  --! @brief Clear accumulator (mark first valid input factors of accumulation sequence).
  --! If accumulation is not wanted then set constant '1'.
  clr        : in  std_logic := '1';
  --! Valid signal for input factors, high-active
  vld        : in  std_logic;
  --! Negation of partial products , '0' -> +(x(n)*y(n)), '1' -> -(x(n)*y(n)). Negation is disabled by default.
  neg        : in  std_logic_vector(0 to NUM_MULT-1) := (others=>'0');
  --! Real component of first factor vector. Requires 'TO' range.
  x_re       : in  signed_vector(0 to NUM_MULT-1);
  --! Imaginary component of first factor vector. Requires 'TO' range.
  x_im       : in  signed_vector(0 to NUM_MULT-1);
  --! Complex conjugate of X input , '0'=+x_im(n) , '1'=-x_im(n). Complex conjugate is disabled by default.
  x_conj     : in  std_logic_vector(0 to NUM_MULT-1) := (others=>'0');
  --! Complex conjugate of Y input , '0'=+y_im(n) , '1'=-y_im(n). Complex conjugate is disabled by default.
  y_conj     : in  std_logic_vector(0 to NUM_MULT-1) := (others=>'0');
  --! Real component of second factor vector. Requires 'TO' range.
  y_re       : in  signed_vector;
  --! Imaginary component of second factor vector. Requires 'TO' range.
  y_im       : in  signed_vector;
  --! Real component of the result output (optionally rounded and clipped).
  result_re  : out signed;
  --! Imaginary component of the result output (optionally rounded and clipped).
  result_im  : out signed;
  --! Valid signal for result output, high-active
  result_vld : out std_logic;
  --! Result output overflow/clipping detection
  result_ovf : out std_logic;
  --! Number of pipeline stages, constant, depends on configuration and device specific implementation
  PIPESTAGES : out integer := 1
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (IMPLEMENTATION="AUTO" or IMPLEMENTATION="BEHAVE" or IMPLEMENTATION="DSP48E2" or IMPLEMENTATION="DSP58")
    report "ERROR in " & complex_mult_sum'INSTANCE_NAME & 
           " Supported values for IMPLEMENTATION are: AUTO, BEHAVE, DSP48E2 ."
    severity failure;

  assert ((y_re'length=1 or y_re'length=x_re'length) and y_re'ascending)
    report "ERROR in " & complex_mult_sum'INSTANCE_NAME & 
           " Input vector Y_RE must have length of 1 or 'TO' range with same length as input X_RE."
    severity failure;

  assert ((y_im'length=1 or y_im'length=x_im'length) and y_im'ascending)
    report "ERROR in " & complex_mult_sum'INSTANCE_NAME & 
           " Input vector Y_IM must have length of 1 or 'TO' range with same length as input X_IM."
    severity failure;

  assert (not OUTPUT_ROUND) or (OUTPUT_SHIFT_RIGHT/=0)
    report "WARNING in " & complex_mult_sum'INSTANCE_NAME &
           " Disabled rounding because OUTPUT_SHIFT_RIGHT is 0."
    severity warning;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;

-------------------------------------------------------------------------------

architecture rtl of complex_mult_sum is

  -- Currently only maximum 3 chain links supported!
  constant MAX_CHAIN_LENGTH : positive := 3;

  -- number Y vector input elements
  constant NY : integer := y_re'length;

  signal y_re_i : signed_vector(0 to NUM_MULT-1)(y_re(y_re'left)'length-1 downto 0);
  signal y_im_i : signed_vector(0 to NUM_MULT-1)(y_im(y_im'left)'length-1 downto 0);

begin

 -- Map Y input to internal vector
 gy: if NY=1 generate
   -- same factor y for all vector elements of x
   gn: for n in 0 to (NUM_MULT-1) generate
     y_re_i(n) <= y_re(y_re'left); -- duplication !
     y_im_i(n) <= y_im(y_im'left); -- duplication !
   end generate;
 else generate
   -- separate factor y for each vector element of x
   y_re_i <= y_re; -- range conversion !
   y_im_i <= y_im; -- range conversion !
 end generate;


 gchain : if NUM_MULT<=MAX_CHAIN_LENGTH generate

  -- TODO : move high-speed option further down? How to distinguish different delays in impl. in AUTO mode ?

  -- last compiled architecture
  auto : if IMPLEMENTATION="AUTO" generate
    dspchain : entity work.complex_macc_chain
    generic map(
      OPTIMIZATION       => OPTIMIZATION,
      USE_ACCU           => USE_ACCU,
      NUM_MULT           => NUM_MULT,
--      NUM_SUMMAND        => NUM_MULT,
      USE_NEGATION       => USE_NEGATION,
      USE_CONJUGATE_X    => USE_CONJUGATE_X,
      USE_CONJUGATE_Y    => USE_CONJUGATE_Y,
      NUM_INPUT_REG_XY   => NUM_INPUT_REG + 2, -- high-speed requires at least two XY input registers
      NUM_INPUT_REG_Z    => open, -- unused
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
      clr           => clr,
      vld           => vld,
      neg           => neg,
      x_re          => x_re,
      x_im          => x_im,
      x_conj        => x_conj,
      y_re          => y_re_i,
      y_im          => y_im_i,
      y_conj        => y_conj,
      z_re          => (0 to NUM_MULT-1=>"00"), -- unused
      z_im          => (0 to NUM_MULT-1=>"00"), -- unused
      z_vld         => open, -- unused
      result_re     => result_re,
      result_im     => result_im,
      result_vld    => result_vld,
      result_ovf    => result_ovf,
      PIPESTAGES    => PIPESTAGES
    );
  end generate;

  -- behavioral model
  behave : if IMPLEMENTATION="BEHAVE" generate
    dspchain : entity work.complex_macc_chain(behave)
    generic map(
      OPTIMIZATION       => OPTIMIZATION,
      USE_ACCU           => USE_ACCU,
      NUM_MULT           => NUM_MULT,
--      NUM_SUMMAND        => NUM_MULT,
      USE_NEGATION       => USE_NEGATION,
      USE_CONJUGATE_X    => USE_CONJUGATE_X,
      USE_CONJUGATE_Y    => USE_CONJUGATE_Y,
      NUM_INPUT_REG_XY   => NUM_INPUT_REG + 2, -- high-speed requires at least two XY input registers
      NUM_INPUT_REG_Z    => open, -- unused
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
      clr           => clr,
      vld           => vld,
      neg           => neg,
      x_re          => x_re,
      x_im          => x_im,
      x_conj        => x_conj,
      y_re          => y_re_i,
      y_im          => y_im_i,
      y_conj        => y_conj,
      z_re          => (0 to NUM_MULT-1=>"00"), -- unused
      z_im          => (0 to NUM_MULT-1=>"00"), -- unused
      z_vld         => open, -- unused
      result_re     => result_re,
      result_im     => result_im,
      result_vld    => result_vld,
      result_ovf    => result_ovf,
      PIPESTAGES    => PIPESTAGES
    );
  end generate;

  -- Xilinx Ultrascale+
  dsp48e2 : if IMPLEMENTATION="DSP48E2" generate
    dspchain : entity work.complex_macc_chain(dsp48e2)
    generic map(
      OPTIMIZATION       => OPTIMIZATION,
      USE_ACCU           => USE_ACCU,
      NUM_MULT           => NUM_MULT,
--      NUM_SUMMAND        => NUM_MULT,
      USE_NEGATION       => USE_NEGATION,
      USE_CONJUGATE_X    => USE_CONJUGATE_X,
      USE_CONJUGATE_Y    => USE_CONJUGATE_Y,
      NUM_INPUT_REG_XY   => NUM_INPUT_REG + 2, -- high-speed requires at least two XY input registers
      NUM_INPUT_REG_Z    => open, -- unused
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
      clr           => clr,
      vld           => vld,
      neg           => neg,
      x_re          => x_re,
      x_im          => x_im,
      x_conj        => x_conj,
      y_re          => y_re_i,
      y_im          => y_im_i,
      y_conj        => y_conj,
      z_re          => (0 to NUM_MULT-1=>"00"), -- unused
      z_im          => (0 to NUM_MULT-1=>"00"), -- unused
      z_vld         => open, -- unused
      result_re     => result_re,
      result_im     => result_im,
      result_vld    => result_vld,
      result_ovf    => result_ovf,
      PIPESTAGES    => PIPESTAGES
    );
  end generate;

  -- Xilinx Versal
  dsp58 : if IMPLEMENTATION="DSP58" generate
    dspchain : entity work.complex_macc_chain(dsp58)
    generic map(
      OPTIMIZATION       => OPTIMIZATION,
      USE_ACCU           => USE_ACCU,
      NUM_MULT           => NUM_MULT,
--      NUM_SUMMAND        => NUM_MULT,
      USE_NEGATION       => USE_NEGATION,
      USE_CONJUGATE_X    => USE_CONJUGATE_X,
      USE_CONJUGATE_Y    => USE_CONJUGATE_Y,
      NUM_INPUT_REG_XY   => NUM_INPUT_REG + 2, -- high-speed requires at least two XY input registers
      NUM_INPUT_REG_Z    => open, -- unused
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
      clr           => clr,
      vld           => vld,
      neg           => neg,
      x_re          => x_re,
      x_im          => x_im,
      x_conj        => x_conj,
      y_re          => y_re_i,
      y_im          => y_im_i,
      y_conj        => y_conj,
      z_re          => (0 to NUM_MULT-1=>"00"), -- unused
      z_im          => (0 to NUM_MULT-1=>"00"), -- unused
      z_vld         => open, -- unused
      result_re     => result_re,
      result_im     => result_im,
      result_vld    => result_vld,
      result_ovf    => result_ovf,
      PIPESTAGES    => PIPESTAGES
    );
  end generate;

 end generate; --chain

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

  signal re0 : signed(result_re'length-1 downto 0);
  signal im0 : signed(result_im'length-1 downto 0);
  signal vld0 : std_logic;
  signal ovf0 : std_logic;
  signal pipestages0 : integer;

  -- maximum difference between pipestages
  constant MAX_DIFF : positive := 2;

  signal re1_q : signed_vector(0 to MAX_DIFF)(result_re'length-1 downto 0);
  signal im1_q : signed_vector(0 to MAX_DIFF)(result_im'length-1 downto 0);
  signal vld1_q : std_logic_vector(0 to MAX_DIFF);
  signal ovf1_q : std_logic_vector(0 to MAX_DIFF);
  signal pipestages1 : integer;

  signal re : signed(result_re'length downto 0);
  signal im : signed(result_im'length downto 0);
  signal ovf : std_logic;
  signal result_ovf_re, result_ovf_im : std_logic;

 begin

  i0 : entity work.complex_mult_sum(rtl)
  generic map(
    IMPLEMENTATION     => IMPLEMENTATION,
    OPTIMIZATION       => OPTIMIZATION,
    NUM_MULT           => NUM_MULT_0,
    USE_ACCU           => USE_ACCU,
    USE_NEGATION       => USE_NEGATION,
    USE_CONJUGATE_X    => USE_CONJUGATE_X,
    USE_CONJUGATE_Y    => USE_CONJUGATE_Y,
    NUM_INPUT_REG      => NUM_INPUT_REG,
    NUM_OUTPUT_REG     => 0, -- additional output registers are always implemented at the end of the adder tree
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT-LSBEXT,
    OUTPUT_ROUND       => false,
    OUTPUT_CLIP        => false,
    OUTPUT_OVERFLOW    => false
  )
  port map(
    clk        => clk,
    rst        => rst,
    clkena     => clkena,
    clr        => clr,
    vld        => vld,
    neg        => neg(0 to NUM_MULT_0-1),
    x_re       => x_re(0 to NUM_MULT_0-1),
    x_im       => x_im(0 to NUM_MULT_0-1),
    x_conj     => x_conj(0 to NUM_MULT_0-1),
    y_conj     => y_conj(0 to NUM_MULT_0-1),
    y_re       => y_re_i(0 to NUM_MULT_0-1),
    y_im       => y_im_i(0 to NUM_MULT_0-1),
    result_re  => re0,
    result_im  => im0,
    result_vld => vld0,
    result_ovf => ovf0,
    PIPESTAGES => pipestages0
  );

  i1 : entity work.complex_mult_sum(rtl)
  generic map(
    IMPLEMENTATION     => IMPLEMENTATION,
    OPTIMIZATION       => OPTIMIZATION,
    NUM_MULT           => NUM_MULT_1,
    USE_ACCU           => USE_ACCU,
    USE_NEGATION       => USE_NEGATION,
    USE_CONJUGATE_X    => USE_CONJUGATE_X,
    USE_CONJUGATE_Y    => USE_CONJUGATE_Y,
    NUM_INPUT_REG      => NUM_INPUT_REG,
    NUM_OUTPUT_REG     => 0, -- additional output registers are always implemented at the end of the adder tree
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT-LSBEXT,
    OUTPUT_ROUND       => false,
    OUTPUT_CLIP        => false,
    OUTPUT_OVERFLOW    => false
  )
  port map(
    clk        => clk,
    rst        => rst,
    clkena     => clkena,
    clr        => clr,
    vld        => vld,
    neg        => neg(NUM_MULT_0 to NUM_MULT-1),
    x_re       => x_re(NUM_MULT_0 to NUM_MULT-1),
    x_im       => x_im(NUM_MULT_0 to NUM_MULT-1),
    x_conj     => x_conj(NUM_MULT_0 to NUM_MULT_0+NUM_MULT_1-1),
    y_conj     => y_conj(NUM_MULT_0 to NUM_MULT-1),
    y_re       => y_re_i(NUM_MULT_0 to NUM_MULT-1),
    y_im       => y_im_i(NUM_MULT_0 to NUM_MULT-1),
    result_re  => re1_q(0),
    result_im  => im1_q(0),
    result_vld => vld1_q(0), -- actually needed ?
    result_ovf => ovf1_q(0),
    PIPESTAGES => pipestages1
  );

  -- pipeline to compensate different number of pipestages
  comp : process(clk) begin
    if rising_edge(clk) then
      if rst/='0' then
        vld1_q(1 to MAX_DIFF) <= (others=>'0');
        ovf1_q(1 to MAX_DIFF) <= (others=>'0');
        re1_q(1 to MAX_DIFF) <= (others=>(others=>'-'));
        im1_q(1 to MAX_DIFF) <= (others=>(others=>'-'));
      elsif clkena='1' then
        vld1_q(1 to MAX_DIFF) <= vld1_q(0 to MAX_DIFF-1);
        ovf1_q(1 to MAX_DIFF) <= ovf1_q(0 to MAX_DIFF-1);
        re1_q(1 to MAX_DIFF) <= re1_q(0 to MAX_DIFF-1);
        im1_q(1 to MAX_DIFF) <= im1_q(0 to MAX_DIFF-1);
      end if;
    end if;
  end process;

  -- here always pipestages0 >= pipestages1
  re <= resize(re0,re'length) + resize(re1_q(pipestages0-pipestages1),re'length);
  im <= resize(im0,im'length) + resize(im1_q(pipestages0-pipestages1),im'length);
  ovf <= ovf0 or ovf1_q(pipestages0-pipestages1);

  i_re : entity work.xilinx_output_logic
  generic map(
    PIPELINE_STAGES    => 1 + NUM_OUTPUT_REG,
    OUTPUT_SHIFT_RIGHT => LSBEXT,
    OUTPUT_CLIP        => OUTPUT_CLIP,
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
  )
  port map(
    clk         => clk,
    rst         => rst,
    clkena      => clkena,
    dsp_out     => re,
    dsp_out_vld => vld0,
    dsp_out_ovf => ovf,
    dsp_out_rnd => to_01(OUTPUT_ROUND),
    result      => result_re,
    result_vld  => result_vld,
    result_ovf  => result_ovf_re
  );

  i_im : entity work.xilinx_output_logic
  generic map(
    PIPELINE_STAGES    => 1 + NUM_OUTPUT_REG,
    OUTPUT_SHIFT_RIGHT => LSBEXT,
    OUTPUT_CLIP        => OUTPUT_CLIP,
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
  )
  port map(
    clk         => clk,
    rst         => rst,
    clkena      => clkena,
    dsp_out     => im,
    dsp_out_vld => vld0,
    dsp_out_ovf => ovf,
    dsp_out_rnd => to_01(OUTPUT_ROUND),
    result      => result_im,
    result_vld  => open, -- same as real component
    result_ovf  => result_ovf_im
  );

  result_ovf <= result_ovf_re or result_ovf_im;

  PIPESTAGES <= pipestages0 + 1 + NUM_OUTPUT_REG;

 end generate; --tree

end architecture;
