# +++ FOR VHDL SIMULATION ONLY +++ #
# This script compiles all generic entities of the DSPLIB Library for VHDL-1993.
# The device specific architectures are compiled separately.
# It is required to compile the BASELIB library first !

# Library name into which the entities are compiled
set LIB "dsplib"
vlib $LIB

# path/location of this script
set SCRIPTPATH [ file dirname [dict get [ info frame 0 ] file ] ]

# create file list
set filelist [list]
lappend filelist $SCRIPTPATH/signed_accu.vhdl
lappend filelist $SCRIPTPATH/signed_adder_tree.vhdl
lappend filelist $SCRIPTPATH/signed_mult1add1_accu.vhdl
lappend filelist $SCRIPTPATH/signed_mult1add1_sum.vhdl
lappend filelist $SCRIPTPATH/signed_mult1_accu.vhdl
lappend filelist $SCRIPTPATH/signed_mult2.vhdl
lappend filelist $SCRIPTPATH/signed_mult2_accu.vhdl
lappend filelist $SCRIPTPATH/signed_mult2_sum.vhdl
lappend filelist $SCRIPTPATH/signed_mult3.vhdl
lappend filelist $SCRIPTPATH/signed_mult4_accu.vhdl
lappend filelist $SCRIPTPATH/signed_mult4_sum.vhdl
lappend filelist $SCRIPTPATH/signed_mult8_accu.vhdl
lappend filelist $SCRIPTPATH/signed_mult16_accu.vhdl
lappend filelist $SCRIPTPATH/signed_multn_chain_accu.vhdl
lappend filelist $SCRIPTPATH/signed_multN.vhdl
lappend filelist $SCRIPTPATH/signed_multN_accu.vhdl
lappend filelist $SCRIPTPATH/signed_multN_sum.vhdl
lappend filelist $SCRIPTPATH/signed_preadd_mult1_accu.vhdl

# compile file list
set SWITCHES "-93 -explicit -dbg"
vcom $SWITCHES -work $LIB $filelist
