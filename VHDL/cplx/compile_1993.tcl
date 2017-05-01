# +++ FOR VHDL SIMULATORS ONLY +++ #
# This script compiles the CPLXLIB Library for VHDL-1993.
# It is required to compile the DSPLIB library first !

# path/location of this script
set SCRIPTPATH [ file dirname [dict get [ info frame 0 ] file ] ]

set LIB "cplxlib"
# vlib $LIB

# create file list
set filelist [list]

# General
lappend filelist $SCRIPTPATH/cplx_pkg_1993.vhdl
lappend filelist $SCRIPTPATH/cplx_vector_serialization.vhdl
lappend filelist $SCRIPTPATH/cplx_vectorization.vhdl

# Entities
lappend filelist $SCRIPTPATH/cplx_mult.vhdl
lappend filelist $SCRIPTPATH/cplx_mult_accu.vhdl
lappend filelist $SCRIPTPATH/cplx_mult_sum.vhdl
lappend filelist $SCRIPTPATH/cplx_mult1_accu.vhdl
lappend filelist $SCRIPTPATH/cplx_mult2_accu.vhdl
lappend filelist $SCRIPTPATH/cplx_mult4_accu.vhdl
lappend filelist $SCRIPTPATH/cplx_weight.vhdl
lappend filelist $SCRIPTPATH/cplx_weight_sum.vhdl

# Architectures
lappend filelist $SCRIPTPATH/cplx_mult.sdr.vhdl
lappend filelist $SCRIPTPATH/cplx_mult_accu.sdr.vhdl
lappend filelist $SCRIPTPATH/cplx_mult_sum.sdr.vhdl
lappend filelist $SCRIPTPATH/cplx_mult1_accu.sdr.vhdl
lappend filelist $SCRIPTPATH/cplx_mult2_accu.sdr.vhdl
lappend filelist $SCRIPTPATH/cplx_mult4_accu.sdr.vhdl
lappend filelist $SCRIPTPATH/cplx_weight.sdr.vhdl
lappend filelist $SCRIPTPATH/cplx_weight_sum.sdr.vhdl

# compile file list
set SWITCHES "-93 -explicit -dbg"
vcom $SWITCHES -work $LIB $filelist
