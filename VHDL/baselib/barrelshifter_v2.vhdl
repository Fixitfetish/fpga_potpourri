---------------------------------------------------------------------------------------------------
--! @file       barrelshifter.vhdl
--! @author     Fixitfetish
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
---------------------------------------------------------------------------------------------------
library ieee;
package local_fixed_pkg is new ieee.fixed_generic_pkg; -- @suppress "Generic map uses default values. Missing optional actuals: FIXED_ROUND_STYLE, FIXED_OVERFLOW_STYLE, and 2 more"
-- Locally use default fixed_pkg. Generics are irrelevant here.
-- UFIXED instead of SLV type is only used because of integer range and not for arithmetic operations.

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

use work.local_fixed_pkg.all;

-- The barrelshifter shifts a DIN vector of any size left or right.
-- The configurable barrel size allows grouping of bits into barrels. 
-- The width of the SHIFT and DIN_EXT inputs define the maximum possible number of barrels to shift. 
-- The shifter is implemented as recursive loop performing first the coarse and then the fine shifts
-- because this order can significantly reduce the number of pipeline registers in larger shifters. 
-- Parameters help to optimize the implemention and timing for a certain type of HW.
--
-- Example 1: Circular shift of 23 bits by 0 to 11 bits to the right.
-- * set RIGHT_SHIFT=true and BARREL_SIZE=1
-- * DIN width = 23 bits, DIN_EXT=DIN(10 downto 0), SHIFT width = 4 bits
--
-- Example 2: A vector of 19 bytes need to be shifted logically by 0 to 6 bytes to the left.
-- * set RIGHT_SHIFT=false and BARREL_SIZE=8
-- * DIN width = 19*8=152 bits, DIN_EXT=(47 downto 0=>'0'), SHIFT width = 3 bits
entity barrelshifter_v2 is
generic(
  -- Shifter barrel size in number of bits. Example: for byte-wise shifts the barrel size is 8.
  BARREL_SIZE : positive := 1;
  -- Max number of shifts per logic level (e.g. a LUT6 supports 4 shifts, so the LOG2 value is 2)
  SHIFTS_PER_LOGIC_LEVEL_LOG2 : positive := 2;
  -- Maximum number of shifter logic levels/stages between pipeline registers
  MAX_LOGIC_LEVELS : positive := 2;
  -- Enforce an input/pipeline register
  INPUT_REG : boolean := false;
  -- Shift direction, by default shift left
  RIGHT_SHIFT : boolean := false
);
port(
  -- clock
  clk         : in  std_logic;
  -- Synchronous reset, optional, only use when really required otherwise leave open
  rst         : in  std_logic := '0';
  -- Clock enable, optional, do not connect or leave open if unused
  ce          : in  std_logic := '1';
  -- The shift value defines by how many barrels the input is shifted left or right.
  -- The value cannot exceed the number of DIN_EXT barrels.
  shift       : in  unsigned;
  -- Data input vector. Length must be a multiple of the shifter barrel size.
  din         : in  std_logic_vector;
  -- Data input extension vector, extends data input to the right for left shifts and
  -- to the left for right shifts. Length must be a multiple of the shifter barrel size
  -- and not larger than DIN. Length also indirectly limits the possible number of shifts. 
  din_ext     : in  std_logic_vector;
  -- Data input valid signal, optional
  din_vld     : in  std_logic := '1';
  -- Data output vector. Same length as data input vector.
  dout        : out std_logic_vector;
  -- Data output valid signal, optional
  dout_vld    : out std_logic;
  -- Error flag when shift value is larger than expected, optional, leave open if unused
  shift_error : out boolean;
  -- Number of overall pipeline registers including input and output registers.
  -- Optional constant signal that might useful for delay compensation or reporting. 
  PIPESTAGES  : out integer range 0 to 15
);
begin
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  -- synthesis translate_off (Altera Quartus)
  assert (din'length mod BARREL_SIZE)=0 and (din_ext'length mod BARREL_SIZE)=0
    report barrelshifter_v2'INSTANCE_NAME & " Length of both input vectors must be a multiple of the shifter barrel size."
    severity failure;
  assert (din'length >= din_ext'length)
    report barrelshifter_v2'INSTANCE_NAME & " Input extension vector cannot be larger than the input vector."
    severity failure;
  assert (2**shift'length > din_ext'length/BARREL_SIZE)
    report barrelshifter_v2'INSTANCE_NAME & " SHIFT input range 0 to " & integer'image(2**shift'length-1) & 
           " is too small for provided input extension vector length of " & 
           integer'image(din_ext'length/BARREL_SIZE) & " barrels."
    severity warning;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)
