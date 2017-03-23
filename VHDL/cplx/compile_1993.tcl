# +++ FOR VHDL SIMULATORS ONLY +++ #

# This script compiles the CPLX Library for VHDL-1993.
# It is required to compile the DSP library first !

# path/location of this script
set BASEPATH [ file dirname [dict get [ info frame 0 ] file ] ]

set CPLXLIB "fixitfetish"
# vlib $CPLXLIB

# create file list
set filelist [list]

# General / Entities
lappend filelist $BASEPATH/cplx_pkg_1993.vhdl
lappend filelist $BASEPATH/cplx_mult1_accu.vhdl
lappend filelist $BASEPATH/cplx_mult2_accu.vhdl
lappend filelist $BASEPATH/cplx_mult4_accu.vhdl
lappend filelist $BASEPATH/cplx_multN_accu.vhdl
lappend filelist $BASEPATH/cplx_multN_sum.vhdl

# Architectures
lappend filelist $BASEPATH/cplx_mult1_accu.sdr.vhdl
lappend filelist $BASEPATH/cplx_mult2_accu.sdr.vhdl
lappend filelist $BASEPATH/cplx_mult4_accu.sdr.vhdl
lappend filelist $BASEPATH/cplx_multN_accu.sdr.vhdl
lappend filelist $BASEPATH/cplx_multN_sum.sdr.vhdl

# compile file list
set SWITCHES "-93 -explicit -dbg"
vcom $SWITCHES -work $CPLXLIB $filelist
