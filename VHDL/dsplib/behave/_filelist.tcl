# Append the generic DSPLIB Library file list with the behavioral architectures.
# It is required to create the file list of all the generic DSP entities first !

# path/location of this script
set BEHAVE_PATH [ file dirname [dict get [ info frame 0 ] file ] ]

# create local file list
set files [list]

# behavioral models
lappend files dsp_pkg.behave.vhdl
lappend files signed_mult1_accu.behave.vhdl
lappend files signed_mult2_accu.behave.vhdl
lappend files signed_mult2_sum.behave.vhdl
lappend files signed_mult_accu.behave.vhdl
lappend files signed_mult_sum.behave.vhdl
lappend files signed_mult.behave.vhdl

# append files to existing file list
foreach f $files {
  lappend filelist [file normalize "${BEHAVE_PATH}/$f"]
}
