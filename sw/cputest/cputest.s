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

   
    .set TARGET_HARDWARE, 1                 # Don't use simulation-only features
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

    
    #-- Core addresses ---------------------------------------------------------
    
    # TB registers. These are only available in the SW simulator and in the 
    # RTL simulation test bench, not on real hardware.

    # Simulated UART TX buffer register.
    .set TB_UART_TX,        0xffff8000    
    # Block of 4 32-bit byte-addressable registers.
    .set TB_DEBUG,          0xffff8020
    # Register connected to HW interrupt lines.
    .set TB_HW_IRQ,         0xffff8010
    
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
    mfc0    $26,$13             # Return with trap cause code into $26
    srl     $26,$26,2
    andi    $26,$26,0x01f
    move    $25,$24             # Copy $24 into $25.
    addi    $27,$27,1           # Increment exception count.
    eret
    addi    $27,$27,1           # Increment exception count. Should NOT execute.
    

init:
    # Display a welcome message. Remember all output is line buffered!
    PUTS    msg_welcome

    # Reset error and exception counters.
    ori     $28,$0,0            # Error count for the test in course. 
    ori     $30,$0,0            # Total test error count.
    ori     $27,$0,0            # Total exception count.

    
    # So far, we were in supervisor mode and ERL=1, which means we'll be unable 
    # to return from exceptions properly. 
    # We'll run the rest of the test in user mode. 
    
    li      $k0,0x00400010      # Enter user mode...
    mtc0    $k0,$12             # ...NOW


    
    
    
    # Test BREAK and SYSCALL opcodes. Remember we're in user mode (ERL=0).
break_syscall:
    INIT_TEST msg_break_syscall
    
    .macro  TRAP_OP op, code, count
    li      $24,0x42
    li      $25,0x99
    \op
    addi    $24,$0,1
    CMP     $23,$25,0x42
    CMP     $23,$26,\code
    CMP     $23,$27,\count
    .endm
    
    TRAP_OP break, 0x09, 1
    TRAP_OP "syscall 0", 0x08, 2
    
break_syscall_0:
    PRINT_RESULT
    
    # FIXME test HW interrupts
    #la      $9,TB_HW_IRQ
    #li      $2,0x42
    #sb      $2,0($9)
    
    
    
    .ifle   TARGET_HARDWARE
    # Test access to debug registers over uncached data WB bridge.
debug_regs:
    INIT_TEST msg_debug_regs
    la      $9,TB_DEBUG          # Base of debug register block.
    
    # Debug regs reset to zero; let's see if we can read them.
    #addi    $2,$0,-1            # Put some nonzero value in $2...
    #lw      $2,0($9)            # ...then read a zero from a debug reg.
    #beqz    $2,debug_regs_0     # If not zero, increment error count.
    #CMP     $3,$2,0x0
    li      $2,0x12345678
    sw      $2,0x0($9)
    nop
    lw      $3,0x0($9)
    CMP     $4,$3,0x12345678
debug_regs_0:       
    PRINT_RESULT
    .endif
    
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
    .ifle   TARGET_HARDWARE
    li      $5,0x90000000       # $5 points to base of test pattern ROM.
    lw      $4,0x04($5)         # Ok, get a couple of words...
    lw      $6,0x08($5)         
    CMP     $20,$6,0x00080008   # ...and see if we got what we expected.
    CMP     $20,$4,0x00040004
    nop
    .endif
    # Now do a write-read test on cached RAM (also simulated in swsin and TB).
    li      $3,0x80000000       # $3 points to base of cached RAM.
    li      $6,0x18026809 
    sw      $6,0x08($3)         # Store test pattern...
    nop     # FIXME back to back SW/LW fails!
    lw      $7,0x08($3)         # ...and see if we can read it back.
    CMPR    $6,$7
    NOP
    # Now, store a test byte and read it back. Repeat a few times with 
    # different byte alignments. We'll want a macro to do this comfortably:
    .macro  BYTE_READBACK r3, bexp, off
    ori     $6,$0,\bexp
    ori     $8,$0,\bexp
    ori     $10,$0,\bexp
    ori     $12,$0,\bexp
    sb      $6,\off(\r3)
    # Note we're doing a RD-WR back-to-back here; this is intended.
    lb      $7,\off(\r3)
    sb      $8,(\off+0x40)(\r3) # RD-WR-RD-WR sequence tested here.
    lb      $9,(\off+0x40)(\r3)
    addi    $7,-\bexp
    beqz    $7,1100f
    addi    $8,-\bexp
    beqz    $8,1100f
    nop
    sb      $10,(\off+0x70)(\r3)    # Now try sequence WR-WR-RD-RD    
    sb      $12,(\off+0x90)(\r3)
    lb      $13,(\off+0x90)(\r3)
    lb      $11,(\off+0x70)(\r3)
    addi    $11,-\bexp
    beqz    $11,1100f
    addi    $13,-\bexp
    beqz    $13,1100f
    nop
    addi    $28,$28,1
    1100:
    .endm
    # Ok, we'll try first the same cached area we've been using for word tests.
    # Alignment 0 to 3
    BYTE_READBACK $3, 0x42, 0x00
    BYTE_READBACK $3, 0x34, 0x01
    BYTE_READBACK $3, 0x74, 0x02
    BYTE_READBACK $3, 0x29, 0x03
    # Same deal, different offsets and read first the last address in the cache 
    # line. This'll catch some classes of errors in the tag invalidation logic.
    BYTE_READBACK $3, 0x24, 0x133
    BYTE_READBACK $3, 0x43, 0x131
    BYTE_READBACK $3, 0x47, 0x132
    BYTE_READBACK $3, 0x77, 0x130
    # Same again, only mixing different areas.
    BYTE_READBACK $3, 0x24, 0x233
    BYTE_READBACK $3, 0x43, 0x331
    BYTE_READBACK $3, 0x47, 0x232
    BYTE_READBACK $3, 0x77, 0x330
    
dcache_end:    
    PRINT_RESULT
    .endif
    
    # Test code cache minimally.
    # (We're gonna execute only a few instructions off the cache.)
icache:
    INIT_TEST msg_icache

    # Initialize the CODE cache with CACHE Hit Invalidate instructions.
icache_init:
    li      $9,0x80000000
    li      $8,128              # FIXME number of tags hardcoded!
icache_init_0:
    cache   IndexStoreTagI,0x0($9)
    addi    $8,$8,-1
    bnez    $8,icache_init_0
    addi    $9,$9,0x04

    # First, we write a single "JR RA" (a return) instruction at the start of
    # the cached RAM, and jump to it. 
    # Failure in this test will crash the program, of course.
    li      $3,0x03e00008       
    sw      $3,0x0($9)
    sw      $0,0x4($9)
    nop
    jalr    $9
    nop
    # Now we should copy a chunk of position independent code onto RAM and call
    # it; that test will have to wait FIXME write it.
    
icache_0:    
    PRINT_RESULT    
    
    
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
    li      $a1,TB_UART_TX
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
msg_icache:             .asciiz     "Code Cache basic test........ "
msg_debug_regs:         .asciiz     "Access to debug registers.... "
msg_interlock:          .asciiz     "Load interlocks.............. "
msg_arith:              .asciiz     "Add*/Sub* opcodes............ "
msg_logic:              .asciiz     "Logic opcodes................ "
msg_muldiv:             .asciiz     "Mul*/Div* opcodes............ "
msg_break_syscall:      .asciiz     "Break/Syscall opcodes........ "

    .end entry
 
 