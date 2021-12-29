-------------------------------------------------------------------------------
--! @file       dsp_input_logic.ultrascale.vhdl
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

--! @brief This entity implements a generic DSP input logic for Xilinx UltraScale.
--!
--! Refer to Xilinx UltraScale Architecture DSP48E2 Slice, UG579 (v1.11) August 30, 2021
--!
entity dsp_input_logic_ultrascale is
generic (
  --! @brief Number of DSP internal input pipeline registers in A/B/D path.
  --! At least one is strongly recommended.
  NUM_INPUT_REG : natural range 0 to 3 := 1
);
port (
  --! Standard system clock
  clk         : in  std_logic;
  --! Clock enable (optional)
  clkena      : in  std_logic := '1';
  src_rst     : in  std_logic := '0';
  src_vld     : in  std_logic;
  src_inmode  : in  std_logic_vector(4 downto 0);
  src_opmode  : in  std_logic_vector(8 downto 0);
  src_a       : in  signed;
  src_b       : in  signed;
  src_c       : in  signed;
  src_d       : in  signed;
  dest_rst    : out std_logic;
  dest_vld    : out std_logic;
  dest_inmode : out std_logic_vector(4 downto 0);
  dest_opmode : out std_logic_vector(8 downto 0);
  dest_a      : out signed(MAX_WIDTH_A-1 downto 0);
  dest_b      : out signed(MAX_WIDTH_B-1 downto 0);
  dest_c      : out signed(MAX_WIDTH_C-1 downto 0);
  dest_d      : out signed(MAX_WIDTH_D-1 downto 0)
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of dsp_input_logic_ultrascale is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "dsp_input_logic_ultrascale";

--  alias src_opmode_xy is src_opmode(3 downto 0);
--  alias src_opmode_z  is src_opmode(6 downto 4);
--  alias src_opmode_w  is src_opmode(8 downto 7);

  -- DSP input register pipeline
  type r_dsp_ireg is
  record
    rst, vld : std_logic;
    inmode : std_logic_vector(4 downto 0);
    opmode : std_logic_vector(8 downto 0);
    a : src_a'subtype;
    b : src_b'subtype;
    d : src_d'subtype;
  end record;
  type array_dsp_ireg is array(integer range <>) of r_dsp_ireg;
  signal ireg : array_dsp_ireg(NUM_INPUT_REG downto 0) := (others=>(
    rst => '1',
    vld => '0',
    inmode => (others=>'0'),
    opmode => (others=>'0'),
    a => (others=>'-'),
    b => (others=>'-'),
    d => (others=>'-')
  ));

begin

  -- check input length
  assert (src_a'length<=MAX_WIDTH_A)
    report "ERROR " & IMPLEMENTATION & ": " & 
           "Input A width cannot exceed " & integer'image(MAX_WIDTH_A)
    severity failure;
  assert (src_b'length<=MAX_WIDTH_B)
    report "ERROR " & IMPLEMENTATION & ": " & 
           "Input B width cannot exceed " & integer'image(MAX_WIDTH_B)
    severity failure;
  assert (src_c'length<=MAX_WIDTH_C)
    report "ERROR " & IMPLEMENTATION & ": " & 
           "Input C width cannot exceed " & integer'image(MAX_WIDTH_C)
    severity failure;
  assert (src_d'length<=MAX_WIDTH_D)
    report "ERROR " & IMPLEMENTATION & ": " & 
           "Input D width cannot exceed " & integer'image(MAX_WIDTH_D)
    severity failure;

  ireg(NUM_INPUT_REG).rst <= src_rst;
  ireg(NUM_INPUT_REG).vld <= src_vld;
  ireg(NUM_INPUT_REG).inmode <= src_inmode;
  ireg(NUM_INPUT_REG).opmode <= src_opmode;
  ireg(NUM_INPUT_REG).a <= src_a;
  ireg(NUM_INPUT_REG).b <= src_b;
  ireg(NUM_INPUT_REG).d <= src_d;

  -- DSP cell data input registers AD/B2 are used as third input register stage.
  g_dsp_ireg3 : if NUM_INPUT_REG>=3 generate
  begin
    process(clk)
    begin
      if rising_edge(clk) then
        if clkena='1' then
          ireg(2).rst <= ireg(3).rst;
          ireg(2).vld <= ireg(3).vld;
          ireg(2).opmode <= ireg(3).opmode;
        end if;
      end if;
    end process;
    -- for INMODE the third register delay stage is irrelevant
    ireg(2).inmode <= ireg(3).inmode;
    -- the following register are located within the DSP cell
    ireg(2).a <= ireg(3).a;
    ireg(2).b <= ireg(3).b;
    ireg(2).d <= ireg(3).d;
  end generate;

  -- DSP cell MREG register is used as second data input register stage
  g_dsp_ireg2 : if NUM_INPUT_REG>=2 generate
  begin
    process(clk)
    begin
      if rising_edge(clk) then
        if clkena='1' then
          ireg(1).rst <= ireg(2).rst;
          ireg(1).vld <= ireg(2).vld;
          ireg(1).opmode <= ireg(2).opmode;
        end if;
      end if;
    end process;
    -- for INMODE the second register delay stage is irrelevant
    ireg(1).inmode <= ireg(2).inmode;
    -- the following register are located within the DSP cell
    ireg(1).a <= ireg(2).a;
    ireg(1).b <= ireg(2).b;
    ireg(1).d <= ireg(2).d;
  end generate;

  -- DSP cell data input registers A1/B1/D are used as first input register stage.
  g_dsp_ireg1 : if NUM_INPUT_REG>=1 generate
  begin
    process(clk)
    begin
      if rising_edge(clk) then
        if clkena='1' then
          ireg(0).rst <= ireg(1).rst;
          ireg(0).vld <= ireg(1).vld;
        end if;
      end if;
    end process;
    -- DSP cell registers are used for first input register stage
    ireg(0).inmode <= ireg(1).inmode;
    ireg(0).opmode <= ireg(1).opmode;
    ireg(0).a <= ireg(1).a;
    ireg(0).b <= ireg(1).b;
    ireg(0).d <= ireg(1).d;
  end generate;

  dest_rst <= ireg(0).rst;
  dest_vld <= ireg(0).vld;
  dest_inmode <= ireg(0).inmode;
  dest_opmode <= ireg(0).opmode;

  -- RESIZE to DSP-Cell port width (input data is assumed to be LSB bound)
  dest_a <= resize(ireg(0).a,MAX_WIDTH_A);
  dest_b <= resize(ireg(0).b,MAX_WIDTH_B);
  dest_d <= resize(ireg(0).d,MAX_WIDTH_D);

  -- bypass C
  dest_c <= resize(src_c,MAX_WIDTH_C);

end architecture;
