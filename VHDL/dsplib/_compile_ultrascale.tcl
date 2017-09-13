#+++ FOR VHDL SIMULATORS ONLY +++#
# This script compiles all UltraScale specific architectures of the DSPLIB Library.
# It is required to compile the generic DSP entities first !

# path/location of this script
set SCRIPTPATH [ file dirname [dict get [ info frame 0 ] file ] ]

# library name
set LIB "dsplib"
set VHDL 1993

if ![file exists $XILINX_LIB] {
  error "Path to Xilinx libraries not found - please provide global variable XILINX_LIB"
}

vmap unisim $XILINX_LIB/unisim

# create file list
set filelist [list]

lappend filelist $SCRIPTPATH/dsp_pkg/dsp_pkg.ultrascale.vhdl

lappend filelist $SCRIPTPATH/delay_dsp/delay_dsp.ultrascale.vhdl
lappend filelist $SCRIPTPATH/signed_mult1_accu/signed_mult1_accu.ultrascale.vhdl
lappend filelist $SCRIPTPATH/signed_preadd_mult1_accu/signed_preadd_mult1_accu.ultrascale.vhdl
lappend filelist $SCRIPTPATH/signed_mult1add1_accu/signed_mult1add1_accu.ultrascale.vhdl
lappend filelist $SCRIPTPATH/signed_mult1add1_sum/signed_mult1add1_sum.ultrascale.vhdl
lappend filelist $SCRIPTPATH/signed_mult2_accu/signed_mult2_accu.ultrascale.vhdl
lappend filelist $SCRIPTPATH/signed_mult2_sum/signed_mult2_sum.ultrascale.vhdl
lappend filelist $SCRIPTPATH/signed_mult4_sum/signed_mult4_sum.ultrascale.vhdl
lappend filelist $SCRIPTPATH/signed_mult/signed_mult.ultrascale.vhdl

# compile file list
if {[string equal $VHDL 2008]} {
  set SWITCHES "-2008 -explicit -dbg"
} else {
  set SWITCHES "-93 -explicit -dbg"
}

vcom $SWITCHES -work $LIB $filelist
