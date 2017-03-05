################################################################################
# Run a given SW test on ion32sim and the RTL and compare execution logs.
#
# Variables optionally set over command line:
#
#	TEST: 	SW test to run -- name of subdirectory of ../../sw.
#
#
# Targets:
#
#	iss:	Run test on ISS ion32sim.
#	rtl: 	Run test on RTL simulation on iverilog.
#   bin:	Build test SW.
#	all:	Do iss+rtl and then compare execution logs.
#	clean:	Clean simulation files *and clean sw test build*.
#
################################################################################

#!!!!!!!!!!!!!!!!!!!!!!!!!! -- WARNING-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# Obviously won't work with current VHDL RTL, part of refactor in progress.
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


TEST ?= cputest

CC_HIGLIGHT = "\033[1m"
CC_NORMAL = "\033[0m"

ION32SIM = ../../tools/ion32sim/bin/ion32sim
SWDIR = ../../sw



.PHONY: iss bin iss all clean


# Built test code.
bin: $(TEST)/firmware.bin

$(TEST)/firmware.bin:
	@echo -e $(CC_HIGLIGHT)"Building '"$(TEST)"'..."$(CC_NORMAL)
	make -C $(SWDIR)/$(TEST) all



# Run test code on ISS (ion32sim)
iss: bin
	@echo -e $(CC_HIGLIGHT)"Running '"$(TEST)"' on ion32sim..."$(CC_NORMAL)
	$(ION32SIM) --bram=$(SWDIR)/$(TEST)/firmware.bin --noprompt




clean:
	@make -C $(SWDIR)/$(TEST) clean