# +++ FOR VHDL SIMULATION ONLY +++ #
# This script compiles the BASELIB Library for VHDL-1993.

# Library name into which the entities are compiled
set LIB "baselib"
vlib $LIB
set VHDL 1993

# path/location of this script
set SCRIPTPATH [ file dirname [dict get [ info frame 0 ] file ] ]

# create file list
set filelist [list]
lappend filelist $SCRIPTPATH/ieee_extension_types_${VHDL}.vhdl
lappend filelist $SCRIPTPATH/ieee_extension.vhdl
lappend filelist $SCRIPTPATH/string_conversion_pkg.vhdl
lappend filelist $SCRIPTPATH/file_io_pkg.vhdl

# compile file list
if {[string equal $VHDL 2008]} {
  set SWITCHES "-2008 -explicit -dbg"
} else {
  set SWITCHES "-93 -explicit -dbg"
}
vcom $SWITCHES -work $LIB $filelist
