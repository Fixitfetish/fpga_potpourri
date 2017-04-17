#+++ FOR VHDL SIMULATORS ONLY +++#
# This script compiles all Stratix V specific architectures of the DSP Library.
# It is required to compile the generic DSP entities first !

# path/location of this script
set SCRIPTPATH [ file dirname [dict get [ info frame 0 ] file ] ]

if ![file exists $ALTERA_LIB] {
  error "Path to Altera libraries not found - please provide global variable ALTERA_LIB"
}

# Altera VHDL library
vmap stratixv $ALTERA_LIB/vhdl_libs/stratixv

# Altera Verilog library
vmap stratixv_ver $ALTERA_LIB/verilog_libs/stratixv_ver

# create file list
set filelist [list]
lappend filelist $SCRIPTPATH/dsp_pkg.stratixv.vhdl
lappend filelist $SCRIPTPATH/signed_mult1_accu.stratixv.vhdl
lappend filelist $SCRIPTPATH/signed_mult1add1_accu.stratixv.vhdl
lappend filelist $SCRIPTPATH/signed_mult1add1_sum.stratixv.vhdl
lappend filelist $SCRIPTPATH/signed_mult2_accu.stratixv.vhdl
lappend filelist $SCRIPTPATH/signed_mult2.stratixv_partial.vhdl
lappend filelist $SCRIPTPATH/signed_mult3.stratixv_compact.vhdl
lappend filelist $SCRIPTPATH/signed_mult4_sum.stratixv.vhdl
lappend filelist $SCRIPTPATH/signed_multn_chain_accu.stratixv.vhdl
lappend filelist $SCRIPTPATH/signed_multN_accu.stratixv.vhdl
lappend filelist $SCRIPTPATH/signed_multN_sum.stratixv.vhdl
lappend filelist $SCRIPTPATH/signed_multN.stratixv.vhdl
lappend filelist $SCRIPTPATH/signed_preadd_mult1_accu.stratixv.vhdl

# compile file list
set SWITCHES "-93 -explicit -dbg"
vcom $SWITCHES -work $DSPLIB $filelist
