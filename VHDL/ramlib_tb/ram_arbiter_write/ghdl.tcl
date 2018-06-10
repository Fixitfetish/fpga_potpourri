# get tool path, settings and procedures
source tools_ghdl.tcl

# testbench library
set WORK work

# create work directory if not yet existing
if {![file exists $WORK]} then [file mkdir $WORK]

puts "--------------------------------------------------------------------------"
puts "INFO: BASELIB"
source ../../baselib/_filelist.tcl
compile $LIB $filelist
puts "--------------------------------------------------------------------------"
puts "INFO: RAMLIB"
source ../../ramlib/_filelist.tcl
source ../../ramlib/behave/_filelist.tcl
compile $LIB $filelist

puts "--------------------------------------------------------------------------"
puts "INFO: Testbench"

set top ram_arbiter_write_tb

set files [list]
lappend files [ file normalize usr_write_emulator.vhdl ]
lappend files [ file normalize ${top}.vhdl ]

compile $WORK $files

puts "=========================================================================="

set VCD $WORK/sim.vcd
simulate $top $VCD

puts "=========================================================================="

wave $VCD sim.gtkw

puts "=========================================================================="
puts "DONE"
