# Create file list of the generic RAMLIB entities.

set LIB ramlib

# path/location of this script
set RAMLIB_PATH [ file dirname [dict get [ info frame 0 ] file ] ]

# create local file list
set files [list]

# entities
lappend files fifo_logic_sync.vhdl
lappend files fifo_sync.vhdl
lappend files ram_sdp.vhdl
lappend files arbiter_mux_stream_to_burst.vhdl
lappend files arbiter_demux_single_to_stream.vhdl
lappend files arbiter_read_single_to_burst.vhdl
lappend files ram_arbiter_pkg.vhdl
lappend files ram_arbiter_write.vhdl
lappend files ram_arbiter_write_data_width_adapter.vhdl

# create final file list with absolute path
set filelist [list]
foreach f $files {
  lappend filelist [file normalize "${RAMLIB_PATH}/$f"]
}
