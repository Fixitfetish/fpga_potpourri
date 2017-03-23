# +++ FOR VHDL SIMULATION ONLY +++ #

# This script compiles all generic entities of the DSP Library for VHDL-1993.
# The device specific architectures are compiled separately.

# path/location of this script
set BASEPATH [ file dirname [dict get [ info frame 0 ] file ] ]

set DSPLIB "fixitfetish"
vlib $DSPLIB

# create file list
set filelist [list]
lappend filelist $BASEPATH/../ieee_extension_types_1993.vhdl
lappend filelist $BASEPATH/../ieee_extension.vhdl
lappend filelist $BASEPATH/signed_mult1_accu.vhdl
lappend filelist $BASEPATH/signed_mult1add1_accu.vhdl
lappend filelist $BASEPATH/signed_mult1add1_sum.vhdl
lappend filelist $BASEPATH/signed_mult2.vhdl
lappend filelist $BASEPATH/signed_mult2_accu.vhdl
lappend filelist $BASEPATH/signed_mult2_sum.vhdl
lappend filelist $BASEPATH/signed_mult3.vhdl
lappend filelist $BASEPATH/signed_mult4_accu.vhdl
lappend filelist $BASEPATH/signed_mult4_sum.vhdl
lappend filelist $BASEPATH/signed_mult8_accu.vhdl
lappend filelist $BASEPATH/signed_mult16_accu.vhdl
lappend filelist $BASEPATH/signed_multN.vhdl
lappend filelist $BASEPATH/signed_multN_accu.vhdl
lappend filelist $BASEPATH/signed_multN_sum.vhdl
lappend filelist $BASEPATH/signed_preadd_mult1_accu.vhdl

# compile file list
set SWITCHES "-93 -explicit -dbg"
vcom $SWITCHES -work $DSPLIB $filelist
