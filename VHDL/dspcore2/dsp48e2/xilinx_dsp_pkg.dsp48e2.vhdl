-------------------------------------------------------------------------------
-- @file       xilinx_dsp_pkg.dsp48e2.vhdl
-- @author     Fixitfetish
-- @date       05/Sep/2024
-- @version    0.21
-- @note       VHDL-1993
-- @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Code comments are optimized for SIGASI.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension.all;

-- This package includes a Xilinx UltraScale specific collection of common
-- parameters and functions. It helps to minimize code duplication in the
-- different DSP implementations.
--
-- Refer to Xilinx UltraScale Architecture DSP48E2 Slice, UG579 (v1.11) August 30, 2021
--
package xilinx_dsp_pkg_dsp48e2 is

  -- accumulator width in bits
  constant ACCU_WIDTH : positive := 48;

  constant MAX_WIDTH_A  : positive := 30;
  constant MAX_WIDTH_B  : positive := 18;
  constant MAX_WIDTH_D  : positive := 27;
  constant MAX_WIDTH_C  : positive := ACCU_WIDTH;
  constant MAX_WIDTH_AB : positive := ACCU_WIDTH;
  constant MAX_WIDTH_AD : positive := MAX_WIDTH_D;

  type t_resource_type is (DSP, LOGIC);

  type t_dspreg is
  record
    A       : natural range 0 to 2;
    B       : natural range 0 to 2;
    C       : natural range 0 to 1;
    D       : natural range 0 to 1;
    AD      : natural range 0 to 1;
    M       : natural range 0 to 1;
    INMODE  : natural range 0 to 1;
    OPMODE  : natural range 0 to 1;
    ALUMODE : natural range 0 to 1;
  end record;

  function GET_NUM_DSP_REG(
    use_d : boolean; -- Input D and preadder required
    use_a_neg : boolean;
    aregs : natural; -- overall required number of port A input register (DSP internal + external in logic)
    bregs : natural; -- overall required number of port B input register (DSP internal + external in logic)
    cregs : natural; -- overall required number of port C input register (DSP internal + external in logic)
    dregs : natural  -- overall required number of port D input register (DSP internal + external in logic)
  ) return t_dspreg;

  -- determine number of required additional guard bits (MSBs)
  function accu_guard_bits(
    num_summand : natural; -- number of summands that are accumulated
    dflt : natural; -- default value when num_summand=0
    impl : string -- implementation identifier string for warnings and errors
  ) return integer;

  -- rounding bit generation (+0.5)
  function RND(
    ena : boolean; -- enable rounding
    shift : natural; -- number of right shifts
    simd : positive := 1  -- SIMD factor 1, 2 or 4
  ) return std_logic_vector;

  -- determine number of input registers within DSP cell and in LOGIC
  function NUM_IREG(
    loc : t_resource_type; -- location either DSP or LOGIC
    n : natural -- overall number of input registers
  ) return integer;

  -- determine number of A/B input registers within DSP cell and in LOGIC
  function NUM_IREG_AB(
    loc : t_resource_type; -- location either DSP or LOGIC
    n : natural -- overall number of input registers
  ) return integer;

  -- determine number of C input registers within DSP cell and in LOGIC
  function NUM_IREG_C(
    loc : t_resource_type; -- location either DSP or LOGIC
    n : natural -- overall number of input registers
  ) return integer;

  -- Register M is used as second input register when NUM_INPUT_REG>=2
  function MREG(n:natural) return natural;

  -- Register M only requires clock enable when register is enabled 
  function CEM(clkena:std_logic; n:natural) return std_logic;

  -- Pass clock enable only when at least one register is enabled
  function CE(clkena:std_logic; nreg:natural) return std_logic;

  -- INMODE has only one register stage
  function INMODEREG(n:natural) return natural;

  -- OPMODE has only one register stage
  function OPMODEREG(n:natural) return natural;

  -- Register P is the first output register when NUM_OUTPUT_REG=>1 (strongly recommended!)
  function PREG(n:natural) return natural;

  -- Determine possible number of parallel SIMD operations based on input and output(accumulator) width
  function SIMD_FACTOR(wi,wo:positive) return natural;

  -- DSP cell generic to configure the SIMD mode. Setting depends on the SIMD factor.
  function USE_SIMD(factor:natural) return string;

