# Typically ALDEC Riviera-Pro reports the installation path with the variable $aldec

set TOOLPATH $aldec

if ![file exists $TOOLPATH] {
  error "Tool path not found. Please provide path to compiler/simulator."
}

# library path
set LIBROOT ../../..
set LIBSRC $LIBROOT/VHDL

set TEST_LIB "work"
vlib $TEST_LIB

# ALTERA library path
#  set ALTERA_LIB $TOOLPATH/vlib/altera_16v0
set ALTERA_LIB $TOOLPATH/vlib/altera_14v1

# XILINX library path
set XILINX_LIB $TOOLPATH/vlib/xilinx_16v4

source $LIBSRC/baselib/_compile_1993.tcl
source $LIBSRC/dsplib/_compile_1993.tcl
# source $LIBSRC/dsplib/stratixv/_compile.tcl
# source $LIBSRC/dsplib/ultrascale/_compile.tcl
source $LIBSRC/dsplib/behave/_compile.tcl
source $LIBSRC/cplxlib/_compile_1993.tcl

vcom -93 -explicit -dbg -work $TEST_LIB ../cplx_stimuli.vhdl
vcom -93 -explicit -dbg -work $TEST_LIB ../cplx_logger.vhdl
vcom -93 -explicit -dbg -work $TEST_LIB weight_tb.vhdl

# get read access to all signals
vsim +access +r weight_tb

# waveforms
do weight.do

run -all
