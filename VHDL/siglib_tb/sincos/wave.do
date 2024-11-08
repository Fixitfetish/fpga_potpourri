onerror { resume }
set curr_transcript [transcript]
transcript off

add wave -literal /sincos_tb/i_dut/PHASE_MAJOR_WIDTH
add wave -literal /sincos_tb/i_dut/PHASE_MINOR_WIDTH
add wave -literal /sincos_tb/i_dut/OUTPUT_WIDTH
add wave -literal /sincos_tb/i_dut/SINCOS_WIDTH
add wave -literal /sincos_tb/i_dut/SINCOS_MAX
add wave -literal /sincos_tb/i_dut/LUT_WIDTH
add wave -literal /sincos_tb/i_dut/LUT_DEPTH_LD
add wave -literal /sincos_tb/i_dut/LUT_DEPTH
add wave -literal /sincos_tb/i_dut/LUT
add wave -literal /sincos_tb/i_dut/SLOPE_WIDTH
add wave /sincos_tb/i_dut/clk
add wave /sincos_tb/i_dut/rst
add wave /sincos_tb/i_dut/clkena
add wave /sincos_tb/i_dut/phase_vld
add wave -unsigned /sincos_tb/i_dut/phase
add wave -logic /sincos_tb/i_dut/lut_in_vld
add wave /sincos_tb/i_dut/lut_in_quad
add wave -unsigned /sincos_tb/i_dut/lut_in_addr
add wave -dec -literal /sincos_tb/i_dut/lut_in_frac
add wave -logic /sincos_tb/i_dut/lut_in_vld_q
add wave -literal /sincos_tb/i_dut/lut_in_quad_q
add wave -unsigned /sincos_tb/i_dut/lut_in_addr_q
add wave -dec -literal /sincos_tb/i_dut/lut_in_frac_q
add wave -logic /sincos_tb/i_dut/lut_out_vld
add wave /sincos_tb/i_dut/lut_out_quad
add wave -dec /sincos_tb/i_dut/lut_out_frac
add wave -literal /sincos_tb/i_dut/lut_out_data
add wave -dec /sincos_tb/i_dut/cos_p
add wave -dec /sincos_tb/i_dut/sin_p
add wave -logic /sincos_tb/i_dut/vld_major
add wave -dec /sincos_tb/i_dut/cos_major
add wave -dec /sincos_tb/i_dut/sin_major
add wave /sincos_tb/i_dut/cos_interpol
add wave /sincos_tb/i_dut/sin_interpol
add wave /sincos_tb/i_dut/vld_interpol
add wave /sincos_tb/i_dut/frac_interpol
add wave /sincos_tb/i_dut/cos_slope
add wave /sincos_tb/i_dut/sin_slope
add wave -logic /sincos_tb/i_dut/dout_vld
add wave -dec -literal /sincos_tb/i_dut/dout_cos
add wave -dec -literal /sincos_tb/i_dut/dout_sin
add wave -literal /sincos_tb/i_dut/PIPESTAGES
wv.cursors.add -time 8210500ps+1 -name {Default cursor}
wv.cursors.setactive -name {Default cursor}
wv.zoom.range -from 0fs -to 53600ps
wv.time.unit.auto.set
transcript $curr_transcript
