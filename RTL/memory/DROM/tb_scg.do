# ModelSim/Questa simulation script for tb_scg
# SCG (Shift Count Generation) Testbench

# Create and map work library
vlib work
vmap work work

# Compile design files in dependency order
# First compile package
vlog -sv ../../RISCV_Config_PKG.sv

# Then compile scg
vlog -sv scg.sv

# Compile testbench
vlog -sv tb_scg.sv

# Start simulation
vsim -voptargs=+acc work.scg_tb

# Add waves
add wave -divider "Input Parameters"
add wave -position insertpoint -radix unsigned sim:/scg_tb/stride
add wave -position insertpoint -radix unsigned sim:/scg_tb/SEW
add wave -position insertpoint -radix unsigned sim:/scg_tb/offset

add wave -divider "Control Outputs"
add wave -position insertpoint -radix binary sim:/scg_tb/controls

add wave -divider "Internal Signals"
add wave -position insertpoint -radix unsigned sim:/scg_tb/dut/diff
add wave -position insertpoint -radix unsigned sim:/scg_tb/dut/final_shifts

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
