@echo off
:: create work directory
if not exist work\ (
  mkdir work
)
:: create output directory
if not exist output\ (
  mkdir output
)

set GHDL=%GHDL_PATH%\bin\ghdl
set GTKWAVE=%GTKWAVE_PATH%\bin\gtkwave

:: standard options
set FLAGS=--std=93 --workdir=work -Pwork

:: waveform file
set VCD=output\cplx_1993.vcd
if exist %VCD% (
  del %VCD%
)

@echo on
 
:: analyze files of fixitfetish library
%GHDL% -a %FLAGS% --work=fixitfetish ..\VHDL\ieee_extension.vhdl
%GHDL% -a %FLAGS% --work=fixitfetish ..\VHDL\cplx_pkg_1993.vhdl

:: analyze testbench
%GHDL% -a %FLAGS% cplx_1993_tb.vhdl

pause

:: run testbench
%GHDL% -r %FLAGS% cplx_1993_tb --stop-time=500ns --vcd=%VCD%

pause

:: start waveform viewer
@if not exist %VCD% goto END
%GTKWAVE% %VCD% cplx_1993.gtkw

:END