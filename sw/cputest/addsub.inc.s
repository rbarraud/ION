    #---------------------------------------------------------------------------
    # Add/Sub instructions: add, addi, addiu, addu, sub, subu.
addsub:
    INIT_TEST msg_addsub
    INIT_REGS I
    
    add     $6,$2,$3
    CMP     $9,$6, I2 + I3
    add     $6,$4,$5
    CMP     $20,$6, I4 + I5
    add     $6,$4,$5
    addi    $6, C1
    CMP     $20,$6, I4 + I5 + C1 + 0xffff0000
    add     $6,$4,$5
    addi    $6, C0
    CMP     $20,$6, I4 + I5 + C0
    
    # Remember ADDIU is NOT unsigned! it will sign-extend the 16-bit imm word.
    add     $6,$4,$5
    addiu   $6, C1
    CMP     $20,$6, I4 + I5 + C1 + 0xffff0000
    
    add     $6,$4,$5
    addiu   $6, C0
    CMP     $20,$6, I4 + I5 + C0
    
    # Since we support no overflow exceptions ADDU is identical to ADD.
    addu    $6,$2,$3
    CMP     $9,$6, I2 + I3
    addu    $6,$4,$5
    CMP     $20,$6, I4 + I5
    addu    $6,$4,$5
    addi    $6, C1
    CMP     $20,$6, I4 + I5 + C1 + 0xffff0000
    addu    $6,$4,$5
    addi    $6, C0
    CMP     $20,$6, I4 + I5 + C0
    
    sub     $6,$2,$3
    CMP     $9,$6, I2 - I3
    sub     $6,$4,$5
    CMP     $20,$6, I4 - I5
    subu    $6,$2,$3
    CMP     $9,$6, I2 - I3
    subu    $6,$4,$5
    CMP     $20,$6, I4 - I5
    
addsub_end:
    PRINT_RESULT

    .data 
msg_addsub:             .asciiz     "Add*/Sub*.................... "    
    .text 
