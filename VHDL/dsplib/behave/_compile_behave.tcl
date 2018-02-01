#+++ FOR VHDL SIMULATORS ONLY +++#
# This script compiles all behavioral architectures of the DSP Library.
# It is required to compile the generic DSP entities first !

# library name
set LIB "dsplib"
set VHDL 1993

# path/location of this script
set BEHAVE_PATH [ file dirname [dict get [ info frame 0 ] file ] ]

# create file list (with list compilation is faster)
set filelist [list]

source $BEHAVE_PATH/_filelist.tcl 

# compile file list
if {[string equal $VHDL 2008]} {
  set SWITCHES "-2008 -explicit -dbg"
} else {
  set SWITCHES "-93 -explicit -dbg"
}

vcom $SWITCHES -work $LIB $filelist
