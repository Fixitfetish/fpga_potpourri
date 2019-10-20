# Create file list of the generic DSPLIB entities.

set LIB dsplib

# path/location of this script
set DSPLIB_PATH [ file dirname [dict get [ info frame 0 ] file ] ]

# create local file list
set files [list]

# entities
lappend files signed_output_logic.vhdl
lappend files signed_adder_tree.vhdl

# generic entities without architecture
lappend files signed_add_accu.vhdl
lappend files signed_add2_accu.vhdl
lappend files signed_add2_sum.vhdl
lappend files signed_mult1_accu.vhdl
lappend files signed_mult1add1_accu.vhdl
lappend files signed_mult1add1_sum.vhdl
lappend files signed_mult2.vhdl
lappend files signed_mult2_accu.vhdl
lappend files signed_mult2_sum.vhdl
lappend files signed_mult3.vhdl
lappend files signed_mult4_sum.vhdl
lappend files signed_preadd_mult1_accu.vhdl
lappend files signed_mult.vhdl
lappend files signed_mult_accu.vhdl
lappend files signed_mult_sum.vhdl

# create final file list with absolute path
set filelist [list]
foreach f $files {
  lappend filelist [file normalize "${DSPLIB_PATH}/$f"]
}
