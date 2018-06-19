-------------------------------------------------------------------------------
--! @file       signed_adder_tree.vhdl
--! @author     Fixitfetish
--! @date       07/Feb/2018
--! @version    0.50
--! @copyright  MIT License
--! @note       VHDL-1993
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library baselib;
 use baselib.ieee_extension_types.all;
 use baselib.ieee_extension.all;
library dsplib;

--! @brief Signed Adder Tree. Sum of N signed values.
--!
--! VHDL Instantiation Template:
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
--! I1 : signed_adder_tree
--! generic map(
--!   HIGH_SPEED_MODE    => boolean,  -- enable high speed mode
--!   NUM_INPUT_REG      => natural,  -- number of input registers
--!   INPUT_WIDTH        => positive, -- bit width of input x
--!   NUM_OUTPUT_REG     => natural,  -- number of output registers
--!   OUTPUT_SHIFT_RIGHT => natural,  -- number of right shifts
--!   OUTPUT_ROUND       => boolean,  -- enable rounding half-up
--!   OUTPUT_CLIP        => boolean,  -- enable clipping
--!   OUTPUT_OVERFLOW    => boolean   -- enable overflow detection
--! )
--! port map(
--!   clk        => in  std_logic, -- clock
--!   rst        => in  std_logic, -- reset
--!   vld        => in  std_logic, -- valid
--!   x          => in  signed48_vector, -- input summands
--!   result     => out signed, -- sum result
--!   result_vld => out std_logic, -- output valid
--!   result_ovf => out std_logic, -- output overflow
--!   PIPESTAGES => out natural -- constant number of pipeline stages
--! );
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

