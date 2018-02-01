#+++ FOR VHDL SIMULATORS ONLY +++#
# This script compiles all UltraScale specific architectures of the DSPLIB Library.
# It is required to compile the generic DSP entities first !

# library name
set LIB "dsplib"
set VHDL 2008

# path/location of this script
set ULTRASCALE_PATH [ file dirname [dict get [ info frame 0 ] file ] ]

if ![file exists $XILINX_LIB] {
  error "Path to Xilinx libraries not found - please provide global variable XILINX_LIB"
}

vmap unisim $XILINX_LIB/unisim

# create file list
set filelist [list]

source $ULTRASCALE_PATH/_filelist.tcl 

# compile file list
if {[string equal $VHDL 2008]} {
  set SWITCHES "-2008 -explicit -dbg"
} else {
  set SWITCHES "-93 -explicit -dbg"
}

vcom $SWITCHES -work $LIB $filelist
