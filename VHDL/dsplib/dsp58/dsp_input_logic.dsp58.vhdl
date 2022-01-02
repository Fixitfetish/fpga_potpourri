-------------------------------------------------------------------------------
--! @file       dsp_input_logic.dsp58.vhdl
--! @author     Fixitfetish
--! @date       29/Dec/2021
--! @version    0.00-draft
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
library dsplib;
  use dsplib.dsp_pkg_dsp58.all;

--! @brief This entity implements a generic DSP input logic for Xilinx Versal.
--!
--! Refer to Xilinx Versal ACAP DSP Engine, Architecture Manual, AM004 (v1.1.2) July 15, 2021
--!
entity dsp_input_logic_dsp58 is
generic (
  --! @brief Number of DSP internal input pipeline registers in A/B/D path.
  --! At least one is strongly recommended.
  PIPEREGS_RST     : natural := 1;
  PIPEREGS_CLR     : natural := 1;
  PIPEREGS_VLD     : natural := 1;
  PIPEREGS_ALUMODE : natural := 1;
  PIPEREGS_INMODE  : natural := 1;
  PIPEREGS_OPMODE  : natural := 1;
  PIPEREGS_A       : natural := 1;
  PIPEREGS_B       : natural := 1;
  PIPEREGS_C       : natural := 1;
  PIPEREGS_D       : natural := 1
);
port (
  --! Standard system clock
  clk         : in  std_logic;
  --! Global synchronous reset (optional, only connect if really required!)
  rst         : in  std_logic := '0';
  --! Clock enable (optional)
  clkena      : in  std_logic := '1';

  src_rst     : in  std_logic := '0';
  src_clr     : in  std_logic := '1';
  src_vld     : in  std_logic := '1';
  src_alumode : in  std_logic_vector(3 downto 0) := (others=>'0');
  src_inmode  : in  std_logic_vector(4 downto 0) := (others=>'0');
  src_opmode  : in  std_logic_vector(8 downto 0) := (others=>'0');
  src_a       : in  signed;
  src_b       : in  signed;
  src_c       : in  signed;
  src_d       : in  signed;
  dsp_feed    : out r_dsp_feed
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of dsp_input_logic_dsp58 is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "dsp_input_logic_dsp58";

  signal pipe_rst : std_logic_vector(PIPEREGS_RST downto 0);
  signal pipe_clr : std_logic_vector(PIPEREGS_CLR downto 0);
  signal pipe_vld : std_logic_vector(PIPEREGS_VLD downto 0);
  signal pipe_alumode : slv4_array(PIPEREGS_ALUMODE downto 0);
  signal pipe_inmode : slv5_array(PIPEREGS_INMODE downto 0);
  signal pipe_opmode : slv9_array(PIPEREGS_OPMODE downto 0);
  signal pipe_a : signed_vector(PIPEREGS_A downto 0)(src_a'length-1 downto 0);
  signal pipe_b : signed_vector(PIPEREGS_B downto 0)(src_b'length-1 downto 0);
  signal pipe_c : signed_vector(PIPEREGS_C downto 0)(src_c'length-1 downto 0);
  signal pipe_d : signed_vector(PIPEREGS_D downto 0)(src_d'length-1 downto 0);

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

  pipe_rst(PIPEREGS_RST) <= src_rst;
  pipe_clr(PIPEREGS_CLR) <= src_clr;
  pipe_vld(PIPEREGS_VLD) <= src_vld;
  pipe_alumode(PIPEREGS_ALUMODE) <= src_alumode;
  pipe_inmode(PIPEREGS_INMODE) <= src_inmode;
  pipe_opmode(PIPEREGS_OPMODE) <= src_opmode;
  pipe_a(PIPEREGS_A) <= src_a;
  pipe_b(PIPEREGS_B) <= src_b;
  pipe_c(PIPEREGS_C) <= src_c;
  pipe_d(PIPEREGS_D) <= src_d;

  g_rst : if PIPEREGS_RST>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if rst/='0' then
          pipe_rst(PIPEREGS_RST-1 downto 0) <= (others=>'1');
        elsif clkena='1' then
          pipe_rst(PIPEREGS_RST-1 downto 0) <= pipe_rst(PIPEREGS_RST downto 1);
        end if;
      end if;
    end process;
  end generate;

  g_clr : if PIPEREGS_CLR>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if rst/='0' then
          pipe_clr(PIPEREGS_CLR-1 downto 0) <= (others=>'1');
        elsif clkena='1' then
          pipe_clr(PIPEREGS_CLR-1 downto 0) <= pipe_clr(PIPEREGS_CLR downto 1);
        end if;
      end if;
    end process;
  end generate;

  g_vld : if PIPEREGS_VLD>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if rst/='0' then
          pipe_vld(PIPEREGS_VLD-1 downto 0) <= (others=>'0');
        elsif clkena='1' then
          pipe_vld(PIPEREGS_VLD-1 downto 0) <= pipe_vld(PIPEREGS_VLD downto 1);
        end if;
      end if;
    end process;
  end generate;

  g_alumode : if PIPEREGS_ALUMODE>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if rst/='0' then
          pipe_alumode(PIPEREGS_ALUMODE-1 downto 0) <= (others=>(others=>'0'));
        elsif clkena='1' then
          pipe_alumode(PIPEREGS_ALUMODE-1 downto 0) <= pipe_alumode(PIPEREGS_ALUMODE downto 1);
        end if;
      end if;
    end process;
  end generate;

  g_inmode : if PIPEREGS_INMODE>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if rst/='0' then
          pipe_inmode(PIPEREGS_INMODE-1 downto 0) <= (others=>(others=>'0'));
        elsif clkena='1' then
          pipe_inmode(PIPEREGS_INMODE-1 downto 0) <= pipe_inmode(PIPEREGS_INMODE downto 1);
        end if;
      end if;
    end process;
  end generate;

  g_opmode : if PIPEREGS_OPMODE>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if rst/='0' then
          pipe_opmode(PIPEREGS_OPMODE-1 downto 0) <= (others=>(others=>'0'));
        elsif clkena='1' then
          pipe_opmode(PIPEREGS_OPMODE-1 downto 0) <= pipe_opmode(PIPEREGS_OPMODE downto 1);
        end if;
      end if;
    end process;
  end generate;

  g_a : if PIPEREGS_A>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if rst/='0' then
          pipe_a(PIPEREGS_A-1 downto 0) <= (others=>(others=>'-'));
        elsif clkena='1' then
          pipe_a(PIPEREGS_A-1 downto 0) <= pipe_a(PIPEREGS_A downto 1);
        end if;
      end if;
    end process;
  end generate;

  g_b : if PIPEREGS_B>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if rst/='0' then
          pipe_b(PIPEREGS_B-1 downto 0) <= (others=>(others=>'-'));
        elsif clkena='1' then
          pipe_b(PIPEREGS_B-1 downto 0) <= pipe_b(PIPEREGS_B downto 1);
        end if;
      end if;
    end process;
  end generate;

  g_c : if PIPEREGS_C>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if rst/='0' then
          pipe_c(PIPEREGS_C-1 downto 0) <= (others=>(others=>'-'));
        elsif clkena='1' then
          pipe_c(PIPEREGS_C-1 downto 0) <= pipe_c(PIPEREGS_C downto 1);
        end if;
      end if;
    end process;
  end generate;

  g_d : if PIPEREGS_D>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if rst/='0' then
          pipe_d(PIPEREGS_D-1 downto 0) <= (others=>(others=>'-'));
        elsif clkena='1' then
          pipe_d(PIPEREGS_D-1 downto 0) <= pipe_d(PIPEREGS_D downto 1);
        end if;
      end if;
    end process;
  end generate;

  dsp_feed.rst <= pipe_rst(0);
  dsp_feed.clr <= pipe_clr(0);
  dsp_feed.vld <= pipe_vld(0);
  dsp_feed.alumode <= pipe_alumode(0);
  dsp_feed.inmode <= pipe_inmode(0);
  dsp_feed.opmode <= pipe_opmode(0);
  dsp_feed.a <= resize(pipe_a(0), MAX_WIDTH_A);
  dsp_feed.b <= resize(pipe_b(0), MAX_WIDTH_B);
  dsp_feed.c <= resize(pipe_c(0), MAX_WIDTH_C);
  dsp_feed.d <= resize(pipe_d(0), MAX_WIDTH_D);

end architecture;
