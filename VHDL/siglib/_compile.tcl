# +++ FOR VHDL SIMULATION ONLY +++ #
# This script compiles the SIGLIB Library for VHDL-1993.

# library name
set LIB "siglib"
vlib $LIB

# path/location of this script
set SCRIPTPATH [ file dirname [dict get [ info frame 0 ] file ] ]

# create file list
set filelist [list]
lappend filelist $SCRIPTPATH/sincos.vhdl

# compile file list
set SWITCHES "-93 -explicit -dbg"
vcom $SWITCHES -work $LIB $filelist
