:: +++ FOR VHDL SIMULATION ONLY +++ #
:: This script compiles all generic entities of the DSP Library for VHDL-1993.
:: The device specific architectures are compiled separately.
::
:: Required environment variables :
::
::   VCOM_EXE    e.g. set VCOM_EXE=C:\FPGA\ghdl.exe
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
echo.INFO: Start compiling generic entities of the DSP Library ...

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
%COMPILE% %SCRIPTPATH%\..\ieee_extension_types_1993.vhdl
%COMPILE% %SCRIPTPATH%\..\ieee_extension.vhdl
%COMPILE% %SCRIPTPATH%\signed_mult1add1_accu.vhdl
%COMPILE% %SCRIPTPATH%\signed_mult1add1_sum.vhdl
%COMPILE% %SCRIPTPATH%\signed_mult1_accu.vhdl
%COMPILE% %SCRIPTPATH%\signed_mult2.vhdl
%COMPILE% %SCRIPTPATH%\signed_mult2_accu.vhdl
%COMPILE% %SCRIPTPATH%\signed_mult2_sum.vhdl
%COMPILE% %SCRIPTPATH%\signed_mult3.vhdl
%COMPILE% %SCRIPTPATH%\signed_mult4_accu.vhdl
%COMPILE% %SCRIPTPATH%\signed_mult4_sum.vhdl
%COMPILE% %SCRIPTPATH%\signed_mult8_accu.vhdl
%COMPILE% %SCRIPTPATH%\signed_mult16_accu.vhdl
%COMPILE% %SCRIPTPATH%\signed_multN.vhdl
%COMPILE% %SCRIPTPATH%\signed_multN_accu.vhdl
%COMPILE% %SCRIPTPATH%\signed_multN_sum.vhdl
%COMPILE% %SCRIPTPATH%\signed_preadd_mult1_accu.vhdl

:END
@EXIT /B
