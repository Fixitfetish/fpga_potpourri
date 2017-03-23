#+++ FOR VHDL SIMULATORS ONLY +++#
# This script compiles all UltraScale specific architectures of the DSP Library.
# It is required to compile the generic DSP entities first !

# path/location of this script
set BASEPATH [ file dirname [dict get [ info frame 0 ] file ] ]

if ![file exists $XILINX_LIB] {
  error "Path to Xilinx libraries not found - please provide global variable XILINX_LIB"
}

vmap unisim $XILINX_LIB/unisim

# create file list
set filelist [list]
lappend filelist $BASEPATH/dsp_pkg.ultrascale.vhdl
lappend filelist $BASEPATH/signed_mult1_accu.ultrascale.vhdl
lappend filelist $BASEPATH/signed_mult1add1_accu.ultrascale.vhdl
lappend filelist $BASEPATH/signed_mult1add1_sum.ultrascale.vhdl
lappend filelist $BASEPATH/signed_mult2_accu.ultrascale.vhdl
lappend filelist $BASEPATH/signed_multN.ultrascale.vhdl
lappend filelist $BASEPATH/signed_preadd_mult1_accu.ultrascale.vhdl

# compile file list
set SWITCHES "-93 -explicit -dbg"
vcom $SWITCHES -work $DSPLIB $filelist