entity signed_adder_tree is
generic (
  --! Enable high speed mode with more pipelining for higher clock rates
  HIGH_SPEED_MODE : boolean := false;
  --! @brief Number of additional input registers. At least one is strongly
  --! recommended if DSP cells are used for the adder tree.
  NUM_INPUT_REG : natural := 1;
  --! @brief Defines how many LSBs of each element of input vector X are used. 
  --! This generic is required for VHDL-1993. Mandatory!
  INPUT_WIDTH : positive range 4 to 48;
  --! @brief Number of result output registers. 
  --! At least one register is required as adder tree result register.
  --! At least one more output register is recommended when logic for rounding,
  --! clipping and/or overflow detection (after adder tree) is enabled.
  --! Typically all additional output registers after the first one are implemented in logic.
  NUM_OUTPUT_REG : positive := 1;
  --! Number of bits by which the accumulator result output is shifted right.
  OUTPUT_SHIFT_RIGHT : natural := 0;
  --! @brief Round 'nearest' (half-up) of result output.
  --! This flag is only relevant when OUTPUT_SHIFT_RIGHT>0.
  --! If the device specific DSP cell supports rounding then rounding is done
  --! within the DSP cell. If rounding in logic is necessary then it is recommended
  --! to use an additional output register.
  OUTPUT_ROUND : boolean := false;
  --! Enable clipping when right shifted result exceeds output range.
  OUTPUT_CLIP : boolean := false;
  --! Enable overflow/clipping detection 
  OUTPUT_OVERFLOW : boolean := false
);
port (
  --! Standard system clock
  clk        : in  std_logic;
  --! Reset result output (optional)
  rst        : in  std_logic := '0';
  --! Valid signal for input, high-active
  vld        : in  std_logic;
  --! signed input (for VHDL-1993 width is limited to 48 bits)
  x          : in  signed48_vector;
  --! Resulting adder tree output (optionally rounded and clipped).
  result     : out signed;
  --! Valid signal for result output, high-active
  result_vld : out std_logic;
  --! Result output overflow/clipping detection
  result_ovf : out std_logic;
  --! Number of pipeline stages, constant, depends on configuration and device specific implementation
  PIPESTAGES : out natural := 1
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (x'ascending)
    report "ERROR in " & signed_adder_tree'INSTANCE_NAME & 
           " Input vector X must have 'TO' range."
    severity failure;

  assert (not OUTPUT_ROUND) or (OUTPUT_SHIFT_RIGHT/=0)
    report "WARNING in " & signed_adder_tree'INSTANCE_NAME & 
           " Disabled rounding because OUTPUT_SHIFT_RIGHT is 0."
    severity warning;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;

-------------------------------------------------------------------------------

--! @brief This is an implementation of the entity signed_adder_tree.
--! N signed values are added using FPGA logic.
--!
--! The number of inputs is LX = x'length. The number of required adder stages is
--! S = ceil(log2(LX)).
--! The bit width W of the input X defines the accuracy of the adder tree.
--! Every adder stage extends the width by one guard MSB to avoid overflows.
--! Thus the width after the first output register is W+S.
--!
--! After the first output register the result can be trimmed, i.e. LSBs can be
--! discarded with or without rounding and/or MSB can be discarded with or without
--! clipping and overflow detection. If trimming is enabled it is recommended to
--! use a subsequent second output register. See also signed_output_logic .
--!
--! If HIGH_SPEED_MODE=false then a pipeline register after every odd adder stage
--! is inserted when NUM_INPUT_REG=0. For NUM_INPUT_REG>=1 a pipeline register
--! after every even adder stage is inserted.
--! If HIGH_SPEED_MODE=true then a pipeline register after every adder stage is inserted.
--! A pipeline register after the last adder stage is always indentical to the first output register.
--!
--! Number of pipeline registers dependent on the number of adder stages:
--! |Number of Adder Stages (S)              |  1 |  2 |  3 |  4 |  5 |  6 |  7 |  8 | .. 
--! |:-----------------------              --|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--
--! |HIGH_SPEED_MODE=false, NUM_INPUT_REG=0  |  0 |  1 |  1 |  2 |  2 |  3 |  3 |  4 | .. 
--! |HIGH_SPEED_MODE=false, NUM_INPUT_REG>=1 |  0 |  0 |  1 |  1 |  2 |  2 |  3 |  3 | ..
--! |HIGH_SPEED_MODE=true, NUM_INPUT_REG>=0  |  0 |  1 |  2 |  3 |  4 |  5 |  6 |  7 | ..
--!
--! The overall number of pipeline stages is NUM_INPUT_REG + NUM_PIPELINE_REG + NUM_OUTPUT_REG .
--!
--! @image html signed_adder_tree.svg "" width=1000px

architecture rtl of signed_adder_tree is

  -- number of inputs into adder tree, should be >=2
  constant INPUT_LENGTH : natural := x'length;

  -- number of required adder tree stages - is at least 1 +++ TODO 0!?
  constant NUM_STAGES : natural := LOG2CEIL(INPUT_LENGTH);

  -- data width after last adder stage
  constant FINAL_WIDTH : natural := INPUT_WIDTH + NUM_STAGES;

  -- input register pipeline
  type t_xvec is array(integer range <>) of signed(INPUT_WIDTH-1 downto 0);
  type r_ireg is
  record
    rst, vld : std_logic;
    x : t_xvec(0 to INPUT_LENGTH-1);
  end record;
  type array_ireg is array(integer range <>) of r_ireg;
  signal ireg : array_ireg(NUM_INPUT_REG downto 0);

  -- stage outputs (after sum and register)
  type t_dout is array(0 to NUM_STAGES,0 to INPUT_LENGTH-1) of signed(FINAL_WIDTH-1 downto 0);
  signal dout : t_dout := (others=>(others=>(others=>'-')));

  -- stage sum results
  constant MAX_NUM_DIN : natural := 2**(NUM_STAGES-1);
  type t_dsum is array(1 to NUM_STAGES, 0 to MAX_NUM_DIN-1) of signed(FINAL_WIDTH-1 downto 0);
  signal dsum : t_dsum := (others=>(others=>(others=>'-')));

  -- calculate number of inputs to each stage
  function calc_num_inputs(n:natural) return integer_vector is
    variable res : integer_vector(1 to NUM_STAGES+1);
  begin
    res(1) := n;
    for i in 2 to res'length loop res(i):=(res(i-1)+1)/2; end loop;
    return res;
  end function;
  constant NUM_INPUTS_STAGE : integer_vector(1 to NUM_STAGES+1) := calc_num_inputs(INPUT_LENGTH);

  function get_piperegs(n:natural) return boolean_vector is
    variable res : boolean_vector(1 to n) := (others=>false);
    variable is_even_stage : boolean;
  begin
    if HIGH_SPEED_MODE then
      res := (others=>true);
    else
      for s in 1 to n loop
        is_even_stage := ( (s/2) = ((s+1)/2) );
        if s=n then
          -- always pipeline register after last stage
          res(s) := true;
        elsif NUM_INPUT_REG>=1 then
          -- pipeline register after even stages
          res(s) := is_even_stage;
        else
          -- pipeline register after odd stages
          res(s) := not is_even_stage;
        end if;
      end loop;
    end if;
    return res;
  end function;
  constant HAS_PIPEREG_STAGE : boolean_vector(1 to NUM_STAGES) := get_piperegs(NUM_STAGES);

  -- number of pipeline registers
  constant NUM_PIPELINE_REG : natural := NUMBER_OF_ONES(HAS_PIPEREG_STAGE);

  -- delayed valid signal
  signal vld_q : std_logic_vector(0 to NUM_PIPELINE_REG);

begin

  -- map input signals
  ireg(NUM_INPUT_REG).rst <= rst;
  ireg(NUM_INPUT_REG).vld <= vld;
  g_map : for n in 0 to INPUT_LENGTH-1 generate
  begin
    ireg(NUM_INPUT_REG).x(n) <= x(x'left+n)(INPUT_WIDTH-1 downto 0);
  end generate;
  
  g_in : if NUM_INPUT_REG>=1 generate
  begin
    g_1 : for n in 1 to NUM_INPUT_REG generate
    begin
      ireg(n-1) <= ireg(n) when rising_edge(clk);
    end generate;
  end generate;

  -- resize input signals for adder tree 
  g_init : for n in 0 to INPUT_LENGTH-1 generate
  begin
    dout(0,n) <= resize(ireg(0).x(n),FINAL_WIDTH);
  end generate;

  -- adder tree
  g_stages : for s in 1 to NUM_STAGES generate
  begin

    -- adder tree for all pairs of inputs
    add : for i in 0 to NUM_INPUTS_STAGE(s)/2-1 generate
      dsum(s,i)(INPUT_WIDTH+s-1 downto 0) <=
          resize(dout(s-1,2*i+0)(INPUT_WIDTH+s-2 downto 0),INPUT_WIDTH+s)
        + resize(dout(s-1,2*i+1)(INPUT_WIDTH+s-2 downto 0),INPUT_WIDTH+s);
    end generate;

    -- in case of odd number of inputs forward last input to next stage
    forward : if (2*NUM_INPUTS_STAGE(s+1))/=NUM_INPUTS_STAGE(s) generate
      dsum(s,NUM_INPUTS_STAGE(s+1)-1)(INPUT_WIDTH+s-1 downto 0) <=
         resize(dout(s-1,NUM_INPUTS_STAGE(s)-1)(INPUT_WIDTH+s-2 downto 0),INPUT_WIDTH+s);
    end generate;

    -- pipeline register (with sign extension relevant for simulation only)
    pipe_on : if HAS_PIPEREG_STAGE(s) generate
      gi : for i in 0 to (NUM_INPUTS_STAGE(s+1)-1) generate
        dout(s,i) <= resize(dsum(s,i)(INPUT_WIDTH+s-1 downto 0),FINAL_WIDTH) when rising_edge(clk);
      end generate;
    end generate;
    pipe_off : if not HAS_PIPEREG_STAGE(s) generate
      gi : for i in 0 to (NUM_INPUTS_STAGE(s+1)-1) generate
        dout(s,i) <= resize(dsum(s,i)(INPUT_WIDTH+s-1 downto 0),FINAL_WIDTH);
      end generate;
    end generate;

  end generate;

  -- input into VLD pipeline
  vld_q(0) <= ireg(0).vld;
  gvld : for n in 1 to NUM_PIPELINE_REG generate
    vld_q(n) <= vld_q(n-1) when rising_edge(clk);
  end generate;

  -- right-shift, round and resize, clipping
  i_out : entity dsplib.signed_output_logic
  generic map(
    PIPELINE_STAGES    => NUM_OUTPUT_REG-1,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => OUTPUT_ROUND,
    OUTPUT_CLIP        => OUTPUT_CLIP,
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
  )
  port map (
    clk         => clk,
    rst         => rst,
    dsp_out     => dout(NUM_STAGES,0),
    dsp_out_vld => vld_q(NUM_PIPELINE_REG),
    result      => result,
    result_vld  => result_vld,
    result_ovf  => result_ovf
  );

  -- report constant number of pipeline register stages
  -- (note: first output register is last pipeline register)
  PIPESTAGES <= NUM_INPUT_REG + NUM_PIPELINE_REG + NUM_OUTPUT_REG - 1;

end architecture;
