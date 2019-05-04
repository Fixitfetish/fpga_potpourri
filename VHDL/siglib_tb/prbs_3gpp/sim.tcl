
# Create work library
vlib work
vlib siglib

vmap work work
vmap siglib siglib

set SIGLIB_PATH ../../siglib

set SWITCHES "-08 -explicit -dbg"
vcom $SWITCHES -work siglib  $SIGLIB_PATH/lfsr_pkg.vhdl
vcom $SWITCHES -work siglib  $SIGLIB_PATH/lfsr.vhdl
vcom $SWITCHES -work siglib  $SIGLIB_PATH/prbs_3gpp.vhdl
vcom $SWITCHES -work work    prbs_3gpp_tb.vhdl

# Run Riviera_PRO simulator
vsim +access +r -t ps -dbg -ieee_nowarn prbs_3gpp_tb
run
