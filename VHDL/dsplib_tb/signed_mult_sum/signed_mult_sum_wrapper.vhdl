library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library baselib;
 use baselib.ieee_extension_types.all;
library dsplib;

entity signed_mult_sum_wrapper is
  generic (
    NUM_MULT : positive := 1; -- number of parallel multiplications
    NUM_INPUT_REG : positive := 1
  );
  port (
    clk             : in  std_logic;
    rst_ipin        : in  std_logic;
    vld_ipin        : in  std_logic;
    neg_ipin        : in  std_logic_vector(0 to NUM_MULT-1);
    x_ipin          : in  std_logic_vector(18*NUM_MULT-1 downto 0);
    y_ipin          : in  std_logic_vector(17 downto 0);
    result_opin     : out signed(21 downto 0); -- product result
    result_vld_opin : out std_logic; -- output valid
    result_ovf_opin : out std_logic -- output overflow
  );
end entity;

architecture rtl of signed_mult_sum_wrapper is

  signal rst, rst_ioreg : std_logic;
  signal vld, vld_ioreg : std_logic;
  signal neg, neg_ioreg : std_logic_vector(0 to NUM_MULT-1);
  signal x, x_ioreg : signed18_vector(0 to NUM_MULT-1);
  signal y, y_ioreg : signed18_vector(0 to 0);
  
  signal result, result_ioreg : signed(21 downto 0); -- product result
  signal result_vld, result_vld_ioreg : std_logic; -- output valid
  signal result_ovf, result_ovf_ioreg : std_logic; -- output overflow

begin

 rst_ioreg <= rst_ipin when rising_edge(clk);
 vld_ioreg <= vld_ipin when rising_edge(clk);
 neg_ioreg <= neg_ipin when rising_edge(clk);
 result_opin <= result_ioreg when rising_edge(clk);
 result_vld_opin <= result_vld_ioreg when rising_edge(clk);
 result_ovf_opin <= result_ovf_ioreg when rising_edge(clk);
 
 rst <= rst_ioreg when rising_edge(clk);
 vld <= vld_ioreg when rising_edge(clk);
 neg <= neg_ioreg when rising_edge(clk);
 result_ioreg <= result when rising_edge(clk);
 result_vld_ioreg <= result_vld when rising_edge(clk);
 result_ovf_ioreg <= result_ovf when rising_edge(clk);
-- result_vld_opin <= result_vld when rising_edge(clk);
-- result_ovf_opin <= result_ovf when rising_edge(clk);
 
 gx: for n in 0 to NUM_MULT-1 generate
   -- X input pipeline
   x_ioreg(n) <= signed(x_ipin(18*(n+1)-1 downto 18*n)) when rising_edge(clk);
   x(n) <= x_ioreg(n) when rising_edge(clk);
 end generate;
 -- Y input pipeline
 y_ioreg(0) <= signed(y_ipin) when rising_edge(clk);
 y(0) <= y_ioreg(0) when rising_edge(clk);

 I1 : entity dsplib.signed_mult_sum
 generic map(
   NUM_MULT           => NUM_MULT, -- number of parallel multiplications
   HIGH_SPEED_MODE    => true,
   NUM_INPUT_REG      => NUM_INPUT_REG,  -- number of input registers
   NUM_OUTPUT_REG     => 1,  -- number of output registers
   OUTPUT_SHIFT_RIGHT => 10,  -- number of right shifts
   OUTPUT_ROUND       => true,  -- enable rounding half-up
   OUTPUT_CLIP        => false,  -- enable clipping
   OUTPUT_OVERFLOW    => true   -- enable overflow detection
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
   PIPESTAGES => open -- constant number of pipeline stages
 );

end architecture;
