onerror { resume }
set curr_transcript [transcript]
transcript off

add wave /counter_tb/rst
add wave /counter_tb/clk
add wave /counter_tb/finish
add wave -unsigned /counter_tb/second
add wave /counter_tb/second_incr
add wave /counter_tb/second_decr
add wave /counter_tb/second_min
add wave /counter_tb/second_max
add wave -unsigned /counter_tb/minute
add wave /counter_tb/minute_incr
add wave /counter_tb/minute_decr
add wave /counter_tb/minute_min
add wave /counter_tb/minute_max
add wave -unsigned /counter_tb/hour
add wave /counter_tb/hour_incr
add wave /counter_tb/hour_decr
wv.cursors.add -time 7204750ms+1 -name {Default cursor}
wv.cursors.setactive -name {Default cursor}
wv.zoom.range -from 0fs -to 7204750ms
wv.time.unit.auto.set
transcript $curr_transcript
