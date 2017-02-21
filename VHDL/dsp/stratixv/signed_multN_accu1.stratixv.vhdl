-------------------------------------------------------------------------------
--! @file       signed_multN_accu1.stratixv.vhdl
--! @author     Fixitfetish
--! @date       19/Feb/2017
--! @version    0.10
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

library stratixv;
 use stratixv.stratixv_components.all;

--! @brief This is an implementation of the entity 
--! @link signed_multN_accu1 signed_multN_accu1 @endlink
--! for Altera Stratix-V.
--! N signed multiplications are performed and all results are accumulated.
--!
--! +++ TODO +++ Multiple instances of the implementation
--! +++ TODO +++ @link signed_mult2_accu1 signed_mult2_accu1 @endlink are chained.
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
--! @image html signed_multN_accu1.stratixv.svg "" width=800px

architecture stratixv of signed_multN_accu1 is

  -- identifier for reports of warnings and errors
  constant IMPLEMENTATION : string := "signed_multN_accu1(stratixv)";

  constant NUM_MULT2_BLOCKS : natural := (NUM_MULT+1)/2; -- ceil(NUM_MULT/2)
  
  type t_chain_vector is array(integer range <>) of signed(chainout'length-1 downto 0);
  signal chainin_i : t_chain_vector(0 to NUM_MULT2_BLOCKS-1) := (others=>(others=>'0'));

  -- inputs to last block 
  signal sub_last : std_logic := '0';
  signal x_last : signed(x(0)'length-1 downto 0) := (others=>'0');
  signal y_last : signed(y(0)'length-1 downto 0) := (others=>'0');

  function chain_input(n:natural) return boolean is
    variable res : boolean := true;
  begin
    if n=1 and (not USE_CHAIN_INPUT) then res:=false; end if;
    return res;
  end function;

  -- dummy sink to avoid warnings
  type t_dummy_vector is array(integer range <>) of signed(17 downto 0);
  signal dummy : t_dummy_vector(0 to NUM_MULT2_BLOCKS-1) := (others=>(others=>'0'));
  procedure signed_sink(d:in signed) is
    variable b : boolean := false;
  begin b := (d(d'right)='1') or b; end procedure;

begin

  chainin_i(0) <= chainin;

  g_chain: if NUM_MULT2_BLOCKS>=2 generate
   g_n: for n in 0 to (NUM_MULT2_BLOCKS-2) generate
    -- instances with disabled accumulator
    mult2_accu : entity fixitfetish.signed_mult2_accu1
    generic map(
      NUM_SUMMAND        => 2*(n+1), -- irrelevant because only chain output is used
      USE_CHAIN_INPUT    => chain_input(n+1),
      NUM_INPUT_REG      => NUM_INPUT_REG+n, -- additional pipeline register(s) because of chaining
      NUM_OUTPUT_REG     => 1,     -- use first output register as pipeline register
      OUTPUT_SHIFT_RIGHT => 0,     -- irrelevant because only chain output is used
      OUTPUT_ROUND       => false, -- irrelevant because only chain output is used
      OUTPUT_CLIP        => false, -- irrelevant because only chain output is used
      OUTPUT_OVERFLOW    => false  -- irrelevant because only chain output is used
    )
    port map (
     clk        => clk,
     rst        => rst,
     clr        => '1', -- disable accumulation
     vld        => vld,
     sub        => sub(2*n to 2*n+1),
     x0         => x(2*n),
     y0         => y(2*n),
     x1         => x(2*n+1),
     y1         => y(2*n+1),
     result     => dummy(n),
     result_vld => open,
     result_ovf => open,
     chainin    => chainin_i(n),
     chainout   => chainin_i(n+1),
     PIPESTAGES => open
    );
    signed_sink(dummy(n));
   end generate;
  end generate;

  -- consider odd number of multiplications
  g_even_mult : if NUM_MULT=(2*NUM_MULT2_BLOCKS) generate
    sub_last <= sub(NUM_MULT-1);
    x_last <= x(NUM_MULT-1);
    y_last <= y(NUM_MULT-1);
  end generate;

  -- last instance with enabled accumulator
  last : entity fixitfetish.signed_mult2_accu1
  generic map(
    NUM_SUMMAND        => NUM_SUMMAND,
    USE_CHAIN_INPUT    => chain_input(NUM_MULT2_BLOCKS),
    NUM_INPUT_REG      => NUM_INPUT_REG+NUM_MULT2_BLOCKS-1, -- additional pipeline register(s) because of chaining
    NUM_OUTPUT_REG     => NUM_OUTPUT_REG,
    OUTPUT_SHIFT_RIGHT => OUTPUT_SHIFT_RIGHT,
    OUTPUT_ROUND       => OUTPUT_ROUND,
    OUTPUT_CLIP        => OUTPUT_CLIP,
    OUTPUT_OVERFLOW    => OUTPUT_OVERFLOW
  )
  port map (
   clk        => clk,
   rst        => rst,
   clr        => clr,
   vld        => vld,
   sub(0)     => sub(2*NUM_MULT2_BLOCKS-2),
   sub(1)     => sub_last,
   x0         => x(2*NUM_MULT2_BLOCKS-2),
   y0         => y(2*NUM_MULT2_BLOCKS-2),
   x1         => x_last,
   y1         => y_last,
   result     => result,
   result_vld => result_vld,
   result_ovf => result_ovf,
   chainin    => chainin_i(NUM_MULT2_BLOCKS-1),
   chainout   => chainout,
   PIPESTAGES => PIPESTAGES
  );

end architecture;

