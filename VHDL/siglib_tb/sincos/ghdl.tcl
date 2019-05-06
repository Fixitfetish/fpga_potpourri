# get tool path, settings and procedures
source ../../tools_ghdl.tcl

# testbench library
set WORK work

# create work directory if not yet existing
if {![file exists $WORK]} then [file mkdir $WORK]

puts "--------------------------------------------------------------------------"
puts "INFO: BASELIB"
source ../../baselib/_filelist.tcl
compile $LIB $filelist

puts "--------------------------------------------------------------------------"
puts "INFO: SIGLIB"
source ../../siglib/_filelist.tcl
compile $LIB $filelist

puts "--------------------------------------------------------------------------"
puts "INFO: CPLXLIB"
set LIB cplxlib
set filelist [list]
lappend filelist [ file normalize ../../cplxlib/1993/cplx_pkg_1993.vhdl ]
compile $LIB $filelist

puts "--------------------------------------------------------------------------"
puts "INFO: Testbench"

set top sincos_tb

set files [list]
lappend files [ file normalize ../../cplxlib_tb/cplx_logger.vhdl ]
lappend files [ file normalize ${top}.vhdl ]

compile $WORK $files

puts "=========================================================================="

set VCD $WORK/sim.vcd
simulate $top $VCD

puts "=========================================================================="

wave $VCD sim.gtkw

puts "=========================================================================="
puts "DONE"
