@echo off

set LIBROOT=..\..
set VHDL=1993

:: create work directory
if not exist work\ (
  mkdir work
)
:: create output directory
if not exist output\ (
  mkdir output
)

:: GHDL compiler and simulator settings
set VCOM_EXE=%GHDL_PATH%\bin\ghdl.exe
set VSIM_EXE=%GHDL_PATH%\bin\ghdl.exe
set VIEW_EXE=%GTKWAVE_PATH%\bin\gtkwave.exe

:: analyze library files
@call %LIBROOT%\baselib\_compile.bat %VHDL%

@echo off

if "%VHDL%"=="2008" (
  set VCOM_FLAGS=-a --std=08 --workdir=work -Pwork --work=
  set VSIM_FLAGS=-r --std=08 --workdir=work -Pwork
) else (
  set VCOM_FLAGS=-a --std=93 --workdir=work -Pwork --work=
  set VSIM_FLAGS=-r --std=93 --workdir=work -Pwork
)

set COMPILE=%VCOM_EXE% %VCOM_FLAGS%
set SIMULATE=%VSIM_EXE% %VSIM_FLAGS%


:: analyze testbench
@echo.--------------------------------------------------------------------------
@echo.INFO: Starting to compile the testbench ...
@echo on

@set LIB=dsplib
%COMPILE%%LIB% %LIBROOT%\dsplib\signed_output_logic.vhdl
%COMPILE%%LIB% %LIBROOT%\dsplib\signed_add2_accu.vhdl
%COMPILE%%LIB% %LIBROOT%\dsplib\behave\dsp_pkg.behave.vhdl
%COMPILE%%LIB% %LIBROOT%\dsplib\behave\signed_add2_accu.behave.vhdl

@set LIB=work
%COMPILE%%LIB% signed_add2_accu_tb.vhdl

@echo.
@echo.INFO: Compilation finished - ready to start simulation. 
@pause

:: run testbench
@echo.--------------------------------------------------------------------------
@echo.INFO: Starting simulation ...
:: waveform file
set VCD=output\sim.vcd
%SIMULATE% signed_add2_accu_tb --vcd=%VCD%

@pause

:: start waveform viewer
@if not exist %VCD% goto END
%VIEW_EXE% %VCD% sim.gtkw

:END