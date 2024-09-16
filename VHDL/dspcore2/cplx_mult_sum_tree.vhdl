-------------------------------------------------------------------------------
-- @file       cplx_mult_sum_tree.vhdl
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
  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;

-- TODO : move high-speed option further down? How to distinguish different delays in impl. in AUTO mode ?

architecture tree of cplx_mult_sum is

  constant OPTIMIZATION : string := "RESOURCES";--"PERFORMANCE"; -- TODO: OPTIMIZATION
  constant clkena : std_logic := '1'; -- TODO : CLKENA not yet supported

  -- TODO : CONJ not yet supported
  constant USE_CONJUGATE_X : boolean := false;
  constant USE_CONJUGATE_Y : boolean := false;
  constant x_conj, y_conj : std_logic_vector(0 to NUM_MULT-1) := (others=>'0');

  -- Currently only a maximum of 3 chain links are supported!
  -- Reason: number of required input pipeline registers grows significantly with every new chain link
  constant MAX_CHAIN_LENGTH : positive := 3;

  constant PRODUCT_WIDTH : natural := x(x'low).re'length + y(y'low).re'length;

begin

  gchain : if NUM_MULT<=MAX_CHAIN_LENGTH generate
    signal x_re  : signed_vector(0 to NUM_MULT-1)(x(x'low).re'length-1 downto 0);
    signal x_im  : signed_vector(0 to NUM_MULT-1)(x(x'low).im'length-1 downto 0);
    signal x_vld : std_logic_vector(0 to NUM_MULT-1) := (others=>'0');
    signal x_ovf : std_logic_vector(0 to NUM_MULT-1) := (others=>'0');
    signal y_re  : signed_vector(0 to NUM_MULT-1)(y(y'low).re'length-1 downto 0);
    signal y_im  : signed_vector(0 to NUM_MULT-1)(y(y'low).im'length-1 downto 0);
    signal y_vld : std_logic_vector(0 to NUM_MULT-1) := (others=>'0');
    signal y_ovf : std_logic_vector(0 to NUM_MULT-1) := (others=>'0');
    signal rst_i : std_logic;
    signal result_ovf : std_logic;
  begin

    rst_i <= x(x'low).rst or y(y'low).rst;

    -- convert input vectors
    process(x,y)
    begin
      for n in 0 to (NUM_MULT-1) loop
        x_re(n)  <= x(n).re;
        x_im(n)  <= x(n).im;
        x_vld(n) <= x(n).vld;
        x_ovf(n) <= x(n).ovf;
        y_re(n)  <= y(n).re;
        y_im(n)  <= y(n).im;
        y_vld(n) <= y(n).vld;
        y_ovf(n) <= y(n).ovf;
      end loop;
    end process;
  
    -- last compiled architecture (only device specific architectures shall be compiled!)
    dspchain : entity work.complex_macc_chain(dsp48e2) -- TODO: remove architecture
    generic map(
      OPTIMIZATION       => OPTIMIZATION,
      NUM_MULT           => NUM_MULT,
      NUM_ACCU_CYCLES    => 1, -- accu disabled
      NUM_SUMMAND_Z      => 0, -- Z input unused
      USE_NEGATION       => USE_NEGATION,
      USE_CONJUGATE_X    => USE_CONJUGATE_X,
      USE_CONJUGATE_Y    => USE_CONJUGATE_Y,
      NUM_INPUT_REG_XY   => NUM_INPUT_REG,
      NUM_INPUT_REG_Z    => 0, -- only relevant for OPTIMIZATION="RESOURCES"
      NUM_OUTPUT_REG     => NUM_OUTPUT_REG,
      OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
      OUTPUT_ROUND       => (MODE='N'),
      OUTPUT_CLIP        => (MODE='S'),
      OUTPUT_OVERFLOW    => (MODE='O')
    )
    port map(
      clk           => clk,
      rst           => rst_i,
      clkena        => clkena,
      clr           => open, -- irrelevant because accumulation disabled
      neg           => neg,
      x_re          => x_re,
      x_im          => x_im,
      x_vld         => x_vld,
      x_conj        => x_conj,
      y_re          => y_re,
      y_im          => y_im,
      y_vld         => y_vld,
      y_conj        => y_conj,
      z_re          => (0 to NUM_MULT-1=>"00"), -- unused
      z_im          => (0 to NUM_MULT-1=>"00"), -- unused
      z_vld         => open, -- unused
      result_re     => result.re,
      result_im     => result.im,
      result_vld    => result.vld,
      result_ovf    => result_ovf,
      result_rst    => result.rst,
      PIPESTAGES    => PIPESTAGES
    );

    -- Merge potential new DSP overflow bits with input overflow bits
    govf : if MODE='X' generate
      -- ignore input overflow bits, just report DSP chain internal overflows
      result.ovf <= result_ovf;
    else generate
      -- The number of pipeline stages is reported as constant at the output port
      -- of the DSP implementation. PIPESTAGES is not a generic and it cannot be used
      -- to constrain the length of a pipeline, hence a maximum pipeline length
      -- must be defined here. Increase the value if required.
      constant MAX_PIPESTAGES : positive := 16;
      signal ovf_q : std_logic_vector(1 to MAX_PIPESTAGES) := (others=>'0');
    begin
      -- At least two DSP pipeline stages are assumed.
      -- To relax timing the input OVF signals are merged in two steps
      -- 1. merge overflow bits of each input pair, X and Y must be valid!
      --    (otherwise product will be invalid and not contribute to sum, hence the overflow bit is irrelevant)
      -- 2. merge overflow bits of all NUM_MULT input pairs
      process(clk)
        variable ovf1 : x_ovf'subtype;
      begin
        ovf_q(1) <= (or ovf1);
        if rising_edge(clk) then
          if clkena='1' then
            ovf1 := (x_ovf or y_ovf) and x_vld and y_vld;
            ovf_q(2 to MAX_PIPESTAGES) <= ovf_q(1 to MAX_PIPESTAGES-1);
          end if;
        end if;
      end process;
      result.ovf <= result_ovf or ovf_q(PIPESTAGES);
    end generate govf;

  end generate gchain;

 ------------------------------------------------------------------------------

 -- recursive tree
 gtree : if NUM_MULT>MAX_CHAIN_LENGTH generate

  -- ensure here that always NUM_MULT_0 >= NUM_MULT_1
  constant NUM_MULT_1 : positive := NUM_MULT/2; -- floor(NUM_MULT/2)
  constant NUM_MULT_0 : positive := NUM_MULT - NUM_MULT_1;

  -- only pass modes 'N' and 'X' (if set) down to leafs
  function MODE_FILTERED return cplx_mode is
  begin
    if MODE='N' and MODE='X' then return "NX";
    elsif MODE='N'           then return "N" ;
    elsif MODE='X'           then return "X" ;
    else return "-" ; end if;
  end function;

  -- Place an additional pipeline register after the adder stage when saturation/clipping
  -- (within output logic) is enabled. Otherwise connect to output logic directly and
  -- use the first output register as pipeline register.
  -- This might be required only after the final adder stage of the tree.
  function PIPEREGS_AFTER_ADDER return natural is
  begin
    if MODE='S' then return 1; else return 0; end if;
  end function;

  -- at least one output register after each adder stage
  constant OUTREGS : natural := maximum(1, NUM_OUTPUT_REG);

  -- Dimension the result width of each tree branch such that overflows in the leafs are impossible.
  -- Consider one additional guard bit for the complex multiplication.
  -- Also consider that the shift-right and rounding is performed in the tree leafs, i.e. in the DSPs.
  constant RESULT_WIDTH : positive := PRODUCT_WIDTH + 1 + log2ceil(NUM_MULT_0) - OUTPUT_SHIFT_RIGHT;

  signal result0 : cplx(re(RESULT_WIDTH-1 downto 0),im(RESULT_WIDTH-1 downto 0));
  signal pipestages0 : integer range 0 to 31;

  -- maximum difference between pipeline stages
  constant MAX_PIPE_DIFF : positive := 2;

  signal result1, result1_q : cplx(re(RESULT_WIDTH-1 downto 0),im(RESULT_WIDTH-1 downto 0));
  signal pipestages1 : integer range 0 to 31;

  -- result requires one more guard bit because of final adder stage
  signal res, res_q : cplx(re(RESULT_WIDTH downto 0),im(RESULT_WIDTH downto 0));
  signal result_ovf_re, result_ovf_im : std_logic;

 begin

  i0 : entity work.cplx_mult_sum
  generic map(
    NUM_MULT           => NUM_MULT_0,
    HIGH_SPEED_MODE    => open,  -- TODO: HIGH_SPEED_MODE
    USE_NEGATION       => USE_NEGATION,
    NUM_INPUT_REG      => NUM_INPUT_REG,
    NUM_OUTPUT_REG     => 0, -- additional output registers are always implemented after every adder stage and at the end of the adder tree
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    MODE               => MODE_FILTERED -- most modes must be considered in last stage only
  )
  port map(
    clk        => clk,
    clk2       => open, -- unused
    neg        => neg(0 to NUM_MULT_0-1),
    x          => x(0 to NUM_MULT_0-1),
    y          => y(0 to NUM_MULT_0-1),
    result     => result0,
    PIPESTAGES => pipestages0
  );

  i1 : entity work.cplx_mult_sum
  generic map(
    NUM_MULT           => NUM_MULT_1,
    HIGH_SPEED_MODE    => open,  -- TODO: HIGH_SPEED_MODE
    USE_NEGATION       => USE_NEGATION,
    NUM_INPUT_REG      => NUM_INPUT_REG,
    NUM_OUTPUT_REG     => 0, -- additional output registers are always implemented after every adder stage and at the end of the adder tree
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    MODE               => MODE_FILTERED -- most modes must be considered in last stage only
  )
  port map(
    clk        => clk,
    clk2       => open, -- unused
    neg        => neg(NUM_MULT_0 to NUM_MULT-1),
    x          => x(NUM_MULT_0 to NUM_MULT-1),
    y          => y(NUM_MULT_0 to NUM_MULT-1),
    result     => result1,
    PIPESTAGES => pipestages1
  );

  -- delay compensation, here always pipestages0 >= pipestages1
  delay_comp : entity work.cplx_delay_compensation
  generic map(
    MAX_PIPELINE_STAGES => MAX_PIPE_DIFF,
    MODE                => open
  )
  port map(
    clk        => clk,
    rst        => open,
    clkena     => clkena,
    delay      => pipestages0-pipestages1,
    din        => result1,
    dout       => result1_q
  );

  -- adder stage
  process(all)
    variable re0, re1 : res.re'subtype;
    variable im0, im1 : res.im'subtype;
  begin
    res.rst <= result0.rst or result1_q.rst;
    res.vld <= result0.vld or result1_q.vld;
    res.ovf <= result0.ovf or result1_q.ovf;
    re0 := resize(result0.re,re0'length); re1 := resize(result1_q.re,re1'length);
    im0 := resize(result0.im,im0'length); im1 := resize(result1_q.im,im1'length);
    res.re <= re0 + re1 when result0.vld='1' and result1_q.vld='1' else
              re0       when result0.vld='1'   else
              re1       when result1_q.vld='1' else (others=>'0');
    res.im <= im0 + im1 when result0.vld='1' and result1_q.vld='1' else
              im0       when result0.vld='1'   else
              im1       when result1_q.vld='1' else (others=>'0');
  end process;

  pipereg : entity cplxlib.cplx_pipeline
    generic map(
      NUM_PIPELINE_STAGES => PIPEREGS_AFTER_ADDER,
      MODE                => open
    )
    port map(
      clk    => clk,
      rst    => open,
      clkena => clkena,
      din    => res,
      dout   => res_q
    );

  -- real part output
  re_out : entity work.xilinx_output_logic
  generic map(
    PIPELINE_STAGES    => OUTREGS,
    OUTPUT_SHIFT_RIGHT => 0,
    OUTPUT_CLIP        => (MODE='S'),
    OUTPUT_OVERFLOW    => (MODE='O')
  )
  port map(
    clk         => clk,
    rst         => res_q.rst,
    clkena      => clkena,
    dsp_out     => res_q.re,
    dsp_out_vld => res_q.vld,
    dsp_out_ovf => res_q.ovf,
    dsp_out_rnd => open, -- rounding already done in leaf DSPs
    result      => result.re,
    result_vld  => result.vld,
    result_ovf  => result_ovf_re,
    result_rst  => result.rst
  );

  -- imaginary part output
  im_out : entity work.xilinx_output_logic
  generic map(
    PIPELINE_STAGES    => OUTREGS,
    OUTPUT_SHIFT_RIGHT => 0,
    OUTPUT_CLIP        => (MODE='S'),
    OUTPUT_OVERFLOW    => (MODE='O')
  )
  port map(
    clk         => clk,
    rst         => res_q.rst,
    clkena      => clkena,
    dsp_out     => res_q.im,
    dsp_out_vld => res_q.vld,
    dsp_out_ovf => open, -- not needed here, already considered in real part
    dsp_out_rnd => open, -- rounding already done in leaf DSPs
    result      => result.im,
    result_vld  => open, -- same as real part
    result_ovf  => result_ovf_im,
    result_rst  => open  -- same as real part
  );

  result.ovf <= result_ovf_re or result_ovf_im;

  PIPESTAGES <= pipestages0 + PIPEREGS_AFTER_ADDER + OUTREGS;

 end generate gtree;

end architecture;
