# ModelSim/Questa simulation script for tb_DROM
# DROM (Dynamic Reorder Module) Testbench

# Create and map work library
vlib work
vmap work work

# Compile design files in dependency order
# First compile basic building blocks
vlog -sv ../../RISCV_Config_PKG.sv
vlog -sv shift_networks/in_node.sv
vlog -sv shift_networks/out_node.sv
vlog -sv shift_networks/switch_node.sv

# Then compile shift networks
vlog -sv shift_networks/gsn.sv
vlog -sv shift_networks/ssn.sv

# Compile shift count generation
vlog -sv scg.sv

# Compile top-level module
vlog -sv DROM.sv

# Compile testbench
vlog -sv tb_DROM.sv

# Start simulation
vsim -voptargs=+acc work.tb_DROM

# Add waves
add wave -divider "Clock & Control"
add wave -position insertpoint sim:/tb_DROM/clk
add wave -position insertpoint sim:/tb_DROM/mode

add wave -divider "Input Parameters"
add wave -position insertpoint -radix unsigned sim:/tb_DROM/stride
add wave -position insertpoint -radix unsigned sim:/tb_DROM/SEW
add wave -position insertpoint -radix unsigned sim:/tb_DROM/offset

add wave -divider "Input Data"
add wave -position insertpoint -radix hexadecimal sim:/tb_DROM/data_in

add wave -divider "Output Data"
add wave -position insertpoint -radix hexadecimal sim:/tb_DROM/data_out

add wave -divider "Internal Control Signals"
add wave -position insertpoint -radix binary sim:/tb_DROM/dut/Ctrl_wire
add wave -position insertpoint -radix binary sim:/tb_DROM/dut/Ctrl_buff

add wave -divider "Internal Data"
add wave -position insertpoint -radix hexadecimal sim:/tb_DROM/dut/Data_buff

# Configure wave window
configure wave -namecolwidth 300
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
