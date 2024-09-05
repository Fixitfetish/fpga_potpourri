-------------------------------------------------------------------------------
--! @file       complex_macc_chain.vhdl
--! @author     Fixitfetish
--! @date       05/Sep/2024
--! @version    0.21
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Code comments are optimized for SIGASI.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension_types.all;
  use baselib.ieee_extension.all;

-- N complex multiplications and the chained sum/accumulation of all product results.
--
-- This entity can be used for example
-- * for complex multiplication and scalar products
--
-- The first operation mode is:
-- * VLD=0  then  r = r
-- * VLD=1  then  r = +/-(x0*y0) +/-(x1*y1) +/-...
--
-- The second operation mode is (single y factor):
-- * VLD=0  then  r = r
-- * VLD=1  then  r = +/-(x0*y0) +/-(x1*y0) +/-...
--
-- Note that for the second mode a more efficient implementation might be possible
-- because only one multiplication after summation is required.
--
-- The length of the input factors is flexible.
-- The input factors are automatically resized with sign extensions bits to the
-- maximum possible factor length.
-- The maximum length of the input factors is device and implementation specific.
-- The resulting length of all products (x(n)'length + y(n)'length) must be the same.
--
-- The delay depends on the configuration and the underlying hardware.
-- The number pipeline stages is reported as constant at output port PIPESTAGES.
--
-- VHDL Instantiation Template:
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
-- I1 : entity work.complex_macc_chain
-- generic map(
--   OPTIMIZATION       => string,   -- "PERFORMANCE" or "RESOURCES"
--   USE_ACCU           => boolean,  -- enable accumulator
--   NUM_MULT           => positive, -- number of parallel multiplications
--   USE_NEGATION       => boolean,  -- enable negation port
--   USE_CONJUGATE_X    => boolean,  -- enable X complex conjugate port
--   USE_CONJUGATE_Y    => boolean,  -- enable Y complex conjugate port
--   NUM_INPUT_REG_XY   => natural,  -- number of X/Y input registers
--   NUM_INPUT_REG_Z    => natural,  -- number of Z input registers
--   NUM_OUTPUT_REG     => positive, -- number of output registers
--   OUTPUT_SHIFT_RIGHT => natural,  -- number of right shifts
--   OUTPUT_ROUND       => boolean,  -- enable rounding half-up
--   OUTPUT_CLIP        => boolean,  -- enable clipping
--   OUTPUT_OVERFLOW    => boolean   -- enable overflow detection
-- )
-- port map(
--   clk        => in  std_logic, -- clock
--   rst        => in  std_logic, -- reset
--   clkena     => in  std_logic, -- clock enable
--   clr        => in  std_logic, -- clear accu
--   neg        => in  std_logic_vector(0 to NUM_MULT-1), -- negation
--   x_re       => in  signed_vector(0 to NUM_MULT-1), -- first factors
--   x_im       => in  signed_vector(0 to NUM_MULT-1), -- first factors
--   x_vld      => in  std_logic, -- valid
--   x_conj     => in  std_logic_vector(0 to NUM_MULT-1), -- conjugate X
--   y_re       => in  signed_vector(0 to NUM_MULT-1), -- second factors
--   y_im       => in  signed_vector(0 to NUM_MULT-1), -- second factors
--   y_vld      => in  std_logic, -- valid
--   y_conj     => in  std_logic_vector(0 to NUM_MULT-1), -- conjugate Y
--   z_re       => in  signed_vector(0 to NUM_MULT-1), -- summand after multiplication
--   z_im       => in  signed_vector(0 to NUM_MULT-1), -- summand after multiplication
--   z_vld      => in  std_logic_vector(0 to NUM_MULT-1), -- Z valid
--   result_re  => out signed, -- result
--   result_im  => out signed, -- result
--   result_vld => out std_logic, -- output valid
--   result_ovf => out std_logic, -- output overflow
--   PIPESTAGES => out integer -- constant number of pipeline stages
-- );
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--
entity complex_macc_chain is
generic (
  -- OPTIMIZATION can be either "PERFORMANCE" or "RESOURCES"
  OPTIMIZATION : string := "RESOURCES";
  -- Enable accumulation over multiple cycles (enable CLR input port)
  USE_ACCU : boolean := false;
  -- Number of parallel multiplications - mandatory generic!
  NUM_MULT : positive;
  -- Enable negation port. If enabled then static or dynamic negation of partial
  -- products is implemented (preferably within the DSP cells otherwise in logic).
  -- Enabling the negation might have negative side effects on pipeline stages,
  -- input width limitations and timing.
  -- Disable negation if not needed and the negation port input is ignored.
  USE_NEGATION : boolean := false;
  -- Enable X_CONJ input port for static or dynamic complex conjugate X, i.e. negation of input port X_IM.
  USE_CONJUGATE_X : boolean := false;
  -- Enable Y_CONJ input port for static or dynamic complex conjugate Y, i.e. negation of input port Y_IM.
  USE_CONJUGATE_Y : boolean := false;
  -- Number of additional X/Y input registers. At least one is strongly recommended for performance.
  -- If possible then input registers within the DSP cell are used.
  NUM_INPUT_REG_XY : natural := 0;
  -- Number of additional Z input registers which will always be implemented in logic.
  NUM_INPUT_REG_Z : natural := 0;
  -- Number of result output registers. At least one is required. The
  -- first output register is typically the result register within the DSP cell.
  -- A second output register is recommended when logic for rounding, clipping
  -- and/or overflow detection is enabled.
  -- Typically all output registers after the first one are not part of a DSP cell
  -- and therefore implemented in logic.
  NUM_OUTPUT_REG : positive := 1;
  -- Number of bits by which the accumulator result output is shifted right
  OUTPUT_SHIFT_RIGHT : natural := 0;
  -- Round 'nearest' (half-up) of result output.
  -- This flag is only relevant when OUTPUT_SHIFT_RIGHT>0.
  -- If the device specific DSP cell supports rounding then rounding is done
  -- within the DSP cell. If rounding in logic is necessary then it is recommended
  -- to use an additional output register.
  OUTPUT_ROUND : boolean := false;
  -- Enable clipping when right shifted result exceeds output range.
  OUTPUT_CLIP : boolean := false;
  -- Enable overflow/clipping detection 
  OUTPUT_OVERFLOW : boolean := false
);
port (
  --! Standard system clock
  clk        : in  std_logic;
  --! Reset result output (optional)
  rst        : in  std_logic := '0';
  --! Clock enable (optional)
  clkena     : in  std_logic := '1';
  --! @brief Clear accumulator (mark first valid input factors of accumulation sequence).
  --! Only relevant when USE_ACCU=true .
  clr        : in  std_logic := '1';
  --! Negation of partial products , '0' -> +(x(n)*y(n)), '1' -> -(x(n)*y(n)). Negation is disabled by default.
  neg        : in  std_logic_vector(0 to NUM_MULT-1) := (others=>'0');
  --! Real component of first factor vector. Requires 'TO' range.
  x_re       : in  signed_vector(0 to NUM_MULT-1);
  --! Imaginary component of first factor vector. Requires 'TO' range.
  x_im       : in  signed_vector(0 to NUM_MULT-1);
  --! Valid signals for X input factors, high-active
  x_vld      : in  std_logic_vector(0 to NUM_MULT-1);
  --! Complex conjugate of X input , '0'=+x_im(n) , '1'=-x_im(n). Complex conjugate is disabled by default.
  x_conj     : in  std_logic_vector(0 to NUM_MULT-1) := (others=>'0');
  --! Real component of second factor vector. Requires 'TO' range.
  y_re       : in  signed_vector(0 to NUM_MULT-1);
  --! Imaginary component of second factor vector. Requires 'TO' range.
  y_im       : in  signed_vector(0 to NUM_MULT-1);
  --! Valid signals for Y input factors, high-active
  y_vld      : in  std_logic_vector(0 to NUM_MULT-1);
  --! Complex conjugate of Y input , '0'=+y_im(n) , '1'=-y_im(n). Complex conjugate is disabled by default.
  y_conj     : in  std_logic_vector(0 to NUM_MULT-1) := (others=>'0');
  --! @brief Additional summand after multiplication, real component.
  --! Z is LSB bound to the LSB of the product x*y before shift right, i.e. similar to chain input.
  --! Set (others=>"00") if unused.
  z_re       : in  signed_vector(0 to NUM_MULT-1);
  --! @brief Additional summand after multiplication, imaginary component.
  --! Z is LSB bound to the LSB of the product x*y before shift right, i.e. similar to chain input.
  --! Set (others=>"00") if unused.
  z_im       : in  signed_vector(0 to NUM_MULT-1);
  --! Valid signal for summand input Z, high-active. Set (others=>'0') if unused.
  z_vld      : in  std_logic_vector(0 to NUM_MULT-1) := (others=>'0');
  --! Real component of the result output (optionally rounded and clipped).
  result_re  : out signed;
  --! Imaginary component of the result output (optionally rounded and clipped).
  result_im  : out signed;
  --! Valid signal for result output, high-active
  result_vld : out std_logic;
  --! Result output overflow/clipping detection
  result_ovf : out std_logic;
  --! Number of pipeline stages, constant, depends on configuration and device specific implementation
  PIPESTAGES : out integer := 1
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (not OUTPUT_ROUND) or (OUTPUT_SHIFT_RIGHT/=0)
    report "WARNING in " & complex_macc_chain'INSTANCE_NAME &
           " Disabled rounding because OUTPUT_SHIFT_RIGHT is 0."
    severity warning;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;
