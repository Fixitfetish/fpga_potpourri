-------------------------------------------------------------------------------
--! @file       dsp_pkg.ultrascale.vhdl
--! @author     Fixitfetish
--! @date       19/Mar/2017
--! @version    0.10
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension.all;

--! @brief This package includes a Xilinx UltraScale specific collection of common
--! parameters and functions. It helps to minimize code duplication in the
--! different DSP implementations.

package dsp_pkg_ultrascale is

  --! accumulator width in bits
  constant ACCU_WIDTH : positive := 48;

  constant MAX_WIDTH_A  : positive := 30;
  constant MAX_WIDTH_B  : positive := 18;
  constant MAX_WIDTH_D  : positive := 27;
  constant MAX_WIDTH_C  : positive := ACCU_WIDTH;
  constant MAX_WIDTH_AB : positive := ACCU_WIDTH;

  type t_resource_type_ultrascale is (DSP, LOGIC);
  
  --! determine number of required additional guard bits (MSBs)
  function accu_guard_bits(
    num_summand : natural; -- number of summands that are accumulated
    dflt : natural; -- default value when num_summand=0
    impl : string -- implementation identifier string for warnings and errors
  ) return integer;

  --! rounding bit generation (+0.5)
  function RND(
    ena : boolean; -- enable rounding
    shift : natural -- number of right shifts
  ) return std_logic_vector;

  --! determine number of input registers within DSP cell and in LOGIC
  function NUM_IREG(
    loc : t_resource_type_ultrascale; -- location either DSP or LOGIC
    n : natural -- overall number of input registers
  ) return integer;

  --! determine number of A/B input registers within DSP cell and in LOGIC
  function NUM_IREG_AB(
    loc : t_resource_type_ultrascale; -- location either DSP or LOGIC
    n : natural -- overall number of input registers
  ) return integer;

  --! determine number of C input registers within DSP cell and in LOGIC
  function NUM_IREG_C(
    loc : t_resource_type_ultrascale; -- location either DSP or LOGIC
    n : natural -- overall number of input registers
  ) return integer;

  --! Register M is used as second input register when NUM_INPUT_REG>=2
  function MREG(n:natural) return natural;

  --! Register M only requires clock enable when register is enabled 
  function CEM(clkena:std_logic; n:natural) return std_logic;

  --! INMODE has only one register stage
  function INMODEREG(n:natural) return natural;

  --! Register P is the first output register when NUM_OUTPUT_REG=>1 (strongly recommended!)
  function PREG(n:natural) return natural;

end package;

-------------------------------------------------------------------------------

package body dsp_pkg_ultrascale is

  --! determine number of required additional guard bits (MSBs)
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

  --! rounding bit generation (+0.5)
  function RND(
    ena : boolean; -- enable rounding
    shift : natural -- number of right shifts
  ) return std_logic_vector is
    variable res : std_logic_vector(ACCU_WIDTH-1 downto 0) := (others=>'0');
  begin 
    if ena and (shift>=1) then res(shift-1):='1'; end if;
    return res;
  end function;

  --! determine number of input registers within DSP cell and in LOGIC
  function NUM_IREG(
    loc : t_resource_type_ultrascale; -- location either DSP or LOGIC
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

  --! determine number of A/B input registers within DSP cell and in LOGIC
  function NUM_IREG_AB(
    loc : t_resource_type_ultrascale; -- location either DSP or LOGIC
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

  --! determine number of C input registers within DSP cell and in LOGIC
  function NUM_IREG_C(
    loc : t_resource_type_ultrascale; -- location either DSP or LOGIC
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

  --! Register M is used as second input register when NUM_INPUT_REG>=2
  function MREG(n:natural) return natural is
  begin if n>=2 then return 1; else return 0; end if; end function;

  --! Register M only requires clock enable when register is enabled 
  function CEM(clkena:std_logic; n:natural) return std_logic is
  begin if n>=2 then return clkena; else return '0'; end if; end function;

  --! INMODE has only one register stage
  function INMODEREG(n:natural) return natural is
  begin if n>=1 then return 1; else return 0; end if; end function;

  --! Register P is the first output register when NUM_OUTPUT_REG=>1 (strongly recommended!)
  function PREG(n:natural) return natural is
  begin if n>=1 then return 1; else return 0; end if; end function;

end package body;
