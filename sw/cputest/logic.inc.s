    
    #---------------------------------------------------------------------------
    # Logic instructions: and, andi, or, ori, xor, xori, nor.
logic:
    INIT_TEST msg_logic
    INIT_REGS I
    
    and     $6,$2,$3
    CMP     $9,$6, I2 & I3
    
    and     $6,$4,$5
    CMP     $20,$6, I4 & I5
    
    andi    $6,$5, C1
    CMP     $20,$6, I5 & C1
    
    or      $6,$4,$5
    CMP     $20,$6, I4 | I5
    
    ori     $6,$5, C1
    CMP     $20,$6, I5 | C1

    xor     $6,$4,$5
    CMP     $20,$6, I4 ^ I5
    
    xori    $6,$5, C1
    CMP     $20,$6, I5 ^ C1

    nor     $6,$4,$5
    CMP     $20,$6, ~(I4 | I5)
    
logic_end:
    PRINT_RESULT

    .data
msg_logic:              .asciiz     "Logic opcodes................ "
    .text
