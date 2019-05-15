# Create file list of the BASELIB Library.

set LIB baselib

# path/location of this script
set BASELIB_PATH [ file dirname [dict get [ info frame 0 ] file ] ]

# create local file list
set files [list]

# entities
lappend files ieee_extension_types_2008.vhdl
#lappend files ieee_extension_types_1993.vhdl
lappend files ieee_extension.vhdl
lappend files pipereg_pkg.vhdl
#lappend files bitpotpourri.vhdl
lappend files counter.vhdl
lappend files enable_burst_generator.vhdl
lappend files gray_code.vhdl
lappend files string_conversion_pkg.vhdl
lappend files file_io_pkg.vhdl
lappend files slv_pack.vhdl
lappend files slv_unpack.vhdl

# create final file list with absolute path
set filelist [list]
foreach f $files {
  lappend filelist [file normalize "${BASELIB_PATH}/$f"]
}
