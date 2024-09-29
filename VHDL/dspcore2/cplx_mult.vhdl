-------------------------------------------------------------------------------
--! @file       cplx_mult.vhdl
--! @author     Fixitfetish
--! @date       29/Sep/2024
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Code comments are optimized for SIGASI and DOXYGEN.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;
  use baselib.pipereg_pkg.all;
library cplxlib;
  use cplxlib.cplx_pkg.all;

--! @brief N complex multiplications.
--!
--! Use this entity for full complex multiplications or scalar multiplications. 
--!
--! If just weighting (only real factor) is required use the entity cplx_weight
--! instead because less multiplications and resources are required in this case.
--! Two operation modes are supported:
--! 1. result(n) = +/- x(n) * y(n)  # separate factor y for each element of x
--! 2. result(n) = +/- x(n) * y(0)  # factor y is the same for all elements of x
--!
--! The length of the input factors is flexible.
--! The input factors are automatically resized with sign extensions bits to the
--! maximum possible factor length needed.
--! The maximum length of the input factors is device and implementation specific.
--! The size of the real and imaginary part of a complex input must be identical.
--! The maximum result width is
--!   W = x.re'length + y.re'length + 1 .
--! (Note that a complex multiplication requires two signed multiplication, hence
--!  an additional guard bit is needed.)
--!
--! Dependent on result.re'length a shift right is required to avoid overflow or clipping.
--!   OUTPUT_SHIFT_RIGHT = W - result.re'length .
--! The number right shifts can also be smaller with the risk of overflows/clipping.
--!
--! The number of delay cycles depends on the configuration and the underlying hardware.
--! The number pipeline stages is reported as constant at output port PIPESTAGES.
--! Note that the number of input register stages should be chosen carefully
--! because dependent on the number of inputs the number resulting registers
--! in logic can be very high. If just more delay is needed use additional
--! output registers instead of input registers.
--!
--! The Double Data Rate (DDR) clock 'clk2' input is only relevant when a DDR
--! implementation of this module is used.
--! Note that the double rate clock 'clk2' must have double the frequency of
--! system clock 'clk' and must be synchronous and related to 'clk'.
--!
--! @image html cplx_mult.svg "" width=600px
--!
--! Also available are the following entities:
--! * cplx_mult_accu
--! * cplx_mult_sum
--! * cplx_weight
--! * cplx_weight_accu
--! * cplx_weight_sum
--!
--! VHDL Instantiation Template:
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
--! I1 : cplx_mult
--! generic map(
--!   NUM_MULT           => positive, -- number of parallel multiplications
--!   HIGH_SPEED_MODE    => boolean,  -- enable high speed mode
--!   USE_NEGATION       => boolean,  -- enable negation port
--!   NUM_INPUT_REG      => natural,  -- number of input registers
--!   NUM_OUTPUT_REG     => natural,  -- number of output registers
--!   OUTPUT_SHIFT_RIGHT => natural,  -- number of right shifts
--!   AUX_DEFAULT        => std_logic_vector, -- auxiliary default/reset value
--!   MODE               => cplx_mode -- options
--! )
--! port map(
--!   clk        => in  std_logic, -- clock
--!   clk2       => in  std_logic, -- clock x2
--!   neg        => in  std_logic_vector(0 to NUM_MULT-1), -- negation per input x
--!   aux        => in  std_logic_vector, -- optional auxiliary input
--!   x          => in  cplx_vector(0 to NUM_MULT-1), -- first factors
--!   y          => in  cplx_vector, -- second factors
--!   result     => out cplx_vector(0 to NUM_MULT-1), -- product results
--!   result_aux => out std_logic_vector, -- optional auxiliary output
--!   PIPESTAGES => out natural -- constant number of pipeline stages
--! );
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--!
entity cplx_mult is
generic (
  --! Number of parallel multiplications - mandatory generic!
  NUM_MULT : positive;
  --! Enable high speed mode with more pipelining for higher clock rates
  HIGH_SPEED_MODE : boolean := false;
  --! @brief Enable negation port. If enabled then dynamic negation of partial
  --! products is implemented (preferably within the DSP cells otherwise in logic). 
  --! Enabling the negation might have negative side effects on pipeline stages,
  --! input width limitations and timing.
  --! Disable negation if not needed and the negation port input is ignored.
  USE_NEGATION : boolean := false;
  --! @brief Number of additional input registers in system clock domain.
  --! At least one is strongly recommended.
  --! If available the input registers within the DSP cell are used.
  NUM_INPUT_REG : natural := 1;
  --! @brief Number of additional result output registers in system clock domain.
  --! At least one is recommended when logic for rounding and/or clipping is enabled.
  --! Typically all output registers are implemented in logic and are not part of a DSP cell.
  NUM_OUTPUT_REG : natural := 0;
  --! Number of bits by which the result output is shifted right
  OUTPUT_SHIFT_RIGHT : natural := 0;
  --! @brief Default and reset value of the optional auxiliary signal.
  --! Given range also defines width of auxiliary signal.
  AUX_DEFAULT : std_logic_vector := (0 downto 0=>'-');
  --! Supported operation modes 'R','O','N','S' and 'X'
  MODE : cplx_mode := "-"
);
port (
  --! Standard system clock
  clk        : in  std_logic;
  --! Optional double rate clock (only relevant when a DDR implementation is used)
  clk2       : in  std_logic := '0';
  --! @brief Negation of partial products , '0' -> +(x(n)*y(n)), '1' -> -(x(n)*y(n)).
  --! Negation is disabled by default.
  --! Dependent on the DSP cell type some implementations might not fully support
  --! the negation feature. Either additional logic is required or negation
  --! of certain input indices is not supported. Please refer to the description of
  --! vendor specific implementation.
  neg        : in  std_logic_vector(0 to NUM_MULT-1) := (others=>'0');
  --! Optional input of user-defined auxiliary bits
  aux        : in  std_logic_vector(AUX_DEFAULT'range) := AUX_DEFAULT;
  --! x(n) are the complex inputs of the N multiplications.
  x          : in  cplx_vector(0 to NUM_MULT-1);
  --! complex factor (either one for all elements of X or one per each element of X). Requires 'TO' range.
  y          : in  cplx_vector;
  --! Resulting product output vector (optionally rounded and clipped).
  result     : out cplx_vector(0 to NUM_MULT-1);
  --! Optional output of delayed auxiliary user-defined bits (same length as auxiliary input)
  result_aux : out std_logic_vector(AUX_DEFAULT'range);
  --! Number of pipeline stages, constant, depends on configuration and device specific implementation
  PIPESTAGES : out natural := 1
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert ((y'length=1 or y'length=x'length) and y'ascending)
    report cplx_mult'INSTANCE_NAME & " Input vector Y must have length of 1 or 'TO' range with same length as input X."
    severity failure;

  assert (x(x'left).re'length=x(x'left).im'length) and (y(y'left).re'length=y(y'left).im'length)
     and (result(result'left).re'length=result(result'left).im'length)
    report cplx_mult'INSTANCE_NAME & " Real and imaginary components must have same size."
    severity failure;

  assert (MODE/='U' and MODE/='Z' and MODE/='I')
    report cplx_mult'INSTANCE_NAME & " Rounding options 'U', 'Z' and 'I' are not supported."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;

---------------------------------------------------------------------------------------------------

architecture rtl of cplx_mult is

  constant OPTIMIZATION : string := "RESOURCES";--"PERFORMANCE"; -- TODO: OPTIMIZATION
  constant rst : std_logic := '0'; -- TODO  global reset
  constant clkena : std_logic := '1'; -- TODO  clock enable

  -- TODO : CONJ not yet supported
  constant USE_CONJUGATE_X : boolean := false;
  constant USE_CONJUGATE_Y : boolean := false;
  constant x_conj, y_conj : std_logic_vector(0 to NUM_MULT-1) := (others=>'0');

  -- The number of pipeline stages is reported as constant at the output port
  -- of the DSP implementation. PIPE_DSP is not a generic and it cannot be used
  -- to constrain the length of a pipeline, hence a maximum pipeline length
  -- must be defined here. Increase the value if required.
  constant MAX_NUM_PIPE_DSP : positive := 16;

  -- bit resolution of input and output data
  constant WIDTH_X : positive := x(x'left).re'length;
  constant WIDTH_Y : positive := y(y'left).re'length;
  constant WIDTH_R : positive := result(result'left).re'length;

  -- number of elements of factor vector
  -- (must be either 1 or the same length as x)
  constant NUM_FACTOR : positive := y'length;

  -- convert to default range
  alias y_i : cplx_vector(0 to NUM_FACTOR-1)(re(WIDTH_Y-1 downto 0),im(WIDTH_Y-1 downto 0)) is y;

  signal x_re, x_im : signed_vector(0 to NUM_MULT-1)(WIDTH_X-1 downto 0);
  signal y_re, y_im : signed_vector(0 to NUM_MULT-1)(WIDTH_Y-1 downto 0);
  signal x_vld, y_vld : std_logic_vector(0 to NUM_MULT-1);

  -- merged input signals and compensate for multiplier pipeline stages
  type t_delay is array(integer range <>) of std_logic_vector(0 to NUM_MULT-1);
  signal rst_i : t_delay(0 to MAX_NUM_PIPE_DSP) := (others=>(others=>'1'));
  signal ovf : t_delay(0 to MAX_NUM_PIPE_DSP) := (others=>(others=>'0'));

  -- auxiliary
  signal data_reset : std_logic_vector(0 to NUM_MULT-1) := (others=>'0');
  type t_aux_delay is array(integer range <>) of std_logic_vector(AUX_DEFAULT'range);
  signal aux_q : t_aux_delay(0 to MAX_NUM_PIPE_DSP) := (others=>AUX_DEFAULT);

  -- DSP output signals
  signal r_ovf_re, r_ovf_im : std_logic_vector(0 to NUM_MULT-1);
  signal rslt : cplx_vector(0 to NUM_MULT-1)(re(WIDTH_R-1 downto 0),im(WIDTH_R-1 downto 0));

  -- pipeline stages of used DSP cell
  type t_pipe is array(integer range <>) of natural;
  signal PIPE_DSP : t_pipe(0 to NUM_MULT-1);

  -- dummy sink to avoid warnings
  procedure dummy_sink(si:in std_logic) is
    variable sv : std_logic := '1';
  begin sv:=sv or si; end procedure;

begin

  -- dummy sink for unused clock
  dummy_sink(clk2);

  g_merge : for n in 0 to NUM_MULT-1 generate
    g1 : if NUM_FACTOR=1 generate
      -- merge input control signals
      rst_i(0)(n) <= (x(n).rst or y_i(0).rst);
      -- Consider overflow flags of all inputs.
      -- If the overflow flag of any input is set then also the result
      -- will have the overflow flag set.   
      ovf(0)(n) <= '0' when (MODE='X' or rst_i(0)(n)='1') else
                   (x(n).ovf or y_i(0).ovf);
    end generate;
    gn : if NUM_FACTOR=NUM_MULT generate
      -- merge input control signals
      rst_i(0)(n) <= (x(n).rst or y_i(n).rst);
      -- Consider overflow flags of all inputs.
      -- If the overflow flag of any input is set then also the result
      -- will have the overflow flag set.   
      ovf(0)(n) <= '0' when (MODE='X' or rst_i(0)(n)='1') else
                   (x(n).ovf or y_i(n).ovf);
    end generate;
  end generate;

  -- convert input vectors
  g_in : for n in 0 to NUM_MULT-1 generate
    x_re(n)  <= x(n).re;
    x_im(n)  <= x(n).im;
    x_vld(n) <= x(n).vld;
    g1 : if NUM_FACTOR=1 generate
      y_re(n)  <= y_i(0).re;
      y_im(n)  <= y_i(0).im;
      y_vld(n) <= y_i(0).vld;
    end generate;
    gn : if NUM_FACTOR=NUM_MULT generate
      y_re(n)  <= y_i(n).re;
      y_im(n)  <= y_i(n).im;
      y_vld(n) <= y_i(n).vld;
    end generate;
  end generate;

  -- reset result data output to zero
  data_reset <= rst_i(0) when MODE='R' else (others=>'0'); -- TODO reset

  -- feed auxiliary signal pipeline
  aux_q(0) <= aux;

  -- accumulator delay compensation (DSP bypassed!)
  g_delay : for n in 1 to MAX_NUM_PIPE_DSP generate
    pipereg(xout=>rst_i(n), xin=>rst_i(n-1), clk=>clk, ce=>clkena);
    pipereg(xout=>ovf(n)  , xin=>ovf(n-1)  , clk=>clk, ce=>clkena);
    pipereg(xout=>aux_q(n), xin=>aux_q(n-1), clk=>clk, ce=>clkena, rst=>rst, rstval=>AUX_DEFAULT);
  end generate;

  g_mult : for n in 0 to NUM_MULT-1 generate

    cmacc : entity work.complex_mult1add1--(dsp48e2) -- TODO: remove architecture
    generic map(
      OPTIMIZATION        => OPTIMIZATION,
      NUM_ACCU_CYCLES     => open, -- accumulation not required
      NUM_SUMMAND_CHAININ => open, -- unused
      NUM_SUMMAND_Z       => open, -- unused
      USE_NEGATION        => USE_NEGATION,
      USE_CONJUGATE_X     => USE_CONJUGATE_X,
      USE_CONJUGATE_Y     => USE_CONJUGATE_Y,
      NUM_INPUT_REG_XY    => 1 + NUM_INPUT_REG, -- minimum one input register
      NUM_INPUT_REG_Z     => open, -- unused
      RELATION_RST        => open, -- TODO
      RELATION_CLR        => open, -- accumulation unused
      RELATION_NEG        => open, -- TODO
      NUM_OUTPUT_REG      => 1, -- at least the DSP internal output register
      OUTPUT_SHIFT_RIGHT  => OUTPUT_SHIFT_RIGHT,
      OUTPUT_ROUND        => (MODE='N'),
      OUTPUT_CLIP         => (MODE='S'),
      OUTPUT_OVERFLOW     => (MODE='O')
    )
    port map(
      clk             => clk,
      rst             => data_reset(n),
      clkena          => clkena,
      clr             => open, -- accumulation unused
      neg             => neg(n),
      x_re            => x_re(n),
      x_im            => x_im(n),
      x_vld           => x_vld(n),
      x_conj          => x_conj(n),
      y_re            => y_re(n),
      y_im            => y_im(n),
      y_vld           => y_vld(n),
      y_conj          => y_conj(n),
      z_re            => "00", -- unused
      z_im            => "00", -- unused
      z_vld           => open, -- unused
      result_re       => rslt(n).re,
      result_im       => rslt(n).im,
      result_vld      => rslt(n).vld,
      result_ovf_re   => r_ovf_re(n),
      result_ovf_im   => r_ovf_im(n),
      result_rst      => rslt(n).rst,
      chainin_re      => open, -- unused
      chainin_im      => open, -- unused
      chainin_re_vld  => open, -- unused
      chainin_im_vld  => open, -- unused
      chainout_re     => open, -- unused
      chainout_im     => open, -- unused
      chainout_re_vld => open, -- unused
      chainout_im_vld => open, -- unused
      PIPESTAGES      => PIPE_DSP(n)
    );

    -- pipeline delay is the same for all
--    rslt(n).rst <= rst_i(PIPE_DSP(0))(n);
    rslt(n).ovf <= (r_ovf_re(n) or r_ovf_im(n)) when MODE='X' else
                   (r_ovf_re(n) or r_ovf_im(n) or ovf(PIPE_DSP(0))(n));
  end generate;

  -- result output pipeline
  i_out : entity cplxlib.cplx_vector_pipeline
  generic map(
    NUM_PIPELINE_STAGES => NUM_OUTPUT_REG,
    MODE                => MODE
  )
  port map(
    clk        => clk,
    rst        => open, -- TODO
    clkena     => clkena,
    din        => rslt,
    dout       => result
  );

  -- report constant number of pipeline register stages (in 'clk' domain)
  PIPESTAGES <= PIPE_DSP(0) + NUM_OUTPUT_REG;

  -- auxiliary signal output
  result_aux <= aux_q(PIPE_DSP(0)+NUM_OUTPUT_REG);

end architecture;
