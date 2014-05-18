#-------------------------------------------------------------------------------
# This makefile contains all the variables and targets that are expected to be 
# common to all other makefiles within the project.
# It is meant to be included and not used standalone.
#-------------------------------------------------------------------------------
# TARGETS:
#
# Some of the targets defined in this file are meant for DIRECT invocation from 
# the command line:
#
# tb_app
# tb_core
#
#-------------------------------------------------------------------------------
# NOTE:
# 
# See info on flag -G0 in ion_noxram.lds
#-------------------------------------------------------------------------------

# Hack used to include files in this file's directory.
SELF_DIR := $(dir $(lastword $(MAKEFILE_LIST)))

# Get hardware dependent variables (address ranges, etc.).
include $(SELF_DIR)toolchain.mak
# Get hardware dependent variables (address ranges, etc.).
include $(SELF_DIR)hardware.mak

### Expansion of hardware-related symbols ######################################

# Format HW symbol list for 'as' command line.
AS_HWSYMS=$(foreach item,$(HWSYMS),--defsym $(item)_BASE=$($(item)_BASE) --defsym $(item)_SIZE=$($(item)_SIZE))
# Format HW symbol list for 'cc' command line.
CC_HWSYMS=$(foreach item,$(HWSYMS),-D$(item)_BASE=$($(item)_BASE) -D$(item)_SIZE=$($(item)_SIZE))
# Format HW symbol list for 'ld' command line.
LD_HWSYMS=$(foreach item,$(HWSYMS),--defsym $(item)_BASE=$($(item)_BASE) --defsym $(item)_SIZE=$($(item)_SIZE))


### VHDL source file manipulation tools ########################################
ION_TOOLS = ../../tools
VHDL_OBJ_PKG = $(PYTHON) $(ION_TOOLS)/build_pkg/build_pkg.py -t $(ION_TOOLS)/build_pkg/templates

### Project directories -- to be replaced in application makefile ##############

# Root test code source directory, where python script and vhdl templates are
SW_ROOT = ..
# VHDL test bench directory, where VHDL output files will be created
TB_DIR = ../../src/testbench
# Directory for object code package, to be used in synthesis.
OBJ_DIR = ../../src/rtl/obj

### Build options -- to be replaced in application makefile ####################

# Link script to be used: by default, link for internal memory mode
LINK_SCRIPT = $(SW_ROOT)/common/link/internal.lds
# FIXME library stuff unfinished!
LIB_PATH=.

# Don't use gcc builtin functions, and try to target MIPS-I architecture.
# This will prevent usage of unimplemented opcodes but will insert nops after
# load instructions, which Ion does not need.
# (See comment above about -G0 flag)
CFLAGS = -O2 -Wall -c -s -msoft-float -mips1 -G0 $(CC_HWSYMS) -I$(SW_ROOT)/common/hal
# LFLAGS: Position main sections on memory, etc.
LFLAGS = -T$(LINK_SCRIPT) $(LD_HWSYMS) -eentry -I elf32-big -L $(LIB_PATH)
# AFLAGS: 
AFLAGS = $(AS_HWSYMS)
# Symbol definitions for assembler and compiler.
ADDR_SYMS = -defsym TB_REGS_BOT=$(TB_REGS_START),TB_REGS_BOT=$(TB_REGS_START)


### Targets common to all C programs; indirect invocation! #####################

#-- Common code build -- crt0 and bootstrap ------------------------------------

CRTDIR = $(SW_ROOT)/common/crt
BOOTDIR = $(SW_ROOT)/common/boot
HALDIR = $(SW_ROOT)/common/hal

#-- crt0
SRCCRT := $(wildcard $(CRTDIR)/*.s)
OBJCRT := $(SRCCRT:$(CRTDIR)/%.s=%.o)
#-- bootstrap code
SRCBOOT := $(wildcard $(BOOTDIR)/*.s)  
OBJBOOT := $(SRCBOOT:$(BOOTDIR)/%.s=%.o)
#-- HAL code
SRCHAL := $(wildcard $(HALDIR)/*.c)  
OBJHAL := $(SRCHAL:$(HALDIR)/%.c=%.o)


%.o: $(CRTDIR)/%.s
	$(AS) $(AFLAGS) -o $@ $^

%.o: $(BOOTDIR)/%.s
	$(AS) $(AFLAGS) -o $@ $^

%.o: $(HALDIR)/%.c
	$(CC) $(CFLAGS) -o $@ $^

    
#-- Application build config ---------------------------------------------------

SRCDIR = .
SRCS := $(wildcard $(SRCDIR)/*.c)
OBJAPP := $(SRCS:$(SRCDIR)/%.c=%.o) 

#-- IMPORTANT: Keep this order or the linked executable will crash.
OBJS = $(OBJBOOT) $(OBJCRT) $(OBJHAL) $(OBJAPP) 


### Targets that build the synthesizable vhdl; meant for direct invocation #####
  
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


#-- Create VHDL package with data and parameters for syntesis.
synth: program
	$(VHDL_OBJ_PKG) --project=$(APP_NAME) \
		--package OBJ_CODE_PKG \
		--bin $(TARGET).bin --name OBJ_CODE --cmem_size $(CODE_TCM_SIZE) \
        --bin $(TARGET).data --name INIT_DATA --dmem_size $(DATA_TCM_SIZE)\
		--output $(OBJ_DIR)/obj_code_pkg.vhdl


### Other common targets #######################################################
        
clean:
	-$(RM) *.o *.map *.lst *.map *.axf *.data *.bin

