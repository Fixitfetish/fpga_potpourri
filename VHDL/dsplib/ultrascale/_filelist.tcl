# Append the generic DSPLIB Library file list with the UltraScale specific architectures.
# It is required to create the file list of all the generic DSP entities first !

# path/location of this script
set ULTRASCALE_PATH [ file dirname [dict get [ info frame 0 ] file ] ]

# create local file list
set files [list]

# ultrascale specific
lappend files dsp_pkg.ultrascale.vhdl
lappend files ../delay_dsp/delay_dsp.ultrascale.vhdl
lappend files ../signed_mult1_accu/signed_mult1_accu.ultrascale.vhdl
lappend files ../signed_preadd_mult1_accu/signed_preadd_mult1_accu.ultrascale.vhdl
lappend files ../signed_mult1add1_accu/signed_mult1add1_accu.ultrascale.vhdl
lappend files ../signed_mult1add1_sum/signed_mult1add1_sum.ultrascale.vhdl
lappend files ../signed_mult2_accu/signed_mult2_accu.ultrascale.vhdl
lappend files ../signed_mult2_sum/signed_mult2_sum.ultrascale.vhdl
lappend files ../signed_mult4_sum/signed_mult4_sum.ultrascale.vhdl
lappend files ../signed_mult/signed_mult.ultrascale.vhdl
lappend files ../signed_mult/signed_mult_sum.ultrascale.vhdl

# append files to existing file list
foreach f $files {
  lappend filelist [file normalize "${ULTRASCALE_PATH}/$f"]
}
