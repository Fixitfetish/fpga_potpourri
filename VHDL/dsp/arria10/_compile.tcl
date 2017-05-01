#+++ FOR VHDL SIMULATORS ONLY +++#
# This script compiles all Arria 10 specific architectures of the DSP Library.
# It is required to compile the generic DSP entities first !

# path/location of this script
set SCRIPTPATH [ file dirname [dict get [ info frame 0 ] file ] ]

# library name
set LIB "dsplib"

if ![file exists $ALTERA_LIB] {
  error "Path to Altera libraries not found - please provide global variable ALTERA_LIB"
}

# Altera VHDL library
vmap twentynm $ALTERA_LIB/vhdl_libs/twentynm

# Altera Verilog library
vmap twentynm_ver $ALTERA_LIB/verilog_libs/twentynm_ver

# create file list
set filelist [list]
lappend filelist $SCRIPTPATH/dsp_pkg.arria10.vhdl
lappend filelist $SCRIPTPATH/signed_mult2_accu.arria10.vhdl

# compile file list
set SWITCHES "-93 -explicit -dbg"
vcom $SWITCHES -work $LIB $filelist
