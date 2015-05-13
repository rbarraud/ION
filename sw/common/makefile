#-------------------------------------------------------------------------------
# This makefile contains all the variables and targets that are expected to be 
# common to all other makefiles within the project.
# It is meant to be included and not used standalone.
#-------------------------------------------------------------------------------
# TARGETS:
# Some of the targets defined in this file are meant for DIRECT invocation from 
# the command line:
#
# tb_app        Builds application files for tb_app TB. <--------- USE THIS.
# tb_core       Builds application files for tb_core TB.
# 
# The tb_core rtl is more limited and will only be useful when debugging the 
# TCM interconnect.
# 
#-------------------------------------------------------------------------------
# NOTE:
# See info on flag -G0 in ion_noxram.lds
#-------------------------------------------------------------------------------

### Give default values to the build variables that need it ####################

# Default platform is 'onchip' (no external memory, only TCMs).
PLATFORM ?= onchip
# Default name is irrelevant.
DESCRIPTION ?= "(not named)"
# Simulation length gets an arbitrary default.
SIM_LENGTH ?= 100000
# By default, HW execution trace disabled by using unreachable trigger address.
LOG_TRIGGER ?= 0xffffffff

### Include toolchain and hardware-related symbols #############################

# Hack used to include files in this file's directory.
SELF_DIR := $(dir $(lastword $(MAKEFILE_LIST)))

# Get hardware dependent variables (address ranges, etc.).
include $(SELF_DIR)toolchain.mak

### Expansion of hardware-related symbols ######################################

# FIXME HW symbols no longer necessary in common application code
# Format HW symbol list for 'as' command line.
AS_HWSYMS=$(foreach item,$(HWSYMS),--defsym $(item)_BASE=$($(item)_BASE) --defsym $(item)_SIZE=$($(item)_SIZE))
# Format HW symbol list for 'cc' command line.
CC_HWSYMS=$(foreach item,$(HWSYMS),-D$(item)_BASE=$($(item)_BASE) -D$(item)_SIZE=$($(item)_SIZE))
# Format HW symbol list for 'ld' command line.
LD_HWSYMS=$(foreach item,$(HWSYMS),--defsym $(item)_BASE=$($(item)_BASE) --defsym $(item)_SIZE=$($(item)_SIZE))


### VHDL source file manipulation tools ########################################
ION_TOOLS = ../../tools
VHDL_OBJ_PKG = $(PYTHON) $(ION_TOOLS)/build_pkg/build_pkg.py -t $(ION_TOOLS)/build_pkg/templates

### Project directories ########################################################

# Root test code source directory, where python script and vhdl templates are
SW_ROOT = ..
# VHDL test bench directory, where VHDL output files will be created
TB_DIR = ../../src/testbench
# Directory for object code package, to be used in synthesis.
OBJ_DIR = ../../src/rtl/obj

### Build options ##############################################################

# Link script to be used: by default, link for internal memory mode
LINK_SCRIPT = $(SW_ROOT)/common/bsp/$(PLATFORM)/config/linkscript.lds
# Path to elib (the clib replacement we're using in this build).
ELIBDIR = $(SW_ROOT)/common/elib/lib
# Path to HAL source directory for selected board. HAL header expected here.
HALDIR = $(SW_ROOT)/common/bsp/$(PLATFORM)/hal
HALLIBDIR = $(SW_ROOT)/common/bsp/$(PLATFORM)/lib

# Get hardware dependent variables (address ranges, etc.).
include $(SW_ROOT)/common/bsp/$(PLATFORM)/config/hardware.mak

# Don't use gcc builtin functions, and try to target MIPS-I architecture.
# This will prevent usage of unimplemented opcodes but will insert nops after
# load instructions, which Ion does not need.
# (See comment above about -G0 flag)
CFLAGS = -O2 -Wall -c -s -msoft-float -mips1 -G0 $(CC_HWSYMS) -I$(HALDIR)
# LFLAGS: Use HAL (BSP) library and ErsatzLib.
LFLAGS = -T$(LINK_SCRIPT) $(LD_HWSYMS) -eentry -I elf32-big -L $(HALLIBDIR) -lhal -L $(ELIBDIR) -le
# AFLAGS: 
AFLAGS = $(AS_HWSYMS) -msoft-float
# Symbol definitions for assembler and compiler.
ADDR_SYMS = -defsym TB_REGS_BOT=$(TB_REGS_START),TB_REGS_BOT=$(TB_REGS_START)


