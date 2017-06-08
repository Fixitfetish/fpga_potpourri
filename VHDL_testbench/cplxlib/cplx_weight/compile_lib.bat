@echo off

set SRC_PATH=..\..\..\VHDL

:: create work directory
if not exist work\ (
  mkdir work
)
:: create output directory
if not exist output\ (
  mkdir output
)

:: GHDL compiler settings
set VCOM_EXE=%GHDL_PATH%\bin\ghdl.exe
set VCOM_FLAGS=-a --std=93 --workdir=work -Pwork --work=
set COMPILE=%VCOM_EXE% %VCOM_FLAGS%

:: analyze library files
@call %SRC_PATH%\baselib\_compile.bat
@call %SRC_PATH%\dsplib\_compile.bat
@call %SRC_PATH%\dsplib\behave\_compile.bat
@call %SRC_PATH%\cplxlib\_compile.bat
