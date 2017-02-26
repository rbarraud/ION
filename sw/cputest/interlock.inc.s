
   
    #---------------------------------------------------------------------------
    # Test load interlock.
interlock:
    INIT_TEST msg_interlock
    la      $9,DATA_TCM_BASE    # We'll be using the TCM in this test.
    INIT_REGS I
    sw      $2,0($9)            # Ok, store a known pattern in the TCM...
    nop
    ori     $7,$0,0x4242        # ...now put something else in $7...
    lw      $7,0($9)            # ...read the pattern into $7...
    sub     $7,$7,$2            # ...and immediately do arith with it.
    beqz    $7,interlock_0      # If the arith worked the interlock worked.
    nop
    addi    $28,$28,1
interlock_0:    
    PRINT_RESULT

    .data 
msg_interlock:          .asciiz     "Load interlocks.............. "
    .text 
