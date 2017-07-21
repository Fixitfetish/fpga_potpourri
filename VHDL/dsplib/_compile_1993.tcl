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

lappend filelist $SCRIPTPATH/dsp_output_logic.vhdl
lappend filelist $SCRIPTPATH/signed_accu.vhdl
lappend filelist $SCRIPTPATH/signed_adder_tree.vhdl

lappend filelist $SCRIPTPATH/delay_dsp/delay_dsp.vhdl
lappend filelist $SCRIPTPATH/signed_mult1add1_accu/signed_mult1add1_accu.vhdl
lappend filelist $SCRIPTPATH/signed_mult1add1_sum/signed_mult1add1_sum.vhdl
lappend filelist $SCRIPTPATH/signed_mult1_accu/signed_mult1_accu.vhdl
lappend filelist $SCRIPTPATH/signed_mult2/signed_mult2.vhdl
lappend filelist $SCRIPTPATH/signed_mult2_accu/signed_mult2_accu.vhdl
lappend filelist $SCRIPTPATH/signed_mult2_sum/signed_mult2_sum.vhdl
lappend filelist $SCRIPTPATH/signed_mult3/signed_mult3.vhdl
lappend filelist $SCRIPTPATH/signed_mult4_sum/signed_mult4_sum.vhdl
lappend filelist $SCRIPTPATH/signed_mult/signed_mult.vhdl
lappend filelist $SCRIPTPATH/signed_mult_accu/signed_mult_accu.vhdl
lappend filelist $SCRIPTPATH/signed_mult_sum/signed_mult_sum.vhdl
lappend filelist $SCRIPTPATH/signed_preadd_mult1_accu/signed_preadd_mult1_accu.vhdl

lappend filelist $SCRIPTPATH/signed_multn_chain_accu.vhdl

# compile file list
set SWITCHES "-93 -explicit -dbg"
vcom $SWITCHES -work $LIB $filelist
