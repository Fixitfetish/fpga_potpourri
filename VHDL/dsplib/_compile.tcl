# +++ FOR VHDL SIMULATION ONLY +++ #
# This script compiles all generic entities of the DSPLIB Library.
# The device specific architectures are compiled separately.
# It is required to compile the BASELIB library first !

# Library name into which the entities are compiled
set LIB "dsplib"
vlib $LIB
set VHDL 2008

# path/location of this script
set DSPLIB_PATH [ file dirname [dict get [ info frame 0 ] file ] ]

# create file list
set filelist [list]

source $DSPLIB_PATH/_filelist.tcl 

# compile file list
if {[string equal $VHDL 2008]} {
  set SWITCHES "-2008 -explicit -dbg"
} else {
  set SWITCHES "-93 -explicit -dbg"
}

vcom $SWITCHES -work $LIB $filelist
