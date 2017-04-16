:: +++ FOR VHDL SIMULATION ONLY +++
:: This script compiles all generic entities of the DSP Library.
:: The device specific architectures are compiled separately.
::
:: ARGUMENTS
::   %1 = 1993 or 2008, VHDL standard, default is 1993
::
:: ENVIRONMENT VARIABLES
::   VCOM_EXE    e.g. set VCOM_EXE=C:\FPGA\ghdl.exe
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

:: Library name into which the entities are compiled
set LIB=fixitfetish

:: path/location of this script
set SCRIPTPATH=%~dp0

echo.--------------------------------------------------------------------------
echo.INFO: Start compiling generic entities of the DSP Library ...
:: Arguments
if "%1"=="" (
  :: by default use VHDL-1993
  set VHDL=1993
) else (
  if "%1"=="1993" (
    set VHDL=1993
  ) else (
    if "%1"=="2008" (
      set VHDL=2008
    ) else (
      echo.ERROR: VHDL standard %1 not supported. Use either 1993 or 2008.
      goto END
    )
  )
)
echo.INFO: Using standard VHDL-%VHDL% .

:: GHDL flags
if "%VHDL%"=="2008" (
  set VCOM_FLAGS=-a --std=08 --workdir=work -Pwork --work=%LIB%
) else (
  set VCOM_FLAGS=-a --std=93 --workdir=work -Pwork --work=%LIB%
)

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

:: analyze/compile files
set COMPILE=%VCOM_EXE% %VCOM_FLAGS%
@echo on
%COMPILE% %SCRIPTPATH%\..\ieee_extension_types_%VHDL%.vhdl
%COMPILE% %SCRIPTPATH%\..\ieee_extension.vhdl
%COMPILE% %SCRIPTPATH%\signed_accu.vhdl
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
