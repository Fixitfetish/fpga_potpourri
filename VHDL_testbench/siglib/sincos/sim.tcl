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

set TEST_LIB "work"
set CPLX_LIB "cplxlib"
vlib $TEST_LIB
vlib $CPLX_LIB

source $LIBSRC/baselib/_compile_1993.tcl
source $LIBSRC/siglib/_compile.tcl

# compile testbench
vcom -93 -dbg -explicit -work cplxlib $LIBSRC/cplxlib/cplx_pkg_1993.vhdl
vcom -93 -dbg -explicit -work $TEST_LIB ../../cplxlib/cplx_logger4.vhdl
vcom -93 -dbg -explicit -work $TEST_LIB sincos_tb.vhdl
  
# Initialize simulation
vsim +access +r -t ps sincos_tb

# Show waveforms
do wave.do

# Run simulation
run -all
