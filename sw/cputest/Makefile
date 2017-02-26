
include ../Toolchain.mk

# All sources are included into the main file. No independent assembly.
FIRMWARE_OBJS = main.o


all: firmware.bin firmware.lst

firmware.hex: firmware.bin $(MAKEHEX)
	python $(MAKEHEX) $< 16384 > $@

firmware.bin: firmware.elf 
	$(TOOLCHAIN_PREFIX)objcopy -O binary $< $@
	chmod -x $@

firmware.elf: $(FIRMWARE_OBJS) sections.lds
	$(TOOLCHAIN_PREFIX)gcc -Os -mips32 -ffreestanding -nostdlib -EB -o $@ \
		-Wl,-Bstatic,-T,sections.lds,-Map,firmware.map,--strip-debug \
		$(FIRMWARE_OBJS) -lgcc
	chmod -x $@

firmware.lst: firmware.elf
	$(TOOLCHAIN_PREFIX)objdump -D firmware.elf > firmware.lst

main.o: main.s
	$(TOOLCHAIN_PREFIX)gcc -c -EB -Wa,-call_nonpic,-mips32,-EB -o $@ $<



clean:
	rm -rf $(FIRMWARE_OBJS) $(TEST_OBJS) firmware.elf firmware.bin firmware.hex firmware.map firmware.lst




.PHONY: all clean

