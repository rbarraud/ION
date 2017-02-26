

    
    #---------------------------------------------------------------------------
    # Test COP2 interface.
    # We'll be using the dummy COP2 implemented in tb_core.
    # Note we don't test the FUNCTIONALITY of any COP2 in particular; only the
    # interface.

    .ifgt   TEST_COP2_IF

cop2_interface:
    INIT_TEST msg_cop2
    INIT_REGS I

    # We can't test this while in user mode so we've devised a scheme: we enter
    # the COP2 test through a syscall. 
    
    syscall 1
    nop

    # Upon return, the same register conventions of all tests hold.
    
cop2_interface_end:
    PRINT_RESULT

    j cop2_continue



    # Test COP2 interface -- called from SYSCALL exception ISR.
    # We'll be using the dummy COP2 implemented in tb_core.
    # Note we don't test the FUNCTIONALITY of any COP2 in particular; only the
    # interface.
cop2_test_function:    

    # Note that COP2_STUB does not have any feedforward logic so a register 
    # can't be read back the cycle after being written to. 
    # Reading back a DIFFERENT register does not require a delay, of course.

    # MTC2, MFC2, CTC2, CFC2.
    # Store a bunch of values in control & data registers...
    ctc2    $2,$0
    ctc2    $3,$1
    ctc2    $4,$2
    ctc2    $5,$3
    mtc2    $2,$0,0
    mtc2    $3,$1,1
    mtc2    $4,$2,2
    mtc2    $5,$3,3
    
    # ...then read them back.
    cfc2    $6,$0
    CMP     $7,$6, I2
    cfc2    $6,$1
    CMP     $7,$6, I3
    cfc2    $6,$2
    CMP     $7,$6, I4
    cfc2    $6,$3
    CMP     $7,$6, I5
    # Note that COP2_STUB stores the SEL field along with the data for testing;
    # the sel field is written on the top 3 bits of the register word.
    mfc2    $6,$0,0
    CMP     $7,$6,(0 << 29) | (I2 & 0x1fffffff)
    mfc2    $6,$1,1
    CMP     $7,$6,(1 << 29) | (I3 & 0x1fffffff)
    mfc2    $6,$2,2
    CMP     $7,$6,(2 << 29) | (I4 & 0x1fffffff)
    mfc2    $6,$3,3
    CMP     $7,$6,(3 << 29) | (I5 & 0x1fffffff)   
    
    .ifgt   TEST_COP2_LW_SW
    # FIXME These opcodes are not yet implemented.
    # SWC2, LWC2.
    
    li      $2,(I2 & 0x1fffffff)    # Load $2 to $5 with I constants...
    li      $3,(I3 & 0x1fffffff)    # ...with the 3 top bits clipped away...
    li      $4,(I4 & 0x1fffffff)    # ...because they'll be zeroed in the COP2.
    li      $5,(I5 & 0x1fffffff)
    
    li      $18,DATA_TCM_BASE       # Set up pointers to memory areas we'll use.
    li      $17,CACHED_AREA_BASE
    
    mtc2    $2,$0,0             # Initialize a few COP2 regs as "sources".
    mtc2    $3,$1,0
    mtc2    $4,$2,0
    mtc2    $5,$3,0
    
    swc2    $0,0($17)           # WR-RD back-to-back.
    lwc2    $4,0($17)
    swc2    $1,0x40($17)        # WR-RD-WR-RD sequence.
    lwc2    $5,0x40($17)
    nop                         # TWO delay slots after LWC2 before we can read
    nop                         # the SAME COP2 register.
    mfc2    $1,$4,0             # Make sure we got the right values back.
    CMPR    $1,$2
    mfc2    $1,$5,0
    CMPR    $1,$3
    
    swc2    $0,(0x70)($17)      # Now try sequence WR-WR-RD-RD    
    swc2    $1,(0x90)($17)
    lwc2    $6,(0x90)($17)
    lwc2    $7,(0x70)($17)
    nop                         # Remember, 2 delay slots for $6...
    mfc2    $1,$6,0             # Make sure we got the right values back.
    CMPR    $1,$3
    mfc2    $1,$7,0
    CMPR    $1,$2
    
    .endif
    
    jr      $31                 # End of COP2 tests.
    nop

cop2_continue:


    .data 
msg_cop2:               .asciiz     "COP2 interface (TB only)..... "
    .text 

    .endif # TEST_COP2_IF
