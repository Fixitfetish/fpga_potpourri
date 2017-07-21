# Typically ALDEC Riviera-Pro reports the installation path with the variable $aldec

set TOOLPATH $aldec

if ![file exists $TOOLPATH] {
  error "Tool path not found. Please provide path to compiler/simulator."
}

# library path
set LIBROOT [ file normalize ../.. ]

set TEST_LIB "work"
vlib $TEST_LIB

# ALTERA library path
#  set ALTERA_LIB $TOOLPATH/vlib/altera_16v0
set ALTERA_LIB $TOOLPATH/vlib/altera_14v1

# XILINX library path
set XILINX_LIB $TOOLPATH/vlib/xilinx_16v4

source $LIBROOT/baselib/_compile_1993.tcl
source $LIBROOT/dsplib/_compile_1993.tcl
source $LIBROOT/dsplib/_compile_behave.tcl
# source $LIBROOT/dsplib/_compile_stratixv.tcl
# source $LIBROOT/dsplib/_compile_ultrascale.tcl
source $LIBROOT/cplxlib/_compile_1993.tcl

vcom -93 -explicit -dbg -work $TEST_LIB $LIBROOT/cplxlib_tb/cplx_stimuli.vhdl
vcom -93 -explicit -dbg -work $TEST_LIB $LIBROOT/cplxlib_tb/cplx_logger.vhdl
vcom -93 -explicit -dbg -work $TEST_LIB dftmtx8.vhdl
vcom -93 -explicit -dbg -work $TEST_LIB dft8_v1.vhdl
vcom -93 -explicit -dbg -work $TEST_LIB dft8_v2.vhdl
vcom -93 -explicit -dbg -work $TEST_LIB dft8_tb.vhdl

# get read access to all signals
vsim +access +r dft8_tb

# waveforms
do wave.tcl

run -all
