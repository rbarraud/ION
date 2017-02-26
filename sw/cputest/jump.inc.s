

    #---------------------------------------------------------------------------
    # Jump instructions.
jumps:
    INIT_TEST msg_jump
    INIT_REGS I
    
    .macro TEST_JR target
    la      $20,target
    jr      $20
    .endm
    
    # We can use all the "branch" test macros defined above.
    
    TEST_BRANCH_Y "j"           # J
    TEST_BLINK_Y "jal"          # JAL
    
    # FIXME jr and jalr tests missing!
    
jumps_end:
    PRINT_RESULT

    .data 
msg_jump:               .asciiz     "Jump opcodes................. "
    .text 
