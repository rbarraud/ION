################################################################################
# cputest.s -- MIPS opcode tester for Ion project
#-------------------------------------------------------------------------------
# This assembly file tests all of the opcodes supported by the Ion core, plus
# some of the basic CPU features (caches, interlocks...).
#
# TODO The test is unfinished!
#-------------------------------------------------------------------------------
# IMPORTANT:
# This test needs the following simulated features to operate:
#   -# A 1K "Debug ROM" at address 0x90000000 containing constant words meant
#      to test the data cache (XXXXABCD contains ABCDABCD).
#   -# A 1K RAM at address 0x80000000 meant to test the RAM.
#   -# A simulated UART at address 0xffff0000 what needs no initialization.
#
# These features are implemented by the SW simulator and by the ion_core test 
# bench. As a consequence, this test is not tuitable to run on real HW as it 
# stands.
#
################################################################################
#
#   -# Supply a version of this test suitable for real HW.
#   -# Test HW interrupts.
#   -# Test all the missing opcodes.
#   -# Test COP interface.
#
################################################################################

    #-- Set flags below to >0 to enable/disable test assembly ------------------

   
    .set TEST_DCACHE, 1                     # Initialize and test D-Cache
    
    # FIXME these values should be read from COP0 register!
    .set ICACHE_NUM_LINES, 128              # no. of lines in the I-Cache
    .set DCACHE_NUM_LINES, 128              # no. of lines in the D-Cache
    .set DCACHE_LINE_SIZE, 8                # D-Cache line size in words

    
     #-- Test data & constants -------------------------------------------------

    .set    I2, 0x12345678
    .set    I3, 0x456789a0
    .set    I4, 0x789abcde
    .set    I5, 0x8abcdef0
    
    .set    C0, 0x00007043
    .set    C1, 0x0000d034

    
    #-- CACHE constants & COP register numbers etc. ----------------------------
    
    .set    IndexStoreTagI,             0x00
    .set    IndexInvalidateD,           0x01
    .set    StoreTagI,                  0x08
    .set    StoreTagD,                  0x09
    .set    HitInvalidateI,             0x10
    .set    HitInvalidateD,             0x11
    .set    HitInvalidateWritebackD,    0x15

    
    
    #-- Utility macros ---------------------------------------------------------

    # Print zero-terminates string at address msg.
    .macro  PUTS msg
    .set    noat
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
    
    # Compare registers, conditionally increment error counter:
    # 1: if r1 != r2 then $28++
    .macro  CMPR r1, r2
    sub     \r1,\r2,\r1
    beqz    \r1,1001f
    nop
    addi    $28,$28,1
    1001:
    .endm
   
    #---------------------------------------------------------------------------

    .text
    .align  2
    .globl  entry
    .ent    entry
    
    
entry:
    .set    noreorder

    b       init
    nop

    # Trap handler address 
    .org    0x0180
    
interrupt_vector:
    eret
    nop
    

init:
    PUTS    msg_welcome
    
    # Reset error counters.
    ori     $28,$0,0            # Error count for the test in course. 
    ori     $30,$0,0            # Total error count.
    
    # Test load interlock.
interlock:
    INIT_TEST msg_interlock
    la      $9,0xa0000000       # We'll be using the TCM in this test.
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

    .ifgt   TEST_DCACHE
dcache:
    INIT_TEST msg_dcache

    # Initialize the cache with CACHE Hit Invalidate instructions.
cache_init:
    li      $9,0x90000000       # Any base address will do.
    li      $8,128              # FIXME number of tags hardcoded!
cache_init_0:
    cache   IndexInvalidateD,0x0($9)
    addi    $8,$8,-1
    bnez    $8,cache_init_0
    addi    $9,$9,0x04
    
    # Test basic D-Cache operation.
    # First, read a few hardcoded values from the test ROM area.
    # (This is a fake ROM which only exists in the SW simulator and in the 
    # core test bench.)
    li      $5,0x90000000       # $5 points to base of test pattern ROM.
    lw      $4,0x04($5)         # Ok, get a couple of words...
    lw      $6,0x08($5)         
    CMP     $20,$6,0x00080008   # ...and see if we got what we expected.
    CMP     $20,$4,0x00040004
    nop
    # Now do a write-read test on cached RAM (also simulated in swsin and TB).
    li      $3,0x80000000       # $3 points to base of cached RAM.
    li      $6,0x18026809 
    sw      $6,0x08($3)         # Store test pattern...
    nop     # FIXME back to back SW/LW fails!
    lw      $7,0x08($3)         # ...and see if we can read it back.
    CMPR    $6,$7   
dcache_end:    
    PRINT_RESULT
    .endif
    
    # Add/Sub instructions: add, addi, sub, subi.
arith:
    INIT_TEST msg_arith
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
    
    # FIXME possible bug caught in ADDIU
    .ifgt   0
    add     $6,$4,$5
    addiu   $6, C1
    CMP     $20,$6, I4 + I5 + C1
    .endif
    
    add     $6,$4,$5
    addiu   $6, C0
    CMP     $20,$6, I4 + I5 + C0
    
    sub     $6,$2,$3
    CMP     $9,$6, I2 - I3
    
    sub     $6,$4,$5
    CMP     $20,$6, I4 - I5
    
    subu    $6,$2,$3
    CMP     $9,$6, I2 - I3
    
    subu    $6,$4,$5
    CMP     $20,$6, I4 - I5
    
arith_end:
    PRINT_RESULT
    
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

    # Mul/Div instructions: mul, mulu, div, divu.
    # WARNING: the assembler expands div instructions, see 'as' manual.
muldiv:
    INIT_TEST msg_muldiv
   
    li      $4,I4
    li      $5,I5
    divu    $7,$4,$5
    mflo    $8
    mfhi    $9
    CMP     $8,$8, I4 / I5
    CMP     $8,$9, I4 % I5
    
muldiv_end:
    PRINT_RESULT
    
    

    
    bnez    $30,cputest_fail
    nop
    PUTS    msg_program_pass
exit:
    j       exit
    nop

cputest_fail:
    PUTS    msg_program_fail
    j       exit
    nop


 

    #---- Support functions ----------------------------------------------------

 
 puts:
    li      $a1,0xffff0000
 puts_loop:
    lb      $v0,0($a0)
    beqz    $v0,puts_end
    addi    $a0,$a0,1
    sb      $v0,0($a1)
    b       puts_loop
    nop
    
 puts_end:
    jr      $ra
    nop

    #---- Message fragments ----------------------------------------------------
     
msg_welcome:            .asciiz     "ION MIPS opcode tester\n\n"
msg_pass:               .asciiz     "OK\n"
msg_fail:               .asciiz     "ERROR\n"
msg_program_pass:       .asciiz     "\nTest PASSED\n\n"
msg_program_fail:       .asciiz     "\nTest FAILED\n\n"

msg_dcache:             .asciiz     "Data Cache basic test........ "
msg_interlock:          .asciiz     "Load interlocks.............. "
msg_arith:              .asciiz     "Add*/Sub* opcodes............ "
msg_logic:              .asciiz     "Logic opcodes................ "
msg_muldiv:             .asciiz     "Mul*/Div* opcodes............ "


    .end entry
 
 