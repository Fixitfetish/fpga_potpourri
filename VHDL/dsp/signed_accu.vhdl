-------------------------------------------------------------------------------
--! @file       signed_accu.vhdl
--! @author     Fixitfetish
--! @date       16/Apr/2017
--! @version    0.10
--! @copyright  MIT License
--! @note       VHDL-1993
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library baselib;
 use baselib.ieee_extension.all;

--! @brief Signed Accumulator

entity signed_accu is
generic (
  --! @brief The number of summands is important to determine the number of additional
  --! guard bits (MSBs) that are required for the accumulation process. @link NUM_SUMMAND More...
  --!
  --! The setting is relevant to save logic especially when saturation/clipping
  --! and/or overflow detection is enabled.
  --! * 0 => maximum possible, not recommended (worst case, hardware dependent)
  --! * 1 => just one multiplication without accumulation
  --! * 2 => accumulate up to 2 products
  --! * 3 => accumulate up to 3 products
  --! * and so on ...
  --!
  --! Note that every single accumulated product result counts!
  NUM_SUMMAND : natural := 0;
  --! Enable chain input from neighbor DSP cell, i.e. enable additional accumulator input
  USE_CHAIN_INPUT : boolean := false;
  --! @brief Number of additional input registers. At least one is strongly recommended.
  --! If available the input registers within the DSP cell are used.
  NUM_INPUT_REG : natural := 1;
  --! @brief Number of result output registers. 
  --! At least one register is required which is typically the result/accumulation
  --! register within the DSP cell. A second output register is recommended
  --! when logic for rounding, clipping and/or overflow detection is enabled.
  --! Typically all output registers after the first one are not part of a DSP cell
  --! and therefore implemented in logic.
  NUM_OUTPUT_REG : positive := 1;
  --! @brief Number of bits by which the accumulator input is shifted right.
  --! This setting is only relevant when the accumulator in implemented in logic.
  --! If INPUT_SHIFT_RIGHT>0 then the input is automatically rounded.
  --! If the accumulator is implemented in logic then shifting might be needed
  --! to reduce the width of the accumulator and to meet timing requirements
  --! in high speed designs. For timing also set at least one input register
  --! which will be placed between rounding and accumulation. 
  INPUT_SHIFT_RIGHT : natural := 0;
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
  --! @brief Clear accumulator (mark first valid input factors of accumulation sequence).
  --! If accumulation is not wanted then set constant '1'.
  clr        : in  std_logic;
  --! Valid signal for input, high-active
  vld        : in  std_logic;
  --! Negation of input , '0' -> +x, '1' -> -x. Negation is disabled by default.
  neg        : in  std_logic := '0';
  --! signed input
  x          : in  signed;
  --! @brief Resulting accumulator output (optionally rounded and clipped).
  --! The standard result output might be unused when chain output is used instead.
  result     : out signed;
  --! Valid signal for result output, high-active
  result_vld : out std_logic;
  --! Result output overflow/clipping detection
  result_ovf : out std_logic;
  --! @brief Input from other chained DSP cell (optional, only used when input enabled and connected).
  --! The chain width is device specific. A maximum width of 80 bits is supported.
  --! If the device specific chain width is smaller then only the LSBs are used.
  chainin    : in  signed(79 downto 0) := (others=>'0');
  --! @brief Result output to other chained DSP cell (optional)
  --! The chain width is device specific. A maximum width of 80 bits is supported.
  --! If the device specific chain width is smaller then only the LSBs are used.
  chainout   : out signed(79 downto 0) := (others=>'0');
  --! Number of pipeline stages, constant, depends on configuration and device specific implementation
  PIPESTAGES : out natural := 0
);
begin
  assert (not OUTPUT_ROUND) or (OUTPUT_SHIFT_RIGHT/=0)
    report "WARNING in " & signed_accu'INSTANCE_NAME & 
           " Disabled rounding because OUTPUT_SHIFT_RIGHT is 0."
    severity warning;
end entity;

-------------------------------------------------------------------------------

architecture behave of signed_accu is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := signed_accu'INSTANCE_NAME;

  -- local auxiliary
  -- determine number of required additional guard bits (MSBs)
  function guard_bits(num_summand, dflt:natural) return integer is
    variable res : integer;
  begin
    if num_summand=0 then
      res := dflt; -- maximum possible (default)
    else
      res := LOG2CEIL(num_summand);
    end if;
    return res; 
  end function;

  -- maximum accumulator width in bits
  constant MAX_ACCU_WIDTH : positive := 64;

  -- derived constants
  constant ROUND_ENABLE : boolean := OUTPUT_ROUND and (OUTPUT_SHIFT_RIGHT/=0);
  constant INPUT_WIDTH : natural := x'length - INPUT_SHIFT_RIGHT;
  constant MAX_GUARD_BITS : natural := MAX_ACCU_WIDTH - INPUT_WIDTH;
  constant GUARD_BITS_EVAL : natural := guard_bits(NUM_SUMMAND,MAX_GUARD_BITS);
  constant ACCU_WIDTH : positive := GUARD_BITS_EVAL + INPUT_WIDTH;
  constant ACCU_SHIFTED_WIDTH : natural := ACCU_WIDTH - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result'length;

  -- input register pipeline
  type r_ireg is
  record
    rst, vld : std_logic;
    clr : std_logic;
    neg : std_logic;
    x   : signed(INPUT_WIDTH-1 downto 0);
  end record;
  type array_ireg is array(integer range <>) of r_ireg;
  signal ireg : array_ireg(NUM_INPUT_REG downto 0);

  -- output register pipeline
  type r_oreg is
  record
    dat : signed(OUTPUT_WIDTH-1 downto 0);
    vld : std_logic;
    ovf : std_logic;
  end record;
  type array_oreg is array(integer range <>) of r_oreg;
  signal rslt : array_oreg(0 to NUM_OUTPUT_REG);

  signal sum, chainin_i : signed(ACCU_WIDTH-1 downto 0) := (others=>'0');
  signal accu : signed(ACCU_WIDTH-1 downto 0);
  signal accu_shifted : signed(ACCU_SHIFTED_WIDTH-1 downto 0);

