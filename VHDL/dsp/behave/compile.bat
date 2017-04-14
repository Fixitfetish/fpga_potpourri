::+++ FOR VHDL SIMULATORS ONLY +++#
:: This script compiles all behavioral architectures of the DSP Library.
:: It is required to compile the generic DSP entities first !
::
:: Required environment variables :
::
::   VCOM_EXE    e.g. set VCOM_EXE=ghdl.exe
::
::   VCOM_FLAGS  e.g. set VCOM_FLAGS=-a --std=93 --workdir=work -Pwork --work=
::               Note that the flags need to be appended with the library name
::               into which the files shalle be compiled.
::
:: There two ways to call to this script.
::
::   1. Variables above are static system environment variable.
::      You can directly call this script (or double-click on it).
::
::   2. Variables above are set by a master script.
::      Call this script as sub-script.

@echo off
setlocal

echo.--------------------------------------------------------------------------
echo.INFO: Start compiling behavioral architectures of the DSP Library ...

:: Library name into which the entities are compiled
set LIB=fixitfetish

:: path/location of this script
set SCRIPTPATH=%~dp0

:: compiler check
if "%VCOM_EXE%"=="" (
  echo.ERROR: Compiler environment variable VCOM_EXE is not defined.
  goto END
) else (
  if not exist %VCOM_EXE% (
    echo.ERROR: Compiler not found. VCOM_EXE = %VCOM_EXE%
    goto END
  )
)

:: compiler flag check
if "%VCOM_FLAGS%"=="" (
  echo.ERROR: Compiler flag environment variable VCOM_FLAGS is not defined.
  goto END
)
 
:: analyze/compile files
set COMPILE=%VCOM_EXE% %VCOM_FLAGS%%LIB%
@echo on
%COMPILE% %SCRIPTPATH%\signed_mult1_accu.behave.vhdl
%COMPILE% %SCRIPTPATH%\signed_mult2_accu.behave.vhdl
%COMPILE% %SCRIPTPATH%\signed_mult2_sum.behave.vhdl
%COMPILE% %SCRIPTPATH%\signed_multN_accu.behave.vhdl
%COMPILE% %SCRIPTPATH%\signed_multN_sum.behave.vhdl

:END
@EXIT /B
