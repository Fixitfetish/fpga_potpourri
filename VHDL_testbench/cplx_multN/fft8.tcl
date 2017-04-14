# default ALDEC Riviera-Pro path
set ALDEC "C:/Aldec/Riviera-PRO-2016.06-x64"
if ![file exists $ALDEC] {
  error "Aldec Riviera-Pro not found - please set variable ALDEC in sim.tcl correctly"
}

set LIBPATH  "../../VHDL"

set TEST_LIB "work"
vlib $TEST_LIB

# ALTERA library path
#  set ALTERA_LIB $ALDEC/vlib/altera_16v0
set ALTERA_LIB $ALDEC/vlib/altera_14v1

# XILINX library path
set XILINX_LIB $ALDEC/vlib/xilinx_16v4

source $LIBPATH/dsp/compile_1993.tcl
source $LIBPATH/dsp/stratixv/compile.tcl
# source $LIBPATH/dsp/ultrascale/compile.tcl
# source $LIBPATH/dsp/behave/compile.tcl
source $LIBPATH/cplx/compile_1993.tcl

vcom -93 -explicit -dbg -work fixitfetish $LIBPATH/string_conversion_pkg.vhdl

vcom -93 -explicit -dbg -work $TEST_LIB dftmtx8.vhdl
vcom -93 -explicit -dbg -work $TEST_LIB fft8_v1.vhdl
vcom -93 -explicit -dbg -work $TEST_LIB ifft8_v1.vhdl
vcom -93 -explicit -dbg -work $TEST_LIB ../cplx_logger4.vhdl

vcom -93 -explicit -dbg -work $TEST_LIB fft8_tb.vhdl

# get read access to all signals
vsim +access +r fft8_tb

# waveforms
do fft8.do

run 0.1 us
