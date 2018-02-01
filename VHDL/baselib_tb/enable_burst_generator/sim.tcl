
# Create work library
vlib work
vlib baselib

vmap work work
vmap baselib baselib

set BASELIB_PATH ../../baselib

set SWITCHES "-93 -explicit -dbg"
vcom $SWITCHES -work baselib $BASELIB_PATH/enable_burst_generator.vhdl
vcom $SWITCHES -work work    enable_burst_generator_tb.vhdl

# Run Riviera_PRO simulator
vsim +access +r -t ps -dbg -ieee_nowarn enable_burst_generator_tb
do wave.tcl
run
