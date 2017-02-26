

    
    #---------------------------------------------------------------------------
    # Branch instructions.
branch:
    INIT_TEST msg_branch
    INIT_REGS I

    .macro TEST_BRANCH_Y op
    ori     $25,$0,0            # $25 will be used to count delay slot opcodes.
    \op     4000f
    addi    $25,$25,1           # $25++ so we can see the slot opcode executed.
    addi    $28,$28,1           # Should never execute; inc error counter.
    4001:    
    \op     4002f
    addi    $25,$25,1
    addi    $28,$28,1
    4000:
    \op     4001b               # Ok, now try to jump backwards.
    addi    $25,$25,1
    addi    $28,$28,1
    4002:
    CMP     $23,$25,3
    .endm

    .macro TEST_BRANCH_N op, r1, r2
    ori     $25,$0,0
    \op     4000f
    addi    $25,$25,1           # $25++ so we can see the slot opcode executed.
    b       4002f
    nop
    4000:    
    addi    $28,$28,1           # Should never execute; inc error counter.
    4002:
    CMP     $23,$25,1
    .endm

    .macro TEST_BLINK_Y op
    ori     $25,$0,0            # $25 will be used to count delay slot opcodes.
    la      $24,5000f
    \op     4000f
    addi    $25,$25,1           # $25++ so we can see the slot opcode executed.
    5000:
    addi    $28,$28,1           # Should never execute; inc error counter.
    4001:    
    CMPR    $24,$31             # Check link register
    la      $24,5002f
    \op     4002f
    addi    $25,$25,1
    5002:
    addi    $28,$28,1
    4000:
    CMPR    $24,$31             # Check link register
    la      $24,5001f
    \op     4001b               # Ok, now try to jump backwards.
    addi    $25,$25,1
    5001:
    addi    $28,$28,1
    4002:
    CMPR    $24,$31             # Check link register
    CMP     $23,$25,3           # Check delay slot count
    .endm
    
    TEST_BRANCH_Y "beq $2, $2," # BEQ
    TEST_BRANCH_N "beq $2, $3,"
    TEST_BRANCH_Y "bgez $4,"    # BGEZ
    TEST_BRANCH_Y "bgez $0,"
    TEST_BRANCH_N "bgez $5,"
    TEST_BLINK_Y "bgezal $4,"   # BGEZAL
    TEST_BLINK_Y "bgezal $0,"
    TEST_BRANCH_N "bgezal $5,"
    TEST_BRANCH_Y "bgtz $4,"    # BGTZ
    TEST_BRANCH_N "bgtz $0,"
    TEST_BRANCH_N "bgtz $5,"
    TEST_BRANCH_N "blez $4,"    # BLEZ
    TEST_BRANCH_Y "blez $0,"
    TEST_BRANCH_Y "blez $5,"
    TEST_BRANCH_N "bltz $4,"    # BLTZ
    TEST_BRANCH_N "bltz $0,"
    TEST_BRANCH_Y "bltz $5,"
    TEST_BRANCH_N "bltzal $4,"  # BLTZAL
    TEST_BRANCH_N "bltzal $0,"
    TEST_BLINK_Y "bltzal $5,"
    TEST_BRANCH_Y "bne $2, $3," # BNE
    TEST_BRANCH_N "bne $2, $2,"
    
branch_end:
    PRINT_RESULT    

    .data 
msg_branch:             .asciiz     "Branch opcodes............... "
    .text 
