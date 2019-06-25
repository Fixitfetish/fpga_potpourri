# Create file list of the CPLXLIB Library.
# It is required to compile the DSP, RAM and SIG library first !

set VHDL 2008
set LIB cplxlib

# path/location of this script
set CPLXLIB_PATH [ file dirname [dict get [ info frame 0 ] file ] ]

# create local file list
set files [list]

# General
lappend files ${VHDL}/cplx_pkg_${VHDL}.vhdl
lappend files ${VHDL}/cplx_pkg_m.vhdl
lappend files cplx_pipeline.vhdl
lappend files cplx_vector_pipeline.vhdl
lappend files cplx_exp.vhdl
lappend files cplx_fifo_sync.vhdl
lappend files cplx_noise_normal.vhdl
lappend files cplx_noise_uniform.vhdl

# Entities
lappend files cplx_vector_serialization.vhdl
lappend files cplx_vectorization.vhdl
lappend files cplx_mult.vhdl
lappend files cplx_mult_accu.vhdl
lappend files cplx_mult_sum.vhdl
lappend files cplx_weight.vhdl
lappend files cplx_weight_accu.vhdl
lappend files cplx_weight_sum.vhdl

# Architectures
if {[string equal $VHDL 2008]} {
  lappend files ${VHDL}/cplx_vector_serialization.rtl.vhdl
  lappend files ${VHDL}/cplx_vectorization.rtl.vhdl
  lappend files ${VHDL}/cplx_mult.sdr.vhdl
  lappend files ${VHDL}/cplx_mult_accu.sdr.vhdl
  lappend files ${VHDL}/cplx_mult_sum.sdr.vhdl
  lappend files ${VHDL}/cplx_weight.sdr.vhdl
  lappend files ${VHDL}/cplx_weight_accu.sdr.vhdl
  lappend files ${VHDL}/cplx_weight_sum.sdr.vhdl
} else {
  lappend files ${VHDL}/cplx_vector_serialization.rtl_1993.vhdl
  lappend files ${VHDL}/cplx_vectorization.rtl_1993.vhdl
  lappend files ${VHDL}/cplx_mult.sdr_1993.vhdl
  lappend files ${VHDL}/cplx_mult_accu.sdr_1993.vhdl
  lappend files ${VHDL}/cplx_mult_sum.sdr_1993.vhdl
  lappend files ${VHDL}/cplx_weight.sdr_1993.vhdl
  lappend files ${VHDL}/cplx_weight_accu.sdr_1993.vhdl
  lappend files ${VHDL}/cplx_weight_sum.sdr_1993.vhdl
}

# create final file list with absolute path
set filelist [list]
foreach f $files {
  lappend filelist [file normalize "${CPLXLIB_PATH}/$f"]
}
