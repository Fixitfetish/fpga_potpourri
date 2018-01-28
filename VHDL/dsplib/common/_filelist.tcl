# Create file list of all generic entities of the DSPLIB Library.
# The device specific architectures are added to the list separately.

# path/location of this script
set DSP_COMMON_PATH [ file dirname [dict get [ info frame 0 ] file ] ]

# create local file list
set files [list]
lappend files ../dsp_output_logic.vhdl
lappend files ../signed_accu.vhdl
lappend files ../signed_adder_tree.vhdl
lappend files ../delay_dsp/delay_dsp.vhdl
lappend files ../signed_mult1add1_accu/signed_mult1add1_accu.vhdl
lappend files ../signed_mult1add1_sum/signed_mult1add1_sum.vhdl
lappend files ../signed_mult1_accu/signed_mult1_accu.vhdl
lappend files ../signed_mult2/signed_mult2.vhdl
lappend files ../signed_mult2_accu/signed_mult2_accu.vhdl
lappend files ../signed_mult2_sum/signed_mult2_sum.vhdl
lappend files ../signed_mult3/signed_mult3.vhdl
lappend files ../signed_mult4_sum/signed_mult4_sum.vhdl
lappend files ../signed_mult/signed_mult.vhdl
lappend files ../signed_mult_accu/signed_mult_accu.vhdl
lappend files ../signed_mult_sum/signed_mult_sum.vhdl
lappend files ../signed_preadd_mult1_accu/signed_preadd_mult1_accu.vhdl
lappend files ../signed_multn_chain_accu.vhdl

# create final file list
set filelist [list]
foreach f $files {
 lappend filelist [file normalize "${DSP_COMMON_PATH}/$f"]
}
