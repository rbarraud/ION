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


# Get common makefile stuff (toolchain & system config)
include ../common/makefile

#-- Application setup ----------------------------------------------------------

TARGET = cputest
APP_NAME = "CPU tester"

# Link script to be used
LINK_SCRIPT = $(SW_ROOT)/common/link/internal.lds

# Code memory parameters -- Code TCM.
CODE_MEM_START  = 0xbfc00000
CODE_MEM_SIZE   = 16384
# Data memory parameters -- Data TCM.
DATA_MEM_START  = 0x00000000
DATA_MEM_SIZE   = 1024

# Test bench simulation timeout period in clock cycles.
SIM_LENGTH = 25000
# Start logging HW activity after fetching from this address.
LOG_TRIGGER = 0xbfc00000


#-- Build flags ----------------------------------------------------------------

LFLAGS = -Ttext $(CODE_MEM_START) -Tdata $(DATA_MEM_START) -eentry -I elf32-big


#-- Targets & rules ------------------------------------------------------------

# This makefile is a bit special; we link no other files than the opcode test 
# source, so we can cram all in a single rule.

program:
	$(AS) -o opcode_emu.o $(SW_ROOT)/common/crt/opcode_emu.s
	$(AS) -defsym XRAM_BASE=$(DATA_MEM_START) -mips32r2 -o $(TARGET).o $(TBARGS) cputest.s
	$(LD) $(LFLAGS) -Map $(TARGET).map -s -N -o $(TARGET).axf $(TARGET).o opcode_emu.o
	-@$(DUMP) -I elf32-big --disassemble $(TARGET).axf > $(TARGET).lst
	$(COPY) -I elf32-big -O binary $(TARGET).axf $(TARGET).bin
	$(COPY) -I elf32-big -j.data -j.bss -O binary $(TARGET).axf $(TARGET).data

    

#-- Targets that build the synthesizable vhdl; meant for direct invocation -----
  
# Build program for "tb_application" test bench. 
tb_app: set_tb_app_variables program sim

# Build program for "tb_core" test bench. 
tb_core: set_tb_core_variables program sim


#-- Creates VHDL package with data and parameters for simulation and synthesis.
sim: program synth

	$(VHDL_OBJ_PKG) --project=$(APP_NAME) \
		--package SIM_PARAMS_PKG \
		--output $(TB_DIR)/common/sim_params_pkg.vhdl \
		-s $(SIM_LENGTH) --log_trigger=$(LOG_TRIGGER) \


#-- Create VHDL package with data and parameters for syntesis
synth: program
	$(VHDL_OBJ_PKG) --project=$(APP_NAME) \
		--package OBJ_CODE_PKG \
		--bin $(TARGET).bin --name OBJ_CODE --cmem_size $(CODE_MEM_SIZE) \
        --bin $(TARGET).data --name INIT_DATA --dmem_size $(DATA_MEM_SIZE)\
		--output $(OBJ_DIR)/obj_code_pkg.vhdl

#-- Set assembler arguments for "tb_application" test bench.
set_tb_app_variables: 
	$(eval TBARGS := --defsym TEST_ICACHE=1 --defsym TARGET_HARDWARE=1)    

#-- Set assembler arguments for "tb_core" test bench.
set_tb_core_variables: 
	$(eval TBARGS := --defsym TEST_ICACHE=1)

        
#-- And now the usual housekeeping stuff ---------------------------------------

.PHONY: clean

clean:
	-$(RM) *.o *.obj *.map *.lst *.hex *.exe *.axf *.code *.data *.bin

