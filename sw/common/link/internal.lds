/*
    Memory model: INTERNAL -- uses internal TCMs only.
*/

MEMORY
{
    /* FIXME should use maximum block sizes here. */
    CODE_TCM        : ORIGIN = 0xbfc00000, LENGTH = 64K
    DATA_TCM        : ORIGIN = 0x00000000, LENGTH = 4K
}

REGION_ALIAS("REGION_TEXT", CODE_TCM);
REGION_ALIAS("REGION_RODATA", CODE_TCM);
REGION_ALIAS("REGION_DATA", DATA_TCM);
REGION_ALIAS("REGION_BSS", DATA_TCM);


SECTIONS
{
    .text :
    {
        *(.text)
    } > REGION_TEXT
    .rodata :
    {
        *(.rodata)
        *(.rodata.*);
        rodata_end = .;
    } > REGION_RODATA
    .data : AT (rodata_end)
    {
        data_start = .;
        _gp = . + 0x7ff0; /* 0x7ff0 -> middle of 64K area */
        *(.data)
    } > REGION_DATA
    
    data_size = SIZEOF(.data);
    data_load_start = LOADADDR(.data);
    .bss :
    {
        __bss_start = .;
        *(.bss)
        _end = .;
    } > REGION_BSS
}
