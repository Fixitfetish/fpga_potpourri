# +++ FOR VHDL SIMULATION ONLY +++ #

# This script compiles all generic entities of the DSP Library for VHDL-1993.
# The device specific architectures are compiled separately.

# path/location of this script
set BASEPATH [ file dirname [dict get [ info frame 0 ] file ] ]

set DSPLIB "fixitfetish"
vlib $DSPLIB

set SWITCHES "-93 -explicit -dbg"

vcom $SWITCHES -work $DSPLIB $BASEPATH/../ieee_extension_types_1993.vhdl
vcom $SWITCHES -work $DSPLIB $BASEPATH/../ieee_extension.vhdl
vcom $SWITCHES -work $DSPLIB $BASEPATH/signed_mult1_accu.vhdl
vcom $SWITCHES -work $DSPLIB $BASEPATH/signed_mult2.vhdl
vcom $SWITCHES -work $DSPLIB $BASEPATH/signed_mult2_accu.vhdl
vcom $SWITCHES -work $DSPLIB $BASEPATH/signed_mult2_sum.vhdl
vcom $SWITCHES -work $DSPLIB $BASEPATH/signed_mult3.vhdl
vcom $SWITCHES -work $DSPLIB $BASEPATH/signed_mult4_accu.vhdl
vcom $SWITCHES -work $DSPLIB $BASEPATH/signed_mult4_sum.vhdl
vcom $SWITCHES -work $DSPLIB $BASEPATH/signed_mult8_accu.vhdl
vcom $SWITCHES -work $DSPLIB $BASEPATH/signed_mult16_accu.vhdl
vcom $SWITCHES -work $DSPLIB $BASEPATH/signed_multN.vhdl
vcom $SWITCHES -work $DSPLIB $BASEPATH/signed_multN_accu.vhdl
vcom $SWITCHES -work $DSPLIB $BASEPATH/signed_multN_sum.vhdl
