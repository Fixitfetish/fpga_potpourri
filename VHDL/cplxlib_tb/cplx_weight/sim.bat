@echo off

set LIBROOT=..\..

:: GHDL compiler settings
set VCOM_EXE=%GHDL_PATH%\bin\ghdl.exe
set VCOM_FLAGS=-a --std=93 --workdir=work -Pwork --work=
set COMPILE=%VCOM_EXE% %VCOM_FLAGS%

:: GHDL simulator settings
set VSIM_EXE=%GHDL_PATH%\bin\ghdl.exe
set VSIM_FLAGS=-r --std=93 --workdir=work -Pwork
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
