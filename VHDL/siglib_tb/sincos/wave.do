onerror { resume }
set curr_transcript [transcript]
transcript off

add wave -literal /sincos_tb/i_sincos/PHASE_MAJOR_WIDTH
add wave -literal /sincos_tb/i_sincos/PHASE_MINOR_WIDTH
add wave -literal /sincos_tb/i_sincos/OUTPUT_WIDTH
add wave -literal /sincos_tb/i_sincos/SINCOS_WIDTH
add wave -literal /sincos_tb/i_sincos/SINCOS_MAX
add wave -literal /sincos_tb/i_sincos/LUT_WIDTH
add wave -literal /sincos_tb/i_sincos/LUT_DEPTH_LD
add wave -literal /sincos_tb/i_sincos/LUT_DEPTH
add wave -literal /sincos_tb/i_sincos/LUT
add wave -literal /sincos_tb/i_sincos/SLOPE_WIDTH
add wave /sincos_tb/i_sincos/clk
add wave /sincos_tb/i_sincos/rst
add wave /sincos_tb/i_sincos/clkena
add wave /sincos_tb/i_sincos/phase_vld
add wave -unsigned /sincos_tb/i_sincos/phase
add wave -logic /sincos_tb/i_sincos/lut_in_vld
add wave /sincos_tb/i_sincos/lut_in_quad
add wave -unsigned /sincos_tb/i_sincos/lut_in_addr
add wave -dec -literal /sincos_tb/i_sincos/lut_in_frac
add wave -logic /sincos_tb/i_sincos/lut_in_vld_q
add wave -literal /sincos_tb/i_sincos/lut_in_quad_q
add wave -unsigned /sincos_tb/i_sincos/lut_in_addr_q
add wave -dec -literal /sincos_tb/i_sincos/lut_in_frac_q
add wave -logic /sincos_tb/i_sincos/lut_out_vld
add wave /sincos_tb/i_sincos/lut_out_quad
add wave -dec /sincos_tb/i_sincos/lut_out_frac
add wave -literal /sincos_tb/i_sincos/lut_out_data
add wave -dec /sincos_tb/i_sincos/cos_p
add wave -dec /sincos_tb/i_sincos/sin_p
add wave -logic /sincos_tb/i_sincos/vld_major
add wave -dec /sincos_tb/i_sincos/cos_major
add wave -dec /sincos_tb/i_sincos/sin_major
add wave /sincos_tb/i_sincos/cos_interpol
add wave /sincos_tb/i_sincos/sin_interpol
add wave /sincos_tb/i_sincos/vld_interpol
add wave /sincos_tb/i_sincos/frac_interpol
add wave /sincos_tb/i_sincos/cos_slope
add wave /sincos_tb/i_sincos/sin_slope
add wave -logic /sincos_tb/i_sincos/dout_vld
add wave -dec -literal /sincos_tb/i_sincos/dout_cos
add wave -dec -literal /sincos_tb/i_sincos/dout_sin
add wave -literal /sincos_tb/i_sincos/PIPESTAGES
wv.cursors.add -time 8210500ps+1 -name {Default cursor}
wv.cursors.setactive -name {Default cursor}
wv.zoom.range -from 0fs -to 53600ps
wv.time.unit.auto.set
transcript $curr_transcript
