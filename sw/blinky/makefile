
# Get common makefile stuff (toolchain & system config).
include ../common/makefile

#-- Application setup ----------------------------------------------------------

# Name of executable and label to use in VHDL files.
TARGET = blinky
APP_NAME = "Blinky"

# Test bench simulation timeout period in clock cycles.
SIM_LENGTH = 90000
# Start logging HW activity after fetching from this address.
LOG_TRIGGER = 0xbfc00000

#-- Build flag overrides -------------------------------------------------------


#-- App build targets & rules --------------------------------------------------

.PHONY: program
program: $(TARGET).bin $(TARGET).data


$(TARGET).axf: $(OBJS)
	$(LD) $(LFLAGS) -Map $(TARGET).map -N -o $(TARGET).axf $(OBJS)
	-@$(DUMP) -m mips -S --disassemble $(TARGET).axf > $(TARGET).lst

%.o: %.c
	$(CC) $(CFLAGS) $<    

    
$(TARGET).bin: $(TARGET).axf
# Extract object code to be placed in code space
	$(COPY) -I elf32-big -O binary $(TARGET).axf $(TARGET).bin

$(TARGET).data: $(TARGET).axf
# Extract object code to be placed in data space (useful in TBs)
	$(COPY) -I elf32-big -j.rodata -j.bss -O binary $(TARGET).axf $(TARGET).data


#-- Targets invoked by tb_app and tb_core (see common makefile) ----------------

#-- Set assembler arguments for "tb_application" test bench.
set_tb_app_variables: 
	$(eval TBARGS := --defsym TARGET_HARDWARE=1)    

#-- Set assembler arguments for "tb_core" test bench.
set_tb_core_variables: 
	$(eval TBARGS := )

    

#-- And now the usual housekeeping stuff ---------------------------------------

.PHONY: clean

