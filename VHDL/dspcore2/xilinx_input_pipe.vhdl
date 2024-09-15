-------------------------------------------------------------------------------
-- @file       xilinx_input_pipe.vhdl
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

-- This entity implements a generic DSP input pipeline logic for Xilinx Devices.
--
entity xilinx_input_pipe is
generic (
  PIPEREGS_RST     : natural := 1;
  PIPEREGS_CLR     : natural := 1;
  PIPEREGS_NEG     : natural := 1;
  PIPEREGS_A       : natural := 1;
  PIPEREGS_B       : natural := 1;
  PIPEREGS_C       : natural := 1;
  PIPEREGS_D       : natural := 1
);
port (
  -- Standard system clock
  clk       : in  std_logic;
  -- Global synchronous reset (optional, only connect if really required!)
  srst      : in  std_logic := '0';
  -- Clock enable (optional)
  clkena    : in  std_logic := '1';
  src_rst   : in  std_logic := '0';
  src_clr   : in  std_logic := '1';
  src_neg   : in  std_logic := '0';
  src_a_vld : in  std_logic := '0';
  src_b_vld : in  std_logic := '0';
  src_c_vld : in  std_logic := '0';
  src_d_vld : in  std_logic := '0';
  src_a_neg : in  std_logic := '0';
  src_d_neg : in  std_logic := '0';
  src_a     : in  signed;
  src_b     : in  signed;
  src_c     : in  signed;
  src_d     : in  signed;
  dsp_rst   : out std_logic;
  dsp_clr   : out std_logic;
  dsp_neg   : out std_logic;
  dsp_a_vld : out std_logic;
  dsp_b_vld : out std_logic;
  dsp_c_vld : out std_logic;
  dsp_d_vld : out std_logic;
  dsp_a_neg : out std_logic;
  dsp_d_neg : out std_logic;
  dsp_a     : out signed;
  dsp_b     : out signed;
  dsp_c     : out signed;
  dsp_d     : out signed
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of xilinx_input_pipe is

  signal pipe_rst   : std_logic_vector(PIPEREGS_RST downto 0) := (others=>'0');
  signal pipe_clr   : std_logic_vector(PIPEREGS_CLR downto 0) := (others=>'1');
  signal pipe_neg   : std_logic_vector(PIPEREGS_NEG downto 0) := (others=>'0');
  signal pipe_a_vld : std_logic_vector(PIPEREGS_A downto 0) := (others=>'0');
  signal pipe_b_vld : std_logic_vector(PIPEREGS_B downto 0) := (others=>'0');
  signal pipe_c_vld : std_logic_vector(PIPEREGS_C downto 0) := (others=>'0');
  signal pipe_d_vld : std_logic_vector(PIPEREGS_D downto 0) := (others=>'0');
  signal pipe_a_neg : std_logic_vector(PIPEREGS_A downto 0) := (others=>'0');
  signal pipe_d_neg : std_logic_vector(PIPEREGS_D downto 0) := (others=>'0');
  signal pipe_a     : signed_vector(PIPEREGS_A downto 0)(src_a'length-1 downto 0);
  signal pipe_b     : signed_vector(PIPEREGS_B downto 0)(src_b'length-1 downto 0);
  signal pipe_c     : signed_vector(PIPEREGS_C downto 0)(src_c'length-1 downto 0);
  signal pipe_d     : signed_vector(PIPEREGS_D downto 0)(src_d'length-1 downto 0);

begin

  pipe_rst(PIPEREGS_RST) <= src_rst;
  pipe_clr(PIPEREGS_CLR) <= src_clr;
  pipe_neg(PIPEREGS_NEG) <= src_neg;
  pipe_a_vld(PIPEREGS_A) <= src_a_vld;
  pipe_b_vld(PIPEREGS_B) <= src_b_vld;
  pipe_c_vld(PIPEREGS_C) <= src_c_vld;
  pipe_d_vld(PIPEREGS_D) <= src_d_vld;
  pipe_a_neg(PIPEREGS_A) <= src_a_neg;
  pipe_d_neg(PIPEREGS_D) <= src_d_neg;
  pipe_a(PIPEREGS_A) <= src_a;
  pipe_b(PIPEREGS_B) <= src_b;
  pipe_c(PIPEREGS_C) <= src_c;
  pipe_d(PIPEREGS_D) <= src_d;

  g_rst : if PIPEREGS_RST>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if srst/='0' then
          pipe_rst(PIPEREGS_RST-1 downto 0) <= (others=>'0');
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

  g_neg : if PIPEREGS_NEG>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if srst/='0' then
          pipe_neg(PIPEREGS_NEG-1 downto 0) <= (others=>'0');
        elsif clkena='1' then
          pipe_neg(PIPEREGS_NEG-1 downto 0) <= pipe_neg(PIPEREGS_NEG downto 1);
        end if;
      end if;
    end process;
  end generate;

  g_a : if PIPEREGS_A>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if srst/='0' then
          pipe_a_vld(PIPEREGS_A-1 downto 0) <= (others=>'0');
          pipe_a_neg(PIPEREGS_A-1 downto 0) <= (others=>'0');
          pipe_a(PIPEREGS_A-1 downto 0) <= (others=>(others=>'-'));
        elsif clkena='1' then
          pipe_a_vld(PIPEREGS_A-1 downto 0) <= pipe_a_vld(PIPEREGS_A downto 1);
          pipe_a_neg(PIPEREGS_A-1 downto 0) <= pipe_a_neg(PIPEREGS_A downto 1);
          pipe_a(PIPEREGS_A-1 downto 0) <= pipe_a(PIPEREGS_A downto 1);
        end if;
      end if;
    end process;
  end generate;

  g_b : if PIPEREGS_B>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if srst/='0' then
          pipe_b_vld(PIPEREGS_B-1 downto 0) <= (others=>'0');
          pipe_b(PIPEREGS_B-1 downto 0) <= (others=>(others=>'-'));
        elsif clkena='1' then
          pipe_b_vld(PIPEREGS_B-1 downto 0) <= pipe_b_vld(PIPEREGS_B downto 1);
          pipe_b(PIPEREGS_B-1 downto 0) <= pipe_b(PIPEREGS_B downto 1);
        end if;
      end if;
    end process;
  end generate;

  g_c : if PIPEREGS_C>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if srst/='0' then
          pipe_c_vld(PIPEREGS_C-1 downto 0) <= (others=>'0');
          pipe_c(PIPEREGS_C-1 downto 0) <= (others=>(others=>'-'));
        elsif clkena='1' then
          pipe_c_vld(PIPEREGS_C-1 downto 0) <= pipe_c_vld(PIPEREGS_C downto 1);
          pipe_c(PIPEREGS_C-1 downto 0) <= pipe_c(PIPEREGS_C downto 1);
        end if;
      end if;
    end process;
  end generate;

  g_d : if PIPEREGS_D>=1 generate
    process(clk) begin
      if rising_edge(clk) then
        if srst/='0' then
          pipe_d_vld(PIPEREGS_D-1 downto 0) <= (others=>'0');
          pipe_d_neg(PIPEREGS_D-1 downto 0) <= (others=>'0');
          pipe_d(PIPEREGS_D-1 downto 0) <= (others=>(others=>'-'));
        elsif clkena='1' then
          pipe_d_vld(PIPEREGS_D-1 downto 0) <= pipe_d_vld(PIPEREGS_D downto 1);
          pipe_d_neg(PIPEREGS_D-1 downto 0) <= pipe_d_neg(PIPEREGS_D downto 1);
          pipe_d(PIPEREGS_D-1 downto 0) <= pipe_d(PIPEREGS_D downto 1);
        end if;
      end if;
    end process;
  end generate;

  dsp_rst <= pipe_rst(0);
  dsp_clr <= pipe_clr(0);
  dsp_neg <= pipe_neg(0);
  dsp_a_vld <= pipe_a_vld(0);
  dsp_b_vld <= pipe_b_vld(0);
  dsp_c_vld <= pipe_c_vld(0);
  dsp_d_vld <= pipe_d_vld(0);
  dsp_a_neg <= pipe_a_neg(0);
  dsp_d_neg <= pipe_d_neg(0);
  dsp_a <= pipe_a(0);
  dsp_b <= pipe_b(0);
  dsp_c <= pipe_c(0);
  dsp_d <= pipe_d(0);

end architecture;