begin

  -- check chain in/out length
  assert (not USE_CHAIN_INPUT)
    report "WARNING in " & IMPLEMENTATION & ": " &
           " It might be difficult to meet timing with enabled chain input."
    severity warning;

  -- control signal inputs
  ireg(NUM_INPUT_REG).rst <= rst;
  ireg(NUM_INPUT_REG).vld <= vld;
  ireg(NUM_INPUT_REG).clr <= clr;
  ireg(NUM_INPUT_REG).neg <= neg;
  ireg(NUM_INPUT_REG).x <= RESIZE(SHIFT_RIGHT_ROUND(x, INPUT_SHIFT_RIGHT, nearest),INPUT_WIDTH);

  g_in : if NUM_INPUT_REG>=1 generate
  begin
    g_1 : for n in 1 to NUM_INPUT_REG generate
    begin
      ireg(n-1) <= ireg(n) when rising_edge(clk);
    end generate;
  end generate;

  -- chain input
  g_chain : if USE_CHAIN_INPUT generate
    chainin_i <= chainin(ACCU_WIDTH-1 downto 0);
  end generate;

  -- temporary sum of multiplier result and chain input
  sum <= chainin_i - ireg(0).x when ireg(0).neg='1' else
         chainin_i + ireg(0).x;

  p_accu : process(clk)
  begin
    if rising_edge(clk) then
      if ireg(0).clr='1' then
        if ireg(0).vld='1' then
          accu <= sum;
        else
          accu <= (others=>'0');
        end if;
      else  
        if ireg(0).vld='1' then
          accu <= accu + sum;
        end if;
      end if;
    end if;
  end process;

  chainout(ACCU_WIDTH-1 downto 0) <= accu;
  g_chainout : for n in ACCU_WIDTH to (chainout'length-1) generate
    -- sign extension (for simulation and to avoid warnings)
    chainout(n) <= accu(ACCU_WIDTH-1);
  end generate;

  -- shift right and round
  g_rnd_off : if (not ROUND_ENABLE) generate
    accu_shifted <= RESIZE(SHIFT_RIGHT_ROUND(accu, OUTPUT_SHIFT_RIGHT),ACCU_SHIFTED_WIDTH);
  end generate;
  g_rnd_on : if (ROUND_ENABLE) generate
    accu_shifted <= RESIZE(SHIFT_RIGHT_ROUND(accu, OUTPUT_SHIFT_RIGHT, nearest),ACCU_SHIFTED_WIDTH);
  end generate;
  
  p_out : process(accu_shifted, ireg(0).vld)
    variable v_dat : signed(OUTPUT_WIDTH-1 downto 0);
    variable v_ovf : std_logic;
  begin
    RESIZE_CLIP(din=>accu_shifted, dout=>v_dat, ovfl=>v_ovf, clip=>OUTPUT_CLIP);
    rslt(0).vld <= ireg(0).vld;
    rslt(0).dat <= v_dat;
    if OUTPUT_OVERFLOW then rslt(0).ovf<=v_ovf; else rslt(0).ovf<='0'; end if;
  end process;

  g_oreg1 : if NUM_OUTPUT_REG>=1 generate
  begin
    rslt(1).vld <= rslt(0).vld when rising_edge(clk); -- VLD bypass
    -- first output register is the ACCU register
    rslt(1).dat <= rslt(0).dat;
    rslt(1).ovf <= rslt(0).ovf;
  end generate;

  g_oreg2 : if NUM_OUTPUT_REG>=2 generate
    g_loop : for n in 2 to NUM_OUTPUT_REG generate
      rslt(n) <= rslt(n-1) when rising_edge(clk);
    end generate;
  end generate;

  -- map result to output port
  result <= rslt(NUM_OUTPUT_REG).dat;
  result_vld <= rslt(NUM_OUTPUT_REG).vld;
  result_ovf <= rslt(NUM_OUTPUT_REG).ovf;

  -- report constant number of pipeline register stages
  PIPESTAGES <= NUM_INPUT_REG + NUM_OUTPUT_REG;

end architecture;
