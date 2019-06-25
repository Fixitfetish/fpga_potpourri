onerror { resume }
set curr_transcript [transcript]
transcript off

add wave -literal /cplx_noise_tb/RESOLUTION
add wave -literal /cplx_noise_tb/PERIOD
add wave /cplx_noise_tb/load
add wave -logic /cplx_noise_tb/finish
add wave /cplx_noise_tb/clk
add wave /cplx_noise_tb/req_ack
add wave /cplx_noise_tb/n0_dout
wv.cursors.add -time 330sec -name {Default cursor}
wv.cursors.setactive -name {Default cursor}
wv.zoom.range -from 0fs -to 1337600ms
wv.time.unit.auto.set
transcript $curr_transcript
