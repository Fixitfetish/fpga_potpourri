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

:: GHDL simulator settings
set VSIM_EXE=%GHDL_PATH%\bin\ghdl.exe
set VSIM_FLAGS=-r --std=93 --workdir=work -Pwork
set SIMULATE=%VSIM_EXE% %VSIM_FLAGS%

:: Waveform viewer
set GTKWAVE=%GTKWAVE_PATH%\bin\gtkwave

:: waveform file
set VCD=output\dft8.vcd
if exist %VCD% (
  del %VCD%
)

:: analyze library files
@call %LIBROOT%\baselib\_compile.bat
@call %LIBROOT%\dsplib\_compile_behave.bat
@call %LIBROOT%\cplxlib\_compile.bat

:: analyze testbench
@echo.--------------------------------------------------------------------------
@echo.INFO: Starting to compile the testbench ...
@echo on

@set LIB=work
%COMPILE%%LIB% %LIBROOT%\cplxlib_tb\cplx_stimuli.vhdl
%COMPILE%%LIB% %LIBROOT%\cplxlib_tb\cplx_logger.vhdl
%COMPILE%%LIB% dftmtx8.vhdl
%COMPILE%%LIB% dft8_v1.vhdl
%COMPILE%%LIB% dft8_v2.vhdl
%COMPILE%%LIB% dft8_tb.vhdl

@echo.
@echo.INFO: Compilation finished - ready to start simulation. 
@pause

:: run testbench
@echo.--------------------------------------------------------------------------
@echo.INFO: Starting simulation ...
%SIMULATE% dft8_tb --vcd=%VCD%
::%SIMULATE% dft8_tb --stop-time=500ns --vcd=%VCD%

@pause
@goto END

:: start waveform viewer
::@if not exist %VCD% goto END
::%GTKWAVE% %VCD% dft8.gtkw

:END