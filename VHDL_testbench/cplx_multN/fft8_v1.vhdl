library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library fixitfetish;
  use fixitfetish.cplx_pkg.all;

entity fft8_v1 is
port (
  clk      : in  std_logic;
  rst      : in  std_logic;
  start    : in  std_logic;
  data_in  : in  cplx_vector(0 to 7);
  idx_out  : out unsigned(2 downto 0);
  data_out : out cplx
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of fft8_v1 is

  constant DFTMTX_RESOLUTION : positive range 8 to 32 := 18; -- Real/Imag width in bits
  constant DFTMTX_POWER_LD : positive := DFTMTX_RESOLUTION-1;

  signal fft_in : cplx_vector(0 to 7) := cplx_vector_reset(18,8,"R");

  signal dftmtx_slv : std_logic_vector(8*2*DFTMTX_RESOLUTION-1 downto 0);
  signal dftmtx_18bit : cplx_vector(0 to 7);

  signal run : boolean;
  signal idx : unsigned(2 downto 0);

  constant MAX_NUM_PIPE_DSP : positive := 10;
  signal PIPESTAGES : natural;

  type t_idx is array(integer range <>) of unsigned(2 downto 0);
  signal idx_q : t_idx(0 to MAX_NUM_PIPE_DSP);

begin

  -- data input
  p_din : process(clk)
  begin
    if rising_edge(clk) then
      if start='1' or (not run) then
        fft_in <= data_in;
      end if;
    end if;
  end process;

  -- input index generation
  p_idx : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        idx <= (others=>'0');
        run <= false;

      elsif (start='1' or run) then
        if idx=7 then
          idx <= (others=>'0');
          run <= false;
        else
          idx <= idx + 1;
          run <= true;
        end if;
      else
        idx <= (others=>'0');
        run <= false;
     end if; --reset
    end if; --clock
  end process;

  -- DFT-Matrix ROM,  one cycle delay
  i_dtfmtx : entity work.dftmtx8
  generic map(
    IQ_WIDTH => DFTMTX_RESOLUTION,
    POWER_LD => DFTMTX_POWER_LD
  )
  port map(
    clk  => clk,
    rst  => rst,
    idx  => idx,
    conj => '0',
    dout => dftmtx_slv
  );

  -- ROM output data to complex vector
  dftmtx_18bit <= to_cplx_vector(slv=>dftmtx_slv, n=>8, vld=>'1');

  -- multiplier / scalar product
  i_mult : entity fixitfetish.cplx_mult_sum
  generic map(
    NUM_MULT => fft_in'length,
    HIGH_SPEED_MODE => false,
    NUM_INPUT_REG => 1,
    NUM_OUTPUT_REG => 1,
    INPUT_OVERFLOW_IGNORE => false,
    OUTPUT_SHIFT_RIGHT => DFTMTX_POWER_LD,
    MODE => "NSO" -- saturation + overflow detection
  )
  port map(
    clk        => clk,
    clk2       => open, -- unused
    neg        => (others=>'0'),
    x          => fft_in,
    y          => dftmtx_18bit,
    result     => data_out,
    PIPESTAGES => PIPESTAGES
  );

  -- bypassed index
  idx_q(0) <= idx;
  g_delay : for n in 1 to MAX_NUM_PIPE_DSP generate
    idx_q(n) <= idx_q(n-1) when rising_edge(clk);
  end generate;

  -- output data index
  idx_out <= idx_q(PIPESTAGES+1);

end architecture;
