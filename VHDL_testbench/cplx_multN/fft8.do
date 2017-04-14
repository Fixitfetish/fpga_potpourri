onerror { resume }
set curr_transcript [transcript]
transcript off

add wave /fft8_tb/clk
add wave /fft8_tb/rst
add wave /fft8_tb/finish
add wave /fft8_tb/fft1_start
add wave -expand /fft8_tb/fft1_in ( -child \
		( -dec /fft8_tb/fft1_in(0).re ) \
		( -dec /fft8_tb/fft1_in(0).im ) \
)
add wave -expand /fft8_tb/fft1_out ( -child \
	( -dec /fft8_tb/fft1_out.re ) \
	( -dec /fft8_tb/fft1_out.im ) \
)
add wave /fft8_tb/fft1_out_idx
add wave /fft8_tb/ifft1_start
add wave -expand /fft8_tb/ifft1_out ( -child \
		( -dec /fft8_tb/ifft1_out(0).re ) \
		( -dec /fft8_tb/ifft1_out(0).im ) \
)
wv.cursors.add -time 100ns+5 -name {Default cursor}
wv.cursors.setactive -name {Default cursor}
wv.zoom.range -from 70322ps -to 101562ps
wv.time.unit.auto.set
transcript $curr_transcript
