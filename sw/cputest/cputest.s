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
# Also, the test requires a C-TCM of at least 16KB; the attached makefile will 
# set up the core parameter for this size.
#
################################################################################
# KNOWN BUGS:
# (Note: I'm using tags like @hack7 from my personal notes, to be cleaned up.)
#
# @hack7: 
#   Entry into user mode is effective in the 2nd instruction after mtc0.
#   This need to be checked against the specs.
# 
################################################################################
# THINGS TO BE DONE: 
#
#   -# Supply a version of this test suitable for real HW.
#   -# Test all the missing opcodes (see bottom of file).
#   -# Use COP0 to get the cache size params and use them in the initialization.
#   -# Test COP2 interface.
#   -# The cache tests should use all lines.
#   -# There's a few other minor FIXMEs here and there in the code.
#
################################################################################

    #-- Set flags below to >0 to enable/disable test assembly ------------------

    .ifndef TARGET_HARDWARE
    .set TARGET_HARDWARE, 0                 # Don't use simulation-only features
    .endif
    .ifndef TEST_DCACHE
    .set TEST_DCACHE, 1                     # Initialize and test I-/D-Cache
    .endif
    .ifndef TEST_ICACHE
    .set TEST_ICACHE, 1                     # Initialize and test I-Cache
    .endif
    
    # FIXME these values should be read from COP0 register!
    .set ICACHE_NUM_LINES, 128              # no. of lines in the I-Cache
    .set DCACHE_NUM_LINES, 128              # no. of lines in the D-Cache
    .set DCACHE_LINE_SIZE, 8                # D-Cache line size in words
    .set ICACHE_LINE_SIZE, 8                # I-Cache line size in words

    
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
    
    # Start of cached RAM area.
    .set CACHED_RAM_BOT,    0x80000000
    # Start of D-TCM block.
    .set DATA_TCM_BOT,      0xa0000000
    # Start of C-TCM as mapped on the DATA bus.
    .set CODE_TCM_BOT,      0x80000000
    
    # TB registers. These are only available in the SW simulator and in the 
    # RTL simulation test bench, not on real hardware.

    # Simulated UART TX buffer register.
    .set TB_UART_TX,        0xffff8000    
    # Block of 4 32-bit byte-addressable registers.
    .set TB_DEBUG,          0xffff8020
    # Register connected to HW interrupt lines.
    .set TB_HW_IRQ,         0xffff8010
    # Register used to send pass/fail messages to the TB.
    .set TB_RESULT,         0xffff8018
    
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
    # To be used at the end pfothe program or as a breakpoint of sorts.
    .macro EXIT
    .ifle   TARGET_HARDWARE
    li      $9,TB_RESULT
    sw      $30,0($9)
    .endif
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

    #---------------------------------------------------------------------------
    # Test entry in user mode and access to MFC0 from user mode.
    
    # So far, we were in supervisor mode and ERL=1, which means we'll be unable 
    # to return from exceptions properly. 
    # We'll run the rest of the test in user mode. 
    # (Note we'll enable HW interrupt 0 too.)
    PUTS    msg_user_mode
    li      $2,0x00400410       # Enter user mode...
    mtc0    $2,$12              # ...NOW
    nop                         # @hack7: COP0 hazard, we need a nop here.

    mfc0    $3,$12              # This should trigger a COP0 missing exception.
    nop
    CMP     $4,$27,1            # Check that we got an exception...
    CMP     $4,$26,0x0b         # ...and check the cause code.
    
    PRINT_RESULT 
    
    #---------------------------------------------------------------------------
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
    
    TRAP_OP break, 0x09, 2
    TRAP_OP "syscall 0", 0x08, 3
    
break_syscall_0:
    PRINT_RESULT
    
    #---------------------------------------------------------------------------
    # Test HW interrupts using the support logic in the TB.
    .ifle   TARGET_HARDWARE
hardware_interrupts:
    INIT_TEST msg_hw_interrupts
    
    # First test HW IRQ on delay slot instruction.
    la      $9,TB_HW_IRQ        # Prepare to load value in the IRQ test reg...
    li      $2,0x01
    sb      $2,0($9)            # ...and load it, triggering the IRQ countdown.
    li      $2,0x42
    beqz    $0,hardware_interrupts_1
    li      $11,0x79            # THIS is the HW IRQ victim.
    li      $12,0x85
