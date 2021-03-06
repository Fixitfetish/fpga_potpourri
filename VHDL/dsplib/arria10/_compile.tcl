#+++ FOR VHDL SIMULATORS ONLY +++#
# This script compiles all Arria 10 specific architectures of the DSP Library.
# It is required to compile the generic DSP entities first !

# library name
set LIB "dsplib"
set VHDL 1993

# path/location of this script
set ARRIA10_PATH [ file dirname [dict get [ info frame 0 ] file ] ]

if ![file exists $ALTERA_LIB] {
  error "Path to Altera libraries not found - please provide global variable ALTERA_LIB"
}

# Altera VHDL library
vmap twentynm $ALTERA_LIB/vhdl_libs/twentynm

# Altera Verilog library
vmap twentynm_ver $ALTERA_LIB/verilog_libs/twentynm_ver

# create file list
set filelist [list]

source $ARRIA10_PATH/_filelist.tcl 

# compile file list
if {[string equal $VHDL 2008]} {
  set SWITCHES "-2008 -explicit -dbg"
} else {
  set SWITCHES "-93 -explicit -dbg"
}

vcom $SWITCHES -work $LIB $filelist
