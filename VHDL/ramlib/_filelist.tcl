# Create file list of the generic RAMLIB entities.

set LIB ramlib

# path/location of this script
set RAMLIB_PATH [ file dirname [dict get [ info frame 0 ] file ] ]

# create local file list
set files [list]

# entities
lappend files fifo_sync.vhdl
lappend files ram_sdp.vhdl
lappend files burst_forming_arbiter.vhdl

# create final file list with absolute path
set filelist [list]
foreach f $files {
  lappend filelist [file normalize "${RAMLIB_PATH}/$f"]
}
