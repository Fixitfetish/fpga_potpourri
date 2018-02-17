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
puts "INFO: DSPLIB"
source ../../dsplib/_filelist.tcl
compile $LIB $filelist
source ../../dsplib/behave/_filelist.tcl
compile $LIB $filelist

puts "--------------------------------------------------------------------------"
puts "INFO: CPLXLIB"
source ../../cplxlib/_filelist.tcl
compile $LIB $filelist

puts "--------------------------------------------------------------------------"
puts "INFO: Testbench"

set top cplx_weight_tb

set files [list]
lappend files [ file normalize ../cplx_stimuli.vhdl ]
lappend files [ file normalize ../cplx_logger.vhdl ]
lappend files [ file normalize ${top}.vhdl ]

compile $WORK $files

puts "=========================================================================="

set VCD $WORK/sim.vcd
simulate $top $VCD

# puts "=========================================================================="

# wave $VCD sim.gtkw

puts "=========================================================================="
puts "DONE"
