---------------------------------------------------------------------------------------------------
--! @file       barrelshifter.vhdl
--! @author     Fixitfetish
--! @note       VHDL-2008
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
---------------------------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

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
entity barrelshifter is
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
  PIPESTAGES  : out integer range 0 to 63
);
begin
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  -- synthesis translate_off (Altera Quartus)
  assert (din'length mod BARREL_SIZE)=0 and (din_ext'length mod BARREL_SIZE)=0
    report barrelshifter'INSTANCE_NAME & " Length of both input vectors must be a multiple of the shifter barrel size."
    severity failure;
  assert (din'length >= din_ext'length)
    report barrelshifter'INSTANCE_NAME & " Input extension vector cannot be larger than the input vector."
    severity failure;
  assert (2**shift'length > din_ext'length/BARREL_SIZE)
    report barrelshifter'INSTANCE_NAME & " SHIFT input range 0 to " & integer'image(2**shift'length-1) & 
           " is too small for provided input extension vector length of " & 
           integer'image(din_ext'length/BARREL_SIZE) & " barrels."
    severity warning;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)
end entity;

architecture rtl of barrelshifter is

  -- Number of barrels in input vector
  constant BARRELS_IN : positive := din'length / BARREL_SIZE;

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

  -- Number of barrels per unit, depends on the current shifter shifter
  constant BARRELS_PER_UNIT_LOG2 : natural := maximum(0, SHIFT_WIDTH-SHIFTS_PER_LOGIC_LEVEL_LOG2);
  constant BARRELS_PER_UNIT : positive := 2**BARRELS_PER_UNIT_LOG2;

  -- Number of input units, rounded up, ceil(BARRELS_IN/BARRELS_PER_UNIT)
  constant UNITS_IN : positive := (BARRELS_IN + BARRELS_PER_UNIT - 1) / BARRELS_PER_UNIT;

  -- Number of extension input units, rounded up so that the last unit is always incomplete
  constant UNITS_EXT : positive := (BARRELS_EXT + BARRELS_PER_UNIT) / BARRELS_PER_UNIT;

  type t_barrel is array(integer range <>) of std_logic_vector(BARREL_SIZE-1 downto 0);
  type t_unit is array(integer range <>) of t_barrel(BARRELS_PER_UNIT-1 downto 0);

  signal din_barrel_vld : std_logic;
  signal din_barrel : t_barrel(BARRELS_IN - 1 downto 0) := (others=>(others=>'0'));
  signal din_barrel_ext : t_barrel(BARRELS_EXT - 1 downto 0);

  -- output barrels after shifter stage without any extension barrels
  signal dout_barrel : t_barrel(BARRELS_IN - 1 downto 0);

  -- after shifting keep only barrels of first extended unit
  signal dout_barrel_ext : t_barrel(BARRELS_PER_UNIT - 1 downto 0);

  -- zero padded input and extension units before shifter stage
  signal din_unit : t_unit(UNITS_IN + UNITS_EXT - 1 downto 0);

  -- convert SLV into vector of barrels
  function slv2barrel(slv:std_logic_vector) return t_barrel is
    alias v : std_logic_vector(slv'length-1 downto 0) is slv; -- default range
    variable r : t_barrel(v'length/BARREL_SIZE-1 downto 0);
  begin
    for b in r'range loop
      r(b) := v((b+1)*BARREL_SIZE-1 downto b*BARREL_SIZE);
    end loop;
    return r;
  end function;

  -- convert barrels into zero-padded vector of units
  function barrel2unit(b:t_barrel; b_ext:t_barrel) return t_unit is
    variable t : t_barrel(UNITS_IN*BARRELS_PER_UNIT-1 downto -UNITS_IN*BARRELS_PER_UNIT) := (others=>(others=>'-'));
    variable r : t_unit(UNITS_IN-1 downto -UNITS_IN);
  begin
    -- concatenate barrels
    if RIGHT_SHIFT then
      -- right-shift, extend to the left
      t(b_ext'length-1 downto 0) := b_ext;
      t(-1 downto -b'length) := b;
    else
      -- left-shift, extend to the right
      t(b'length-1 downto 0) := b;
      t(-1 downto -b_ext'length) := b_ext;
    end if;
    -- map barrels into units
    for u in UNITS_IN-1 downto -UNITS_IN loop
      r(u) := t((u+1)*BARRELS_PER_UNIT-1 downto u*BARRELS_PER_UNIT);
    end loop;
    -- cut out relevant units
    if RIGHT_SHIFT then
      return r(UNITS_EXT-1 downto -UNITS_IN);
    else
      return r(UNITS_IN-1  downto -UNITS_EXT);
    end if;
  end function;

  -- convert units into vector of barrels
  function unit2barrel(u:t_unit) return t_barrel is
    alias xu : t_unit(u'length-1 downto 0) is u; -- default range
    variable r : t_barrel(xu'length*BARRELS_PER_UNIT-1 downto 0);
  begin
    for b in r'range loop
      r(b) := xu(b/BARRELS_PER_UNIT)(b mod BARRELS_PER_UNIT);
    end loop;
    return r;
  end function;

  -- convert barrels into SLV
  function barrel2slv(b:t_barrel) return std_logic_vector is
    alias xb : t_barrel(b'length-1 downto 0) is b; -- default range
    variable slv : std_logic_vector(BARREL_SIZE*b'length-1 downto 0);
  begin
    for i in xb'range loop
      slv((i+1)*BARREL_SIZE-1 downto i*BARREL_SIZE) := xb(i);
    end loop;
    return slv;
  end function;

  -- number of overall remaining shifts
  signal shift_i : unsigned(SHIFT_WIDTH-1 downto 0);

  -- number of pipeline registers in sub-stages, constant signal
  signal PIPESTAGES_i : integer range 0 to 63; 

begin

  -- input/pipeline register + conversion into barrels
  ireg : if INPUT_REG generate
    process(clk)
    begin
      if rising_edge(clk) then
        if rst='1' then
          din_barrel_vld <= '0';
          din_barrel <= (others=>(others=>'-'));
          din_barrel_ext <= (others=>(others=>'-'));
          shift_i <= (others=>'0');
        elsif ce='1' then
          din_barrel_vld <= din_vld;
          din_barrel <= slv2barrel(din);
          din_barrel_ext <= slv2barrel(din_ext);
          shift_i <= resize(shift, shift_i'length);
        end if;
      end if;
    end process;
  else generate
    din_barrel_vld <= din_vld;
    din_barrel <= slv2barrel(din);
    din_barrel_ext <= slv2barrel(din_ext);
    shift_i <= resize(shift, shift_i'length);
  end generate;

  -- maximum shift value is limited by number of barrels in input DIN_EXT
  shift_error <= (shift > MAX_SHIFT);

  -- concatenate barrels dependent on shift direction and map into units with zero-padding
  din_unit <= barrel2unit(b=>din_barrel, b_ext=>din_barrel_ext);

  -- one logic level of shifting
  p_shift : process(din_unit, shift_i)
    -- number of shifts within single logic level
    variable s : integer range 0 to UNITS_EXT-1 := 0;
    -- Units after shifter stage, only one extension unit required (either left or right)
    variable dout_unit : t_unit(UNITS_IN downto 0);
    -- shifted barrels still including padded barrels
    variable temp_barrel : t_barrel(UNITS_IN*BARRELS_PER_UNIT-1 downto 0);
  begin
    s := to_integer(shift_right(shift_i, BARRELS_PER_UNIT_LOG2));
    if RIGHT_SHIFT then
      -- shift right with for loop to work-around Vivado 2025.1 error: "[Synth 8-561] range expression could not be resolved to a constant"
      for u in dout_unit'range loop
        dout_unit(u) := din_unit(u + s);
      end loop;
      -- get left-aligned main units on right side
      temp_barrel := unit2barrel(dout_unit(dout_unit'left - 1 downto dout_unit'right));
      -- remove all padded barrels at the right end
      dout_barrel <= temp_barrel(temp_barrel'left downto temp_barrel'left - BARRELS_IN + 1);
      -- get right-aligned extension barrels on left side
      dout_barrel_ext <= unit2barrel(dout_unit(dout_unit'left downto dout_unit'left));
    else
      -- shift left with for loop to work-around Vivado 2025.1 error: "[Synth 8-561] range expression could not be resolved to a constant"
      for u in dout_unit'range loop
        dout_unit(u) := din_unit(din_unit'high + u - UNITS_IN - s);
      end loop;
      -- get right-aligned main units on left side
      temp_barrel := unit2barrel(dout_unit(dout_unit'left downto 1 + dout_unit'right));
      -- remove all padded barrels at the left end
      dout_barrel <= temp_barrel(temp_barrel'right + BARRELS_IN - 1 downto temp_barrel'right);
      -- get left-aligned extension barrels on right side
      dout_barrel_ext <= unit2barrel(dout_unit(dout_unit'right downto dout_unit'right));
    end if;
  end process;

  substage : if LOGIC_LEVELS > 1 generate
    -- Another recursive shifter sub-stage is requrired.
    -- Reduce input extension vector and shift value.

    -- Only keep extension barrels that are still relevant.
    signal extension : t_barrel(BARRELS_PER_UNIT-2 downto 0);
    signal extension_slv : std_logic_vector(extension'length*BARREL_SIZE-1 downto 0);
    signal dout_slv : std_logic_vector(dout_barrel'length*BARREL_SIZE-1 downto 0);
  begin
    extension <= dout_barrel_ext(dout_barrel_ext'left - 1 downto dout_barrel_ext'right) when RIGHT_SHIFT else
                 dout_barrel_ext(dout_barrel_ext'left downto 1 + dout_barrel_ext'right);

    -- use intermediate SLV signals as work-around to avoid Vivado 2025.1 warning at port mapping below: 
    -- "[Synth 8-9112] actual for formal port 'din' is neither a static name nor a globally static expression"
    extension_slv <= barrel2slv(extension);
    dout_slv <= barrel2slv(dout_barrel);
    
    shifter : entity work.barrelshifter
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
      din_ext     => extension_slv,
      din_vld     => din_barrel_vld,
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
          dout_vld <= din_barrel_vld;
          dout <= barrel2slv(dout_barrel);
        end if;
      end if;
    end process;
    PIPESTAGES_i <= 1;
  end generate;

  PIPESTAGES <= PIPESTAGES_i + 1 when INPUT_REG else PIPESTAGES_i;

end architecture;
