library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library baselib;
 use baselib.ieee_extension_types.all;
library dsplib;

entity signed_mult_sum_tb is
  generic (
    NUM_MULT           : positive := 1; -- number of parallel multiplications
    HIGH_SPEED_MODE    : boolean := false; 
    NUM_INPUT_REG      : natural := 1; -- number of input registers
    NUM_OUTPUT_REG     : natural := 1; -- number of output registers
    OUTPUT_WIDTH       : natural := 36; -- bit width of result output
    OUTPUT_SHIFT_RIGHT : natural := 0; -- number of right shifts
    OUTPUT_ROUND       : boolean := false; -- enable rounding half-up
    OUTPUT_CLIP        : boolean := false; -- enable clipping
    OUTPUT_OVERFLOW    : boolean := false  -- enable overflow detection
  );
end entity;

architecture rtl of signed_mult_sum_tb is

  -- clock
  constant PERIOD : time := 10 ns;
  signal clk : std_logic := '1';

  signal rst : std_logic := '1';
  signal vld : std_logic := '0';
  signal neg : std_logic_vector(0 to NUM_MULT-1) := (others=>'0');
  signal x : signed18_vector(0 to NUM_MULT-1) := (others=>(others=>'0'));
  signal y : signed18_vector(0 to NUM_MULT-1) := (others=>(others=>'0'));
  
  -- behave
  signal result     : signed(OUTPUT_WIDTH-1 downto 0); -- product result
  signal result_vld : std_logic; -- output valid
  signal result_ovf : std_logic; -- output overflow
  signal pipestages : natural;

--  -- Stratix-V
--  signal s5_result     : signed(OUTPUT_WIDTH-1 downto 0); -- product result
--  signal s5_result_vld : std_logic; -- output valid
--  signal s5_result_ovf : std_logic; -- output overflow
--  signal s5_pipestages : natural;

  -- Ultrascale
  signal us_result     : signed(OUTPUT_WIDTH-1 downto 0); -- product result
  signal us_result_vld : std_logic; -- output valid
  signal us_result_ovf : std_logic; -- output overflow
  signal us_pipestages : natural;

  procedure run_clk_cycles(signal clk:in std_logic; n:in integer) is
  begin
    for i in 1 to n loop wait until rising_edge(clk); end loop;
  end procedure;

begin

  -- Generate clock signal with 50% duty cycle
  clk <= not clk after PERIOD/2;

  -- stimuli process
  p_stim : process
  begin
    rst <= '1';
    run_clk_cycles(clk,10);
    rst <= '0';
    run_clk_cycles(clk,4);
    for i in 1 to 20 loop
      vld <= '1';
      for n in 0 to NUM_MULT-1 loop
--        -- simple test
--        x(n) <= to_signed( i , x(x'left)'length);
--        y(n) <= to_signed( 1 , y(y'left)'length);
        x(n) <= to_signed( n*100 + i   , x(x'left)'length);
        y(n) <= to_signed( (-5)**n + i , y(y'left)'length);
      end loop;
      wait until rising_edge(clk);
    end loop;
    vld <= '0';
    run_clk_cycles(clk,10);
    wait;
  end process;

  behave : entity dsplib.signed_mult_sum(behave)
  generic map(
    NUM_MULT           => NUM_MULT, -- number of parallel multiplications
    HIGH_SPEED_MODE    => HIGH_SPEED_MODE,
    NUM_INPUT_REG      => NUM_INPUT_REG,  -- number of input registers
    NUM_OUTPUT_REG     => NUM_OUTPUT_REG,  -- number of output registers
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,  -- number of right shifts
    OUTPUT_ROUND       => OUTPUT_ROUND,  -- enable rounding half-up
    OUTPUT_CLIP        => OUTPUT_CLIP,  -- enable clipping
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW   -- enable overflow detection
  )
  port map(
    clk        => clk, -- clock
    rst        => rst, -- reset
    vld        => vld, -- valid
    neg        => neg, -- negation
    x          => x, -- first factors
    y          => y, -- second factor(s)
    result     => result, -- product result
    result_vld => result_vld, -- output valid
    result_ovf => result_ovf, -- output overflow
    PIPESTAGES => pipestages -- constant number of pipeline stages
  );
 
--  s5 : entity dsplib.signed_mult_sum(stratixv)
--  generic map(
--    NUM_MULT           => NUM_MULT, -- number of parallel multiplications
--    HIGH_SPEED_MODE    => HIGH_SPEED_MODE,
--    NUM_INPUT_REG      => NUM_INPUT_REG,  -- number of input registers
--    NUM_OUTPUT_REG     => NUM_OUTPUT_REG,  -- number of output registers
--    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,  -- number of right shifts
--    OUTPUT_ROUND       => OUTPUT_ROUND,  -- enable rounding half-up
--    OUTPUT_CLIP        => OUTPUT_CLIP,  -- enable clipping
--    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW   -- enable overflow detection
--  )
--  port map(
--    clk        => clk, -- clock
--    rst        => rst, -- reset
--    vld        => vld, -- valid
--    neg        => neg, -- negation
--    x          => x, -- first factors
--    y          => y, -- second factor(s)
--    result     => s5_result, -- product result
--    result_vld => s5_result_vld, -- output valid
--    result_ovf => s5_result_ovf, -- output overflow
--    PIPESTAGES => s5_pipestages -- constant number of pipeline stages
--  );
 
  us : entity dsplib.signed_mult_sum(ultrascale)
  generic map(
    NUM_MULT           => NUM_MULT, -- number of parallel multiplications
    HIGH_SPEED_MODE    => HIGH_SPEED_MODE,
    NUM_INPUT_REG      => NUM_INPUT_REG,  -- number of input registers
    NUM_OUTPUT_REG     => NUM_OUTPUT_REG,  -- number of output registers
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,  -- number of right shifts
    OUTPUT_ROUND       => OUTPUT_ROUND,  -- enable rounding half-up
    OUTPUT_CLIP        => OUTPUT_CLIP,  -- enable clipping
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW   -- enable overflow detection
  )
  port map(
    clk        => clk, -- clock
    rst        => rst, -- reset
    vld        => vld, -- valid
    neg        => neg, -- negation
    x          => x, -- first factors
    y          => y, -- second factor(s)
    result     => us_result, -- product result
    result_vld => us_result_vld, -- output valid
    result_ovf => us_result_ovf, -- output overflow
    PIPESTAGES => us_pipestages -- constant number of pipeline stages
  );

end architecture;