end entity;

architecture rtl of barrelshifter_v2 is
  
  -- Number of barrels in input extension vector
  constant BARRELS_EXT : positive := din_ext'length / BARREL_SIZE;

  -- Maximum number of possible shifts is derived from the length of the input extension vector and the width of the shift value.
  constant MAX_SHIFT : positive := minimum(BARRELS_EXT, 2**shift'length-1);

  -- | BARRELS EXT | MAX SHIFT | SHIFT WIDTH |
  -- |-------------|-----------|-------------|
  -- |           1 |         1 |           1 | 
  -- |         2-3 |         3 |           2 | 
  -- |         4-7 |         7 |           3 |
  -- |        8-15 |        15 |           4 |
  -- |       16-31 |        31 |           5 |
  -- |         ... |       ... |         ... |
  constant SHIFT_WIDTH : positive := integer(ceil(log2(real(MAX_SHIFT+1))));

  -- Number of required logic levels, ceil(SHIFT_WIDTH/SHIFTS_PER_LOGIC_LEVEL_LOG2)
  constant LOGIC_LEVELS : positive := (SHIFT_WIDTH + SHIFTS_PER_LOGIC_LEVEL_LOG2 - 1) / SHIFTS_PER_LOGIC_LEVEL_LOG2;

  -- Number of barrels per unit, depends on the current shifter stage
  constant BARRELS_PER_UNIT_LOG2 : natural := maximum(0, SHIFT_WIDTH-SHIFTS_PER_LOGIC_LEVEL_LOG2);

  -- unit size in number of bits
  constant UNIT_SIZE : positive := 2**BARRELS_PER_UNIT_LOG2 * BARREL_SIZE;

  signal din_vld_i : std_logic;
  signal din_i : din'subtype;
  signal din_ext_i : din_ext'subtype;

  signal dout_slv : std_logic_vector(din'length-1 downto 0);
  signal dout_ext_slv : std_logic_vector(din_ext'length-1 downto 0);
 
  -- number of overall remaining shifts
  signal shift_i : unsigned(SHIFT_WIDTH-1 downto 0);

  -- number of pipeline registers in sub-stages, constant signal
  signal PIPESTAGES_i : integer range 0 to 15; 

  -- shift left in units
  function shift_left_unit(
    main  : std_logic_vector; -- main part
    ext   : std_logic_vector; -- extension part to the right of the main part
    shift : natural; -- left shifts in number of units
    constant size : positive := UNIT_SIZE -- unit size in number of bits
  ) return std_logic_vector is
    constant UM : positive := (main'length + size - 1) / size; -- number of main units
    constant UE : positive := (ext'length + size - 1) / size; -- number of extension units
    -- locally use ufixed instead of slv type because range allows integer and not only natural
    variable padded  : ufixed(UM*size-1 downto -2*UE*size) := (others=>'-');
    variable shifted : ufixed(UM*size-1 downto   -UE*size);
    variable s : natural range 0 to UE;
  begin
    padded(main'length-1 downto -ext'length) := to_ufixed(main & ext, main'length-1, -ext'length);
    s := shift; -- check range
    for u in UM-1 downto -UE loop
      shifted((u+1)*size-1 downto u*size) := padded((u-s+1)*size-1 downto (u-s)*size);
    end loop;
    return to_slv(shifted(main'length-1 downto -ext'length));
  end function;

  -- shift right in units
  function shift_right_unit(
    main  : std_logic_vector; -- main part
    ext   : std_logic_vector; -- extension part to the left of the main part
    shift : natural; -- right shifts in number of units
    constant size : positive := UNIT_SIZE -- unit size in number of bits
  ) return std_logic_vector is
    constant UM : positive := (main'length + size - 1) / size; -- number of main units
    constant UE : positive := (ext'length + size - 1) / size; -- number of extension units
    -- locally use ufixed instead of slv type because range allows integer and not only natural
    variable padded  : ufixed(2*UE*size-1 downto -UM*size) := (others=>'-');
    variable shifted : ufixed(  UE*size-1 downto -UM*size);
    variable s : natural range 0 to UE;
  begin
    padded(ext'length-1 downto -main'length) := to_ufixed(ext & main, ext'length-1, -main'length);
    s := shift; -- check range
    for u in -UM to UE-1 loop
      shifted((u+1)*size-1 downto u*size) := padded((u+s+1)*size-1 downto (u+s)*size);
    end loop;
    return to_slv(shifted(ext'length-1 downto -main'length));
  end function;

begin

  -- input/pipeline register
  ireg : if INPUT_REG generate
    process(clk)
    begin
      if rising_edge(clk) then
        if rst='1' then
          din_vld_i <= '0';
          din_i <= (others=>'-');
          din_ext_i <= (others=>'-');
          shift_i <= (others=>'0');
        elsif ce='1' then
          din_vld_i <= din_vld;
          din_i <= din;
          din_ext_i <= din_ext;
          shift_i <= resize(shift, shift_i'length);
        end if;
      end if;
    end process;
  else generate
    din_vld_i <= din_vld;
    din_i <= din;
    din_ext_i <= din_ext;
    shift_i <= resize(shift, shift_i'length);
  end generate;

  -- maximum shift value is limited by number of barrels in input DIN_EXT
  shift_error <= (shift > MAX_SHIFT);
  
  -- one logic level of shifting
  p_shift : process(din_i, din_ext_i, shift_i)
    -- shifts in number of units within single logic level
    variable s : integer range 0 to din_ext_i'length / UNIT_SIZE;
    -- the shifter result is a concatenation of the main and extension part, order depends on shift direction
    variable shifted : std_logic_vector(din_i'length+din_ext_i'length-1 downto 0);
  begin
    s := to_integer(shift_right(shift_i, BARRELS_PER_UNIT_LOG2));
    if RIGHT_SHIFT then
      shifted := shift_right_unit(din_i, din_ext_i, s);
      -- extension of shifted output is right-aligned
      dout_slv     <= shifted(shifted'right + dout_slv'length - 1 downto shifted'right);
      dout_ext_slv <= shifted(shifted'left downto shifted'left - dout_ext_slv'length + 1);
    else
      shifted := shift_left_unit(din_i, din_ext_i, s);
      -- extension of shifted output is left-aligned
      dout_slv     <= shifted(shifted'left downto shifted'left - dout_slv'length + 1);
      dout_ext_slv <= shifted(shifted'right + dout_ext_slv'length - 1 downto shifted'right);
    end if;
  end process;

  substage : if LOGIC_LEVELS >= 2 generate
    -- Another recursive shifter sub-stage is requrired. Reduce input extension vector and shift value.

    -- Only keep extension bits that are still relevant.
    constant EXT_BITS_REMAINING : positive := UNIT_SIZE - BARREL_SIZE;
    -- remaining extension bits
    signal extension : std_logic_vector(EXT_BITS_REMAINING-1 downto 0);
  begin
    -- select remaining extension bits according to alignment
    extension <= dout_ext_slv(dout_ext_slv'right + EXT_BITS_REMAINING - 1 downto dout_ext_slv'right) when RIGHT_SHIFT else
                 dout_ext_slv(dout_ext_slv'left downto dout_ext_slv'left - EXT_BITS_REMAINING + 1);

    shifter : entity work.barrelshifter_v2
    generic map(
      BARREL_SIZE                 => BARREL_SIZE,
      SHIFTS_PER_LOGIC_LEVEL_LOG2 => SHIFTS_PER_LOGIC_LEVEL_LOG2,
      MAX_LOGIC_LEVELS            => MAX_LOGIC_LEVELS,
      INPUT_REG                   => (((LOGIC_LEVELS-1) mod MAX_LOGIC_LEVELS) = 0),
      RIGHT_SHIFT                 => RIGHT_SHIFT
    )
    port map(
      clk         => clk,
      rst         => rst,
      ce          => ce,
      shift       => shift_i(BARRELS_PER_UNIT_LOG2-1 downto 0), -- remaining shifts
      din         => dout_slv,
      din_ext     => extension,
      din_vld     => din_vld_i,
      dout        => dout,
      dout_vld    => dout_vld,
      shift_error => open, -- by design, error is not possible in recursive sub-stages
      PIPESTAGES  => PIPESTAGES_i
    );
  end generate;

  oreg : if LOGIC_LEVELS = 1 generate
    -- The recursive loop ends here. After the last shifter stage always place a final output register.
    process(clk)
    begin
      if rising_edge(clk) then
        if rst='1' then
          dout_vld <= '0';
          dout <= (others=>'-');
        elsif ce='1' then
          dout_vld <= din_vld_i;
          dout <= dout_slv;
        end if;
      end if;
    end process;
    PIPESTAGES_i <= 1;
  end generate;

  PIPESTAGES <= PIPESTAGES_i + 1 when INPUT_REG else PIPESTAGES_i;

end architecture;
