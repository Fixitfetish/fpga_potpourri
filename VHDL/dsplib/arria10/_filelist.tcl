# Append the generic DSPLIB Library file list with the Arria-10 specific architectures.
# It is required to create the file list of all the generic DSP entities first !

# path/location of this script
set ARRIA10_PATH [ file dirname [dict get [ info frame 0 ] file ] ]

# create local file list
set files [list]

# arria10 specific
lappend files dsp_pkg.arria10.vhdl
lappend files signed_mult2_accu.arria10.vhdl

# append files to existing file list
foreach f $files {
  lappend filelist [file normalize "${ARRIA10_PATH}/$f"]
}
