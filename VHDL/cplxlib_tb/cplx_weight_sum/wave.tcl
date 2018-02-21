onerror { resume }
set curr_transcript [transcript]
transcript off

add wave /cplx_weight_sum_tb/rst
add wave -logic /cplx_weight_sum_tb/finish
add wave /cplx_weight_sum_tb/clk
add wave -expand /cplx_weight_sum_tb/x ( -child \
	( -expand /cplx_weight_sum_tb/x(0) ) \
		( -dec /cplx_weight_sum_tb/x(0).re ) \
		( -dec /cplx_weight_sum_tb/x(0).im ) \
)
add wave -expand -dec /cplx_weight_sum_tb/w ( -child \
	( -dec /cplx_weight_sum_tb/w(0) ) \
	( -dec /cplx_weight_sum_tb/w(1) ) \
	( -dec /cplx_weight_sum_tb/w(2) ) \
	( -dec /cplx_weight_sum_tb/w(3) ) \
	( -dec /cplx_weight_sum_tb/w(4) ) \
	( -dec /cplx_weight_sum_tb/w(5) ) \
)
add wave -expand /cplx_weight_sum_tb/r ( -child \
	( -expand /cplx_weight_sum_tb/r(0) ) \
		( -dec /cplx_weight_sum_tb/r(0).re ) \
		( -dec /cplx_weight_sum_tb/r(0).im ) \
)
add wave /cplx_weight_sum_tb/PIPESTAGES
wv.cursors.add -time 2367500ps+1 -name {Default cursor}
wv.cursors.setactive -name {Default cursor}
wv.zoom.range -from 30ns -to 199800ps
wv.time.unit.auto.set
transcript $curr_transcript
