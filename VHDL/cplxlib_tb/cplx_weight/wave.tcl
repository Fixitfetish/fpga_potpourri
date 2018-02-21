onerror { resume }
set curr_transcript [transcript]
transcript off

add wave /cplx_weight_tb/rst
add wave -logic /cplx_weight_tb/finish
add wave /cplx_weight_tb/clk
add wave -expand /cplx_weight_tb/x ( -child \
	( -expand /cplx_weight_tb/x(0) ) \
		( -dec /cplx_weight_tb/x(0).re ) \
		( -dec /cplx_weight_tb/x(0).im ) \
)
add wave -expand -dec /cplx_weight_tb/w ( -child \
	( -dec /cplx_weight_tb/w(0) ) \
	( -dec /cplx_weight_tb/w(1) ) \
	( -dec /cplx_weight_tb/w(2) ) \
	( -dec /cplx_weight_tb/w(3) ) \
	( -dec /cplx_weight_tb/w(4) ) \
)
add wave -expand /cplx_weight_tb/r ( -child \
	( -expand /cplx_weight_tb/r(0) ) \
		( -dec /cplx_weight_tb/r(0).re ) \
		( -dec /cplx_weight_tb/r(0).im ) \
)
add wave /cplx_weight_tb/PIPESTAGES
wv.cursors.add -time 2327500ps+1 -name {Default cursor}
wv.cursors.setactive -name {Default cursor}
wv.zoom.range -from 0fs -to 169800ps
wv.time.unit.auto.set
transcript $curr_transcript
