@echo off

:: create work directory
if not exist work\ (
  mkdir work
)
:: create output directory
if not exist output\ (
  mkdir output
)
set GHDL=%GHDL_PATH%\bin\ghdl
set GTKWAVE=%GTKWAVE_PATH%\bin\gtkwave

:: standard options
set FLAGS=--std=93 --workdir=work -Pwork

@echo on

:: analyze files of fixitfetish library
%GHDL% -a %FLAGS% --work=fixitfetish ..\VHDL\fifo_sync.vhdl
%GHDL% -a %FLAGS% --work=fixitfetish ..\VHDL\fifo_sync_behave.vhdl

:: analyze testbench
%GHDL% -a %FLAGS% fifo_sync_tb.vhdl

:: run testbench
%GHDL% -r %FLAGS% fifo_sync_tb --stop-time=500ns --vcd=output\fifo_sync.vcd

:: start waveform viewer
%GTKWAVE% output\fifo_sync.vcd
