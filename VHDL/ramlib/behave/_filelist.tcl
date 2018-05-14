# Create file list with the behavioral RAMLIB architectures.
# It is required to compile the file list of all the generic RAM entities first !

set LIB ramlib

# path/location of this script
set BEHAVE_PATH [ file dirname [dict get [ info frame 0 ] file ] ]

# create local file list
set files [list]

# behavioral models
lappend files fifo_sync.behave.vhdl
lappend files ram_sdp.behave.vhdl

# create final file list with absolute path
# set filelist [list]
foreach f $files {
  lappend filelist [file normalize "${BEHAVE_PATH}/$f"]
}
