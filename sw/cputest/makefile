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

# Get common makefile stuff (toolchain & system config).
include ../common/makefile

#-- Application setup ----------------------------------------------------------

# Name of executable and label to use in VHDL files.
TARGET = cputest
APP_NAME = "CPU tester"

# Test bench simulation timeout period in clock cycles.
SIM_LENGTH = 25000
# Start logging HW activity after fetching from this address.
LOG_TRIGGER = 0xbfc00000


#-- Build flags (override default values if necessary) -------------------------

#CFLAGS =
#LFLAGS =


#-- Targets & rules ------------------------------------------------------------

# This makefile is a bit special; we link no other files than the opcode test 
# source, so we can cram all in a single rule.

program:
	$(AS) -o opcode_emu.o $(SW_ROOT)/common/crt/opcode_emu.s
	$(AS) $(AFLAGS) -mips32r2 -o $(TARGET).o $(TBARGS) cputest.s
	$(LD) $(LFLAGS) -Map $(TARGET).map -s -N -o $(TARGET).axf $(TARGET).o opcode_emu.o
	-@$(DUMP) -I elf32-big --disassemble $(TARGET).axf > $(TARGET).lst
	$(COPY) -I elf32-big -O binary $(TARGET).axf $(TARGET).bin
	$(COPY) -I elf32-big -j.data -j.bss -O binary $(TARGET).axf $(TARGET).data

    

#-- Targets invoked by tb_app and tb_core (see common makefile) ----------------

#-- Set assembler arguments for "tb_application" test bench.
set_tb_app_variables: 
	$(eval TBARGS := --defsym TEST_ICACHE=1 --defsym TARGET_HARDWARE=1)    

#-- Set assembler arguments for "tb_core" test bench.
set_tb_core_variables: 
	$(eval TBARGS := --defsym TEST_ICACHE=1)

        
#-- And now the usual housekeeping stuff ---------------------------------------

.PHONY: clean

