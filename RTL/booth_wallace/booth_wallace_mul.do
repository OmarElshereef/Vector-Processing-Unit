# DO file for tb_booth_wallace_multiplier (ModelSim/Questa GUI style)

# Delete old work library if present
if {[file exists work]} {
	vdel -all
}

# Create work library
vlib work

# Compile sources (explicit ordering helps for dependencies)
vlog full_adder.sv
vlog half_adder.sv
vlog booth_encoder.sv
vlog no_ripple_n_full_adder.sv
vlog wallace_tree.sv
vlog booth_wallace_mul.sv

# Compile the testbench
vlog tb_booth_wallace_mul.sv

# Launch GUI simulation with optimizations
vsim -voptargs="+acc" work.tb_booth_wallace_multiplier

# Add waveform groups and signals
add wave -divider "Testbench"
add wave sim:/tb_booth_wallace_multiplier/a
add wave sim:/tb_booth_wallace_multiplier/b
add wave -divider "DUT"
add wave sim:/tb_booth_wallace_multiplier/dut/product
add wave -divider "Checks"
add wave sim:/tb_booth_wallace_multiplier/expected

# Run the simulation (runs to completion of the testbench)
run -all

# Zoom to see all waveforms
wave zoom full

# Keep GUI open (uncomment to auto-exit)
# quit -sim
