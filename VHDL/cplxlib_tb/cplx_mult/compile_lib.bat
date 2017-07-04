@echo off

set LIBROOT=..\..

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
@call %LIBROOT%\baselib\_compile.bat
@call %LIBROOT%\dsplib\_compile.bat
@call %LIBROOT%\dsplib\behave\_compile.bat
@call %LIBROOT%\cplxlib\_compile.bat
