-------------------------------------------------------------------------------
--! @file       signed_multN_accu.stratixv.vhdl
--! @author     Fixitfetish
--! @date       23/Feb/2017
--! @version    0.20
--! @copyright  MIT License
--! @note       VHDL-1993
-------------------------------------------------------------------------------
-- Copyright (c) 2017 Fixitfetish
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
library fixitfetish;
 use fixitfetish.ieee_extension.all;
 use fixitfetish.ieee_extension_types.all;

--! @brief This is an implementation of the entity 
--! @link signed_multN_accu signed_multN_accu @endlink
--! for Altera Stratix-V.
--! N signed multiplications are performed and all results are accumulated.
--!
--! +++ TODO +++ Multiple instances of the implementation
--! +++ TODO +++ @link signed_mult2_accu signed_mult2_accu @endlink are chained.
--!
--! +++ TODO +++ This implementation requires ceil(N/2) Variable Precision DSP Blocks of mode 'm18x18_sumof2'.
--! +++ TODO +++ For details please refer to the Altera Stratix V Device Handbook.
--!
--! * Input Data      : Nx2 signed values, each max 18 bits
--! * Input Register  : optional, at least one is strongly recommended
--! * Input Chain     : optional, 64 bits
--! * Accu Register   : 64 bits, enabled when NUM_OUTPUT_REG>0
--! * Rounding        : optional half-up, within DSP cell
--! * Output Data     : 1x signed value, max 64 bits
--! * Output Register : optional, at least one strongly recommend, another after shift-right and saturation
--! * Output Chain    : optional, 64 bits
--! * Pipeline stages : NUM_INPUT_REG + floor((N-1)/2) + NUM_OUTPUT_REG
--!
--! This implementation can be chained multiple times.
--! @image html signed_multN_accu.stratixv.svg "" width=800px

architecture stratixv of signed_multN_accu is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "signed_multN_accu(stratixv)";

  -- derived constants
  constant NUM_MULT_PER_ENTITY : natural := 2;
  constant NUM_ENTITY : natural := (NUM_MULT+NUM_MULT_PER_ENTITY-1)/NUM_MULT_PER_ENTITY;

  -- Internal copy of inputs required because some multipliers of an entity might
  -- be unused and need to be set to zero.
  type t_x is array(integer range <>) of signed(x(0)'length-1 downto 0);
  type t_y is array(integer range <>) of signed(y(0)'length-1 downto 0);
  signal x_i : t_x(0 to NUM_ENTITY*NUM_MULT_PER_ENTITY-1) := (others=>(others=>'0'));
  signal y_i : t_y(0 to NUM_ENTITY*NUM_MULT_PER_ENTITY-1) := (others=>(others=>'0'));
  signal sub_i : std_logic_vector(0 to NUM_ENTITY*NUM_MULT_PER_ENTITY-1) := (others=>'0');
  signal clr_i : std_logic_vector(0 to NUM_ENTITY-1) := (others=>'1');

  -- Internal copy of outputs required because some multipliers of an entity might
  -- be unused and need to be ignored.
  type t_r is array(integer range <>) of signed(result'length-1 downto 0);
  signal r_i : t_r(0 to NUM_ENTITY-1);
  signal r_vld_i : std_logic_vector(0 to NUM_ENTITY-1);
  signal r_ovf_i : std_logic_vector(0 to NUM_ENTITY-1);
  type integer_vector is array(integer range <>) of integer;
  signal pipe : integer_vector(0 to NUM_ENTITY-1);

  type t_chain_vector is array(integer range <>) of signed(chainout'length-1 downto 0);
  signal chainin_i : t_chain_vector(0 to NUM_ENTITY) := (others=>(others=>'0'));

  -- auxiliary functions to control generic mapping

  function summands(n:natural) return natural is
  begin
    if n=(NUM_ENTITY-1) then return NUM_SUMMAND; else return 2*(n+1); end if;
  end function;

  function chain_input(n:natural) return boolean is
  begin
    if n=0 then return USE_CHAIN_INPUT; else return true; end if;
  end function;

  function outreg(n:natural) return natural is
  begin
    if n=(NUM_ENTITY-1) then return NUM_OUTPUT_REG; else return 1; end if;
  end function;

  function rshift(n:natural) return natural is
  begin
    if n=(NUM_ENTITY-1) then return OUTPUT_SHIFT_RIGHT; else return 0; end if;
  end function;

  function do_round(n:natural) return boolean is
  begin
    if n=(NUM_ENTITY-1) then return OUTPUT_ROUND; else return false; end if;
  end function;

  function do_clip(n:natural) return boolean is
  begin
    if n=(NUM_ENTITY-1) then return OUTPUT_CLIP; else return false; end if;
  end function;

  function do_overflow(n:natural) return boolean is
  begin
    if n=(NUM_ENTITY-1) then return OUTPUT_OVERFLOW; else return false; end if;
  end function;

begin

  -- Map inputs to internal signals
  g_in: for n in 0 to (NUM_MULT-1) generate
    x_i(n) <= x(n);
    y_i(n) <= y(n);
    sub_i(n) <= sub(n);
  end generate;
  chainin_i(0) <= chainin;
  clr_i(NUM_ENTITY-1) <= clr; -- accumulator enabled in last instance only!

  g_n: for n in 0 to (NUM_ENTITY-1) generate
    mult2 : entity fixitfetish.signed_mult2_accu
    generic map(
      NUM_SUMMAND        => summands(n),
      USE_CHAIN_INPUT    => chain_input(n),
      NUM_INPUT_REG      => NUM_INPUT_REG+n, -- additional pipeline register(s) because of chaining
      NUM_OUTPUT_REG     => outreg(n),
      OUTPUT_SHIFT_RIGHT => rshift(n),
      OUTPUT_ROUND       => do_round(n),
      OUTPUT_CLIP        => do_clip(n),
      OUTPUT_OVERFLOW    => do_overflow(n)
    )
    port map (
      clk        => clk,
      rst        => rst,
      clr        => clr_i(n), -- accumulator enabled in last instance only!
      vld        => vld,
      sub        => sub_i(2*n to 2*n+1),
      x0         => x_i(2*n),
      y0         => y_i(2*n),
      x1         => x_i(2*n+1),
      y1         => y_i(2*n+1),
      result     => r_i(n),
      result_vld => r_vld_i(n),
      result_ovf => r_ovf_i(n),
      chainin    => chainin_i(n),
      chainout   => chainin_i(n+1),
      PIPESTAGES => pipe(n)
    );
  end generate;

  -- Map internal signals to output ports
  result <= r_i(NUM_ENTITY-1);
  result_vld <= r_vld_i(NUM_ENTITY-1);
  result_ovf <= r_ovf_i(NUM_ENTITY-1);
  chainout <= chainin_i(NUM_ENTITY);

  -- overall number of pipeline stages is derived from the last entity
  PIPESTAGES <= pipe(NUM_ENTITY-1);

end architecture;

