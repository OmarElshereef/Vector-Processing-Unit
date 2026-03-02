# =============================================================================
#  tb_booth_encoder_mod.do
#  ModelSim / QuestaSim do-file for tb_booth_encoder_mod
# =============================================================================

# --- Clean up old library ---------------------------------------------------
if {[file exists work]} {
    vdel -all
}
vlib work

# --- Compile dependencies (bottom-up order) ---------------------------------

# Booth / PPG sub-modules
vlog -sv booth_recoder.sv
vlog -sv ppg.sv
vlog -sv last_ppg.sv
vlog -sv booth_encoder_mod.sv

# Testbench
vlog -sv tb_booth_encoder_mod.sv

# --- Simulate ---------------------------------------------------------------
vsim -vopt -voptargs="+acc" work.tb_booth_encoder_mod

# --- Waveforms --------------------------------------------------------------
add wave -divider "Inputs"
add wave -radix hex  sim:/tb_booth_encoder_mod/multiplier
add wave -radix hex  sim:/tb_booth_encoder_mod/multiplicand
add wave -radix bin  sim:/tb_booth_encoder_mod/vector_mode
add wave -radix bin  sim:/tb_booth_encoder_mod/is_unsigned

add wave -divider "Partial Product Sum"
add wave -radix hex  sim:/tb_booth_encoder_mod/pp_sum

add wave -divider "Partial Products"
add wave -radix hex  sim:/tb_booth_encoder_mod/PPs

add wave -divider "Stats"
add wave -radix unsigned sim:/tb_booth_encoder_mod/test_num
add wave -radix unsigned sim:/tb_booth_encoder_mod/pass_cnt
add wave -radix unsigned sim:/tb_booth_encoder_mod/fail_cnt

# Internal DUT signals (uncomment for deeper debug)
# add wave -divider "DUT internals"
# add wave -radix hex  sim:/tb_booth_encoder_mod/dut/selected_mask
# add wave -radix bin  sim:/tb_booth_encoder_mod/dut/booth_rec/selze
# add wave -radix bin  sim:/tb_booth_encoder_mod/dut/booth_rec/selp1
# add wave -radix bin  sim:/tb_booth_encoder_mod/dut/booth_rec/selp2
# add wave -radix bin  sim:/tb_booth_encoder_mod/dut/booth_rec/seln1
# add wave -radix bin  sim:/tb_booth_encoder_mod/dut/booth_rec/seln2
# add wave -radix hex  sim:/tb_booth_encoder_mod/dut/booth_rec/boundary_bits

# --- Run to completion ------------------------------------------------------
run -all

# Fit all waveforms in view
wave zoom full
