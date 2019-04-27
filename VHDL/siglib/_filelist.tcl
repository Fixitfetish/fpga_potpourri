# Create file list of the SIGLIB Library.

set LIB siglib

# path/location of this script
set SIGLIB_PATH [ file dirname [dict get [ info frame 0 ] file ] ]

# create local file list
set files [list]

# entities
lappend files lfsr_pkg.vhdl
lappend files lfsr.vhdl
lappend files sincos.vhdl

# create final file list with absolute path
set filelist [list]
foreach f $files {
  lappend filelist [file normalize "${SIGLIB_PATH}/$f"]
}
