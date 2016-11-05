@echo off
:: create work directory
if not exist work\ (
  mkdir work
)
@echo on

set GHDL=%GHDL_PATH%\bin\ghdl
set GTKWAVE=%GTKWAVE_PATH%\bin\gtkwave


:: standard options
set FLAGS=--std=93 --workdir=work -Pwork

:: analyze files of fixitfetish library
%GHDL% -a %FLAGS% --work=fixitfetish ..\VHDL\gray_code.vhdl

:: analyze and run testbench
%GHDL% -a %FLAGS% gray_code_tb.vhdl
%GHDL% -r %FLAGS% gray_code_tb --stop-time=500ns --vcd=output\gray_code.vcd

:: start waveform viewer
%GTKWAVE% output\gray_code.vcd
