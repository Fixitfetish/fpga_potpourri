-------------------------------------------------------------------------------
--! @file       xilinx_dsp_input_pipe.vhdl
--! @author     Fixitfetish
--! @date       01/Jan/2022
--! @version    0.10
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

--! @brief This entity implements a generic DSP input pipeline logic for Xilinx Devices.
--!
entity xilinx_dsp_input_pipe is
generic (
  PIPEREGS_RST     : natural := 1;
  PIPEREGS_CLR     : natural := 1;
  PIPEREGS_VLD     : natural := 1;
  PIPEREGS_NEG_A   : natural := 1;
  PIPEREGS_NEG_B   : natural := 1;
  PIPEREGS_NEG_D   : natural := 1;
  PIPEREGS_A       : natural := 1;
  PIPEREGS_B       : natural := 1;
  PIPEREGS_C       : natural := 1;
  PIPEREGS_D       : natural := 1
);
port (
  --! Standard system clock
  clk       : in  std_logic;
  --! Global synchronous reset (optional, only connect if really required!)
  srst      : in  std_logic := '0';
  --! Clock enable (optional)
  clkena    : in  std_logic := '1';
  src_rst   : in  std_logic := '0';
  src_clr   : in  std_logic := '1';
  src_vld   : in  std_logic := '0';
  src_neg_a : in  std_logic := '0';
  src_neg_b : in  std_logic := '0';
  src_neg_d : in  std_logic := '0';
  src_a     : in  signed;
  src_b     : in  signed;
  src_c     : in  signed;
  src_d     : in  signed;
  dsp_rst   : out std_logic;
  dsp_clr   : out std_logic;
  dsp_vld   : out std_logic;
  dsp_neg_a : out std_logic;
  dsp_neg_b : out std_logic;
  dsp_neg_d : out std_logic;
  dsp_a     : out signed;
  dsp_b     : out signed;
  dsp_c     : out signed;
  dsp_d     : out signed
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of xilinx_dsp_input_pipe is

  signal pipe_rst   : std_logic_vector(PIPEREGS_RST downto 0) := (others=>'1');
  signal pipe_clr   : std_logic_vector(PIPEREGS_CLR downto 0) := (others=>'1');
  signal pipe_vld   : std_logic_vector(PIPEREGS_VLD downto 0) := (others=>'0');
  signal pipe_neg_a : std_logic_vector(PIPEREGS_NEG_A downto 0) := (others=>'0');
  signal pipe_neg_b : std_logic_vector(PIPEREGS_NEG_B downto 0) := (others=>'0');
  signal pipe_neg_d : std_logic_vector(PIPEREGS_NEG_D downto 0) := (others=>'0');
  signal pipe_a     : signed_vector(PIPEREGS_A downto 0)(src_a'length-1 downto 0);
  signal pipe_b     : signed_vector(PIPEREGS_B downto 0)(src_b'length-1 downto 0);
  signal pipe_c     : signed_vector(PIPEREGS_C downto 0)(src_c'length-1 downto 0);
  signal pipe_d     : signed_vector(PIPEREGS_D downto 0)(src_d'length-1 downto 0);

begin

  pipe_rst(PIPEREGS_RST) <= src_rst;
  pipe_clr(PIPEREGS_CLR) <= src_clr;
  pipe_vld(PIPEREGS_VLD) <= src_vld;
  pipe_neg_a(PIPEREGS_NEG_A) <= src_neg_a;
  pipe_neg_b(PIPEREGS_NEG_B) <= src_neg_b;
  pipe_neg_d(PIPEREGS_NEG_D) <= src_neg_d;
  pipe_a(PIPEREGS_A) <= src_a;
  pipe_b(PIPEREGS_B) <= src_b;
  pipe_c(PIPEREGS_C) <= src_c;
  pipe_d(PIPEREGS_D) <= src_d;

  g_rst : if PIPEREGS_RST>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if srst/='0' then
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
        if srst/='0' then
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
        if srst/='0' then
          pipe_vld(PIPEREGS_VLD-1 downto 0) <= (others=>'0');
        elsif clkena='1' then
          pipe_vld(PIPEREGS_VLD-1 downto 0) <= pipe_vld(PIPEREGS_VLD downto 1);
        end if;
      end if;
    end process;
  end generate;

  g_neg_a : if PIPEREGS_NEG_A>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if srst/='0' then
          pipe_neg_a(PIPEREGS_NEG_A-1 downto 0) <= (others=>'0');
        elsif clkena='1' then
          pipe_neg_a(PIPEREGS_NEG_A-1 downto 0) <= pipe_neg_a(PIPEREGS_NEG_A downto 1);
        end if;
      end if;
    end process;
  end generate;

  g_neg_b : if PIPEREGS_NEG_B>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if srst/='0' then
          pipe_neg_b(PIPEREGS_NEG_B-1 downto 0) <= (others=>'0');
        elsif clkena='1' then
          pipe_neg_b(PIPEREGS_NEG_B-1 downto 0) <= pipe_neg_b(PIPEREGS_NEG_B downto 1);
        end if;
      end if;
    end process;
  end generate;

  g_neg_d : if PIPEREGS_NEG_D>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if srst/='0' then
          pipe_neg_d(PIPEREGS_NEG_D-1 downto 0) <= (others=>'0');
        elsif clkena='1' then
          pipe_neg_d(PIPEREGS_NEG_D-1 downto 0) <= pipe_neg_d(PIPEREGS_NEG_D downto 1);
        end if;
      end if;
    end process;
  end generate;

  g_a : if PIPEREGS_A>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if srst/='0' then
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
        if srst/='0' then
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
        if srst/='0' then
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
        if srst/='0' then
          pipe_d(PIPEREGS_D-1 downto 0) <= (others=>(others=>'-'));
        elsif clkena='1' then
          pipe_d(PIPEREGS_D-1 downto 0) <= pipe_d(PIPEREGS_D downto 1);
        end if;
      end if;
    end process;
  end generate;

  dsp_rst <= pipe_rst(0);
  dsp_clr <= pipe_clr(0);
  dsp_vld <= pipe_vld(0);
  dsp_neg_a <= pipe_neg_a(0);
  dsp_neg_b <= pipe_neg_b(0);
  dsp_neg_d <= pipe_neg_d(0);
  dsp_a <= pipe_a(0);
  dsp_b <= pipe_b(0);
  dsp_c <= pipe_c(0);
  dsp_d <= pipe_d(0);

end architecture;
