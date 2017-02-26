.ifndef TEST_MACROS_H
.set    TEST_MACROS_H, 1
    
    
     #-- Test data & constants -------------------------------------------------

    .set    I2, 0x12345678
    .set    I3, 0x456789a0
    .set    I4, 0x789abcde
    .set    I5, 0x8abcdef0
    
    .set    C0, 0x00007043
    .set    C1, 0x0000d034
   
    #-- Utility macros ---------------------------------------------------------

    # Print zero-terminated string at address msg.
    .macro  PUTS msg
    .set    noat, 1
    la      $a0,\msg
    jal     puts
    nop
    .endm

    # Start of partial test.
    # Display the partial test name (msg) and zero the partial error counter.
    .macro INIT_TEST msg
    PUTS    \msg
    ori     $28,$0,0
    .endm
    
    # End of partial test.
    # Add partial error counter to total error counter and display a test 
    # outcome message: Pass if $28 == 0, Fail if $28 != 0.
    .macro  PRINT_RESULT
    add     $30,$30,$28
    bnez    $28,50f 
    nop    
    PUTS    msg_pass
    j       99f
    nop
    50:
    PUTS    msg_fail
    99:
    .endm

    # Load registers $2 to $5 with a set of 32 bit constants "${c}2" to "${c}5".
    # Note "\()" is just an incantation used to append parameters.
    .macro  INIT_REGS c
    li      $2,\c\()2 
    li      $3,\c\()3
    li      $4,\c\()4
    li      $5,\c\()5
    .endm

    # Compare register to 32-bit literal, conditionally increment error counter:
    # 1: r1 = exp & 0xffffffff
    # 2: if r1 != r2 then $28++
    .macro  CMP r1, r2, exp
    li      \r1,(\exp) & 0xffffffff
    sub     \r1,\r2,\r1
    beqz    \r1,1000f
    nop
    addi    $28,$28,1
    1000:
    .endm

    # Compare register to the absolute value of a 32-bit literal,
    # conditionally increment error counter:
    # 1: r1 = exp & 0xffffffff
    # 2: if r1 != r2 then $28++
    .macro  CMPU r1, r2, exp
    li      \r1,(\exp) & 0xffffffff
    bgez    \r1,1010f           # If exp < 0...
    nop
    sub     \r1,$0,\r1          # ...negate it
    1010:
    sub     \r1,\r2,\r1
    beqz    \r1,1000f
    nop
    addi    $28,$28,1
    1000:
    .endm

    # Compare register to zero, conditionally increment error counter:
    # 1: if r1 != 0 then $28++
    .macro  CMP0 r1, r2
    beqz    \r1,1000f
    nop
    addi    $28,$28,1
    1000:
    .endm
    
    # Compare registers, conditionally increment error counter:
    # 1: if r1 != r2 then $28++
    .macro  CMPR r1, r2
    sub     \r1,\r2,\r1
    beqz    \r1,1001f
    nop
    addi    $28,$28,1
    1001:
    .endm
    
    # Write $28 to TB "exit" register, which will terminate the simulation.
    # To be used at the end of the program or as a breakpoint of sorts.
    # This will only actually work on simulation but it is harmless on real HW.
    .macro EXIT
    li      $9,TB_RESULT
    sw      $30,0($9)
    .endm
   
    # Now, store a test byte and read it back. Repeat a few times with 
    # different byte alignments. We'll want a macro to do this comfortably:
    .macro  BYTE_READBACK u, r3, bexp, off
    ori     $6,$0,\bexp
    ori     $8,$0,\bexp
    ori     $10,$0,\bexp
    ori     $12,$0,\bexp
    sb      $6,\off(\r3)
    # Note we're doing a RD-WR back-to-back here; this is intended.
    lb\u    $7,\off(\r3)
    sb      $8,(\off+0x40)(\r3) # RD-WR-RD-WR sequence tested here.
    lb\u    $9,(\off+0x40)(\r3)
    li      $26,\bexp
    bne     $7,$26,1100f
    nop
    bne     $8,$26,1100f
    nop
    sb      $10,(\off+0x70)(\r3)    # Now try sequence WR-WR-RD-RD    
    sb      $12,(\off+0x90)(\r3)
    lb\u    $13,(\off+0x90)(\r3)
    lb\u    $11,(\off+0x70)(\r3)
    bne     $11,$26,1100f
    nop
    beq     $13,$26,1101f
    nop
    1100:
    addi    $28,$28,1
    1101:
    .endm

    # A simpler macro for 32-bit word accesses will come in handy too.
    .macro  WORD_READBACK r3, wexp, off
    li      $6,\wexp
    li      $8,\wexp
    li      $10,\wexp
    li      $12,\wexp
    li      $14,\wexp
    sw      $6,\off(\r3)
    # Note we're doing a RD-WR back-to-back here; this is intended.
    lw      $7,\off(\r3)
    sw      $8,\off+0x40(\r3)   # RD-WR-RD-WR sequence tested here.
    lw      $9,\off+0x40(\r3)
    bne     $7,$14,1100f
    nop
    bne     $9,$14,1100f
    nop
    sw      $10,(\off+0x70)(\r3)    # Now try sequence WR-WR-RD-RD    
    sw      $12,(\off+0x90)(\r3)
    lw      $13,(\off+0x90)(\r3)
    lw      $11,(\off+0x70)(\r3)
    bne     $11,$14,1100f
    nop
    beq     $13,$14,1101f
    nop
    1100:
    addi    $28,$28,1
    1101:
    .endm

    # Another macro for 16-bit halfword accesses.
    .macro  HWORD_READBACK u, r3, wexp, off
    li      $6,\wexp
    li      $8,\wexp
    li      $10,\wexp
    li      $12,\wexp
    li      $14,\wexp
    sh      $6,\off(\r3)
    # Note we're doing a RD-WR back-to-back here; this is intended.
    lh\u    $7,\off(\r3)
    sh      $8,\off+0x40(\r3)   # RD-WR-RD-WR sequence tested here.
    lh\u    $9,\off+0x40(\r3)
    bne     $7,$14,1100f
    nop
    bne     $9,$14,1100f
    nop
    sh      $10,(\off+0x70)(\r3)    # Now try sequence WR-WR-RD-RD    
    sh      $12,(\off+0x90)(\r3)
    lh\u    $13,(\off+0x90)(\r3)
    lh\u    $11,(\off+0x70)(\r3)
    bne     $11,$14,1100f
    nop
    beq     $13,$14,1101f
    nop
    1100:
    addi    $28,$28,1
    1101:
    .endm
   
.endif # __TEST_MACROS_H
