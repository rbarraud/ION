#-- Bring toolchain config parameters from the common makefile
include ../common/makefile


#-- Application setup ----------------------------------------------------------

APP_NAME = "Hello World!"

# Link script to be used: run from BRAM
LINK_SCRIPT = $(SRC_DIR)/common/link/internal.lds

# Code memory parameters -- Code TCM.
CODE_MEM_START  = 0xbfc00000
CODE_MEM_SIZE   = 2048
# Data memory parameters -- Data TCM.
DATA_MEM_START  = 0x00000000
DATA_MEM_SIZE   = 2048

# Test bench simulation timeout period in clock cycles.
SIM_LENGTH = 90000
# Start logging HW activity after fetching from this address.
LOG_TRIGGER = 0xbfc00000

#-- Build flags ----------------------------------------------------------------


LFLAGS = -T$(LINK_SCRIPT) -L $(LIB_PATH) \
         -Ttext $(CODE_MEM_START) -Tdata $(DATA_MEM_START) \
         -ereset -I elf32-big
CFLAGS = -O2 -Wall -c -s -msoft-float -mips1 -G0
AFLAGS = --defsym XRAM_BASE=$(DATA_MEM_START)


OBJS = boot_rom.o opcode_emu.o crt0.o hello.o


#-- Targets & rules ------------------------------------------------------------

.PHONY: program
program: hello.code hello.data

hello.axf: $(OBJS)
	$(LD) $(LFLAGS) -Map hello.map -s -N -o hello.axf $(OBJS)
	-@$(DUMP) -m mips --disassemble hello.axf > hello.lst

hello.code: hello.axf
# Extract object code to be placed in code space
	$(COPY) -I elf32-big -O binary hello.axf hello.code

hello.data: hello.axf
# Extract object code to be placed in data space
	$(COPY) -I elf32-big -j.rodata -j.bss -O binary hello.axf hello.data



boot_rom.o: $(SRC_DIR)/common/boot/boot_rom.s
	$(AS) $(AFLAGS) -o boot_rom.o $(SRC_DIR)/common/boot/boot_rom.s

crt0.o: $(SRC_DIR)/common/crt/crt0.s
	$(AS) $(AFLAGS) -o crt0.o $(SRC_DIR)/common/crt/crt0.s

opcode_emu.o: $(SRC_DIR)/common/crt/opcode_emu.s
	$(AS) $(AFLAGS) -o opcode_emu.o $(SRC_DIR)/common/crt/opcode_emu.s

hello.o: hello.c
	$(CC) $(CFLAGS) -o hello.o hello.c



#-- Targets that build the synthesizable vhdl; meant for direct invocation -----

#-- Create VHDL package with data and parameters for simulation and synthesis
sim: program synth
	$(VHDL_OBJ_PKG) --project=$(APP_NAME) \
		--package SIM_PARAMS_PKG \
		--output $(TB_DIR)/common/sim_params_pkg.vhdl \
		-s $(SIM_LENGTH) --log_trigger=$(LOG_TRIGGER) \


#-- Create VHDL package with data and parameters for syntesis
synth: program
	$(VHDL_OBJ_PKG) --project=$(APP_NAME) \
		--package OBJ_CODE_PKG \
		--bin hello.code --name OBJ_CODE --cmem_size $(CODE_MEM_SIZE) \
        --bin hello.data --name INIT_DATA --dmem_size $(DATA_MEM_SIZE)\
		--output $(OBJ_DIR)/obj_code_pkg.vhdl


#-- And now the usual housekeeping stuff ---------------------------------------

.PHONY: clean

clean:
	-$(RM) *.o *.obj *.map *.lst *.hex *.exe *.axf *.code *.data *.bin
