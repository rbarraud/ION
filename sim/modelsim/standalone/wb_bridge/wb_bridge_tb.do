# assumed to run from /<project directory>/sim/modelsim/standalone/wb_bridge
vlib work

# Compile all the core files.
vcom -reportprogress 300 -work work ../../../../src/rtl/common/ion_interfaces_pkg.vhdl
vcom -reportprogress 300 -work work ../../../../src/rtl/common/ion_internal_pkg.vhdl
vcom -reportprogress 300 -work work ../../../../src/rtl/buses/ion_wishbone_bridge.vhdl

# Compile the test bench and its support stuff.
vcom -reportprogress 300 -work work ../../../../src/testbench/common/txt_util.vhdl
vcom -reportprogress 300 -work work ../../../../src/testbench/standalone/wb_bridge_tb.vhdl

# Set up the simulation.
vsim -t ps work.wb_bridge_tb(testbench)

# Run a script that will set up a neat waveform window for us...
do ./wb_bridge_tb_wave.do
# ...and do some other cosmetic configuration choices.
set PrefMain(font) {Courier 9 roman normal}

# Tell simulator to ignore these warnings or we´ll be swamped in them.
# These are produced by Z or U values in the buses and are harmless.
set NumericStdNoWarnings 1
set StdArithNoWarnings 1

# Ready to run, do so for a resonable time.
run 100 us
