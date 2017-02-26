
    
    #---------------------------------------------------------------------------
    # Load and store instructions
load_store:
    INIT_TEST msg_load_store
    INIT_REGS I
    
    # We'll be targetting the data TCM and not the cached areas. 
    li      $17,DATA_TCM_BASE
    
    # SB, LB, LBU
    BYTE_READBACK  , $17, 0x42, 0x10
    BYTE_READBACK u, $17, 0xc3, 0x21
    BYTE_READBACK  , $17, 0x44, 0x32
    BYTE_READBACK u, $17, 0x85, 0x43
    
    # SW, LW
    WORD_READBACK $17, 0x39404142, 0
    WORD_READBACK $17, 0x01234567, 4

    # SH, LH, LHU
    HWORD_READBACK  , $17, 0x1234, 0x00
    HWORD_READBACK  , $17, 0x5678, 0x02
    HWORD_READBACK u, $17, 0x5678, 0x02
    HWORD_READBACK u, $17, 0xcdef, 0x04
    
    # TODO evaluate coverage of this test somehow.
    # FIXME eventually we'll test unaligned loads and stores.
    
load_store_end:
    PRINT_RESULT

    .data 
msg_load_store:         .asciiz     "Load/Store opcodes........... "
    .text 
