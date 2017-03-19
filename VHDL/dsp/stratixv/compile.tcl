#+++ FOR VHDL SIMULATORS ONLY +++#
# This script compiles all Stratix V specific architectures of the DSP Library.
# It is required to compile the generic DSP entities first !

# path/location of this script
set BASEPATH [ file dirname [dict get [ info frame 0 ] file ] ]

if ![file exists $ALTERA_LIB] {
  error "Path to Altera libraries not found - please provide global variable ALTERA_LIB"
}

# Altera VHDL libraries
vmap altera $ALTERA_LIB/vhdl_libs/altera
vmap altera_mf $ALTERA_LIB/vhdl_libs/altera_mf
vmap altera_lnsim $ALTERA_LIB/vhdl_libs/altera_lnsim
vmap lpm $ALTERA_LIB/vhdl_libs/lpm
vmap sgate $ALTERA_LIB/vhdl_libs/sgate
vmap stratixv $ALTERA_LIB/vhdl_libs/stratixv
# Altera Verilog libraries
vmap altera_ver $ALTERA_LIB/verilog_libs/altera_ver
vmap altera_mf_ver $ALTERA_LIB/verilog_libs/altera_mf_ver
vmap altera_lnsim_ver $ALTERA_LIB/verilog_libs/altera_lnsim_ver
vmap lpm_ver $ALTERA_LIB/verilog_libs/lpm_ver
vmap sgate_ver $ALTERA_LIB/verilog_libs/sgate_ver
vmap stratixv_ver $ALTERA_LIB/verilog_libs/stratixv_ver

set SWITCHES "-93 -explicit -dbg"

vcom $SWITCHES -work $DSPLIB $BASEPATH/dsp_pkg.stratixv.vhdl

vcom $SWITCHES -work $DSPLIB $BASEPATH/signed_mult1_accu.stratixv.vhdl
vcom $SWITCHES -work $DSPLIB $BASEPATH/signed_mult1add1_accu.stratixv.vhdl
vcom $SWITCHES -work $DSPLIB $BASEPATH/signed_mult1add1_sum.stratixv.vhdl
vcom $SWITCHES -work $DSPLIB $BASEPATH/signed_mult2_accu.stratixv.vhdl
vcom $SWITCHES -work $DSPLIB $BASEPATH/signed_mult2.stratixv_partial.vhdl
vcom $SWITCHES -work $DSPLIB $BASEPATH/signed_mult3.stratixv_compact.vhdl
vcom $SWITCHES -work $DSPLIB $BASEPATH/signed_mult4_sum.stratixv.vhdl
vcom $SWITCHES -work $DSPLIB $BASEPATH/signed_multN_accu.stratixv.vhdl
vcom $SWITCHES -work $DSPLIB $BASEPATH/signed_multN_sum.stratixv.vhdl
vcom $SWITCHES -work $DSPLIB $BASEPATH/signed_multN.stratixv.vhdl
vcom $SWITCHES -work $DSPLIB $BASEPATH/signed_preadd_mult1_accu.stratixv.vhdl