end package;

-------------------------------------------------------------------------------

package body xilinx_dsp_pkg_dsp48e2 is

  function GET_NUM_DSP_REG(
    use_d : boolean; -- Input D and preadder required
    use_a_neg : boolean;
    aregs : natural; -- overall required number of port A input register (DSP internal + external in logic)
    bregs : natural; -- overall required number of port B input register (DSP internal + external in logic)
    cregs : natural; -- overall required number of port C input register (DSP internal + external in logic)
    dregs : natural  -- overall required number of port D input register (DSP internal + external in logic)
  ) return t_dspreg is
    variable dsp : t_dspreg;
  begin
    -- After the data input registers the M pipeline register is the most important for timing and
    -- performance. The M register can be seen as second input register. Since input ports A, B and D
    -- contribute to the multiplier result these ports must have at least 2 input registers to enable M.
    if (aregs>=2 and bregs>=2 and dregs>=2) then dsp.M:=1; else dsp.M:=0; end if;

    -- NOTE: Currently, when D input is enabled, data inputs A and D into to the DSP cell must be
    -- synchronous, mainly because of the additional external negation logic. Since A supports 2 input
    -- registers but D only 1 register we need to be careful with the pipeline register AD here.
    if use_d then
      -- Input D with preadder and negation functionality is required
      if (aregs-dsp.M)>=2 and (dregs-dsp.M)>=2 then dsp.AD:=1; else dsp.AD:=0; end if;
    elsif use_a_neg then
      -- just A into preadder
      if (aregs-dsp.M)>=2 then dsp.AD:=1; else dsp.AD:=0; end if;
    else
      dsp.AD := 0;
    end if;

    -- When D and preadder enabled then A is limited to one input register, as D is.
    if use_d then
      dsp.A := minimum(1,aregs-dsp.M-dsp.AD);
    else
      dsp.A := minimum(2,aregs-dsp.M-dsp.AD);
    end if;
    dsp.B := minimum(2,bregs-dsp.M);
    dsp.C := minimum(1,cregs);
    dsp.D := minimum(1,dregs);
    dsp.INMODE  := 1; -- currently always one input register expected
    dsp.OPMODE  := 1; -- currently always one input register expected
    dsp.ALUMODE := 0; -- currently ALUMODE is constant, no register required
    return dsp;
  end function;

  -- determine number of required additional guard bits (MSBs)
  function accu_guard_bits(
    num_summand : natural; -- number of summands that are accumulated
    dflt : natural; -- default value when num_summand=0
    impl : string -- implementation identifier string for warnings and errors
  ) return integer is
    variable res : integer;
  begin
    if num_summand=0 then
      res := dflt; -- maximum possible (default)
    else
      res := LOG2CEIL(num_summand);
      if res>dflt then 
        report "WARNING " & impl & ": Too many summands. " & 
           "Maximum number of " & integer'image(dflt) & " guard bits reached."
           severity warning;
        res:=dflt;
      end if;
    end if;
    return res; 
  end function;

  -- rounding bit generation (+0.5)
  function RND(
    ena : boolean; -- enable rounding
    shift : natural; -- number of right shifts
    simd : positive := 1  -- SIMD factor 1, 2 or 4
  ) return std_logic_vector is
    variable res : std_logic_vector(ACCU_WIDTH-1 downto 0) := (others=>'0');
  begin 
    if ena and (shift>=1) then 
      res(shift-1):='1';
      if simd>=2 then 
        res(ACCU_WIDTH/2+shift-1):='1';
      end if;
      if simd>=4 then 
        res(  ACCU_WIDTH/4+shift-1):='1';
        res(3*ACCU_WIDTH/4+shift-1):='1';
      end if;
    end if;
    return res;
  end function;

  -- determine number of input registers within DSP cell and in LOGIC
  function NUM_IREG(
    loc : t_resource_type; -- location either DSP or LOGIC
    n : natural -- overall number of input registers
  ) return integer is
    -- maximum number of input registers supported within the DSP cell
    constant NUM_INPUT_REG_DSP : natural := 3;
  begin
    if loc=DSP then
      return MINIMUM(n,NUM_INPUT_REG_DSP);
    elsif loc=LOGIC then
      if n>NUM_INPUT_REG_DSP then return n-NUM_INPUT_REG_DSP;
      else return 0; end if;
    else
      report "ERROR: Input registers can be either within DSP or in LOGIC."
        severity failure;
      return -1;
    end if;
  end function;

  -- determine number of A/B input registers within DSP cell and in LOGIC
  function NUM_IREG_AB(
    loc : t_resource_type; -- location either DSP or LOGIC
    n : natural -- overall number of input registers
  ) return integer is
    -- maximum number of input registers supported within the DSP cell
    constant NUM_INPUT_REG_DSP : natural := 2;
  begin
    if loc=DSP then
      return MINIMUM(n,NUM_INPUT_REG_DSP);
    elsif loc=LOGIC then
      if n>NUM_INPUT_REG_DSP then return n-NUM_INPUT_REG_DSP;
      else return 0; end if;
    else
      report "ERROR: Input registers can be either within DSP or in LOGIC."
        severity failure;
      return -1;
    end if;
  end function;

  -- determine number of C input registers within DSP cell and in LOGIC
  function NUM_IREG_C(
    loc : t_resource_type; -- location either DSP or LOGIC
    n : natural -- overall number of input registers
  ) return integer is
    -- maximum number of input registers supported within the DSP cell
    constant NUM_INPUT_REG_DSP : natural := 1;
  begin
    if loc=DSP then
      return MINIMUM(n,NUM_INPUT_REG_DSP);
    elsif loc=LOGIC then
      if n>NUM_INPUT_REG_DSP then return n-NUM_INPUT_REG_DSP;
      else return 0; end if;
    else
      report "ERROR: Input registers can be either within DSP or in LOGIC."
        severity failure;
      return -1;
    end if;
  end function;

  -- Register M is used as second input register when NUM_INPUT_REG>=2
  function MREG(n:natural) return natural is
  begin if n>=2 then return 1; else return 0; end if; end function;

  -- Register M only requires clock enable when register is enabled 
  function CEM(clkena:std_logic; n:natural) return std_logic is
  begin if n>=2 then return clkena; else return '0'; end if; end function;

  -- Pass clock enable only when at least one register is enabled
  function CE(clkena:std_logic; nreg:natural) return std_logic is
  begin if nreg>=1 then return clkena; else return '0'; end if; end function;

  -- INMODE has only one register stage
  function INMODEREG(n:natural) return natural is
  begin if n>=1 then return 1; else return 0; end if; end function;

  -- OPMODE has only one register stage
  function OPMODEREG(n:natural) return natural is
  begin if n>=1 then return 1; else return 0; end if; end function;

  -- Register P is the first output register when NUM_OUTPUT_REG=>1 (strongly recommended!)
  function PREG(n:natural) return natural is
  begin if n>=1 then return 1; else return 0; end if; end function;

  -- Determine possible number of parallel SIMD operations based on input and output(accumulator) width
  function SIMD_FACTOR(wi,wo:positive) return natural is
    variable w : positive;
  begin
    w := MAXIMUM(wi,wo);
    if w<=ACCU_WIDTH/4 then
      return 4;
    elsif w<=ACCU_WIDTH/2 then
      return 2;
    elsif w<=ACCU_WIDTH then
      return 1;
    else
      return 0;
    end if;
  end function;

  function USE_SIMD(factor:natural) return string is
  begin
    if factor=4 then
      return "FOUR12";
    elsif factor=2 then
      return "TWO24";
    else
      return "ONE48";
    end if;
  end function;

end package body;
