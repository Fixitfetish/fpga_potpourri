-------------------------------------------------------------------------------
--! @file       dsp_pkg.arria10.vhdl
--! @author     Fixitfetish
--! @date       19/Mar/2017
--! @version    0.10
--! @copyright  MIT License
--! @note       VHDL-1993
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension.all;

--! @brief This package includes a Altera Arria 10 specific collection of common
--! parameters and functions. It helps to minimize code duplication in the
--! different DSP implementations.

package dsp_pkg_arria10 is

  --! accumulator width in bits
  constant ACCU_WIDTH : positive := 64;

  --! determine number of required additional guard bits (MSBs)
  function accu_guard_bits(
    num_summand : natural; -- number of summands that are accumulated
    dflt : natural; -- default value when num_summand=0
    impl : string -- implementation identifier string for warnings and errors
  ) return integer;

  --! chain input adder enable/disable
  function use_chainadder(
    ena : boolean -- enable chain input adder
  ) return string;

  --! constant rounding value that is loaded initially
  function load_const_value(
    round : boolean; -- rounding enable
    shifts : natural -- number of right shifts
  ) return natural;

  --! clock select for input/output registers
  function clock(
    clksel : integer range 0 to 2; --! clock select
    n_reg : integer -- number of register stages
  ) return string;

  --! determine number of input registers within DSP cell and in LOGIC
  function NUM_IREG(
    loc : string; -- location either "DSP" or "LOGIC"
    n : natural -- overall number of input registers
  ) return integer;

end package;

-------------------------------------------------------------------------------

package body dsp_pkg_arria10 is

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

  --! chain input adder enable/disable
  function use_chainadder(
    ena : boolean -- enable chain input adder
  ) return string is
  begin
    if ena then return "true"; else return "false"; end if;
  end function;

  --! constant rounding value that is loaded initially
  function load_const_value(
    round : boolean; -- rounding enable
    shifts : natural -- number of right shifts
  ) return natural is
  begin
    -- if rounding is enabled then +0.5 in the beginning of accumulation
    if round and (shifts>0) then return (shifts-1); else return 0; end if;
  end function;

  --! clock select for input/output registers
  function clock(
    clksel : integer range 0 to 2; -- clock select
    n_reg : integer -- number of register stages
  ) return string is
  begin
    if    clksel=0 and n_reg>0 then return "0";
    elsif clksel=1 and n_reg>0 then return "1";
    elsif clksel=2 and n_reg>0 then return "2";
    else return "none";
    end if;
  end function;

  --! determine number of input registers within DSP cell and in LOGIC
  function NUM_IREG(
    loc : string; -- location either "DSP" or "LOGIC"
    n : natural -- overall number of input registers
  ) return integer is
    -- maximum number of input registers supported within the DSP cell
    constant NUM_INPUT_REG_DSP : natural := 2;
  begin
    if loc="DSP" then
      return MINIMUM(n,NUM_INPUT_REG_DSP);
    elsif loc="LOGIC" then
      if n>NUM_INPUT_REG_DSP then return n-NUM_INPUT_REG_DSP;
      else return 0; end if;
    else
      report "ERROR: Input registers can be either within 'DSP' or in 'LOGIC'."
        severity failure;
      return -1;
    end if;
  end function;

end package body;
