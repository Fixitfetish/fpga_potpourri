# +++ FOR VHDL SIMULATORS ONLY +++ #
# This script compiles the CPLX Library for VHDL-1993.
# It is required to compile the DSP library first !

# path/location of this script
set SCRIPTPATH [ file dirname [dict get [ info frame 0 ] file ] ]

set CPLXLIB "fixitfetish"
# vlib $CPLXLIB

# create file list
set filelist [list]

# General / Entities
lappend filelist $SCRIPTPATH/cplx_pkg_1993.vhdl
lappend filelist $SCRIPTPATH/cplx_mult1_accu.vhdl
lappend filelist $SCRIPTPATH/cplx_mult2_accu.vhdl
lappend filelist $SCRIPTPATH/cplx_mult4_accu.vhdl
lappend filelist $SCRIPTPATH/cplx_multN.vhdl
lappend filelist $SCRIPTPATH/cplx_multN_accu.vhdl
lappend filelist $SCRIPTPATH/cplx_multN_sum.vhdl
lappend filelist $SCRIPTPATH/cplx_weightN.vhdl
lappend filelist $SCRIPTPATH/cplx_weightN_sum.vhdl

# Architectures
lappend filelist $SCRIPTPATH/cplx_mult1_accu.sdr.vhdl
lappend filelist $SCRIPTPATH/cplx_mult2_accu.sdr.vhdl
lappend filelist $SCRIPTPATH/cplx_mult4_accu.sdr.vhdl
lappend filelist $SCRIPTPATH/cplx_multN.sdr.vhdl
lappend filelist $SCRIPTPATH/cplx_multN_accu.sdr.vhdl
lappend filelist $SCRIPTPATH/cplx_multN_sum.sdr.vhdl
lappend filelist $SCRIPTPATH/cplx_weightN.sdr.vhdl
lappend filelist $SCRIPTPATH/cplx_weightN_sum.sdr.vhdl

# compile file list
set SWITCHES "-93 -explicit -dbg"
vcom $SWITCHES -work $CPLXLIB $filelist