# +++ FOR VHDL SIMULATORS ONLY +++ #
# This script compiles the CPLXLIB Library for VHDL-1993.
# It is required to compile the DSPLIB library first !

# path/location of this script
set SCRIPTPATH [ file dirname [dict get [ info frame 0 ] file ] ]

set LIB "cplxlib"
vlib $LIB
set VHDL 1993

# create file list
set filelist [list]

# General
lappend filelist $SCRIPTPATH/${VHDL}/cplx_pkg_${VHDL}.vhdl
lappend filelist $SCRIPTPATH/cplx_pipeline.vhdl

# Entities
lappend filelist $SCRIPTPATH/cplx_vector_serialization.vhdl
lappend filelist $SCRIPTPATH/cplx_vectorization.vhdl
lappend filelist $SCRIPTPATH/cplx_mult.vhdl
lappend filelist $SCRIPTPATH/cplx_mult_accu.vhdl
lappend filelist $SCRIPTPATH/cplx_mult_sum.vhdl
lappend filelist $SCRIPTPATH/cplx_weight.vhdl
lappend filelist $SCRIPTPATH/cplx_weight_accu.vhdl
lappend filelist $SCRIPTPATH/cplx_weight_sum.vhdl

# Architectures
if {[string equal $VHDL 2008]} {
  lappend filelist $SCRIPTPATH/${VHDL}/cplx_vector_serialization.rtl.vhdl
  lappend filelist $SCRIPTPATH/${VHDL}/cplx_vectorization.rtl.vhdl
  lappend filelist $SCRIPTPATH/${VHDL}/cplx_mult.sdr.vhdl
  lappend filelist $SCRIPTPATH/${VHDL}/cplx_mult_accu.sdr.vhdl
  lappend filelist $SCRIPTPATH/${VHDL}/cplx_mult_sum.sdr.vhdl
  lappend filelist $SCRIPTPATH/${VHDL}/cplx_weight.sdr.vhdl
  lappend filelist $SCRIPTPATH/${VHDL}/cplx_weight_accu.sdr.vhdl
  lappend filelist $SCRIPTPATH/${VHDL}/cplx_weight_sum.sdr.vhdl
  # compile file list
  set SWITCHES "-2008 -explicit -dbg"
} else {
  lappend filelist $SCRIPTPATH/${VHDL}/cplx_vector_serialization.rtl_1993.vhdl
  lappend filelist $SCRIPTPATH/${VHDL}/cplx_vectorization.rtl_1993.vhdl
  lappend filelist $SCRIPTPATH/${VHDL}/cplx_mult.sdr_1993.vhdl
  lappend filelist $SCRIPTPATH/${VHDL}/cplx_mult_accu.sdr_1993.vhdl
  lappend filelist $SCRIPTPATH/${VHDL}/cplx_mult_sum.sdr_1993.vhdl
  lappend filelist $SCRIPTPATH/${VHDL}/cplx_weight.sdr_1993.vhdl
  lappend filelist $SCRIPTPATH/${VHDL}/cplx_weight_accu.sdr_1993.vhdl
  lappend filelist $SCRIPTPATH/${VHDL}/cplx_weight_sum.sdr_1993.vhdl
  # compile file list
  set SWITCHES "-93 -explicit -dbg"
}

vcom $SWITCHES -work $LIB $filelist