hardware_interrupts_1:
    CMP     $4,$27,4            # Check that we got an exception...
    CMP     $4,$26,0x00         # ...and check the cause code.
    sb      $0,($9)             # Clear HW IRQ source.

    
    # FIXME test HW IRQ on regular instruction.
    # FIXME test HW IRQ on jump instruction.
    # FIXME test HW IRQ on mul/div instruction.
    
hardware_interrupts_0:
    PRINT_RESULT
    .endif
    
    #---------------------------------------------------------------------------
    .ifle   TARGET_HARDWARE
    .ifgt   0
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
    .endif
    
    #---------------------------------------------------------------------------
    # Test load interlock.
interlock:
    INIT_TEST msg_interlock
    la      $9,DATA_TCM_BOT     # We'll be using the TCM in this test.
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

    #---------------------------------------------------------------------------
    # Minimal test for data cache. 
    .ifgt   TEST_DCACHE
dcache:
    INIT_TEST msg_dcache

    # Initialize the cache with CACHE Hit Invalidate instructions.
cache_init:
    li      $9,CACHED_RAM_BOT   # Any base address will do.
    li      $8,DCACHE_NUM_LINES
cache_init_0:
    cache   IndexInvalidateD,0x0($9)
    addi    $8,$8,-1
    bnez    $8,cache_init_0
    addi    $9,$9,DCACHE_LINE_SIZE*4
    
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
    # Now do a write-read test on cached RAM (also simulated in swsim and TB).
    li      $3,CACHED_RAM_BOT # $3 points to base of cached RAM.
    li      $6,0x18026809 
    sw      $6,0x08($3)         # Store test pattern...
    # (We do back to back SW/LW)
    lw      $7,0x08($3)         # ...and see if we can read it back.
    CMPR    $6,$7
    NOP
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

    # Ok, we'll try first the same cached area we've been using for word tests.
    # Alignment 0 to 3
    BYTE_READBACK , $3, 0x42, 0x00
    BYTE_READBACK , $3, 0x34, 0x01
    BYTE_READBACK , $3, 0x74, 0x02
    BYTE_READBACK u, $3, 0x89, 0x03
    # Same deal, different offsets and read first the last address in the cache 
    # line. This'll catch some classes of errors in the tag invalidation logic.
    BYTE_READBACK , $3, 0x24, 0x133
    BYTE_READBACK , $3, 0x43, 0x131
    BYTE_READBACK u, $3, 0x97, 0x132
    BYTE_READBACK , $3, 0x77, 0x130
    # Same again, only mixing different areas.
    BYTE_READBACK , $3, 0x24, 0x233
    BYTE_READBACK u, $3, 0xd3, 0x331
    BYTE_READBACK , $3, 0x47, 0x232
    BYTE_READBACK , $3, 0x77, 0x330
    
dcache_end:    
    PRINT_RESULT
    .endif

    #---------------------------------------------------------------------------
    # Test code cache minimally.
    # (We're just gonna execute only a few instructions off the cache.)
    .ifgt   TEST_ICACHE
icache:
    INIT_TEST msg_icache

    # Initialize the CODE cache with CACHE Hit Invalidate instructions.
icache_init:
    li      $9,CACHED_RAM_BOT
    li      $8,ICACHE_NUM_LINES
icache_init_0:
    cache   IndexStoreTagI,0x0($9)
    addi    $8,$8,-1
    bnez    $8,icache_init_0
    addi    $9,$9,ICACHE_LINE_SIZE*4

    # First, we write a single "JR RA" (a return) instruction at the start of
    # the cached RAM, and jump to it. 
    # Failure in this test will crash the program, of course.
    li      $9,CACHED_RAM_BOT
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
    .endif
    
    #---------------------------------------------------------------------------
    # Add/Sub instructions: add, addi, addiu, addu, sub, subu.
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
    
arith_end:
    PRINT_RESULT
    
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

    #---------------------------------------------------------------------------
    # Mul/Div instructions: mul, mulu, div, divu.
    # WARNING: the assembler expands div instructions, see 'as' manual.
