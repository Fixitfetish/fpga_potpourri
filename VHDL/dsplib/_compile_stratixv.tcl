#+++ FOR VHDL SIMULATORS ONLY +++#
# This script compiles all Stratix V specific architectures of the DSPLIB Library.
# It is required to compile the generic DSP entities first !

# path/location of this script
set SCRIPTPATH [ file dirname [dict get [ info frame 0 ] file ] ]

# library name
set LIB "dsplib"
set VHDL 1993

if ![file exists $ALTERA_LIB] {
  error "Path to Altera libraries not found - please provide global variable ALTERA_LIB"
}

# Altera VHDL library
vmap stratixv $ALTERA_LIB/vhdl_libs/stratixv

# Altera Verilog library
vmap stratixv_ver $ALTERA_LIB/verilog_libs/stratixv_ver

# create file list
set filelist [list]

lappend filelist $SCRIPTPATH/dsp_pkg/dsp_pkg.stratixv.vhdl

lappend filelist $SCRIPTPATH/signed_mult1_accu/signed_mult1_accu.stratixv.vhdl
lappend filelist $SCRIPTPATH/signed_mult1add1_accu/signed_mult1add1_accu.stratixv.vhdl
lappend filelist $SCRIPTPATH/signed_mult1add1_sum/signed_mult1add1_sum.stratixv.vhdl
lappend filelist $SCRIPTPATH/signed_mult2_accu/signed_mult2_accu.stratixv.vhdl
lappend filelist $SCRIPTPATH/signed_mult2/signed_mult2.stratixv.vhdl
lappend filelist $SCRIPTPATH/signed_mult3/signed_mult3.stratixv.vhdl
lappend filelist $SCRIPTPATH/signed_mult4_sum/signed_mult4_sum.stratixv.vhdl
lappend filelist $SCRIPTPATH/signed_mult_accu/signed_mult_accu.stratixv.vhdl
lappend filelist $SCRIPTPATH/signed_mult_sum/signed_mult_sum.stratixv.vhdl
lappend filelist $SCRIPTPATH/signed_mult/signed_mult.stratixv.vhdl
lappend filelist $SCRIPTPATH/signed_preadd_mult1_accu/signed_preadd_mult1_accu.stratixv.vhdl

lappend filelist $SCRIPTPATH/stratixv/signed_multn_chain_accu.stratixv.vhdl

# compile file list
if {[string equal $VHDL 2008]} {
  set SWITCHES "-2008 -explicit -dbg"
} else {
  set SWITCHES "-93 -explicit -dbg"
}

vcom $SWITCHES -work $LIB $filelist
