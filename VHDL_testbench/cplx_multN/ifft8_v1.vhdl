library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library fixitfetish;
  use fixitfetish.cplx_pkg.all;

entity ifft8_v1 is
port (
  clk      : in  std_logic;
  rst      : in  std_logic;
  start    : in  std_logic;
  idx_in   : in  unsigned(2 downto 0);
  data_in  : in  cplx;
  data_out : out cplx_vector(0 to 7) := cplx_vector_reset(18,8,"R")
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of ifft8_v1 is

  constant DFTMTX_RESOLUTION : positive range 8 to 32 := 16; -- Real/Imag width in bits
  constant DFTMTX_POWER_LD : positive := DFTMTX_RESOLUTION-1;

  signal fft_start : std_logic := '0';
  signal fft_in : cplx := cplx_reset(18,"R");

  signal dftmtx_slv : std_logic_vector(8*2*DFTMTX_RESOLUTION-1 downto 0);
  signal dftmtx_16bit : cplx16_vector(0 to 7);
  signal dftmtx_18bit : cplx_vector(0 to 7);

  signal run : boolean;
  signal idx : unsigned(2 downto 0);

  constant MAX_NUM_PIPE_DSP : positive := 10;
  
  type integer_vector is array(integer range <>) of integer;
  signal PIPESTAGES : integer_vector(0 to 7);

  type t_idx is array(integer range <>) of unsigned(2 downto 0);
  signal idx_q : t_idx(0 to MAX_NUM_PIPE_DSP);

  signal data_out_i : cplx_vector(0 to 7);

begin

  -- data input
  p_din : process(clk)
  begin
    if rising_edge(clk) then
      fft_in <= data_in;
      fft_start <= start;
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
    conj => '1', -- ifft !
    dout => dftmtx_slv
  );

  -- ROM output data to complex vector
  dftmtx_16bit <= to_cplx_vector(slv=>dftmtx_slv, n=>8, vld=>'1');
  dftmtx_18bit <= resize(dftmtx_16bit,18); -- resize to 18-bit standard for VHDL-1993

  g_loop : for n in 0 to 7 generate
  -- multiplier
  i_mult : entity fixitfetish.cplx_mult1_accu
  generic map(
    NUM_SUMMAND => 8,
    NUM_INPUT_REG => 1,
    NUM_OUTPUT_REG => 0,
    INPUT_OVERFLOW_IGNORE => false,
    OUTPUT_SHIFT_RIGHT => DFTMTX_POWER_LD,
    MODE => "NSO" -- round + saturation + overflow detection
  )
  port map(
    clk        => clk,
    clk2       => open, -- unused
    clr        => fft_start,
    sub        => '0',
    x          => fft_in,
    y          => dftmtx_18bit(n),
    result     => data_out_i(n),
    PIPESTAGES => PIPESTAGES(n)
  );
  end generate;

  -- bypassed index
  idx_q(0) <= idx;
  g_delay : for n in 1 to MAX_NUM_PIPE_DSP generate
    idx_q(n) <= idx_q(n-1) when rising_edge(clk);
  end generate;

  p_out : process(clk)
  begin
    if rising_edge(clk) then
      if idx_q(PIPESTAGES(0)+1)=7 then
        data_out <= data_out_i;
      else
        for n in 0 to 7 loop
          data_out(n).vld <= '0';
        end loop;
      end if;
    end if;
  end process;

end architecture;
