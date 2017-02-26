

    .ifgt   0  # MADD/U unimplemented yet
    #---------------------------------------------------------------------------
    # Mac instructions: madd, maddu.
macs:
    INIT_TEST msg_macs

    # Test MADD or MADDU with some arguments. 
    # Will use the same register set in all tests.
    # Note the test does a madd/maddu/msub/msubu upon *existing* HI:LO value.
    .macro TEST_MADD op, a, b, hi, lo
    li      $4,\a               # Load regs with test arguments...
    li      $5,\b
    \op     $4,$5               # ...do the mult operation...
    mflo    $8
    mfhi    $9
    CMP     $7,$8, \lo          # ...and check result.
    CMP     $7,$9, \hi
    .endm

    # Initialize accumulator...
    mtlo    $0
    mthi    $0
    # ...and perform a few MACs on it.
    TEST_MADD maddu, 0x00000010, 0x00000020, 0x00000000, 0x00000200
    #TEST_MADD maddu, 0x00000010, 0x00000020, 0x00000000, 0x00000400
    #TEST_MADD maddu, 0x00000010, 0x80000020, 0x00000008, 0x00000600
    
macs_end:
    PRINT_RESULT

    .data 
msg_macs:               .asciiz     "Madd*/Msub* opcodes.......... "
    .text 

    .endif
    