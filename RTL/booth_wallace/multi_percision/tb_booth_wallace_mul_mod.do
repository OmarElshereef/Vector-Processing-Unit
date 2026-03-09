# =============================================================================
#  tb_booth_wallace_mul_mod.do
#  ModelSim / QuestaSim do-file for tb_booth_wallace_mul_mod
# =============================================================================

# --- Clean up old library ---------------------------------------------------
if {[file exists work]} {
    vdel -all
}
vlib work

# --- Compile dependencies (bottom-up order) ---------------------------------

# Primitives
vlog -sv ../../common/full_adder.sv

# CSA compressors
vlog -sv ../CSA_3_2.sv
vlog -sv ../CSA_4_2.sv

# Booth / PPG sub-modules
vlog -sv booth_recoder.sv
vlog -sv ppg.sv
vlog -sv last_ppg.sv
vlog -sv booth_encoder_mod.sv
vlog -sv wallace_tree_mod.sv

# Combined DUT
vlog -sv booth_wallace_mul_mod.sv

# Testbench
vlog -sv tb_booth_wallace_mul_mod.sv

# --- Simulate ---------------------------------------------------------------
# -vopt forces optimizer on even if the global modelsim.ini sets VoptFlow=0
vsim -vopt -voptargs="+acc" work.tb_booth_wallace_mul_mod

# --- Waveforms --------------------------------------------------------------
add wave -divider "Inputs"
add wave -radix hex sim:/tb_booth_wallace_mul_mod/multiplier
add wave -radix hex sim:/tb_booth_wallace_mul_mod/multiplicand
add wave -radix bin sim:/tb_booth_wallace_mul_mod/vector_mode
add wave -radix bin sim:/tb_booth_wallace_mul_mod/is_unsigned

add wave -divider "Output"
add wave -radix hex sim:/tb_booth_wallace_mul_mod/result

add wave -divider "Stats"
add wave -radix unsigned sim:/tb_booth_wallace_mul_mod/test_num
add wave -radix unsigned sim:/tb_booth_wallace_mul_mod/pass_cnt
add wave -radix unsigned sim:/tb_booth_wallace_mul_mod/fail_cnt

# Internal partial products (encoder output)
# add wave -divider "--- Partial Products (encoder) ---"
# add wave -radix hex sim:/tb_booth_wallace_mul_mod/dut/PPs

# --- Run to completion ------------------------------------------------------
run -all

# Fit all waveforms in view
wave zoom full
