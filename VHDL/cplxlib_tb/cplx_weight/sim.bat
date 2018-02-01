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

:: analyze library files
@call %LIBROOT%\baselib\_compile.bat %VHDL%
@call %LIBROOT%\dsplib\_compile.bat %VHDL%
@call %LIBROOT%\dsplib\behave\_compile.bat %VHDL%
@call %LIBROOT%\cplxlib\_compile.bat %VHDL%

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

@set LIB=work
%COMPILE%%LIB% %LIBROOT%\cplxlib_tb\cplx_stimuli.vhdl
%COMPILE%%LIB% %LIBROOT%\cplxlib_tb\cplx_logger.vhdl
%COMPILE%%LIB% weight_tb.vhdl

@echo.
@echo.INFO: Compilation finished - ready to start simulation. 
@pause

:: run testbench
@echo.--------------------------------------------------------------------------
@echo.INFO: Starting simulation ...
%SIMULATE% weight_tb 

@pause
