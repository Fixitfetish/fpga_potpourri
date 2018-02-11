# Create file list of the BASELIB Library.

set LIB baselib

# path/location of this script
set BASELIB_PATH [ file dirname [dict get [ info frame 0 ] file ] ]

# create local file list
set files [list]

# entities
lappend files [ file normalize ${BASELIB_PATH}/ieee_extension_types_1993.vhdl ]
lappend files [ file normalize ${BASELIB_PATH}/ieee_extension.vhdl ]
lappend files [ file normalize ${BASELIB_PATH}/counter.vhdl ]
lappend files [ file normalize ${BASELIB_PATH}/enable_burst_generator.vhdl ]
lappend files [ file normalize ${BASELIB_PATH}/gray_code.vhdl ]
lappend files [ file normalize ${BASELIB_PATH}/string_conversion_pkg.vhdl ]
lappend files [ file normalize ${BASELIB_PATH}/file_io_pkg.vhdl ]
