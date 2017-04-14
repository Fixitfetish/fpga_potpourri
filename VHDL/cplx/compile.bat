:: +++ FOR VHDL SIMULATORS ONLY +++ #
:: This script compiles the CPLX Library for VHDL-1993.
:: It is required to compile the DSP library first !
::
:: Required environment variables :
::
::   VCOM_EXE    e.g. set VCOM_EXE=ghdl.exe
::
::   VCOM_FLAGS  e.g. set VCOM_FLAGS=-a --std=93 --workdir=work -Pwork --work=
::               Note that the flags need to be appended with the library name
::               into which the files shall be compiled.
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
echo.INFO: Start compiling Complex Library CPLX ...

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
:: General / Entities
%COMPILE% %SCRIPTPATH%\cplx_pkg_1993.vhdl
%COMPILE% %SCRIPTPATH%\cplx_mult1_accu.vhdl
%COMPILE% %SCRIPTPATH%\cplx_mult2_accu.vhdl
%COMPILE% %SCRIPTPATH%\cplx_mult4_accu.vhdl
%COMPILE% %SCRIPTPATH%\cplx_multN.vhdl
%COMPILE% %SCRIPTPATH%\cplx_multN_accu.vhdl
%COMPILE% %SCRIPTPATH%\cplx_multN_sum.vhdl
%COMPILE% %SCRIPTPATH%\cplx_weightN.vhdl
%COMPILE% %SCRIPTPATH%\cplx_weightN_sum.vhdl
:: Architectures
%COMPILE% %SCRIPTPATH%\cplx_mult1_accu.sdr.vhdl
%COMPILE% %SCRIPTPATH%\cplx_mult2_accu.sdr.vhdl
%COMPILE% %SCRIPTPATH%\cplx_mult4_accu.sdr.vhdl
%COMPILE% %SCRIPTPATH%\cplx_multN.sdr.vhdl
%COMPILE% %SCRIPTPATH%\cplx_multN_accu.sdr.vhdl
%COMPILE% %SCRIPTPATH%\cplx_multN_sum.sdr.vhdl
%COMPILE% %SCRIPTPATH%\cplx_weightN.sdr.vhdl
%COMPILE% %SCRIPTPATH%\cplx_weightN_sum.sdr.vhdl

:END
@EXIT /B
