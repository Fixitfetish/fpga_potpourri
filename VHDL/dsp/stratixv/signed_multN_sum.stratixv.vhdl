-------------------------------------------------------------------------------
--! @file       signed_multN_sum.stratixv.vhdl
--! @author     Fixitfetish
--! @date       02/Mar/2017
--! @version    0.10
--! @copyright  MIT License
--! @note       VHDL-1993
-------------------------------------------------------------------------------
-- Copyright (c) 2017 Fixitfetish
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library fixitfetish;
 use fixitfetish.ieee_extension.all;
 use fixitfetish.ieee_extension_types.all;

--! @brief This is an implementation of the entity 
--! @link signed_multN_sum signed_multN_sum @endlink
--! for Altera Stratix-V.
--! N signed multiplications are performed and all results are summed.
--!
--! This implementation uses N4 = floor((N+1)/4) instances of 
--! @link signed_mult4_sum signed_mult4_sum @endlink
--! and N2 = ceil(N/2)-2*N4 instances of
--! @link signed_mult2_accu1 signed_mult2_accu1 @endlink .
--! Overall 2*N4 + N2 Altera Stratix-V DSP blocks are required.
--!
--! * Input Data      : Nx2 signed values, each max 18 bits
--! * Input Register  : optional, at least one is strongly recommended
--! * Accu Register   : just pipeline register, accumulation not supported
--! * Rounding        : optional half-up, only possible in logic!
--! * Output Data     : 1x signed value, max 64 bits
--! * Output Register : optional, at least one strongly recommend, another after shift-right and saturation
--! * Pipeline stages : NUM_INPUT_REG + NUM_PIPELINE_REG + NUM_OUTPUT_REG
--!
--! @image html signed_multN_sum.stratixv.svg "" width=1000px

