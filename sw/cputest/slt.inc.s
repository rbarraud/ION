    #---------------------------------------------------------------------------
    # All "set on less than" instructions: slt, slti, sltiu, sltu.
slt_ops:
    INIT_TEST msg_slt
    INIT_REGS I
    
    slt     $8,$2,$3            # Comparing unsigned numbers.
    CMP     $20,$8, 1
    slt     $8,$3,$2
    CMP0    $20,$8
    slt     $8,$4,$5            # Comparing signed numbers.
    CMP     $20,$8, 0
    slt     $8,$5,$4
    CMP     $20,$8,1
    
    sltu    $8,$2,$3            # Comparing unsigned numbers.
    CMP     $20,$8, 1
    sltu    $8,$3,$2
    CMP0    $20,$8
    sltu    $8,$4,$5            # Comparing large ('signed') numbers.
    CMP     $20,$8,1
    sltu    $8,$5,$4
    CMP     $20,$8,0
    
    li      $2,C0
    li      $3,-20000
    slti    $8,$2,0x7fff
    CMP     $20,$8,1
    slti    $8,$2,0x7000
    CMP     $20,$8,0
    slti    $8,$3,0x8000
    CMP     $20,$8,0
    slti    $8,$3,0xd8f0
    CMP     $20,$8,1
    
    li      $2,0x00007043       # SLTIU doesn't sign-extend the immediate data.
    li      $3,0x00008080
    sltiu   $8,$2,0x7fff
    CMP     $20,$8,1
    sltiu   $8,$2,0x7000
    CMP     $20,$8,0
    sltiu   $8,$3,0x8000
    CMP     $20,$8,0
    sltiu   $8,$3,0xd8f0
    CMP     $20,$8,1
    
slt_ops_end:
    PRINT_RESULT

    .data 
msg_slt:                .asciiz     "Slt* opcodes................. "    
    .text 
