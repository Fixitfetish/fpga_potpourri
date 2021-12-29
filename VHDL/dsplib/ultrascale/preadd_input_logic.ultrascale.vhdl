-------------------------------------------------------------------------------
--! @file       preadd_input_logic.ultrascale.vhdl
--! @author     Fixitfetish
--! @date       12/Dec/2021
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
library dsplib;
  use dsplib.dsp_pkg_ultrascale.all;

--! @brief This entity implements a generic input logic of the (+/-A +/-D) preadder
--! for Xilinx UltraScale.
--!
--! Dependent on the preadder input mode the input data might need to be negated
--! using additional logic. Note that negation of the most negative value is
--! critical because an additional MSB is required.
--! In this implementation this is not an issue because the inputs a and d are
--! limited to 26 bits but the preadder input can be 27 bits wide.
--!
--! | PREADD A  | PREADD D  | Input D | Input A | Preadd +/- | Operation  | Comment
--! |:---------:|:---------:|:-------:|:-------:|:----------:|:----------:|:-------
--! | ADD       | ADD       |    A    |    D    |   '0' (+)  |    D  +  A | ---
--! | ADD       | SUBTRACT  |    A    |    D    |   '1' (-)  |    D  -  A | ---
--! | ADD       | DYNAMIC   |    A    |    D    |   sub_d    |    D +/- A | ---
--! | SUBTRACT  | ADD       |    D    |    A    |   '1' (-)  |    D  -  A | ---
--! | SUBTRACT  | SUBTRACT  |   -D    |    A    |   '1' (-)  |   -D  -  A | additional logic required
--! | SUBTRACT  | DYNAMIC   |   -A    |    D    |   sub_d    |   -D +/- A | additional logic required
--! | DYNAMIC   | ADD       |    D    |    A    |   sub_a    |    D +/- A | ---
--! | DYNAMIC   | SUBTRACT  |   -D    |    A    |   sub_a    |   -D +/- A | additional logic required
--! | DYNAMIC   | DYNAMIC   | +/-A    |    D    |   sub_d    | +/-D +/- A | additional logic required
--!
--! Refer to Xilinx UltraScale Architecture DSP48E2 Slice, UG579 (v1.11) August 30, 2021
--!
--! VHDL Instantiation Template:
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
--! I1 : preadd_input_logic_ultrascale
--! generic map(
--!   PREADDER_INPUT_A  => string,  -- a preadder mode
--!   PREADDER_INPUT_D  => string,  -- d preadder mode
--!   NUM_INPUT_REG     => natural  -- number of input registers in logic
--! )
--! port map(
--!   clk        => in  std_logic, -- clock
--!   rst        => in  std_logic, -- reset
--!   clkena     => in  std_logic, -- clock enable
--!   sub_a      => in  std_logic, -- add/subtract a
--!   sub_d      => in  std_logic, -- add/subtract d
--!   a          => in  signed, -- first preadder input
--!   d          => in  signed, -- second preadder input
--!   a_dsp      => out signed, -- DSP preadder input A
--!   d_dsp      => out signed, -- DSP preadder input D
--!   inmode     => out std_logic_vector(3 downto 0), -- dynamic preadder control signals
--!   PIPESTAGES => out natural -- constant number of pipeline stages
--! );
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--!
entity preadd_input_logic_ultrascale is
generic (
  --! @brief Preadder mode of input A. Options are ADD, SUBTRACT or DYNAMIC.
  --! In ADD and SUBTRACT mode sub_a is ignored. In dynamic mode sub_a='1' means subtract.
  --! Note that additional logic might be required dependent on mode and FPGA type.
  PREADDER_INPUT_A : string := "ADD";
  --! @brief Preadder mode of input D. Options are ADD, SUBTRACT or DYNAMIC.
  --! In ADD and SUBTRACT mode sub_d is ignored. In dynamic mode sub_d='1' means subtract.
  --! Note that additional logic might be required dependent on mode and FPGA type.
  PREADDER_INPUT_D : string := "ADD";
  --! @brief Number of additional input pipeline registers in logic.
  NUM_INPUT_REG : natural := 0
);
port (
  --! Standard system clock
  clk        : in  std_logic;
  --! Reset result output (optional, only connect if really required)
  rst        : in  std_logic := '0';
  --! Clock enable (optional)
  clkena     : in  std_logic := '1';
  --! @brief Add/subtract, '0' -> +a, '1' -> -a
  --! Only relevant in DYNAMIC mode. In DYNAMIC mode subtraction is disabled by default.
  sub_a      : in  std_logic := '0';
  --! @brief Add/subtract, '0' -> +d, '1' -> -d
  --! Only relevant in DYNAMIC mode. In DYNAMIC mode subtraction is disabled by default.
  sub_d      : in  std_logic := '0';
  --! first preadder input
  a          : in  signed;
  --! second preadder input
  d          : in  signed;
  --! DSP preadder input A
  a_dsp      : out signed(MAX_WIDTH_A-1 downto 0);
  --! DSP preadder input D
  d_dsp      : out signed(MAX_WIDTH_D-1 downto 0);
  --! @brief Preadder relevant dynamic control signals which can directly connect to the DSP cell.
  --! The signals are already delay compensated and synchronous to the outputs A and D.
  inmode     : out std_logic_vector(3 downto 0);
  --! Number of pipeline stages, constant, depends on configuration and device specific implementation
  PIPESTAGES : out natural := 1
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (PREADDER_INPUT_A="ADD") or (PREADDER_INPUT_A="SUBTRACT") or (PREADDER_INPUT_A="DYNAMIC")
    report "WARNING in " & preadd_input_logic_ultrascale'INSTANCE_NAME & ": " & 
           "Generic PREADDER_INPUT_A string must be ADD, SUBTRACT or DYNAMIC."
    severity failure;

  assert (PREADDER_INPUT_D="ADD") or (PREADDER_INPUT_D="SUBTRACT") or (PREADDER_INPUT_D="DYNAMIC")
    report "WARNING in " & preadd_input_logic_ultrascale'INSTANCE_NAME & ": " & 
           "Generic PREADDER_INPUT_D string must be ADD, SUBTRACT or DYNAMIC."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;

-------------------------------------------------------------------------------

architecture rtl of preadd_input_logic_ultrascale is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "preadd_input_logic_ultrascale";

  -- max preadder input width
  constant LIM_WIDTH_AD : positive := MAX_WIDTH_D - 1;

  -- logic input register pipeline
  type r_ireg is
  record
    sub_a, sub_d : std_logic;
    a : signed(a'length-1 downto 0);
    d : signed(d'length-1 downto 0);
  end record;
  constant IREG_DEFAULT : r_ireg := ('0','0',(others=>'-'),(others=>'-'));
  type array_ireg is array(integer range <>) of r_ireg;
  signal ireg : array_ireg(NUM_INPUT_REG downto 0);

  -- preadder subtract control - more details in description above
  function preadder_subtract(sub_a,sub_d:std_logic; amode,bmode:string) return std_logic is
  begin
    if (bmode="DYNAMIC") then return sub_d;
    elsif (amode="DYNAMIC") then return sub_a;
    elsif (amode="ADD" and bmode="ADD") then return '0';
    else return '1'; end if;
  end function;

  -- input A  control - more details in description above
  function get_a(a,d:signed; amode,bmode:string) return signed is
  begin
    if (amode="ADD" or bmode="DYNAMIC") then return resize(d,MAX_WIDTH_A);
    else return resize(a,MAX_WIDTH_A); end if;
  end function;

  -- input D  control - more details in description above
  function get_d(a,d:signed; sub_a:std_logic; amode,bmode:string) return signed is
  begin
    if (amode="ADD") then return resize(a,MAX_WIDTH_D);
    elsif (bmode="ADD") then return resize(d,MAX_WIDTH_D);
    elsif (bmode="SUBTRACT") then return -resize(d,MAX_WIDTH_D);
    else -- bmode="DYNAMIC"
      if (amode="DYNAMIC" and sub_a='0') then return resize(a,MAX_WIDTH_D);
      else return -resize(a,MAX_WIDTH_D); end if;
    end if;
  end function;

begin

  -- check input length
  assert (a'length<=LIM_WIDTH_AD and d'length<=LIM_WIDTH_AD)
    report "ERROR " & IMPLEMENTATION & ": " & 
           "Preadder input A and D width cannot exceed " & integer'image(LIM_WIDTH_AD)
    severity failure;

  -- pipeline input
  ireg(NUM_INPUT_REG).sub_a <= sub_a;
  ireg(NUM_INPUT_REG).sub_d <= sub_d;
  ireg(NUM_INPUT_REG).a <= a;
  ireg(NUM_INPUT_REG).d <= d;

  -- pipeline
  g_ireg_on : if NUM_INPUT_REG>=1 generate
    process(clk)
    begin
      if rising_edge(clk) then
        if rst/='0' then
          ireg(NUM_INPUT_REG-1 downto 0) <= (others=>IREG_DEFAULT);
        elsif clkena='1' then
          ireg(NUM_INPUT_REG-1 downto 0) <= ireg(NUM_INPUT_REG downto 1);
        end if;
      end if;
    end process;
  end generate;

  -- preadder control signals
  inmode(0) <= '0'; -- AREG controlled input
  inmode(1) <= '0'; -- do not gate A/B
  inmode(2) <= '1'; -- D into preadder
  inmode(3) <= preadder_subtract(ireg(0).sub_a, ireg(0).sub_d, PREADDER_INPUT_A, PREADDER_INPUT_D);

  -- LSB bound data inputs
  a_dsp <= get_a(ireg(0).a, ireg(0).d, PREADDER_INPUT_A,PREADDER_INPUT_D);
  d_dsp <= get_d(ireg(0).a, ireg(0).d, ireg(0).sub_a, PREADDER_INPUT_A, PREADDER_INPUT_D);

  PIPESTAGES <= NUM_INPUT_REG;

end architecture;
