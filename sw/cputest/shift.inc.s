
    
    #---------------------------------------------------------------------------
    # Shift opcodes: SLL, SLLV, SRA, SRAV, SRL, SRLV
shifts:
    INIT_TEST msg_shift
    INIT_REGS I
    
    li      $10,13              # We'll use these for the variable shifts.
    li      $11,17
       
    sll     $21,$2,7
    CMP     $19,$21,I2 << 7
    sll     $21,$4,23
    CMP     $19,$21,I4 << 23
    sllv    $21,$2,$10
    CMP     $19,$21,I2 << 13
    sllv    $21,$4,$11
    CMP     $19,$21,I4 << 17
    srl     $21,$5,7
    CMP     $19,$21,I5 >> 7
    srl     $21,$4,13
    CMP     $19,$21,I4 >> 13
    srlv    $21,$5,$10
    CMP     $19,$21,I5 >> 13
    srlv    $21,$4,$11
    CMP     $19,$21,I4 >> 17
    
    sra     $21,$5,7
    CMP     $19,$21,(I5 >> 7) | 0xfe000000
    sra     $21,$5,24
    CMP     $19,$21,(I5 >> 24) | 0xffffff00
    srav    $21,$5,$10
    CMP     $19,$21,(I5 >> 13) | 0xfff80000
    srav    $21,$4,$11
    CMP     $19,$21,(I4 >> 17)    
    
shifts_end:
    PRINT_RESULT 

    .data 
msg_shift:              .asciiz     "Shift opcodes................ "
    .text 