muldiv:
    INIT_TEST msg_muldiv
   
    # Test DIV or DIVU with some arguments. 
    # Will use the same register set in all tests. Oh well...
    .macro TEST_DIV op, num, den
    li      $4,\num             # Load regs with test arguments...
    li      $5,\den
    # (By using $0 as first op we tell as not to expand the div opcode.)
    \op     $0,$4,$5            # ...do the div operation...
    mflo    $8
    mfhi    $9
    CMP     $7,$8, \num / \den  # ...and check result.
    CMPU    $6,$9, \num % \den  # Note we expect the remainder to be > 0.
    .endm
   
    TEST_DIV divu, I4, I5
    TEST_DIV divu, I5, I4
    TEST_DIV divu, I2, I3
    TEST_DIV div,  I2, I5
    TEST_DIV div,  10, -5 
    TEST_DIV div,  -5, 10
    TEST_DIV div,  -5, -10

    # Test MULT or MULTU with some arguments. 
    # Will use the same register set in all tests.
    .macro TEST_MUL op, a, b, hi, lo
    li      $4,\a               # Load regs with test arguments...
    li      $5,\b
    \op     $4,$5               # ...do the mult operation...
    mflo    $8
    mfhi    $9
    CMP     $7,$8, \lo          # ...and check result.
    CMP     $7,$9, \hi
    .endm

    TEST_MUL multu, 0x00000010, 0x00000020, 0x00000000, 0x00000200
    TEST_MUL multu, 0x80000010, 0x00000020, 0x00000010, 0x00000200
    TEST_MUL multu, 0x00000010, 0x80000020, 0x00000008, 0x00000200
    TEST_MUL multu, 0x80000010, 0xffffffff, 0x8000000f, 0x7ffffff0

    TEST_MUL mult,  0x00000010, 0x00000020, 0x00000000, 0x00000200
    TEST_MUL mult,  0x80000010, 0x00000020, 0xfffffff0, 0x00000200
    TEST_MUL mult,  0x00000020, 0x80000010, 0xfffffff0, 0x00000200
    TEST_MUL mult,  0x80000010, 0x80000020, 0x3fffffe8, 0x00000200
    
muldiv_end:
    PRINT_RESULT
    
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
    
    #---------------------------------------------------------------------------
    # Load and store instructions
load_store:
    INIT_TEST msg_load_store
    INIT_REGS I
    
    # We'll be targetting the data TCM and not the cached areas. 
    li      $17,DATA_TCM_BOT
    
    # SB, LB, LBU
    BYTE_READBACK  , $17, 0x42, 0x10
    BYTE_READBACK u, $17, 0xc3, 0x21
    BYTE_READBACK  , $17, 0x44, 0x32
    BYTE_READBACK u, $17, 0x85, 0x43
    
    # SW, LW
    WORD_READBACK $17, 0x39404142, 0
    WORD_READBACK $17, 0x01234567, 4

    # SH, LH, LHU
    HWORD_READBACK  , $17, 0x1234, 0x00
    HWORD_READBACK  , $17, 0x5678, 0x02
    HWORD_READBACK u, $17, 0x5678, 0x02
    HWORD_READBACK u, $17, 0xcdef, 0x04
    
    # TODO evaluate coverage of this test somehow.
    # FIXME eventually we'll test unaligned loads and stores.
    
load_store_end:
    PRINT_RESULT
    
    
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
    
    #---------------------------------------------------------------------------
    # FIXME things remain to be minimally tested:
    # Move to/from muldiv registers.
    # Most of COP0
    # Implemented MIPS32 instructions 
    # Traps for unimplemented opcodes
    
    ############################################################################
    # End of the test series. Display global pass/fail message.
    
    bnez    $30,cputest_fail
    nop
    PUTS    msg_program_pass
        
exit:
    EXIT 
exit_0:
    j       exit_0
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

msg_user_mode:          .asciiz     "Entering user mode........... "
msg_dcache:             .asciiz     "Data Cache basic test........ "
msg_icache:             .asciiz     "Code Cache basic test........ "
msg_debug_regs:         .asciiz     "Access to debug registers.... "
msg_interlock:          .asciiz     "Load interlocks.............. "
msg_arith:              .asciiz     "Add*/Sub*.................... "
msg_slt:                .asciiz     "Slt* opcodes................. "
msg_branch:             .asciiz     "Branch opcodes............... "
msg_jump:               .asciiz     "Jump opcodes................. "
msg_logic:              .asciiz     "Logic opcodes................ "
msg_muldiv:             .asciiz     "Mul*/Div* opcodes............ "
msg_load_store:         .asciiz     "Load/Store opcodes........... "
msg_shift:              .asciiz     "Shift opcodes................ "
msg_break_syscall:      .asciiz     "Break/Syscall opcodes........ "
msg_hw_interrupts:      .asciiz     "HW interrupts (TB only)...... "

    .end entry
 
 