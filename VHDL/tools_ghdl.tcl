# TOOL SETTINGS FOR VHDL SIMULATION ONLY

puts "##########################################################################"
puts "INFO: Tool paths, settings and procedures ..."

set COMPILER "C:/FPGA/ghdl/bin/ghdl.exe"

puts "..... COMPILER = $COMPILER"

# Last flag must be the work library without the library name yet. 
# This string is appended with the actual library name later.
set COMPILER_FLAGS "-a --std=08 --workdir=work -Pwork --work="
# set COMPILER_FLAGS "-a --std=93 --workdir=work -Pwork --work="

puts "..... COMPILER_FLAGS = $COMPILER_FLAGS"

set SIMULATOR "C:/FPGA/ghdl/bin/ghdl.exe"

puts "..... SIMULATOR = $SIMULATOR"

set SIMULATOR_FLAGS "-r --std=93 --workdir=work -Pwork"
# set SIMULATOR_FLAGS "-r --std=08 --workdir=work -Pwork"

puts "..... SIMULATOR_FLAGS = $SIMULATOR_FLAGS"

set VIEWER "C:/FPGA/gtkwave/bin/gtkwave.exe"

puts "..... VIEWER = $VIEWER"

if [expr {$tcl_version<8.5}] then {error "ERROR: TCL >= 8.5 required !"}

# start compiler
proc compile {lib files} {
  puts "INFO: Compiling files into library $lib ..."
  foreach f $files { puts "..... $f" }
  set FAIL [catch {{*}[concat exec ${::COMPILER} ${::COMPILER_FLAGS}${lib} $files]} result]
  if [string length $result] then { puts $result }
  if $FAIL then { error "ERROR: Compilation failed." }
}

# start simulator
proc simulate {top vcd} {
  puts "INFO: Running simulation ..."
  set FAIL [catch {{*}[concat exec ${::SIMULATOR} ${::SIMULATOR_FLAGS} $top --vcd=$vcd]} result]
  if [string length $result] then { puts $result }
  if $FAIL then { error "ERROR: Simulation failed." }
}

# start waveform viewer
proc wave {vcd gtkw} {
  puts "INFO: Starting waveform viewer ..."
  if [file exists $vcd] then {
    set FAIL [catch {{*}[concat exec ${::VIEWER} $vcd $gtkw]} result]
    if [string length $result] then { puts $result }
  } else {
    error "ERROR : File not found ... $vcd" 
  }
}
