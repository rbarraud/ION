################################################################################
# HOW TO USE THIS MAKEFILE:
# 
# This program is meant to run in one of two platforms: the "tb_core" simulation 
# test bench and the "tb_application" simulation test bench.
# This makefile will assemble the source(s) and the will build two package files 
# used by the test bench; these packages include the simulation parameters, 
# like the size of the memories, and the object code.
#
# Run "make tb_app" to build for the tb_application test bench.
# Run "make tb_core" to build for the tb_core test bench.
#
# These targets differ only in the arguments passed on to the assembler -- some
# parts of the test are only meant for one of the platforms.
#
# Eventually this program will be upgraded to run on real hardware and a third 
# target will be added.
#
################################################################################

#-- Application setup ----------------------------------------------------------

PLATFORM = onchip
EXECUTABLE = cputest
DESCRIPTION = "CPU Tester"

# Test bench simulation timeout period in clock cycles.
SIM_LENGTH = 25000
# Start logging HW activity after fetching from this address.
LOG_TRIGGER = 0xbfc00000

#-- Build flag overrides -------------------------------------------------------

#CFLAGS =
#LFLAGS =

#-- Targets invoked by tb_app and tb_core (see common makefile) ----------------

# This makefile is a bit special; we link no other runtime files (no crt0, no 
# c library) and we need to use a variant of the main makefile. So we define 
# variable STANDALONE to let the main makefile know we want no support code.
STANDALONE = 1

# The main makefile will now expect us to define a "standalone" rule to build 
# our executable. We can cram everything in this single rule.
standalone:
	$(AS) -o opcode_emu.o $(SW_ROOT)/common/crt/opcode_emu.s
	$(AS) $(AFLAGS) -mips32r2 -o $(EXECUTABLE).o $(TBARGS) cputest.s
	$(LD) $(LFLAGS) -Map $(EXECUTABLE).map -s -N -o $(EXECUTABLE).axf $(EXECUTABLE).o opcode_emu.o
	-@$(DUMP) -I elf32-big --disassemble $(EXECUTABLE).axf > $(EXECUTABLE).lst
	$(COPY) -I elf32-big -O binary $(EXECUTABLE).axf $(EXECUTABLE).bin
	$(COPY) -I elf32-big -j.data -j.bss -O binary $(EXECUTABLE).axf $(EXECUTABLE).data

    
#-- Set assembler arguments for "tb_application" test bench.
set_tb_app_variables: 
	$(eval TBARGS := --defsym TEST_ICACHE=1 --defsym TARGET_HARDWARE=1)    

#-- Set assembler arguments for "tb_core" test bench.
set_tb_core_variables: 
	$(eval TBARGS := --defsym TEST_ICACHE=1)

#-- Application build configuration done, get main makefile --------------------

include ../common/makefile

