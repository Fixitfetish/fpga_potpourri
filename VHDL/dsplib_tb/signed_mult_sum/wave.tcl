onerror { resume }
set curr_transcript [transcript]
transcript off

add wave -expand -vgroup Generics \
	( -literal /signed_mult_sum_tb/NUM_MULT ) \
	/signed_mult_sum_tb/HIGH_SPEED_MODE \
	/signed_mult_sum_tb/USE_NEGATION \
	( -literal /signed_mult_sum_tb/NUM_INPUT_REG ) \
	( -literal /signed_mult_sum_tb/NUM_OUTPUT_REG ) \
	/signed_mult_sum_tb/OUTPUT_WIDTH \
	( -literal /signed_mult_sum_tb/OUTPUT_SHIFT_RIGHT ) \
	( -logic /signed_mult_sum_tb/OUTPUT_ROUND ) \
	( -logic /signed_mult_sum_tb/OUTPUT_CLIP ) \
	( -logic /signed_mult_sum_tb/OUTPUT_OVERFLOW )
add wave -logic /signed_mult_sum_tb/rst
add wave /signed_mult_sum_tb/finish
add wave /signed_mult_sum_tb/clk
add wave /signed_mult_sum_tb/vld
add wave /signed_mult_sum_tb/neg
add wave -dec /signed_mult_sum_tb/x ( -child \
	( -dec /signed_mult_sum_tb/x(0) ) \
	( -dec /signed_mult_sum_tb/x(1) ) \
	( -dec /signed_mult_sum_tb/x(2) ) \
	( -dec /signed_mult_sum_tb/x(3) ) \
	( -dec /signed_mult_sum_tb/x(4) ) \
	( -dec /signed_mult_sum_tb/x(5) ) \
	( -dec /signed_mult_sum_tb/x(6) ) \
	( -dec /signed_mult_sum_tb/x(7) ) \
	( -dec /signed_mult_sum_tb/x(8) ) \
	( -dec /signed_mult_sum_tb/x(9) ) \
	( -dec /signed_mult_sum_tb/x(10) ) \
	( -dec /signed_mult_sum_tb/x(11) ) \
	( -dec /signed_mult_sum_tb/x(12) ) \
	( -dec /signed_mult_sum_tb/x(13) ) \
	( -dec /signed_mult_sum_tb/x(14) ) \
	( -dec /signed_mult_sum_tb/x(15) ) \
	( -dec /signed_mult_sum_tb/x(16) ) \
	( -dec /signed_mult_sum_tb/x(17) ) \
)
add wave -dec /signed_mult_sum_tb/y ( -child \
	( -dec /signed_mult_sum_tb/y(0) ) \
	( -dec /signed_mult_sum_tb/y(1) ) \
	( -dec /signed_mult_sum_tb/y(2) ) \
	( -dec /signed_mult_sum_tb/y(3) ) \
	( -dec /signed_mult_sum_tb/y(4) ) \
	( -dec /signed_mult_sum_tb/y(5) ) \
	( -dec /signed_mult_sum_tb/y(6) ) \
	( -dec /signed_mult_sum_tb/y(7) ) \
	( -dec /signed_mult_sum_tb/y(8) ) \
	( -dec /signed_mult_sum_tb/y(9) ) \
	( -dec /signed_mult_sum_tb/y(10) ) \
	( -dec /signed_mult_sum_tb/y(11) ) \
	( -dec /signed_mult_sum_tb/y(12) ) \
	( -dec /signed_mult_sum_tb/y(13) ) \
	( -dec /signed_mult_sum_tb/y(14) ) \
	( -dec /signed_mult_sum_tb/y(15) ) \
	( -dec /signed_mult_sum_tb/y(16) ) \
	( -dec /signed_mult_sum_tb/y(17) ) \
)
add wave -expand -vgroup Behave \
	( -dec /signed_mult_sum_tb/result ) \
	/signed_mult_sum_tb/result_ovf \
	/signed_mult_sum_tb/result_vld \
	( -literal /signed_mult_sum_tb/pipestages )
add wave -expand -vgroup Ultrascale \
	( -dec /signed_mult_sum_tb/us_result ) \
	/signed_mult_sum_tb/us_result_vld \
	/signed_mult_sum_tb/us_result_ovf \
	/signed_mult_sum_tb/us_pipestages
wv.cursors.add -time 635ns+1 -name {Default cursor}
wv.cursors.setactive -name {Default cursor}
wv.zoom.range -from 0fs -to 302200ps
wv.time.unit.auto.set
transcript $curr_transcript
