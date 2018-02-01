onerror { resume }
set curr_transcript [transcript]
transcript off

add wave /enable_burst_generator_tb/rst
add wave /enable_burst_generator_tb/clk
add wave /enable_burst_generator_tb/clkena
add wave /enable_burst_generator_tb/finish
add wave -unsigned /enable_burst_generator_tb/numerator
add wave -unsigned /enable_burst_generator_tb/denominator
add wave -unsigned /enable_burst_generator_tb/burst_length
add wave -unsigned /enable_burst_generator_tb/equidistant_count
add wave -unsigned /enable_burst_generator_tb/dutycycle_count
add wave /enable_burst_generator_tb/dutycycle_enable
add wave /enable_burst_generator_tb/dutycycle_active
add wave /enable_burst_generator_tb/equidistant_enable
add wave /enable_burst_generator_tb/equidistant_active
wv.cursors.add -time 2050ns+1 -name {Default cursor}
wv.cursors.setactive -name {Default cursor}
wv.zoom.range -from 0fs -to 2050ns
wv.time.unit.auto.set
transcript $curr_transcript