### Targets common to all C programs; indirect invocation! #####################

#-- Runtime object module list -- BSP code -------------------------------------

# Bootstrap code. From reset to crt0, including trap vectors.
OBJBOOT := $(SW_ROOT)/common/bsp/$(PLATFORM)/lib/boot.o
# Crt0.
OBJCRT  := $(SW_ROOT)/common/bsp/$(PLATFORM)/lib/crt0.o 

# If runtime code is not already built, do so now. 
# Note we don't have any runtime source dependencies!
$(OBJBOOT): runtime
$(OBJCRT): runtime
runtime:
	make -C $(SW_ROOT)/common/bsp/$(PLATFORM)
    
#-- Application build ----------------------------------------------------------

SRCDIR = .
SRCS := $(wildcard $(SRCDIR)/*.c)
OBJAPP := $(SRCS:$(SRCDIR)/%.c=%.o) 

#-- IMPORTANT: Keep this order or the linked executable will crash.
OBJS = $(OBJBOOT) $(OBJCRT) $(OBJHAL) $(OBJAPP)

.PHONY: program
program: $(EXECUTABLE).bin $(EXECUTABLE).data runtime

# WE have two different targets for the executable so that the app using this
# makefile can choose to skip all the support code -- crt0, clib, everything.
# This is meant for simple CPU test programs like the opcode tester.
ifdef STANDALONE
executable: standalone
else
executable: program
endif

$(EXECUTABLE).axf: $(OBJS)
	$(LD) -Map $(EXECUTABLE).map -N -o $(EXECUTABLE).axf $(OBJS) $(LFLAGS)
	-@$(DUMP) -m mips -S --disassemble $(EXECUTABLE).axf > $(EXECUTABLE).lst

    
$(EXECUTABLE).bin: $(EXECUTABLE).axf
# Extract object code to be placed in code space
	$(COPY) -I elf32-big -O binary $(EXECUTABLE).axf $(EXECUTABLE).bin

$(EXECUTABLE).data: $(EXECUTABLE).axf
# Extract object code to be placed in data space (useful in TBs)
	$(COPY) -I elf32-big -j.rodata -j.bss -O binary $(EXECUTABLE).axf $(EXECUTABLE).data

# We make this implicit rule explicit for clarity.
%.o: %.c
	$(CC) $(CFLAGS) $<    

    
################################################################################
### Targets that build the synthesizable vhdl; meant for direct invocation #####
  
# Build program for "tb_application" test bench. 
tb_app: set_tb_app_variables executable sim

# Build program for "tb_core" test bench. 
tb_core: set_tb_core_variables executable sim


#-- Creates VHDL package with data and parameters for simulation and synthesis.
sim: executable synth
	$(VHDL_OBJ_PKG) --project=$(DESCRIPTION) \
		--package SIM_PARAMS_PKG \
		--output $(TB_DIR)/common/sim_params_pkg.vhdl \
		-s $(SIM_LENGTH) --log_trigger=$(LOG_TRIGGER) \


#-- Create VHDL package with data and parameters for syntesis.
synth: executable
	$(VHDL_OBJ_PKG) --project=$(DESCRIPTION) \
		--package OBJ_CODE_PKG \
		--bin $(EXECUTABLE).bin --name OBJ_CODE --cmem_size $(CODE_TCM_SIZE) \
        --bin $(EXECUTABLE).data --name INIT_DATA --dmem_size $(DATA_TCM_SIZE)\
		--output $(OBJ_DIR)/obj_code_pkg.vhdl


### Other common targets #######################################################
      

.PHONY: clean      
clean:
	-$(RM) *.o *.map *.lst *.map *.axf *.data *.bin

