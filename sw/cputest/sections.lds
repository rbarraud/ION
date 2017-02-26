/* Not suitable for general use. */
/* 
    Memory map in cpu TB:

    CTCM :          0xbfc00000      64KB        Code TCM, code & data buses.
    DTCM :          0xa0000000      64KB        Data TCM, data bus.

    GPIO regs :     0xffff0000      32KB
    DEBUG regs :    0xffff8000      32KB
*/

MEMORY {
	/* Code TCM as mapped on both code and data buses. */
	ctcm : ORIGIN = 0xbfc00000, LENGTH = 0x00010000
    dtcm : ORIGIN = 0xa0000000, LENGTH = 0x00010000
}

SECTIONS {
    /* Section .bss won't actually be used. Goes to DTCM anyway. */
    RAM : {
        *(.bss);
    } > dtcm

    /* Sections .text and .data on CTCM (.data is constant in this test). */
    ROM : { 
        *(.text);
        *(.data);
        *(*);
    } > ctcm
}
