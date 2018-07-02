
# Create work library
vlib work
vlib baselib

vmap work work
vmap baselib baselib

set BASELIB_PATH ../../baselib

set SWITCHES "-93 -explicit -dbg"
vcom $SWITCHES -work baselib $BASELIB_PATH/lfsr.vhdl
vcom $SWITCHES -work work    lfsr_tb.vhdl

# Run Riviera_PRO simulator
vsim +access +r -t ps -dbg -ieee_nowarn lfsr_tb
run
