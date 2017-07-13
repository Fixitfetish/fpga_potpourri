onerror { resume }
set curr_transcript [transcript]
transcript off

add wave /dft8_tb/clk
add wave /dft8_tb/rst
add wave /dft8_tb/finish
add wave /dft8_tb/fft1_in_ser
add wave -literal /dft8_tb/fft1_in_idx
add wave /dft8_tb/fft1_in_start
add wave -expand /dft8_tb/fft1_in ( -child \
		( -dec /dft8_tb/fft1_in(0).re ) \
		( -dec /dft8_tb/fft1_in(0).im ) \
)
add wave /dft8_tb/fft1_out_idx
add wave /dft8_tb/fft1_out_ser
add wave /dft8_tb/fft2_in_start
add wave /dft8_tb/fft2_in_idx
add wave /dft8_tb/fft2_in_ser
add wave /dft8_tb/fft2_out
add wave /dft8_tb/fft2_out_ser
wv.cursors.add -time 119500ps+1 -name {Default cursor}
wv.cursors.setactive -name {Default cursor}
wv.zoom.range -from 15620ps -to 42ns
wv.time.unit.auto.set
transcript $curr_transcript
