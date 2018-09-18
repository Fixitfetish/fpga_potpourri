# Create file list with the UltraScale specific architectures.
# It is required to compile the file list of all the generic DSP entities first !

set LIB ramlib

# path/location of this script
set ULTRASCALE_PATH [ file dirname [dict get [ info frame 0 ] file ] ]

# create local file list
set files [list]

# ultrascale specific
lappend files ram_sdp.ultrascale.vhdl

# create final file list with absolute path
# set filelist [list]
foreach f $files {
  lappend filelist [file normalize "${ULTRASCALE_PATH}/$f"]
}
