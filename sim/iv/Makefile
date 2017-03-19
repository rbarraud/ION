################################################################################
# Run a given SW test on ion32sim and the RTL and compare execution logs.
#
# Variables optionally set over command line:
#
#	TEST:   SW test to run (name of subdirectory of ../../sw).
#
#
# Targets:
#
#   iss:    Run test on ISS ion32sim.
#   rtl:    Run test on RTL simulation on iverilog.
#   sw:     Build test SW.
#   all:    Do iss+rtl and then compare execution logs.
#   clean:	Clean simulation files *and clean sw test build*.
#
################################################################################

#!!!!!!!!!!!!!!!!!!!!!!!!!! -- WARNING-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# Obviously won't work with current VHDL RTL, part of refactor in progress.
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# Config vars. 
TEST ?= cputest

# Project layout.
SWDIR = ../../sw
RTLDIR = ../../src
TOOLDIR = ../../tools
ION32SIM = $(TOOLDIR)/ion32sim/bin/ion32sim
TEST_OBJ = $(TEST)/software.hex

CC_HIGLIGHT = "\033[1m"
CC_NORMAL = "\033[0m"

# RTL layout.
# TOSO TB entity always has same name 'testbench' but we'll have separate TB
# source files for CPU and CPU+cache+TCM.
RTL_SOURCES = $(RTLDIR)/testbench/tb_cpu.v $(RTLDIR)/rtl/cpu.v


#-------------------------------------------------------------------------------

.PHONY: iss bin iss all rtl view clean


all: iss rtl
	@cmp -s sw_sim_log.txt rtl_sim_log.txt; \
	RETVAL=$$?; \
	if [ $$RETVAL -eq 0 ]; then \
		echo -e "\n\033[1;32mEXECUTION LOGS MATCH\033[0m\n"; \
	else \
		echo -e "\n\033[1;31mEXECUTION LOGS DO NOT MATCH\033[0m\n"; \
	fi	





#-- Test SW build stuff --------------------------------------------------------

sw: $(TEST_OBJ)

$(TEST_OBJ):
	@echo -e $(CC_HIGLIGHT)"Building '"$(TEST)"'..."$(CC_NORMAL)
	make -C $(SWDIR)/$(TEST) all

#-- ISS sim stuff --------------------------------------------------------------

# Run test code on ISS (ion32sim).
iss: $(TEST_OBJ)
	@echo -e $(CC_HIGLIGHT)"Running '"$(TEST)"' on ion32sim..."$(CC_NORMAL)
	$(ION32SIM) --bram=$(SWDIR)/$(TEST)/software.bin --noprompt


#-- RTL sim stuff --------------------------------------------------------------

# Run test on RTL over iverilog.
rtl: testbench.exe $(TEST_OBJ)
	@echo -e $(CC_HIGLIGHT)"Running '"$(TEST)"' on iverilog..."$(CC_NORMAL)
	vvp -N testbench.exe

testbench.exe: $(RTL_SOURCES)
	iverilog -g2005 -o testbench.exe $(RTL_SOURCES)
	@chmod -x testbench.exe

# Waveform generation.
testbench.vcd: testbench.exe  $(TEST_OBJ)
	vvp -N $< +vcd

view: testbench.vcd
	gtkwave $< testbench.gtkw


#-------------------------------------------------------------------------------

clean:
	@rm -f *_log.txt
	@rm -vrf testbench*.exe testbench.vcd
	@make -C $(SWDIR)/$(TEST) clean