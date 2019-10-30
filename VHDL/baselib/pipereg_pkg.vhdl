-------------------------------------------------------------------------------
--! @file       pipereg_pkg.vhdl
--! @author     Fixitfetish
--! @date       30/Oct/2019
--! @version    0.20
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

--! @brief Single pipeline register with clock enable and reset.
--!
--! A pipeline register can be written without process in a single code line.
--! This can be useful for single registers or within 'generate' blocks or loops.
--! Example for std_logic type: 
--! * full long: pipereg(xout=>xout, xin=>xin, clk=>clk, ce=>clkena, rst=>rst, rstval=>'1');
--! * full short : pipereg(xout, xin, clk, clkena, rst, '1');
--! * partly long : pipereg(xout=>xout, xin=>xin, clk=>clk, rst=>rst);
--! * partly short : pipereg(xout, xin, clk, clkena);
--!
--! where XOUT is the output and XIN the input signal of the register.
--!
package pipereg_pkg is

  procedure pipereg(
    signal xout : inout boolean; -- register (output)
    signal xin : in boolean; -- register input
    signal clk : in std_logic; -- clock
    ce : in std_logic:='1'; -- clock enable
    rst : in std_logic:='0'; -- reset
    constant rstval : in boolean:=false -- reset value
  );

  procedure pipereg(
    signal xout : inout std_logic; -- register (output)
    signal xin : in std_logic; -- register input
    signal clk : in std_logic; -- clock
    ce : in std_logic:='1'; -- clock enable
    rst : in std_logic:='0'; -- reset
    constant rstval : in std_logic:='0' -- reset value
  );

  procedure pipereg(
    signal xout : inout std_logic_vector; -- register (output)
    signal xin : in std_logic_vector; -- register input
    signal clk : in std_logic; -- clock
    ce : in std_logic:='1'; -- clock enable
    rst : in std_logic:='0'; -- reset
    constant rstval : in std_logic_vector:="-" -- reset value
  ); 

  procedure pipereg(
    signal xout : inout unsigned; -- register (output)
    signal xin : in unsigned; -- register input
    signal clk : in std_logic; -- clock
    ce : in std_logic:='1'; -- clock enable
    rst : in std_logic:='0'; -- reset
    constant rstval : in unsigned:="-" -- reset value
  ); 

  procedure pipereg(
    signal xout : inout signed; -- register (output)
    signal xin : in signed; -- register input
    signal clk : in std_logic; -- clock
    ce : in std_logic:='1'; -- clock enable
    rst : in std_logic:='0'; -- reset
    constant rstval : in signed:="-" -- reset value
  ); 

end package;

-------------------------------------------------------------------------------

package body pipereg_pkg is

  procedure pipereg(
    signal xout : inout boolean; -- register (output)
    signal xin : in boolean; -- register input
    signal clk : in std_logic; -- clock
    ce : in std_logic:='1'; -- clock enable
    rst : in std_logic:='0'; -- reset
    constant rstval : in boolean:=false -- reset value
  ) is 
  begin 
    xout <= xout;
    if rising_edge(clk) then
      if rst/='0' then xout<=rstval; elsif ce='1' then xout<=xin; end if;
    end if;
  end procedure;

  procedure pipereg(
    signal xout : inout std_logic; -- register (output)
    signal xin : in std_logic; -- register input
    signal clk : in std_logic; -- clock
    ce : in std_logic:='1'; -- clock enable
    rst : in std_logic:='0'; -- reset
    constant rstval : in std_logic:='0' -- reset value
  ) is 
  begin 
    xout <= xout;
    if rising_edge(clk) then
      if rst/='0' then xout<=rstval; elsif ce='1' then xout<=xin; end if;
    end if;
  end procedure;

  procedure pipereg(
    signal xout : inout std_logic_vector; -- register (output)
    signal xin : in std_logic_vector; -- register input
    signal clk : in std_logic; -- clock
    ce : in std_logic:='1'; -- clock enable
    rst : in std_logic:='0'; -- reset
    constant rstval : in std_logic_vector:="-" -- reset value
  ) is 
  begin 
--    xout <= xout;
    if rising_edge(clk) then
      if rst/='0' then 
        if rstval'length=1 then
          xout<=(xout'range=>rstval(rstval'low));
        elsif rstval'length=xin'length then
          xout<=rstval;
        else
          report "ERROR pipereg() : Provided reset value RSTVAL must have same length as input XIN or length 1."
            severity failure;
        end if;
      elsif ce='1' then
        xout<=xin;
      end if;
    end if;
  end procedure;

  procedure pipereg(
    signal xout : inout unsigned; -- register (output)
    signal xin : in unsigned; -- register input
    signal clk : in std_logic; -- clock
    ce : in std_logic:='1'; -- clock enable
    rst : in std_logic:='0'; -- reset
    constant rstval : in unsigned:="-" -- reset value
  ) is 
  begin 
    xout <= xout;
    if rising_edge(clk) then
      if rst/='0' then 
        if rstval'length=1 then
          xout<=(xout'range=>rstval(rstval'low));
        elsif rstval'length=xin'length then
          xout<=rstval;
        else
          report "ERROR pipereg() : Provided reset value RSTVAL must have same length as input XIN or length 1."
            severity failure;
        end if;
      elsif ce='1' then
        xout<=xin;
      end if;
    end if;
  end procedure;

  procedure pipereg(
    signal xout : inout signed; -- register (output)
    signal xin : in signed; -- register input
    signal clk : in std_logic; -- clock
    ce : in std_logic:='1'; -- clock enable
    rst : in std_logic:='0'; -- reset
    constant rstval : in signed:="-" -- reset value
  ) is 
  begin 
    xout <= xout;
    if rising_edge(clk) then
      if rst/='0' then 
        if rstval'length=1 then
          xout<=(xout'range=>rstval(rstval'low));
        elsif rstval'length=xin'length then
          xout<=rstval;
        else
          report "ERROR pipereg() : Provided reset value RSTVAL must have same length as input XIN or length 1."
            severity failure;
        end if;
      elsif ce='1' then
        xout<=xin;
      end if;
    end if;
  end procedure;

end package body;
