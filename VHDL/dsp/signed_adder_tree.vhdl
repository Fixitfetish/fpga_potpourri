-------------------------------------------------------------------------------
--! @file       signed_adder_tree.vhdl
--! @author     Fixitfetish
--! @date       17/Apr/2017
--! @version    0.10
--! @copyright  MIT License
--! @note       VHDL-1993
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library fixitfetish;
 use fixitfetish.ieee_extension.all;
 use fixitfetish.ieee_extension_types.all;

--! @brief Signed Adder Tree. Sum of N inputs using FPGA logic.

entity signed_adder_tree is
generic (
  --! Enable high speed mode with more pipelining for higher clock rates
  HIGH_SPEED_MODE : boolean := false;
  --! @brief Number of additional input registers. At least one is strongly recommended.
  --! If available the input registers within the DSP cell are used.
  NUM_INPUT_REG : natural := 1;
  --! Defines how many LSBs of each element of input vector X are used. Mandatory!
  INPUT_WIDTH : positive range 4 to 48;
  --! @brief Number of result output registers. 
  --! At least one register is required which is typically the result/accumulation
  --! register within the DSP cell. A second output register is recommended
  --! when logic for rounding, clipping and/or overflow detection is enabled.
  --! Typically all output registers after the first one are not part of a DSP cell
  --! and therefore implemented in logic.
  NUM_OUTPUT_REG : positive := 1;
  --! Number of bits by which the accumulator result output is shifted right.
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
  --! Valid signal for input, high-active
  vld        : in  std_logic;
  --! signed input (for VHDL-1993 width is limited to 48 bits)
  x          : in  signed48_vector;
  --! @brief Resulting accumulator output (optionally rounded and clipped).
  --! The standard result output might be unused when chain output is used instead.
  result     : out signed;
  --! Valid signal for result output, high-active
  result_vld : out std_logic;
  --! Result output overflow/clipping detection
  result_ovf : out std_logic;
  --! Number of pipeline stages, constant, depends on configuration and device specific implementation
  PIPESTAGES : out natural := 0
);
begin

  assert (x'ascending)
    report "ERROR in " & signed_adder_tree'INSTANCE_NAME & 
           " Input vector X must have 'TO' range."
    severity failure;

  assert (not OUTPUT_ROUND) or (OUTPUT_SHIFT_RIGHT/=0)
    report "WARNING in " & signed_adder_tree'INSTANCE_NAME & 
           " Disabled rounding because OUTPUT_SHIFT_RIGHT is 0."
    severity warning;

end entity;

-------------------------------------------------------------------------------

architecture behave of signed_adder_tree is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := signed_adder_tree'INSTANCE_NAME;

  -- number of required adder tree stages - is at least 1 +++ TODO 0!?
  constant INPUT_LENGTH : natural := x'length;
  constant NUM_STAGES : natural := LOG2CEIL(INPUT_LENGTH);

  -- data width after last adder stage
  constant FINAL_WIDTH : natural := INPUT_WIDTH + NUM_STAGES;
  constant FINAL_SHIFTED_WIDTH : natural := FINAL_WIDTH - OUTPUT_SHIFT_RIGHT;

  -- derived constants
  constant ROUND_ENABLE : boolean := OUTPUT_ROUND and (OUTPUT_SHIFT_RIGHT/=0);
  constant OUTPUT_WIDTH : positive := result'length;

  type integer_vector is array(integer range <>) of integer;

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

  signal final_shifted : signed(FINAL_SHIFTED_WIDTH-1 downto 0);

  -- output register pipeline
  type r_oreg is
  record
    dat : signed(OUTPUT_WIDTH-1 downto 0);
    vld : std_logic;
    ovf : std_logic;
  end record;
  type array_oreg is array(integer range <>) of r_oreg;
  signal rslt : array_oreg(0 to NUM_OUTPUT_REG);

  -- calculate number of inputs to each stage
  function calc_num_inputs(n:natural) return integer_vector is
    variable res : integer_vector(1 to NUM_STAGES);
  begin
    res(1) := n;
    if NUM_STAGES>=2 then 
      for i in 2 to NUM_STAGES loop res(i):=(res(i-1)+1)/2; end loop;
    end if;
    return res;
  end function;
  constant NUM_INPUTS_STAGE : integer_vector(1 to NUM_STAGES) := calc_num_inputs(INPUT_LENGTH);

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
  constant NUM_PIPELINE_REG : natural := SUM(HAS_PIPEREG_STAGE);

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

  g_init : for n in 0 to INPUT_LENGTH-1 generate
  begin
    dout(0,n) <= resize(ireg(0).x(n),FINAL_WIDTH);
  end generate;

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

    -- pipeline register
    pipe_off : if not HAS_PIPEREG_STAGE(s) generate
      gi : for i in 0 to (NUM_INPUTS_STAGE(s)-1) generate
        dout(s,i) <= resize(dsum(s,i),FINAL_WIDTH);
      end generate;
    end generate;
    pipe_on : if HAS_PIPEREG_STAGE(s) generate
      gi : for i in 0 to (NUM_INPUTS_STAGE(s)-1) generate
        dout(s,i) <= resize(dsum(s,i),FINAL_WIDTH) when rising_edge(clk);
      end generate;
    end generate;

  end generate;

  -- shift right and round
  g_rnd_off : if (not ROUND_ENABLE) generate
    final_shifted <= RESIZE(SHIFT_RIGHT_ROUND(dout(NUM_STAGES,0), OUTPUT_SHIFT_RIGHT),FINAL_SHIFTED_WIDTH);
  end generate;
  g_rnd_on : if (ROUND_ENABLE) generate
    final_shifted <= RESIZE(SHIFT_RIGHT_ROUND(dout(NUM_STAGES,0), OUTPUT_SHIFT_RIGHT, nearest),FINAL_SHIFTED_WIDTH);
  end generate;
  
  p_out : process(final_shifted)
    variable v_dat : signed(OUTPUT_WIDTH-1 downto 0);
    variable v_ovf : std_logic;
  begin
    RESIZE_CLIP(din=>final_shifted, dout=>v_dat, ovfl=>v_ovf, clip=>OUTPUT_CLIP);
    rslt(0).dat <= v_dat;
    if OUTPUT_OVERFLOW then rslt(0).ovf<=v_ovf; else rslt(0).ovf<='0'; end if;
  end process;

  -- input into VLD pipeline
  vld_q(0) <= ireg(0).vld;
  gvld : for n in 1 to NUM_PIPELINE_REG generate
    vld_q(n) <= vld_q(n-1) when rising_edge(clk);
  end generate;
  rslt(0).vld <= vld_q(NUM_PIPELINE_REG);

  g_oreg : if NUM_OUTPUT_REG>=1 generate
    g_loop : for n in 1 to NUM_OUTPUT_REG generate
      rslt(n) <= rslt(n-1) when rising_edge(clk);
    end generate;
  end generate;

  -- map result to output port
  result <= rslt(NUM_OUTPUT_REG).dat;
  result_vld <= rslt(NUM_OUTPUT_REG).vld;
  result_ovf <= rslt(NUM_OUTPUT_REG).ovf;

  -- report constant number of pipeline register stages
  PIPESTAGES <= NUM_INPUT_REG + NUM_PIPELINE_REG + NUM_OUTPUT_REG;

end architecture;
