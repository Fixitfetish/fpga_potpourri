onerror { resume }
set curr_transcript [transcript]
transcript off

add wave /cplx_mult_tb/rst
add wave -logic /cplx_mult_tb/finish
add wave /cplx_mult_tb/clk
add wave -expand /cplx_mult_tb/x ( -child \
	( -expand /cplx_mult_tb/x(0) ) \
		( -dec /cplx_mult_tb/x(0).re ) \
		( -dec /cplx_mult_tb/x(0).im ) \
		( -dec /cplx_mult_tb/x(1).re ) \
		( -dec /cplx_mult_tb/x(1).im ) \
)
add wave -expand /cplx_mult_tb/y ( -child \
	( -expand /cplx_mult_tb/y(0) ) \
		( -dec /cplx_mult_tb/y(0).re ) \
		( -dec /cplx_mult_tb/y(0).im ) \
		( -dec /cplx_mult_tb/y(1).re ) \
		( -dec /cplx_mult_tb/y(1).im ) \
		( -dec /cplx_mult_tb/y(4).re ) \
		( -dec /cplx_mult_tb/y(4).im ) \
)
add wave -expand /cplx_mult_tb/r ( -child \
	( -expand /cplx_mult_tb/r(0) ) \
		( -dec /cplx_mult_tb/r(0).re ) \
		( -dec /cplx_mult_tb/r(0).im ) \
		( -dec /cplx_mult_tb/r(4).re ) \
		( -dec /cplx_mult_tb/r(4).im ) \
)
add wave /cplx_mult_tb/PIPESTAGES
wv.cursors.add -time 465500ps+1 -name {Default cursor}
wv.cursors.setactive -name {Default cursor}
wv.zoom.range -from 0fs -to 26380ps
wv.time.unit.auto.set
transcript $curr_transcript
