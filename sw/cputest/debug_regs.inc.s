
    #---------------------------------------------------------------------------
    # Test access to DEBUG registers over uncached data WB bridge.
    # These regs are only implemented in tb_core and swsim. 
    .ifle   TARGET_HARDWARE
debug_regs:
    INIT_TEST msg_debug_regs
    INIT_REGS I
    la      $9,TB_DEBUG         # Base of debug register block.
    
    sw      $2,0x0($9)          # Store a bunch of values in the 4 regs...
    sw      $3,0x4($9)
    sw      $4,0x8($9)
    sw      $5,0xc($9)
    lw      $10,0xc($9)         # ...and read them back with no delay slot.
    lw      $11,0x8($9)
    lw      $12,0x4($9)
    lw      $13,0x0($9)
    CMPR    $13,$2              # Make sure we got back what we put in.
    CMPR    $12,$3
    CMPR    $11,$4
    CMPR    $10,$5
debug_regs_0:       
    PRINT_RESULT

    .data 
msg_debug_regs:         .asciiz     "DEBUG registers (TB only).... "
    .text 

    .endif
