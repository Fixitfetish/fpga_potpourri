###############################################################################
# Simulation script for ALDEC Riviera_PRO simulator 
#
# 1. Ensure that the need ALTERA or XILINX libraries are in place.
#    (see ALDEC, ALTERA_LIB and XILINX_LIB parameters below)
# 2. Delete all local LIB folders (to have a clean basis)
# 3. Start Riviera-Pro from the folder where this TCL script is located.
# 4. Start simulation at RIVIERA_PRO TCL console
#    > source sim.tcl
###############################################################################


###############################################################################
# The following lines may need to be changed
###############################################################################
set ALTERA_LIB ${aldec}/vlib/altera_14v1
set XILINX_LIB ${aldec}/vlib/VIVADO/2017.2

# top-level entity
set top signed_mult_sum_tb

# set testbench generic values
set generics [list]
lappend generics -G/$top/NUM_MULT=18
lappend generics -G/$top/NUM_INPUT_REG=1
lappend generics -G/$top/HIGH_SPEED_MODE=true

###############################################################################
# DO NOT EDIT MODIFY the following line
###############################################################################
if ![file isdirectory $ALTERA_LIB] {
  error "Path to Altera libraries not found - please provide global variable ALTERA_LIB"
}
if ![file isdirectory $XILINX_LIB] {
  error "Path to XILINX libraries not found - please provide global variable XILINX_LIB"
}

# Map Altera libraries
#amap altera_lnsim $ALTERA_LIB/vhdl_libs/altera_lnsim
#amap altera_mf $ALTERA_LIB/vhdl_libs/altera_mf
amap stratixv $ALTERA_LIB/vhdl_libs/stratixv
#amap altera_lnsim_ver $ALTERA_LIB/verilog_libs/altera_lnsim_ver
#amap altera_mf_ver $ALTERA_LIB/verilog_libs/altera_mf_ver
amap stratixv_ver $ALTERA_LIB/verilog_libs/stratixv_ver

# Map Xilinx libraries
#amap secureip $XILINX_LIB/secureip
#amap unifast $XILINX_LIB/unifast
#amap unimacro $XILINX_LIB/unimacro
amap unisim $XILINX_LIB/unisim
#amap xpm $XILINX_LIB/xpm

# Create work library
alib work
amap work work

# Compile all source files
source ../../baselib/_compile.tcl
source ../../dsplib/_compile.tcl
source ../../dsplib/behave/_compile.tcl
source ../../dsplib/ultrascale/_compile.tcl

acom -93 -dbg -explicit $top.vhdl

# Run Riviera_PRO simulator
vsim +access +r -t ps -dbg -ieee_nowarn $generics $top

do wave.tcl
run 1 us
