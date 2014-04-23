# assumed to run from /<project directory>/sim/modelsim/ion_core
vlib work

# Compile all the core files.
vcom -reportprogress 300 -work work ../../../src/rtl/common/ion_interfaces_pkg.vhdl
vcom -reportprogress 300 -work work ../../../src/rtl/common/ion_internal_pkg.vhdl
vcom -reportprogress 300 -work work ../../../src/rtl/cpu/ion_shifter.vhdl
vcom -reportprogress 300 -work work ../../../src/rtl/cpu/ion_alu.vhdl
vcom -reportprogress 300 -work work ../../../src/rtl/cpu/ion_muldiv.vhdl
vcom -reportprogress 300 -work work ../../../src/rtl/cpu/ion_cop0.vhdl
vcom -reportprogress 300 -work work ../../../src/rtl/cpu/ion_cpu.vhdl
vcom -reportprogress 300 -work work ../../../src/rtl/buses/ion_ctcm_arbiter.vhdl
vcom -reportprogress 300 -work work ../../../src/rtl/buses/ion_tcm_code.vhdl
vcom -reportprogress 300 -work work ../../../src/rtl/buses/ion_tcm_data.vhdl
vcom -reportprogress 300 -work work ../../../src/rtl/caches/ion_cache.vhdl
vcom -reportprogress 300 -work work ../../../src/rtl/caches/ion_wishbone_bridge.vhdl
vcom -reportprogress 300 -work work ../../../src/rtl/cpu/ion_core.vhdl
# Compile the package that contains the object code & other config constants.
vcom -reportprogress 300 -work work ../../../src/rtl/obj/obj_code_pkg.vhdl

# Compile the test bench and its support stuff.
vcom -reportprogress 300 -work work ../../../src/testbench/common/txt_util.vhdl
vcom -reportprogress 300 -work work ../../../src/testbench/common/ion_tb_pkg.vhdl
#vlog -reportprogress 300 -work work ../../../src/testbench/common/models/mt48lc4m16a2.v
vcom -reportprogress 300 -work work ../../../src/testbench/common/sim_params_pkg.vhdl
vcom -reportprogress 300 -work work ../../../src/testbench/ion_core_tb.vhdl

# Set up the simulation.
vsim -t ps work.ion_core_tb(testbench)

# Run a script that will set up a neat waveform window for us...
do ./ion_core_tb_wave.do
# ...and do some other cosmetic configuration choices.
set PrefMain(font) {Courier 9 roman normal}

# Tell simulator to ignore these warnings or we´ll be swamped in them.
# These are produced by Z or U values in the buses and are harmless.
set NumericStdNoWarnings 1
set StdArithNoWarnings 1

# Ready to run, do so for a resonable time.
run 150 us
