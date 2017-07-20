#+++ FOR VHDL SIMULATORS ONLY +++#
# This script compiles all behavioral architectures of the DSP Library.
# It is required to compile the generic DSP entities first !

# path/location of this script
set SCRIPTPATH [ file dirname [dict get [ info frame 0 ] file ] ]

# library name
set LIB "dsplib"

# create file list (with list compilation is faster)
set filelist [list]

lappend filelist $SCRIPTPATH/delay_dsp/delay_dsp.behave.vhdl
lappend filelist $SCRIPTPATH/signed_mult1_accu/signed_mult1_accu.behave.vhdl
lappend filelist $SCRIPTPATH/signed_mult2_accu/signed_mult2_accu.behave.vhdl
lappend filelist $SCRIPTPATH/signed_mult2_sum/signed_mult2_sum.behave.vhdl
lappend filelist $SCRIPTPATH/signed_mult/signed_mult.behave.vhdl
lappend filelist $SCRIPTPATH/signed_mult_accu/signed_mult_accu.behave.vhdl
lappend filelist $SCRIPTPATH/signed_mult_sum/signed_mult_sum.behave.vhdl

# compile file list
set SWITCHES "-93 -explicit -dbg"
vcom $SWITCHES -work $LIB $filelist
