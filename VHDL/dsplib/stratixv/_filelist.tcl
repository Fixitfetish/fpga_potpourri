# Append the generic DSPLIB Library file list with the Stratix-V specific architectures.
# It is required to create the file list of all the generic DSP entities first !

# path/location of this script
set STRATIXV_PATH [ file dirname [dict get [ info frame 0 ] file ] ]

# create local file list
set files [list]

# stratixv specific
lappend files dsp_pkg.stratixv.vhdl
lappend files ../signed_mult1_accu/signed_mult1_accu.stratixv.vhdl
lappend files ../signed_mult1add1_accu/signed_mult1add1_accu.stratixv.vhdl
lappend files ../signed_mult1add1_sum/signed_mult1add1_sum.stratixv.vhdl
lappend files ../signed_mult2_accu/signed_mult2_accu.stratixv.vhdl
lappend files ../signed_mult2/signed_mult2.stratixv.vhdl
lappend files ../signed_mult3/signed_mult3.stratixv.vhdl
lappend files ../signed_mult4_sum/signed_mult4_sum.stratixv.vhdl
lappend files ../signed_mult_accu/signed_mult_accu.stratixv.vhdl
lappend files ../signed_mult_sum/signed_mult_sum.stratixv.vhdl
lappend files ../signed_mult/signed_mult.stratixv.vhdl
lappend files ../signed_preadd_mult1_accu/signed_preadd_mult1_accu.stratixv.vhdl

lappend files signed_multn_chain_accu.stratixv.vhdl

# append files to existing file list
foreach f $files {
  lappend filelist [file normalize "${STRATIXV_PATH}/$f"]
}
