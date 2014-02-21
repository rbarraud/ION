#-- Bring toolchain config parameters from the common makefile
include ../common/makefile


#-- Application setup ----------------------------------------------------------

TARGET = libtest
APP_NAME = "LibC Test"

# Link script to be used: run from BRAM
LINK_SCRIPT = $(SW_ROOT)/common/link/internal.lds

# Code memory parameters -- Code TCM.
CODE_MEM_START  = 0xbfc00000
CODE_MEM_SIZE   = 32768
# Data memory parameters -- Data TCM.
DATA_MEM_START  = 0x00000000
DATA_MEM_SIZE   = 32768

# Test bench simulation timeout period in clock cycles.
SIM_LENGTH = 90000
# Start logging HW activity after fetching from this address.
LOG_TRIGGER = 0xbfc00000

#-- Build flags ----------------------------------------------------------------

LFLAGS = -T$(LINK_SCRIPT) -L $(LIBPATH) \
         -Ttext $(CODE_MEM_START) -Tdata $(DATA_MEM_START) \
         -ereset -I elf32-big 
CFLAGS = -O2 -Wall -c -s -msoft-float -G0
AFLAGS = --defsym XRAM_BASE=$(DATA_MEM_START)


#-- Common code build -- crt0 and bootstrap ------------------------------------

CRTDIR = $(SW_ROOT)/common/crt
BOOTDIR = $(SW_ROOT)/common/boot
SYSDIR = $(SW_ROOT)/common/lib/tb

#-- crt0
SRCCRT := $(wildcard $(CRTDIR)/*.s)
OBJCRT := $(SRCCRT:$(CRTDIR)/%.s=%.o)
#-- bootstrap code
SRCBOOT := $(wildcard $(BOOTDIR)/*.s)  
OBJBOOT := $(SRCBOOT:$(BOOTDIR)/%.s=%.o)
#-- libc system functions code
SRCSYS := $(wildcard $(SYSDIR)/*.c)  
OBJSYS := $(SRCSYS:$(SYSDIR)/%.c=%.o)

%.o: $(CRTDIR)/%.s
	$(AS) $(AFLAGS) -o $@ $^

%.o: $(BOOTDIR)/%.s
	$(AS) $(AFLAGS) -o $@ $^

%.o: $(SYSDIR)/%.c
	$(CC) $(CFLAGS) $<


#-- Application build config ---------------------------------------------------

SRCDIR = .
SRCS := $(wildcard $(SRCDIR)/*.c)
OBJAPP := $(SRCS:$(SRCDIR)/%.c=%.o) 

#-- IMPORTANT: Keep this order or the linked executable will crash.
OBJS = $(OBJBOOT) $(OBJCRT) $(OBJAPP) $(OBJSYS)


#-- App build targets & rules --------------------------------------------------

.PHONY: program
program: $(TARGET).code $(TARGET).data


$(TARGET).axf: $(OBJS)
	$(LD) $(LFLAGS) -Map $(TARGET).map -N -o $(TARGET).axf $(OBJS) $(SYSLIBS)
	-@$(DUMP) -m mips -S --disassemble $(TARGET).axf > $(TARGET).lst

%.o: %.c
	$(CC) $(CFLAGS) $<    

    
$(TARGET).code: $(TARGET).axf
# Extract object code to be placed in code space
	$(COPY) -I elf32-big -O binary $(TARGET).axf $(TARGET).code

$(TARGET).data: $(TARGET).axf
# Extract object code to be placed in data space (useful in TBs)
	$(COPY) -I elf32-big -j.rodata -j.bss -O binary $(TARGET).axf $(TARGET).data


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
		--bin $(TARGET).code --name OBJ_CODE --cmem_size $(CODE_MEM_SIZE) \
        --bin $(TARGET).data --name INIT_DATA --dmem_size $(DATA_MEM_SIZE)\
		--output $(OBJ_DIR)/obj_code_pkg.vhdl


#-- And now the usual housekeeping stuff ---------------------------------------

.PHONY: clean

clean:
	-$(RM) *.o *.obj *.map *.lst *.hex *.exe *.axf *.code *.data *.bin
