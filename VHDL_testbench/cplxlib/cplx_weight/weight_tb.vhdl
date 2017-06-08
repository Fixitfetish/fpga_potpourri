-------------------------------------------------------------------------------
-- FILE    : weight_tb.vhdl
-- AUTHOR  : Fixitfetish
-- DATE    : 06/Jun/2017
-- VERSION : 0.30
-- VHDL    : 1993
-- LICENSE : MIT License
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;
library cplxlib;
  use cplxlib.cplx_pkg.all;

use std.textio.all;

entity weight_tb is
end entity;

architecture sim of weight_tb is
  
  constant PERIOD : time := 5 ns; -- 200MHz
  constant LX : natural := 5;  -- vector length x
  constant LY : natural := 5;  -- vector length w
  constant LR : natural := LX; -- vector length result

  constant FILENAME_X : string := "x_sti.txt"; -- input x
  constant FILENAME_Y : string := "y_sti.txt"; -- input y
  constant FILENAME_R : string := "result_log.txt"; -- result

  signal rst : std_logic := '1';
  signal clk : std_logic := '1';
  signal clkena : std_logic := '0';
  signal finish : std_logic := '0';

  signal x : cplx_vector(0 to LX-1) := cplx_vector_reset(18,LX,"R");
  signal y : cplx_vector(0 to LY-1) := cplx_vector_reset(18,LY,"R"); -- only real used here
  signal w : signed_vector(0 to LY-1) := (others=>(others=>'0'));
  signal r : cplx_vector(0 to LR-1);

begin

  p_clk : process
  begin
    while finish='0' loop
      wait for PERIOD/2;
      clk <= not clk;
    end loop;
    -- epilog, 5 cycles
    for n in 1 to 10 loop
      wait for PERIOD/2;
      clk <= not clk;
    end loop;
    report "INFO: Clock stopped. End of simulation." severity note;
    wait; -- stop clock
  end process;

  -- release reset
  rst <= '0' after 2*PERIOD;

  p_start : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        clkena <= '0';
      else
        clkena <= not clkena;
      end if;
    end if;
  end process;

  x_sti : entity work.cplx_stimuli
  generic map(
    NUM_CPLX => LX,
    SKIP_PRECEDING_LINES => 2,
    GEN_DECIMAL => true,
    GEN_INVALID => true,
    GEN_FILE => FILENAME_X
  )
  port map (
    rst     => rst,
    clk     => clk,
    clkena  => clkena,
    dout    => x,
    finish  => finish
  );

  y_sti : entity work.cplx_stimuli
  generic map(
    NUM_CPLX => LY,
    SKIP_PRECEDING_LINES => 2,
    GEN_DECIMAL => true,
    GEN_INVALID => true,
    GEN_FILE => FILENAME_Y
  )
  port map (
    rst     => rst,
    clk     => clk,
    clkena  => clkena,
    dout    => y,
    finish  => finish
  );

  -- weight factor is the real part of the input y
  gw: for n in 0 to LY-1 generate
    w(n) <= y(n).re;
  end generate;

  I1 : entity cplxlib.cplx_weight
  generic map(
    NUM_MULT              => LX, -- number of parallel multiplications
    HIGH_SPEED_MODE       => false,  -- enable high speed mode
    NUM_INPUT_REG         => 1,  -- number of input registers
    NUM_OUTPUT_REG        => 1,  -- number of output registers
    INPUT_OVERFLOW_IGNORE => false,  -- ignore input overflows
    OUTPUT_SHIFT_RIGHT    => 17,  -- number of right shifts
    MODE                  => "NOS" -- options
  )
  port map(
    clk        => clk  , -- clock
    clk2       => open  , -- clock x2
    neg        => (others=>'0'), -- negation per input x
    x          => x, -- first factors
    w          => w, -- second factors
    result     => r, -- product results
    PIPESTAGES => open  -- constant number of pipeline stages
  );

  i_log : entity work.cplx_logger
  generic map(
    NUM_CPLX => LR+1,
    LOG_DECIMAL => true,
    LOG_INVALID => true,
    LOG_FILE => FILENAME_R,
    TITLE => "OUTPUT"
  )
  port map (
    clk     => clk,
    rst     => rst,
    din(0 to LR-1) => r,
    din(LR) => x(0), -- input reference for delay check
    finish  => finish
  );

end architecture;