architecture stratixv of signed_multN_sum is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "signed_multN_sum(stratixv)";

  -- number of required MULT2 blocks 
  constant NUM_MULT2 : natural := (NUM_MULT+1)/2; -- ceil(NUM_MULT/2)

  -- number of resulting MULT4 instances 
  constant NUM_MULT4 : natural := NUM_MULT2/2; -- floor(NUM_MULT2/2)

  -- number of DSP entity outputs = inputs into first adder stage
  constant NUM_DSP_OUTPUTS : natural := (NUM_MULT2+1)/2;

  -- number of required adder tree stages - is at least 1 +++ TODO 0!?
  constant NUM_STAGES : natural := LOG2CEIL(NUM_DSP_OUTPUTS);

  -- Internal copy of inputs required because some multipliers of an entity might
  -- be unused and need to be set to zero.
  type t_x is array(integer range <>) of signed(x(0)'length-1 downto 0);
  type t_y is array(integer range <>) of signed(y(0)'length-1 downto 0);
  signal x_i : t_x(0 to 2*NUM_MULT2-1) := (others=>(others=>'0'));
  signal y_i : t_y(0 to 2*NUM_MULT2-1) := (others=>(others=>'0'));
  signal sub_i : std_logic_vector(0 to 2*NUM_MULT2-1) := (others=>'0');

  constant ROUND_ENABLE : boolean := OUTPUT_ROUND and (OUTPUT_SHIFT_RIGHT/=0);
  constant PRODUCT_WIDTH : natural := x(0)'length + y(0)'length;
  constant OUTPUT_WIDTH : positive := result'length;

  type integer_vector is array(integer range <>) of integer;
  
  -- output register pipeline (NUM_OUTPUT_REG-1)
  type r_oreg is
  record
    dat : signed(OUTPUT_WIDTH-1 downto 0);
    vld : std_logic;
    ovf : std_logic;
  end record;
  type array_oreg is array(integer range <>) of r_oreg;
  signal rslt : array_oreg(1 to NUM_OUTPUT_REG);
  
  -- calculate number of inputs to each stage
  function calc_num_inputs(n_mult2,n_stages:natural) return integer_vector is
    variable res : integer_vector(1 to n_stages);
  begin
    res(1) := (n_mult2+1)/2;
    if n_stages>=2 then 
      for n in 2 to n_stages loop res(n):=(res(n-1)+1)/2; end loop;
    end if;
    return res;
  end function;
  constant NUM_INPUTS_STAGE : integer_vector(1 to NUM_STAGES+1) := calc_num_inputs(NUM_MULT2,NUM_STAGES+1);

  -- calculate data input width to each stage
  function calc_width(n_stages:natural) return integer_vector is
    variable res : integer_vector(1 to n_stages+1);
  begin
    for n in 1 to n_stages+1 loop
      -- additional guard bits to ensure that overflows cannot occur in adder tree
      res(n) := (PRODUCT_WIDTH+2) - OUTPUT_SHIFT_RIGHT + n-1;
    end loop;
    return res;
  end function;
  constant WIDTH_STAGE : integer_vector(1 to NUM_STAGES+1) := calc_width(NUM_STAGES);

  function get_piperegs(n_stages:natural) return boolean_vector is
    variable res : boolean_vector(1 to n_stages+1) := (others=>false);
    variable is_even_stage : boolean;
  begin
    for s in 1 to n_stages loop
      is_even_stage := ( (s/2) = ((s+1)/2) );
      if ROUND_ENABLE and NUM_DSP_OUTPUTS>=2 then
        -- rounding is done in logic and counts as additional adder stage
        -- which might require an additional pipeline register.
        if FAST_MODE then
          -- add pipeline register before every logic adder stage
          res(s) := (s<=NUM_STAGES);
        else
          -- pipeline register only before every second (even) adder stage
          res(s) := is_even_stage;
        end if;
      else
        -- rounding is disabled
        if FAST_MODE then
          -- add pipeline register before every logic adder stage (except directly after DSP cell output)
          res(s) := (s/=1 and s<=NUM_STAGES);
        else
          -- pipeline register only before every second (odd) adder stage (except directly after DSP cell output)
          res(s) := (s/=1 and (not is_even_stage));
        end if;  
      end if;
    end loop;
    return res;
  end function;
  constant has_pipereg_stage : boolean_vector(1 to NUM_STAGES+1) := get_piperegs(NUM_STAGES);

begin

  -- Map inputs to internal signals
  g_in: for n in 0 to (NUM_MULT-1) generate
    x_i(n) <= x(n);
    y_i(n) <= y(n);
    sub_i(n) <= sub(n);
  end generate;

  -----------------------------------------------------------------------------
  -- when NUM_MULT <= 2  (no adder stage in logic required)
  g2: if NUM_MULT<=2 generate
    i4 : entity fixitfetish.signed_mult2_accu1
    generic map(
      NUM_SUMMAND        => 2,
      USE_CHAIN_INPUT    => false,
      NUM_INPUT_REG      => NUM_INPUT_REG,
      NUM_OUTPUT_REG     => NUM_OUTPUT_REG,
      OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
      OUTPUT_ROUND       => OUTPUT_ROUND,
      OUTPUT_CLIP        => OUTPUT_CLIP,
      OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
    )
    port map (
     clk        => clk,
     rst        => rst,
     clr        => '1', -- accumulator always disabled
     vld        => vld,
     sub        => sub_i(0 to 1),
     x0         => x_i(0),
     y0         => y_i(0),
     x1         => x_i(1),
     y1         => y_i(1),
     result     => result,
     result_vld => result_vld,
     result_ovf => result_ovf,
     chainin    => open,
     chainout   => open,
     PIPESTAGES => PIPESTAGES
    );
  end generate;

  -----------------------------------------------------------------------------

  -- when 3 <= NUM_MULT <= 4  (no adder stage in logic required)
  g4: if (NUM_MULT>=3 and NUM_MULT<=4) generate
    i4 : entity fixitfetish.signed_mult4_sum
    generic map(
      NUM_INPUT_REG      => NUM_INPUT_REG,
      NUM_OUTPUT_REG     => NUM_OUTPUT_REG,
      OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
      OUTPUT_ROUND       => OUTPUT_ROUND,
      OUTPUT_CLIP        => OUTPUT_CLIP,
      OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
    )
    port map (
     clk        => clk,
     rst        => rst,
     vld        => vld,
     sub        => sub_i(0 to 3),
     x0         => x_i(0),
     y0         => y_i(0),
     x1         => x_i(1),
     y1         => y_i(1),
     x2         => x_i(2),
     y2         => y_i(2),
     x3         => x_i(3),
     y3         => y_i(3),
     result     => result,
     result_vld => result_vld,
     result_ovf => result_ovf,
     chainout   => open,
     PIPESTAGES => PIPESTAGES
    );
  end generate;

  -----------------------------------------------------------------------------

  -- NUM_MULT>=5  (requires at least one adder stage in logic)
  gn: if NUM_MULT>=5 generate
    -- number of additional pipeline registers
    constant NUM_PIPELINE_REG : natural := SUM(has_pipereg_stage);
    -- inputs into adder stages (last stage with largest width)
    type t_din is array(integer range <>) of signed(WIDTH_STAGE(NUM_STAGES+1)-1 downto 0);
    -- matrix of inputs, one vector per stage (first stage with the most inputs)
    type t_din_stage is array(integer range <>) of t_din(0 to NUM_INPUTS_STAGE(1)-1);
    signal din_s, din_stage : t_din_stage(1 to NUM_STAGES+1) := (others=>(others=>(others=>'-'))); -- don't care about unused MSBs
    signal dsp_vld : std_logic_vector(0 to NUM_INPUTS_STAGE(1)-1);
    signal PIPEREGS_DSP : integer_vector(0 to NUM_INPUTS_STAGE(1)-1);
    -- delayed valid signal after DSP cell
    signal vld_q : std_logic_vector(0 to NUM_PIPELINE_REG);
  begin

    -- instantiate as many MULT4 instances as possible
    g4 : for n in 0 to NUM_MULT4-1 generate
    begin
      i4 : entity fixitfetish.signed_mult4_sum
      generic map(
        NUM_INPUT_REG      => NUM_INPUT_REG,
        NUM_OUTPUT_REG     => 1,
        OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
        OUTPUT_ROUND       => OUTPUT_ROUND,
        OUTPUT_CLIP        => false,
        OUTPUT_OVERFLOW    => false
      )
      port map (
       clk        => clk,
       rst        => rst,
       vld        => vld,
       sub        => sub_i(4*n+0 to 4*n+3),
       x0         => x_i(4*n+0),
       y0         => y_i(4*n+0),
       x1         => x_i(4*n+1),
       y1         => y_i(4*n+1),
       x2         => x_i(4*n+2),
       y2         => y_i(4*n+2),
       x3         => x_i(4*n+3),
       y3         => y_i(4*n+3),
       result     => din_s(1)(n)(WIDTH_STAGE(1)-1 downto 0),
       result_vld => dsp_vld(n),
       result_ovf => open,
       chainout   => open,
       PIPESTAGES => PIPEREGS_DSP(n)
      );
    end generate;

    -- additional MULT2 instance required if the number of MULT2 blocks is odd
    g2: if NUM_MULT4<NUM_INPUTS_STAGE(1) generate
    begin
      i2 : entity fixitfetish.signed_mult2_accu1
      generic map(
        NUM_SUMMAND        => 2,
        USE_CHAIN_INPUT    => false,
        NUM_INPUT_REG      => NUM_INPUT_REG,
        NUM_OUTPUT_REG     => 1,
        OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
        OUTPUT_ROUND       => OUTPUT_ROUND,
        OUTPUT_CLIP        => false,
        OUTPUT_OVERFLOW    => false
      )
      port map (
       clk        => clk,
       rst        => rst,
       clr        => '1', -- accumulator always disabled
       vld        => vld,
       sub        => sub(4*NUM_MULT4 to 4*NUM_MULT4+1),
       x0         => x_i(4*NUM_MULT4),
       y0         => y_i(4*NUM_MULT4),
       x1         => x_i(4*NUM_MULT4+1),
       y1         => y_i(4*NUM_MULT4+1),
       result     => din_s(1)(NUM_MULT4)(WIDTH_STAGE(1)-1 downto 0),
       result_vld => open,
       result_ovf => open,
       chainin    => open,
       chainout   => open,
       PIPESTAGES => open
      );
    end generate;

   gstages : for s in 1 to NUM_STAGES generate
   begin

    -- pipeline register
    pipe_off : if not has_pipereg_stage(s) generate
      din_stage(s)(0 to NUM_INPUTS_STAGE(s)-1) <=
          din_s(s)(0 to NUM_INPUTS_STAGE(s)-1);
    end generate;
    pipe_on : if has_pipereg_stage(s) generate
      din_stage(s)(0 to NUM_INPUTS_STAGE(s)-1) <= 
          din_s(s)(0 to NUM_INPUTS_STAGE(s)-1) when rising_edge(clk);
    end generate;

    -- adder tree for all pairs of inputs
    add : for i in 0 to NUM_INPUTS_STAGE(s)/2-1 generate
      din_s(s+1)(i)(WIDTH_STAGE(s+1)-1 downto 0) <=
          resize(din_stage(s)(2*i+0)(WIDTH_STAGE(s)-1 downto 0),WIDTH_STAGE(s+1))
        + resize(din_stage(s)(2*i+1)(WIDTH_STAGE(s)-1 downto 0),WIDTH_STAGE(s+1));
    end generate;

    -- in case of odd number of inputs forward last input to next stage
    forward : if (2*NUM_INPUTS_STAGE(s+1))/=NUM_INPUTS_STAGE(s) generate
      din_s(s+1)(NUM_INPUTS_STAGE(s+1)-1)(WIDTH_STAGE(s+1)-1 downto 0) <=
         resize(din_stage(s)(NUM_INPUTS_STAGE(s)-1)(WIDTH_STAGE(s)-1 downto 0),WIDTH_STAGE(s+1));
    end generate;

--    -- output result if last stage
--    final : if s=NUM_STAGES generate
--    begin
--      p_out : process(din_s(s+1)(0))
--       variable v_dat : signed(result'length-1 downto 0);
--       variable v_ovf : std_logic;
--      begin
--        RESIZE_CLIP(din  => din_s(s+1)(0)(WIDTH_STAGE(s+1)-1 downto 0),
--                    dout => v_dat,
--                    ovfl => v_ovf,
--                    clip => OUTPUT_CLIP );
--        rslt(0).dat <= v_dat;
--        if OUTPUT_OVERFLOW then rslt(0).ovf<=v_ovf; else rslt(0).ovf<='0'; end if;
--      end process;
--    end generate;

   end generate; -- for NUM_STAGES

   p_out : process(din_s(NUM_STAGES+1)(0))
    variable v_dat : signed(OUTPUT_WIDTH-1 downto 0);
    variable v_ovf : std_logic;
   begin
     RESIZE_CLIP(din  => din_s(NUM_STAGES+1)(0)(WIDTH_STAGE(NUM_STAGES+1)-1 downto 0),
                 dout => v_dat,
                 ovfl => v_ovf,
                 clip => OUTPUT_CLIP );
     rslt(1).dat <= v_dat;
     if OUTPUT_OVERFLOW then rslt(1).ovf<=v_ovf; else rslt(1).ovf<='0'; end if;
   end process;

   -- input into VLD pipeline
   vld_q(0) <= dsp_vld(0);
   gvld : if NUM_PIPELINE_REG>=1 generate
    gloop : for n in 1 to NUM_PIPELINE_REG generate
      vld_q(n) <= vld_q(n-1) when rising_edge(clk);
    end generate;
   end generate;
   rslt(1).vld <= vld_q(NUM_PIPELINE_REG);

   -- additional output registers always in logic
   g_oreg : if NUM_OUTPUT_REG>=2 generate
     g_loop : for n in 2 to NUM_OUTPUT_REG generate
       rslt(n) <= rslt(n-1) when rising_edge(clk);
     end generate;
   end generate;

   -- map result to output port
   result <= rslt(NUM_OUTPUT_REG).dat;
   result_vld <= rslt(NUM_OUTPUT_REG).vld;
   result_ovf <= rslt(NUM_OUTPUT_REG).ovf;

   -- number of pipeline stages = 
   --     pipeline stages within MULT2/MULT4 (including input registers and first output register)
   --   + additional pipeline stages required for adder tree
   --   + all output registers except for the first one
   PIPESTAGES <= PIPEREGS_DSP(0) + NUM_PIPELINE_REG + (NUM_OUTPUT_REG-1);

  end generate;

end architecture;

