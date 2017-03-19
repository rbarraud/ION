
include ../Toolchain.mk

# All sources are included into the main file. No independent assembly.
SOFTWARE_OBJS = main.o


all: software.bin software.lst software.hex

software.hex: software.bin $(MAKEHEX)
	python $(MAKEHEX) $< 16384 > $@

software.bin: software.elf 
	$(TOOLCHAIN_PREFIX)objcopy -O binary $< $@
	chmod -x $@

software.elf: $(SOFTWARE_OBJS) sections.lds
	$(TOOLCHAIN_PREFIX)gcc -Os -mips32 -ffreestanding -nostdlib -EB -o $@ \
		-Wl,-Bstatic,-T,sections.lds,-Map,software.map,--strip-debug \
		$(SOFTWARE_OBJS) -lgcc
	chmod -x $@

software.lst: software.elf
	$(TOOLCHAIN_PREFIX)objdump -D software.elf > software.lst

main.o: main.s
	$(TOOLCHAIN_PREFIX)gcc -c -EB -Wa,-call_nonpic,-mips32,-EB -o $@ $<



clean:
	rm -rf $(SOFTWARE_OBJS) software.elf software.bin software.hex software.map software.lst




.PHONY: all clean

