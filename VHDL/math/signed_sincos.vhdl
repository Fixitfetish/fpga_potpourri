-------------------------------------------------------------------------------
--! @file       signed_sincos.vhdl
--! @author     Fixitfetish
--! @date       23/Apr/2017
--! @version    0.10
--! @copyright  MIT License
--! @note       VHDL-1993
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
 use ieee.math_real.all;
library fixitfetish;
 use fixitfetish.ieee_extension.all;


entity signed_sincos is
generic (
  --! @brief Major phase resolution in bits (MSBs of the phase input).
  --! This resolution influences the depth of generated look-up table ROM.
  PHASE_MAJOR_WIDTH : positive := 11;
  --! @brief Minor phase resolution in bits (LSBs of the phase input).
  --! This resolution defines granularity of the linear interpolation.
  PHASE_MINOR_WIDTH : natural := 0;
  --! @brief Output resolution in bits. 
  --! This resolution influences the width of the generated look-up table ROM.
  OUTPUT_WIDTH : positive := 18
);
port (
  --! Standard system clock
  clk        : in  std_logic;
  --! Reset result output (optional)
  rst        : in  std_logic := '0';
  --! clock enable (optional)
  clkena     : in  std_logic := '1';
  --! Valid signal for input, high-active
  phase_vld  : in  std_logic;
  --! Phase, either unsigned (range 0 to 2**N-1) or signed (range -(2**(N-1)) to 2**(N-1)-1)
  phase      : in  std_logic_vector(PHASE_MAJOR_WIDTH+PHASE_MINOR_WIDTH-1 downto 0);
  --! Valid signal for output, high-active
  dout_vld   : out std_logic;
  --! Cosine output
  dout_cos   : out signed(OUTPUT_WIDTH-1 downto 0);
  --! Sine output
  dout_sin   : out signed(OUTPUT_WIDTH-1 downto 0);
  --! Number of pipeline stages, constant, depends on configuration
  PIPESTAGES : out natural
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of signed_sincos is

  -- identifier for reports of warnings and errors
--  constant IMPLEMENTATION : string := signed_sincos'INSTANCE_NAME;

  -- The look-up table (LUT) holds the cosine and sine values of the 1st quadrant.
  -- Since these values are all positive the LUT doesn't include the sign bit.
  -- Note the value 1.0 is mapped to highest possible unsigned number (others=>'1')
  -- and therefore is not exactly 1. This inaccuracy is needed to keep the symmetry
  -- of positive and negative integer values and to save an additional bit in the
  -- LUT and at the output.
  constant SINCOS_WIDTH : positive := (OUTPUT_WIDTH-1); -- without sign bit
  constant SINCOS_MAX : real := real(2**SINCOS_WIDTH) - 0.6; -- ensure that max value is 0.9999..
  constant LUT_WIDTH : positive := 2*SINCOS_WIDTH; -- cos and sin combined in single LUT
  constant LUT_DEPTH_LD : positive := PHASE_MAJOR_WIDTH-2; -- only first of the four quadrants
  constant LUT_DEPTH : positive := 2**LUT_DEPTH_LD; -- only first of the four quadrants
  type t_lut is array(0 to LUT_DEPTH-1) of std_logic_vector(LUT_WIDTH-1 downto 0);
  
  function init_lut return t_lut is
    variable lut : t_lut;
    variable x : real;
    variable cosx, sinx : unsigned(SINCOS_WIDTH-1 downto 0);
  begin
    for i in 0 to LUT_DEPTH-1 loop
      x := real(i) * MATH_PI_OVER_2 / real(LUT_DEPTH);
      cosx := to_unsigned(integer(SINCOS_MAX*cos(x)),SINCOS_WIDTH);
      sinx := to_unsigned(integer(SINCOS_MAX*sin(x)),SINCOS_WIDTH);
      lut(i)(LUT_WIDTH/2-1 downto 0) := std_logic_vector(cosx); 
      lut(i)(LUT_WIDTH-1 downto LUT_WIDTH/2) := std_logic_vector(sinx); 
    end loop;
    return lut;
  end;

  -- Look-up table ROM
  constant LUT : t_lut := init_lut;
  signal lut_in_quad, lut_in_quad_q : unsigned(1 downto 0);
  signal lut_in_addr ,lut_in_addr_q : unsigned(PHASE_MAJOR_WIDTH-3 downto 0);
  signal lut_in_frac, lut_in_frac_q : unsigned(PHASE_MINOR_WIDTH downto 0);
  signal lut_in_vld, lut_in_vld_q : std_logic := '0';

  signal lut_out_quad : unsigned(1 downto 0) := (others=>'0');
  signal lut_out_data : std_logic_vector(LUT_WIDTH-1 downto 0) := (others=>'0');
  signal lut_out_frac : unsigned(PHASE_MINOR_WIDTH downto 0) := (others=>'0');
  signal lut_out_vld : std_logic := '0';

  -- major cos and sin values from LUT
  signal cos_p, sin_p : signed(OUTPUT_WIDTH-1 downto 0) := (others=>'0');
  signal cos_major, sin_major : signed(OUTPUT_WIDTH-1 downto 0) := (others=>'0');
  signal vld_major : std_logic := '0';

  type array_output is array(integer range <>) of signed(OUTPUT_WIDTH-1 downto 0);
  type array_frac is array(integer range <>) of unsigned(PHASE_MINOR_WIDTH downto 0);
  signal cos_interpol : array_output(0 to PHASE_MINOR_WIDTH);
  signal sin_interpol : array_output(0 to PHASE_MINOR_WIDTH);
  signal vld_interpol : std_logic_vector(0 to PHASE_MINOR_WIDTH);
  signal frac_interpol : array_frac(-1 to PHASE_MINOR_WIDTH);

  constant SLOPE_WIDTH : positive := OUTPUT_WIDTH - LUT_DEPTH_LD + 2;
  type array_slope is array(integer range <>) of signed(SLOPE_WIDTH-1 downto 0);
  signal cos_slope : array_slope(-1 to PHASE_MINOR_WIDTH);
  signal sin_slope : array_slope(-1 to PHASE_MINOR_WIDTH);

begin

  -- derive LUT address from phase input
  lut_in_vld <= phase_vld;
  lut_in_quad <= unsigned(phase(phase'left downto PHASE_MAJOR_WIDTH+PHASE_MINOR_WIDTH-2));
  lut_in_addr <= unsigned(phase(PHASE_MAJOR_WIDTH+PHASE_MINOR_WIDTH-3 downto PHASE_MINOR_WIDTH));
  lut_in_frac <= unsigned(phase(PHASE_MINOR_WIDTH downto 0));

  p_lut: process(clk)
  begin
    if rising_edge(clk) then
      if clkena='1' then
        -- ROM with input and output register
        lut_in_addr_q <= lut_in_addr;
        lut_in_vld_q <= lut_in_vld;
        lut_in_frac_q <= lut_in_frac;
        lut_in_quad_q <= lut_in_quad;
        lut_out_data <= LUT(to_integer(lut_in_addr_q));
        lut_out_quad <= lut_in_quad_q;
        lut_out_frac <= lut_in_frac_q;
        lut_out_vld <= lut_in_vld_q;
      end if;
    end if;
  end process;

  -- add sign bit and convert to signed
  cos_p <= signed(resize(unsigned(lut_out_data(LUT_WIDTH/2-1 downto 0)),OUTPUT_WIDTH));
  sin_p <= signed(resize(unsigned(lut_out_data(LUT_WIDTH-1 downto LUT_WIDTH/2)),OUTPUT_WIDTH));

  -- quadrant adjustment (before interpolation)
  p_major: process(clk)
    variable v_cos_p, v_sin_p : signed(OUTPUT_WIDTH-1 downto 0);
    variable v_cos_n, v_sin_n : signed(OUTPUT_WIDTH-1 downto 0);
  begin
    if rising_edge(clk) then
      v_cos_p := cos_p;
      v_sin_p := sin_p;
      v_cos_n := -cos_p;
      v_sin_n := -sin_p;
      if rst='1' then
        vld_major <= '0';
        cos_major <= (others=>'-');
        sin_major <= (others=>'-');
      elsif clkena='1' then
        vld_major <= lut_out_vld;
        if lut_out_quad=0 then -- 1st quadrant
          cos_major <= v_cos_p;
          sin_major <= v_sin_p;
        elsif lut_out_quad=1 then -- 2nd quadrant
          cos_major <= v_sin_n;
          sin_major <= v_cos_p;
        elsif lut_out_quad=2 then -- 3rd quadrant
          cos_major <= v_cos_n;
          sin_major <= v_sin_n;
        else -- 4th quadrant
          cos_major <= v_sin_p;
          sin_major <= v_cos_n;
        end if;
      end if;
    end if;
  end process;

  g_interpol_off : if PHASE_MINOR_WIDTH=0 generate
  begin
    PIPESTAGES <= 3;
    vld_interpol(0) <= vld_major;
    cos_interpol(0) <= cos_major;
    sin_interpol(0) <= sin_major;
    cos_slope <= (others=>(others=>'0')); -- irrelevant
    sin_slope <= (others=>(others=>'0')); -- irrelevant
    frac_interpol <= (others=>(others=>'0')); -- irrelevant
  end generate;

  -- NOTE: For interpolation the slope of the cos and sin is required.
  -- The derivatives of cos and sin are as follows:
  --   lut_cos' = -lut_sin / LUT_DEPTH * (pi/2)
  --   lut_sin' =  lut_cos / LUT_DEPTH * (pi/2)
  -- where pi/2 is roughly 25/16 = "11001".

  g_interpol_on : if PHASE_MINOR_WIDTH>=1 generate
  begin
   PIPESTAGES <= 4 + PHASE_MINOR_WIDTH;
   p_minor: process(clk)
    variable v_cos_p, v_sin_p : signed(SLOPE_WIDTH-1 downto 0);
    variable v_cos_n, v_sin_n : signed(SLOPE_WIDTH-1 downto 0);
    variable v_cos_slope, v_sin_slope : signed(SLOPE_WIDTH-1 downto 0);
   begin
    if rising_edge(clk) then

      -- positive base slope with additional bit for accuracy (without factor pi/2)
      v_cos_p := resize(shift_right_round(cos_p,LUT_DEPTH_LD-1,nearest),SLOPE_WIDTH);
      v_sin_p := resize(shift_right_round(sin_p,LUT_DEPTH_LD-1,nearest),SLOPE_WIDTH);
      -- negative base slope (without factor pi/2)
      v_cos_n := -v_cos_p;
      v_sin_n := -v_sin_p;

      if rst='1' then
        cos_interpol <= (others=>(others=>'-'));
        sin_interpol <= (others=>(others=>'-'));
        cos_slope <= (others=>(others=>'-'));
        sin_slope <= (others=>(others=>'-'));
        frac_interpol <= (others=>(others=>'0'));
        vld_interpol <= (others=>'0');

      elsif clkena='1' then

        -- derivative and quadrant adjustment
        if lut_out_quad=0 then -- 1st quadrant
          cos_slope(-1) <= v_sin_n;
          sin_slope(-1) <= v_cos_p;
        elsif lut_out_quad=1 then -- 2nd quadrant
          cos_slope(-1) <= v_cos_n;
          sin_slope(-1) <= v_sin_n;
        elsif lut_out_quad=2 then -- 3rd quadrant
          cos_slope(-1) <= v_sin_p;
          sin_slope(-1) <= v_cos_n;
        else -- 4th quadrant
          cos_slope(-1) <= v_cos_p;
          sin_slope(-1) <= v_sin_p;
        end if;
        frac_interpol(-1) <= lut_out_frac;
        
        -- pipeline register, multiply with pi/2 ~ 25/16 = "11001"
        v_cos_slope := cos_slope(-1) + shift_right(cos_slope(-1),1) + shift_right(cos_slope(-1),4);
        v_sin_slope := sin_slope(-1) + shift_right(sin_slope(-1),1) + shift_right(sin_slope(-1),4);
        cos_slope(0) <= shift_right_round(v_cos_slope,2,truncate);
        sin_slope(0) <= shift_right_round(v_sin_slope,2,truncate);
        frac_interpol(0) <= frac_interpol(-1);
        cos_interpol(0) <= cos_major;
        sin_interpol(0) <= sin_major;
        vld_interpol(0) <= vld_major;

        for n in 1 to PHASE_MINOR_WIDTH loop
          vld_interpol(n) <= vld_interpol(n-1);
          if frac_interpol(n-1)(PHASE_MINOR_WIDTH-n)='0' then
            cos_interpol(n) <= cos_interpol(n-1);
            sin_interpol(n) <= sin_interpol(n-1);
          else
            cos_interpol(n) <= cos_interpol(n-1) + cos_slope(n-1);
            sin_interpol(n) <= sin_interpol(n-1) + sin_slope(n-1);
          end if;
          frac_interpol(n) <= frac_interpol(n-1);
          cos_slope(n) <= shift_right_round(cos_slope(n-1),1,truncate);
          sin_slope(n) <= shift_right_round(sin_slope(n-1),1,truncate);
        end loop;

      end if;
    end if; -- clock
   end process;
  end generate;

  dout_cos <= cos_interpol(PHASE_MINOR_WIDTH);
  dout_sin <= sin_interpol(PHASE_MINOR_WIDTH);
  dout_vld <= vld_interpol(PHASE_MINOR_WIDTH);

end architecture;
