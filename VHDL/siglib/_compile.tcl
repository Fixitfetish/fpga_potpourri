# +++ FOR VHDL SIMULATION ONLY +++ #
# This script compiles the SIGLIB Library for VHDL-1993.

# Library name into which the entities are compiled
set LIB "siglib"
vlib $LIB

# path/location of this script
set SCRIPTPATH [ file dirname [dict get [ info frame 0 ] file ] ]

# create file list
set filelist [list]
lappend filelist $SCRIPTPATH/lfsr_pkg.vhdl
lappend filelist $SCRIPTPATH/lfsr.vhdl
lappend filelist $SCRIPTPATH/prbs_3gpp.vhdl
lappend filelist $SCRIPTPATH/sincos.vhdl

# compile file list
set SWITCHES "-08 -explicit -dbg"
vcom $SWITCHES -work $LIB $filelist
