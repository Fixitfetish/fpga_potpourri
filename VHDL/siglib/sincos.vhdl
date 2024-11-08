-------------------------------------------------------------------------------
--! @file       sincos.vhdl
--! @author     Fixitfetish
--! @date       07/Nov/2024
--! @version    0.61
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Code comments are optimized for SIGASI and DOXYGEN.
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
 use ieee.math_real.all;
library baselib;
 use baselib.ieee_extension.all;

--! @brief Configurable look-up based phase to sine and cosine generator.
--! Additional interpolation/approximation is supported as well.
--! 
--! The phase input can be either signed or unsigned
--! * SIGNED with range -N/2 to N/2-1, i.e. interval [-pi, pi)
--! * UNSIGNED with range 0 to N-1, i.e. interval [0, 2*pi)
--!
--! The phase input is specified by two separate values
--! * PHASE_WIDTH = PHASE_MAJOR_WIDTH + PHASE_MINOR_WIDTH
--! * PHASE_MAJOR_WIDTH (MSBs, coarse) , the major phase step size is 2*pi/(2**PHASE_MAJOR_WIDTH)
--! * PHASE_MINOR_WIDTH (LSBs, fine) , the minor phase step size is 2*pi/(2**PHASE_WIDTH)
--!
--! If **PHASE_MINOR_WIDTH=0** then the sine and cosine values are precalculated
--! for all phases and stored in a look-up table ROM (LUT). The required ROM
--! becomes larger when PHASE_MAJOR_WIDTH increases. In this case an additional
--! interpolation/approximation is not needed.
--! The look-up table (LUT) only holds the 2**(PHASE_MAJOR_WIDTH-2) cosine and sine
--! values of the 1st quadrant. Since LUT values are all positive the LUT
--! doesn't include the sign bit.
--! Note that the value 1.0 is mapped to highest possible unsigned number (others=>'1')
--! and therefore is not exactly 1. This inaccuracy is needed to keep the symmetry
--! of positive and negative integer values and to save an additional bit in the
--! LUT and at the output. The LUT will have the following size in bits:
--!   2**(PHASE_MAJOR_WIDTH-2) * 2(OUTPUT_WIDTH-1). With e.g. PHASE_MAJOR_WIDTH=11
--! and OUTUT_WIDTH=18 typically only a single 18k or 20k Block-RAM is required.
--! Note that the LUT-ROM always uses the address input and the data output register
--! to attain higher frequencies. Therefore just the LUT has two cycles latency.
--! Furthermore, with FRACTIONAL_SCALING the values in the LUT-ROM can be down-scaled
--! if e.g. a static amplitude (or power) adjustment is required.
--!
--! Interpolation/approximation is enabled when **PHASE_MINOR_WIDTH>0**.
--! This implementation uses the initial terms of the Taylor series with the
--! derivatives of cos and sin which can be easily determined from the LUT values.
--! * lut_cos' = -lut_sin / ROM_DEPTH * (pi/2)
--! * lut_sin' =  lut_cos / ROM_DEPTH * (pi/2)
--!
--! where pi/2 is roughly 201/128 = "11001001" (or 25/16 = "11001").
--! To improve the accuracy the interpolation/approximation is performed
--! based on the major phase +0.5, and then either
--! forward or backward dependent on the value of the minor phase.
--! * Backward : when minor phase is within interval [0, 0.5)
--! * Forward  : when minor phase is within interval [0.5, 1.0)
--!
--! Note that PHASE_WIDTH <= OUTPUT_WIDTH+2 should apply because otherwise the
--! required phase resolution at the input exceeds the feasible accuracy at the output.
--!
--! The overall number of pipeline stages is reported at the constant output
--! port PIPESTAGES. The pipeline stages are calculated as follows:
--! * PHASE_MINOR_WIDTH=0   =>  PIPESTAGES = 3
--! * PHASE_MINOR_WIDTH>=1
--!   - OPTIMIZATION/="TIMING" => PIPESTAGES = 4 + ceil(PHASE_MINOR_WIDTH/2)
--!   - OPTIMIZATION="TIMING"  => PIPESTAGES = 4 + PHASE_MINOR_WIDTH
--!
entity sincos is
generic (
  --! @brief Major phase resolution in bits (MSBs of the phase input).
  --! This resolution influences the depth of generated look-up table ROM.
  PHASE_MAJOR_WIDTH : positive := 11;
  --! @brief Minor phase resolution in bits (LSBs of the phase input).
  --! This resolution defines the granularity of the interpolation/approximation.
  PHASE_MINOR_WIDTH : natural := 0;
  --! @brief Output resolution in bits.
  --! This resolution influences the width of the generated look-up table ROM.
  OUTPUT_WIDTH : positive := 18;
  --! @brief Static fractional down-scaling influences the values in the LUT-ROM.
  --! For values below 0.5 consider reduction of OUTPUT_WIDTH with potential FPGA resource savings.
  FRACTIONAL_SCALING : std.standard.real range 0.0 to 1.0 := 1.0;
  --! Valid values for the optimization are "" or "TIMING"
  OPTIMIZATION : string := ""
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
  PIPESTAGES : out natural := 1
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of sincos is

  -- additional fractional bit in ROM to increase rounding accuracy
  function ROM_FRAC_BITS return natural is
  begin
    if PHASE_MINOR_WIDTH=0 then 
      return 0;
    elsif OUTPUT_WIDTH=19 or OUTPUT_WIDTH=37 then
      return 0; -- avoid additional Block-RAM
    else
      return 1;
    end if;
  end function;

  -- ROM cos/sin data width (without sign bit plus additional fractional bits)
  constant SINCOS_WIDTH : positive := OUTPUT_WIDTH - 1 + ROM_FRAC_BITS;

  function max_amplitude return real is
    variable r : real;
    constant rmax : real := real(2**SINCOS_WIDTH) - real(2**ROM_FRAC_BITS);
  begin
    r := round(FRACTIONAL_SCALING*real(2**(SINCOS_WIDTH)));
    if r>(rmax) then
      r := rmax;
    end if;
    return r;
  end;
  constant SINCOS_MAX : real := max_amplitude;

  constant ROM_COARSE_WIDTH : positive := 2*SINCOS_WIDTH; -- cosine and sin combined in single LUT
  constant ROM_COARSE_DEPTH_LD : positive := PHASE_MAJOR_WIDTH-2; -- only first of the four quadrants
  constant ROM_COARSE_DEPTH : positive := 2**ROM_COARSE_DEPTH_LD; -- only first of the four quadrants
  type t_lut_coarse is array(ROM_COARSE_DEPTH-1 downto 0) of std_logic_vector(ROM_COARSE_WIDTH-1 downto 0);

  -- The constant look-up table (LUT) holds the cosine and sine values of the
  -- 1st quadrant only. All values are positive, hence sign bit can be removed.
  function init_lut_coarse return t_lut_coarse is
    variable lut : t_lut_coarse;
    variable x : real;
    variable cosx, sinx : unsigned(SINCOS_WIDTH-1 downto 0);
  begin
    for i in 0 to ROM_COARSE_DEPTH-1 loop
      if PHASE_MINOR_WIDTH=0 then
        x := (real(i)) * MATH_PI_OVER_2 / real(ROM_COARSE_DEPTH);
      else
        x := (real(i)+0.5) * MATH_PI_OVER_2 / real(ROM_COARSE_DEPTH);
      end if;
      cosx := to_unsigned(integer(SINCOS_MAX*cos(x)),SINCOS_WIDTH);
      sinx := to_unsigned(integer(SINCOS_MAX*sin(x)),SINCOS_WIDTH);
      lut(i)(ROM_COARSE_WIDTH/2-1 downto 0) := std_logic_vector(cosx);
      lut(i)(ROM_COARSE_WIDTH-1 downto ROM_COARSE_WIDTH/2) := std_logic_vector(sinx);
    end loop;
    return lut;
  end;

  -- Look-up table for coarse ROM
  constant ROM_COARSE : t_lut_coarse := init_lut_coarse;
--  attribute rom_style : string;
--  attribute rom_style of LUT : constant is "block";

  type r_rom_in is
  record
    vld  : std_logic; -- valid
    quad : unsigned(1 downto 0); -- quadrant, 0=1st, 3=4th
    addr : unsigned(PHASE_MAJOR_WIDTH-3 downto 0); -- coarse phase
    frac : unsigned(PHASE_MINOR_WIDTH-1 downto 0); -- fractional phase
  end record;
  signal rom_in, rom_in_q : r_rom_in;

  -- additional fractional bits to increase accuracy, must be at least ROM_FRAC_BITS
  constant OUTPUT_LSB_EXT : natural := maximum(maximum(PHASE_MINOR_WIDTH-4,4),ROM_FRAC_BITS);

  -- bit width of slope integer part
  constant SLOPE_INT_WIDTH : positive := OUTPUT_WIDTH - ROM_COARSE_DEPTH_LD;

  -- bit width of slope fractional part
  constant SLOPE_FRAC_WIDTH : positive := OUTPUT_LSB_EXT;

  -- overall slope bit width
  constant SLOPE_WIDTH : positive := SLOPE_INT_WIDTH + SLOPE_FRAC_WIDTH;

  type r_rom_coarse_out is
  record
    vld  : std_logic; -- valid
    quad : unsigned(1 downto 0); -- quadrant
    frac : unsigned(PHASE_MINOR_WIDTH-1 downto 0); -- fractional phase
    data : std_logic_vector(ROM_COARSE_WIDTH-1 downto 0); -- value from LUT-ROM
    major_cos : signed(SINCOS_WIDTH downto 0); -- major cosine value from LUT-ROM
    major_sin : signed(SINCOS_WIDTH downto 0); -- major sine value from LUT-ROM
    deriv_cos : signed(SLOPE_WIDTH-1 downto 0); -- derivative of cosine
    deriv_sin : signed(SLOPE_WIDTH-1 downto 0); -- derivative of sine
  end record;
  signal rom_coarse_out : r_rom_coarse_out;

begin

  -- derive ROM address from phase input
  rom_in.vld <= phase_vld;
  rom_in.quad <= unsigned(phase(phase'left downto phase'left-1));
  rom_in.addr <= unsigned(phase(phase'left-2 downto PHASE_MINOR_WIDTH));

  g_frac_on : if PHASE_MINOR_WIDTH>=1 generate
  begin
    rom_in.frac <= unsigned(phase(PHASE_MINOR_WIDTH-1 downto 0)) - 2**(PHASE_MINOR_WIDTH-1);
  end generate;

  p_rom_coarse: process(clk)
  begin
    if rising_edge(clk) then
      if clkena='1' then
        -- ROM_COARSE with input and output register
        rom_in_q <= rom_in;
        rom_coarse_out.data <= ROM_COARSE(to_integer(rom_in_q.addr));
        rom_coarse_out.quad <= rom_in_q.quad;
        rom_coarse_out.frac <= rom_in_q.frac;
        rom_coarse_out.vld  <= rom_in_q.vld;
      end if;
    end if;
  end process;

  p_rom_coarse_out: process(rom_coarse_out.data, rom_coarse_out.quad)
    variable cos_p, cos_n, sin_p, sin_n : signed(SINCOS_WIDTH downto 0);
    variable cos_p_rnd, cos_n_rnd, sin_p_rnd, sin_n_rnd : signed(SLOPE_WIDTH-1 downto 0);
  begin
    -- add sign bit and convert to signed (i.e. add MSB '0')
    cos_p := signed(resize(unsigned(rom_coarse_out.data(ROM_COARSE_WIDTH/2-1 downto 0)),SINCOS_WIDTH+1));
    sin_p := signed(resize(unsigned(rom_coarse_out.data(ROM_COARSE_WIDTH-1 downto ROM_COARSE_WIDTH/2)),SINCOS_WIDTH+1));
    -- negative cosine and sine values
    cos_n := -cos_p;
    sin_n := -sin_p;
    -- shift and round
    cos_p_rnd := resize(shift_right_round(cos_p,ROM_COARSE_DEPTH_LD-SLOPE_FRAC_WIDTH+ROM_FRAC_BITS+1,nearest),SLOPE_WIDTH);
    cos_n_rnd := resize(shift_right_round(cos_n,ROM_COARSE_DEPTH_LD-SLOPE_FRAC_WIDTH+ROM_FRAC_BITS+1,nearest),SLOPE_WIDTH);
    sin_p_rnd := resize(shift_right_round(sin_p,ROM_COARSE_DEPTH_LD-SLOPE_FRAC_WIDTH+ROM_FRAC_BITS+1,nearest),SLOPE_WIDTH);
    sin_n_rnd := resize(shift_right_round(sin_n,ROM_COARSE_DEPTH_LD-SLOPE_FRAC_WIDTH+ROM_FRAC_BITS+1,nearest),SLOPE_WIDTH);

    -- major : final coarse cosine and sine values
    -- deriv : temporary derivative for interpolation
    if rom_coarse_out.quad=0 then    -- 1st quadrant
      rom_coarse_out.major_cos <= cos_p;
      rom_coarse_out.major_sin <= sin_p;
      rom_coarse_out.deriv_cos <= sin_n_rnd;
      rom_coarse_out.deriv_sin <= cos_p_rnd;
    elsif rom_coarse_out.quad=1 then -- 2nd quadrant
      rom_coarse_out.major_cos <= sin_n;
      rom_coarse_out.major_sin <= cos_p;
      rom_coarse_out.deriv_cos <= cos_n_rnd;
      rom_coarse_out.deriv_sin <= sin_n_rnd;
    elsif rom_coarse_out.quad=2 then -- 3rd quadrant
      rom_coarse_out.major_cos <= cos_n;
      rom_coarse_out.major_sin <= sin_n;
      rom_coarse_out.deriv_cos <= sin_p_rnd;
      rom_coarse_out.deriv_sin <= cos_n_rnd;
    else -- 4th quadrant
      rom_coarse_out.major_cos <= sin_p;
      rom_coarse_out.major_sin <= cos_n;
      rom_coarse_out.deriv_cos <= cos_p_rnd;
      rom_coarse_out.deriv_sin <= sin_p_rnd;
    end if;
  end process;

  -- NOTE:
  -- Interpolation/Approximation is only enabled when PHASE_MINOR_WIDTH>0
  g_interpolation_on : if PHASE_MINOR_WIDTH>=1 generate
    type r_interpol is
    record
      vld  : std_logic; -- valid
      cos  : signed(OUTPUT_LSB_EXT+OUTPUT_WIDTH-1 downto 0);
      sin  : signed(OUTPUT_LSB_EXT+OUTPUT_WIDTH-1 downto 0);
      frac : unsigned(PHASE_MINOR_WIDTH-1 downto 0);
      slope_cos : signed(SLOPE_WIDTH-1 downto 0);
      slope_sin : signed(SLOPE_WIDTH-1 downto 0);
    end record;
    constant DEFAULT_INTERPOL : r_interpol := (
      vld  => '0',
      cos  => (others=>'-'),
      sin  => (others=>'-'),
      frac => (others=>'0'),
      slope_cos => (others=>'-'),
      slope_sin => (others=>'-')
    );
    type a_interpol is array(integer range <>) of r_interpol;
    signal interpol_in : a_interpol(1 to PHASE_MINOR_WIDTH);
    signal interpol : a_interpol(0 to PHASE_MINOR_WIDTH);
    signal interpol_pipe : a_interpol(0 to PHASE_MINOR_WIDTH-1);
    signal rom_out_q : r_rom_coarse_out;
  begin
   PIPESTAGES <= (4 + PHASE_MINOR_WIDTH) when OPTIMIZATION="TIMING" else (4 + (PHASE_MINOR_WIDTH+1)/2);
   rom_out_q <= rom_coarse_out when rising_edge(clk);

   g_interpol_in : for n in 1 to PHASE_MINOR_WIDTH generate
     -- The first interpolation result interpol(0) is always registered.
     -- When OPTIMIZATION="TIMING" is enabled then the result of every following interpolation stage is registered.
     -- Otherwise the result of every second following interpolation stage is registered.
     interpol_in(n) <= interpol_pipe(n-1) when ( OPTIMIZATION="TIMING" or n=1 or ((n+PHASE_MINOR_WIDTH) mod 2)=1) else
                       interpol(n-1);
   end generate;

   p_interpol: process(interpol_in, rom_out_q)
    variable v_slope_cos, v_slope_sin : signed(SLOPE_WIDTH-1 downto 0);
   begin
     -- multiply with pi/2 ~ 201/128 = "11001001"
     v_slope_cos := rom_out_q.deriv_cos + shift_right(rom_out_q.deriv_cos,1) + shift_right(rom_out_q.deriv_cos,4) + shift_right(rom_out_q.deriv_cos,7);
     v_slope_sin := rom_out_q.deriv_sin + shift_right(rom_out_q.deriv_sin,1) + shift_right(rom_out_q.deriv_sin,4) + shift_right(rom_out_q.deriv_sin,7);
     if rom_out_q.frac(rom_out_q.frac'left)='0' then
       -- forward interpolation: standard derivative
       interpol(0).slope_cos  <=  v_slope_cos;
       interpol(0).slope_sin  <=  v_slope_sin;
       interpol(0).frac <= rom_out_q.frac;
     else
       -- backward interpolation: negative derivative
       interpol(0).slope_cos  <= -v_slope_cos;
       interpol(0).slope_sin  <= -v_slope_sin;
       interpol(0).frac <= 0 - rom_out_q.frac;
     end if;
     interpol(0).cos  <= shift_left(resize(rom_out_q.major_cos,OUTPUT_LSB_EXT+OUTPUT_WIDTH),OUTPUT_LSB_EXT-ROM_FRAC_BITS);
     interpol(0).sin  <= shift_left(resize(rom_out_q.major_sin,OUTPUT_LSB_EXT+OUTPUT_WIDTH),OUTPUT_LSB_EXT-ROM_FRAC_BITS);
     interpol(0).vld  <= rom_out_q.vld;

     for n in 1 to PHASE_MINOR_WIDTH loop
       if interpol_in(n).frac(PHASE_MINOR_WIDTH-n)='0' then
         interpol(n).cos <= interpol_in(n).cos;
         interpol(n).sin <= interpol_in(n).sin;
       else
         interpol(n).cos <= interpol_in(n).cos + interpol_in(n).slope_cos;
         interpol(n).sin <= interpol_in(n).sin + interpol_in(n).slope_sin;
       end if;
       interpol(n).vld <= interpol_in(n).vld;
       interpol(n).frac <= interpol_in(n).frac;
       interpol(n).slope_cos <= shift_right_round(interpol_in(n).slope_cos,1,floor);
       interpol(n).slope_sin <= shift_right_round(interpol_in(n).slope_sin,1,floor);
     end loop;
   end process;

   p_pipe: process(clk)
   begin
     if rising_edge(clk) then
      if rst='1' then
        interpol_pipe <= (others=>DEFAULT_INTERPOL);
      elsif clkena='1' then
        interpol_pipe(0 to PHASE_MINOR_WIDTH-1) <= interpol(0 to PHASE_MINOR_WIDTH-1);
      end if;
    end if; -- clock
   end process;

   p_dout: process(clk)
   begin
     if rising_edge(clk) then
      if rst='1' then
        dout_vld <= '0';
        dout_cos <= (others=>'-');
        dout_sin <= (others=>'-');
      elsif clkena='1' then
        dout_vld <= interpol(PHASE_MINOR_WIDTH).vld;
        dout_cos <= resize(shift_right_round(interpol(PHASE_MINOR_WIDTH).cos,OUTPUT_LSB_EXT,nearest),OUTPUT_WIDTH);
        dout_sin <= resize(shift_right_round(interpol(PHASE_MINOR_WIDTH).sin,OUTPUT_LSB_EXT,nearest),OUTPUT_WIDTH);
      end if;
    end if; -- clock
   end process;

  end generate;

  g_interpol_off : if PHASE_MINOR_WIDTH=0 generate
  begin
    PIPESTAGES <= 3;
    p_dout: process(clk)
    begin
     if rising_edge(clk) then
      if rst='1' then
        dout_vld <= '0';
        dout_cos <= (others=>'-');
        dout_sin <= (others=>'-');
      elsif clkena='1' then
        dout_vld <= rom_coarse_out.vld;
        dout_cos <= rom_coarse_out.major_cos(OUTPUT_WIDTH+ROM_FRAC_BITS-1 downto ROM_FRAC_BITS);
        dout_sin <= rom_coarse_out.major_sin(OUTPUT_WIDTH+ROM_FRAC_BITS-1 downto ROM_FRAC_BITS);
      end if;
     end if; -- clock
    end process;

  end generate;

end architecture;
