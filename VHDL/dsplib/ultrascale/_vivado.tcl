# To add the DSP Library files to a Xilinx Vivado project (Ultrascale) this
# TCL script must be called from the TCL console:
#   source my_path/_vivado.tcl

# path/location of this script
set ULTRASCALE_PATH [ file dirname [dict get [ info frame 0 ] file ] ]

# get file list
source $ULTRASCALE_PATH/../common/_filelist.tcl 
source $ULTRASCALE_PATH/_filelist.tcl 

# add files to Vivado project
add_files -norecurse $filelist

# set properties of all files in file list
foreach file $filelist {
  set file_obj [get_files [list "*$file"]]
  set_property -name "file_type" -value "VHDL" -objects $file_obj
  set_property -name "library" -value "dsplib" -objects $file_obj
}
