# ModelSim/Questa simulation script for tb_ssn
# SSN (Scatter Shift Network) Testbench

# Create and map work library
vlib work
vmap work work

# Compile design files
vlog -sv ../../../RISCV_Config_PKG.sv
vlog -sv in_node.sv
vlog -sv out_node.sv
vlog -sv switch_node.sv
vlog -sv ssn.sv

# Compile testbench
vlog -sv tb_ssn.sv

# Start simulation
vsim -voptargs=+acc work.tb_ssn

# Add waves
add wave -divider "Clock & Control"
add wave -position insertpoint sim:/tb_ssn/dut/*

add wave -divider "Input Data"
add wave -position insertpoint -radix hexadecimal sim:/tb_ssn/data_in

add wave -divider "Control Signals"
add wave -position insertpoint -radix binary sim:/tb_ssn/controls

add wave -divider "Output Data"
add wave -position insertpoint -radix hexadecimal sim:/tb_ssn/data_out

add wave -divider "Internal Layers"
add wave -position insertpoint -radix hexadecimal sim:/tb_ssn/dut/layer_data

# Configure wave window
configure wave -namecolwidth 250
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2

# Run simulation
run -all

# Zoom to fit
wave zoom full
