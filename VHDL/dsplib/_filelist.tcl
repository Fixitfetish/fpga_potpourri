# Append the generic DSPLIB Library file list with the generic entities.

# path/location of this script
set DSPLIB_PATH [ file dirname [dict get [ info frame 0 ] file ] ]

# create local file list
set files [list]

# entities
lappend files signed_output_logic.vhdl
lappend files signed_adder_tree.vhdl

# generic entities without architecture
lappend files signed_mult1_accu.vhdl
lappend files signed_mult1add1_accu.vhdl
lappend files signed_mult1add1_sum.vhdl
lappend files signed_mult2_accu.vhdl
lappend files signed_mult2_sum.vhdl
lappend files signed_mult4_sum.vhdl
lappend files signed_mult.vhdl
lappend files signed_mult_accu.vhdl
lappend files signed_mult_sum.vhdl

# append files to existing file list
foreach f $files {
  lappend filelist [file normalize "${DSPLIB_PATH}/$f"]
}
