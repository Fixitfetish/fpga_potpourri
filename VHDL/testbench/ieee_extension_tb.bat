@echo off
:: create work directory
if not exist work\ (
  mkdir work
)
:: create output directory
if not exist output\ (
  mkdir output
)
@echo on

set GHDL=%GHDL_PATH%\bin\ghdl
set GTKWAVE=%GTKWAVE_PATH%\bin\gtkwave

:: standard options
set FLAGS=--std=93 --workdir=work -Pwork

:: analyze files of fixitfetish library
%GHDL% -a %FLAGS% --work=fixitfetish ..\ieee_extension.vhdl

:: analyze testbench
%GHDL% -a %FLAGS% ieee_extension_tb.vhdl

pause

:: run testbench
%GHDL% -r %FLAGS% ieee_extension_tb --stop-time=500ns --vcd=output\ieee_extension.vcd

rem %GTKWAVE% output\ieee_extension.vcd

pause
