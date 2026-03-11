# ModelSim/Questa simulation script for tb_LSDO
# LSDO (Load/Store Data Ordering) Testbench

# Create and map work library
vlib work
vmap work work

# Compile design files in dependency order
# First compile package
vlog -sv ../../RISCV_Config_PKG.sv

# Compile basic building blocks for DROM
vlog -sv ../DROM/shift_networks/in_node.sv
vlog -sv ../DROM/shift_networks/out_node.sv
vlog -sv ../DROM/shift_networks/switch_node.sv
vlog -sv ../DROM/shift_networks/gsn.sv
vlog -sv ../DROM/shift_networks/ssn.sv
vlog -sv ../DROM/scg.sv

# Compile DROM module
vlog -sv ../DROM/DROM.sv

# Compile LSDO components
vlog -sv reverser.sv
vlog -sv byte_shifter.sv

# Compile LSDO top-level module
vlog -sv LSDO.sv

# Compile testbench
vlog -sv tb_LSDO.sv

# Start simulation
vsim -voptargs=+acc work.tb_LSDO

# Add waves
add wave -divider "Clock & Control"
add wave -position insertpoint sim:/tb_LSDO/clk
add wave -position insertpoint sim:/tb_LSDO/mode

add wave -divider "Direction & Shift Controls"
add wave -position insertpoint sim:/tb_LSDO/data_dir
add wave -position insertpoint -radix unsigned sim:/tb_LSDO/shift

add wave -divider "DROM Parameters"
add wave -position insertpoint -radix unsigned sim:/tb_LSDO/SEW
add wave -position insertpoint -radix unsigned sim:/tb_LSDO/offset
add wave -position insertpoint -radix unsigned sim:/tb_LSDO/stride

add wave -divider "Input Data"
add wave -position insertpoint -radix hexadecimal sim:/tb_LSDO/data_in

add wave -divider "Output Data"
add wave -position insertpoint -radix hexadecimal sim:/tb_LSDO/data_out


# Configure wave window
configure wave -namecolwidth 250
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1

# Run simulation
run -all

# Zoom to fit
wave zoom full
