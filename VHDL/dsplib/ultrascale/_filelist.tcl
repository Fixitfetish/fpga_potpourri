# Create file list with the UltraScale specific architectures.
# It is required to compile the file list of all the generic DSP entities first !

set LIB dsplib

# path/location of this script
set ULTRASCALE_PATH [ file dirname [dict get [ info frame 0 ] file ] ]

# create local file list
set files [list]

# ultrascale specific
lappend files dsp_pkg.ultrascale.vhdl
lappend files delay_dsp.ultrascale.vhdl
lappend files signed_add_accu.ultrascale.vhdl
lappend files signed_add2_accu.ultrascale.vhdl
lappend files signed_mult1_accu.ultrascale.vhdl
lappend files signed_preadd_mult1_accu.ultrascale.vhdl
lappend files signed_mult1add1_accu.ultrascale.vhdl
lappend files signed_mult1add1_sum.ultrascale.vhdl
lappend files signed_mult2_accu.ultrascale.vhdl
lappend files signed_mult2_sum.ultrascale.vhdl
lappend files signed_mult4_sum.ultrascale.vhdl
lappend files signed_mult.ultrascale.vhdl
lappend files signed_mult_accu.ultrascale.vhdl
lappend files signed_mult_sum.ultrascale.vhdl

# create final file list with absolute path
set filelist [list]
foreach f $files {
  lappend filelist [file normalize "${ULTRASCALE_PATH}/$f"]
}
