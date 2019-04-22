
# Create work library
vlib work
vlib baselib
vlib siglib

vmap work work
vmap baselib baselib
vmap siglib siglib

set BASELIB_PATH ../../baselib
set SIGLIB_PATH ../../siglib

set SWITCHES "-08 -explicit -dbg"
vcom $SWITCHES -work baselib $BASELIB_PATH/std_logic_extension.vhdl
vcom $SWITCHES -work siglib  $SIGLIB_PATH/lfsr.vhdl
vcom $SWITCHES -work work    prbs_3gpp.vhdl
vcom $SWITCHES -work work    lfsr_tb.vhdl

# Run Riviera_PRO simulator
vsim +access +r -t ps -dbg -ieee_nowarn lfsr_tb
run
