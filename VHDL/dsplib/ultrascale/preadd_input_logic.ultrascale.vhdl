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
--!   NUM_INPUT_REG     => natural  -- number of input registers
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
  --! Reset result output (optional)
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
end entity;

-------------------------------------------------------------------------------

architecture rtl of preadd_input_logic_ultrascale is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "preadd_input_logic_ultrascale";

  -- max preadder input width
  constant LIM_WIDTH_AD : positive := MAX_WIDTH_D - 1;

  -- number input registers in LOGIC
  constant c_PIPESTAGES : natural := NUM_IREG(LOGIC,NUM_INPUT_REG);

  -- logic input register pipeline
  type r_logic_ireg is
  record
    sub_a, sub_d : std_logic;
    a : signed(a'length-1 downto 0);
    d : signed(d'length-1 downto 0);
  end record;
  type array_logic_ireg is array(integer range <>) of r_logic_ireg;
  signal ireg : r_logic_ireg;

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

  g_ireg_off : if c_PIPESTAGES=0 generate
    ireg.sub_a <= sub_a;
    ireg.sub_d <= sub_d;
    ireg.a <= a;
    ireg.d <= d;
  end generate;

  g_ireg_on : if c_PIPESTAGES>=1 generate
    signal ireg_q : array_logic_ireg(c_PIPESTAGES downto 1);
  begin
    process(clk)
    begin
      if rising_edge(clk) then
        if clkena='1' then
          ireg_q(c_PIPESTAGES).sub_a <= sub_a;
          ireg_q(c_PIPESTAGES).sub_d <= sub_d;
          ireg_q(c_PIPESTAGES).a <= a;
          ireg_q(c_PIPESTAGES).d <= d;
          for n in 2 to c_PIPESTAGES loop
            ireg_q(n-1) <= ireg_q(n);
          end loop;
        end if;
      end if;
    end process;
    ireg <= ireg_q(0);
  end generate;

  inmode(0) <= '0'; -- AREG controlled input
  inmode(1) <= '0'; -- do not gate A/B
  inmode(2) <= '1'; -- D into preadder
  inmode(3) <= preadder_subtract(ireg.sub_a,ireg.sub_d,PREADDER_INPUT_A,PREADDER_INPUT_D);

  -- LSB bound data inputs
  a_dsp <= get_a(ireg.a, ireg.d, PREADDER_INPUT_A,PREADDER_INPUT_D);
  d_dsp <= get_d(ireg.a, ireg.d, ireg.sub_a, PREADDER_INPUT_A, PREADDER_INPUT_D);

  PIPESTAGES <= c_PIPESTAGES;

end architecture;
