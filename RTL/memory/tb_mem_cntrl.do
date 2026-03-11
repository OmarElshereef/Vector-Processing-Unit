# Memory Controller Testbench DO File
# This script compiles and simulates the memory controller with its testbench

# Create work library if it doesn't exist
if {[file exists work]} {
    vdel -lib work -all
}
vlib work

# Compile the package file first
vlog -work work "../RISCV_Config_PKG.sv"

# Compile common modules
vlog -work work "../common/full_adder.sv"
vlog -work work "../common/half_adder.sv"
vlog -work work "../common/mux_2x1.sv"
vlog -work work "../common/mux_4x1.sv"

# Compile DROM and its dependencies
echo "Compiling DROM and shift networks..."
# Add DROM shift network files if they exist
if {[file exists "DROM/shift_networks"]} {
    vlog -work work "DROM/shift_networks/*.sv"
}
vlog -work work "DROM/scg.sv"
vlog -work work "DROM/DROM.sv"

# Compile LSDO and its dependencies
echo "Compiling LSDO modules..."
vlog -work work "LSDO/reverser.sv"
vlog -work work "LSDO/byte_shifter.sv"
vlog -work work "LSDO/LSDO.sv"

# Compile the memory controller
echo "Compiling memory controller..."
vlog -work work "mem_cntrl.sv"

# Compile the testbench
echo "Compiling testbench..."
vlog -work work "tb_mem_cntrl.sv"

# Start simulation
echo "Starting simulation..."
vsim -voptargs=+acc work.tb_mem_cntrl

# Add waves
add wave -divider "Clock and Control"
add wave -color "Yellow" sim:/tb_mem_cntrl/clk
add wave -color "Cyan" sim:/tb_mem_cntrl/start
add wave -color "Cyan" sim:/tb_mem_cntrl/running

add wave -divider "Configuration Inputs"
add wave -radix unsigned sim:/tb_mem_cntrl/mode
add wave -radix unsigned sim:/tb_mem_cntrl/SEW
add wave -radix unsigned sim:/tb_mem_cntrl/stride
add wave -radix unsigned sim:/tb_mem_cntrl/stride_dir
add wave -radix unsigned sim:/tb_mem_cntrl/offset
add wave -radix hexadecimal sim:/tb_mem_cntrl/vlb
add wave -radix hexadecimal sim:/tb_mem_cntrl/address

add wave -divider "Memory Interface"
add wave -radix hexadecimal sim:/tb_mem_cntrl/address_out
add wave -radix hexadecimal sim:/tb_mem_cntrl/data_mem
add wave -radix binary sim:/tb_mem_cntrl/valid_out_mem
add wave -radix hexadecimal sim:/tb_mem_cntrl/mem_model
add wave sim:/tb_mem_cntrl/mem_drive_enable

add wave -divider "VRF Interface"
add wave -radix hexadecimal sim:/tb_mem_cntrl/data_vrf
add wave -radix binary sim:/tb_mem_cntrl/valid_out_vrf
add wave -radix hexadecimal sim:/tb_mem_cntrl/vrf_model
add wave sim:/tb_mem_cntrl/vrf_drive_enable

add wave -divider "DUT Internal Signals"
add wave -radix unsigned sim:/tb_mem_cntrl/dut/cycle_count
add wave -radix unsigned sim:/tb_mem_cntrl/dut/element_per_cycle
add wave -radix unsigned sim:/tb_mem_cntrl/dut/total_cycles
add wave sim:/tb_mem_cntrl/dut/ended
add wave -radix unsigned sim:/tb_mem_cntrl/dut/stride_reg
# add wave sim:/tb_mem_cntrl/dut/stride_dir_reg
# add wave sim:/tb_mem_cntrl/dut/mode_wire
add wave sim:/tb_mem_cntrl/dut/mode_reg
add wave -radix hexadecimal sim:/tb_mem_cntrl/dut/data_buffer
add wave -radix binary sim:/tb_mem_cntrl/dut/valid_buffer
add wave -radix hexadecimal sim:/tb_mem_cntrl/dut/shift_reg
add wave -radix hexadecimal sim:/tb_mem_cntrl/dut/address_reg

add wave -divider "LSDO Signals"
add wave -radix hexadecimal sim:/tb_mem_cntrl/dut/lsdo_out
add wave -radix binary sim:/tb_mem_cntrl/dut/lsdo_valid_out

add wave -divider "Test Control"
add wave -radix unsigned sim:/tb_mem_cntrl/test_num

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
echo "Running simulation..."
run -all

# Zoom to fit
wave zoom full

echo "Simulation complete. Use 'wave zoom full' to view all signals."
