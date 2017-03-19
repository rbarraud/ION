################################################################################
# cputest.s -- MIPS opcode tester for Ion project
#-------------------------------------------------------------------------------
# This assembly file tests all of the opcodes supported by the Ion core, plus
# some of the basic CPU features (caches, interlocks...).
#
#-------------------------------------------------------------------------------
# SIMULATED SUPPORT HARDWARE:
#
# When assembled with symbol TARGET_HARDWARE defined as 0, the program will
# use some hardware fatures only present in the VHDL test bench and the SW 
# simulator. The simulated features are as follows.
#
#   -# A 1K "Debug ROM" at address 0x90000000 containing constant words meant
#      to test the data cache (9XXXABCD contains ABCDABCD).
#   -# A simulated UART at address 0xffff0000 what needs no initialization.
#   -# A 1K RAM block at 0x80000000 meant to test the cache and SRAM interface.
#
# OTHER HARDWARE REQUIREMENTS:
#
# The test requires a C-TCM of at least 16KB; the attached makefile will 
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
#   -# Use a real UART when targetting real HW.
#   -# Test all the missing opcodes (see bottom of file).
#   -# Use COP0 to get the cache size params and use them in the initialization.
#   -# Test COP2 interface.
#   -# The cache tests should use all lines.
#   -# There's a few other minor FIXMEs here and there in the code.
#
################################################################################

    #-- Set flags below to >0 to enable/disable test assembly ------------------

    .ifndef TARGET_HARDWARE
    .set TARGET_HARDWARE, 0                 # Don't use sim-only features.
    .endif
    .ifndef TEST_DCACHE
    .set TEST_DCACHE, 0                     # Cursory I-/D-Cache test.
    .endif
    .ifndef TEST_ICACHE
    .set TEST_ICACHE, 0                     # Cursory I-Cache test.
    .endif
    .ifndef TEST_COP2_IF
    .set TEST_COP2_IF, 0
    .endif 
    
    .set TEST_COP2_LW_SW, 0                 # LWC2/SWC2 unimplemented so no test
    
    .set RTL_UNDER_CONSTRUCTION, 1

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
    .set CACHED_AREA_BASE,  0x80000000
    # Start of D-TCM block.
    .set DATA_TCM_BASE,     0xa0000000
    # Start of C-TCM as mapped on the DATA bus.
    .set CODE_TCM_BASE,     0xbfc00000
    
    # I/O register block on uncached area. The base address of this block is
    # meant to be overriden from the makefile.
    .ifndef IO_REGS_BASE
    .set IO_REGS_BASE,      0xffff0000
    .endif
    
    # GPIO[i] registers. 
    # Reading (IO_GPIO + i*4) gets you the value of GPIO_[i]_INP.
    # Writing to (IO_GPIO + i*4) sets the value of GPIO_[i]_OUT.
    # You can't read an output port.
    .set IO_GPIO,           IO_REGS_BASE + 0x0020
    
    # TB registers. These are only available in the SW simulator and in the 
    # RTL simulation test bench, not on real hardware.
    # FIXME split the parts that are only in tb_core!

    # Let the makefile override the location of the TB register block.
    .ifndef TB_REGS_BASE
    .set TB_REGS_BASE, 0xffff8000
    .endif
    
    # Simulated UART TX buffer register.
    .set TB_UART_TX,        TB_REGS_BASE + 0x0000
    # Block of 4 32-bit byte-addressable registers (tb_core only!).
    .set TB_DEBUG,          TB_REGS_BASE + 0x0020
    # Register connected to HW interrupt lines.
    .set TB_HW_IRQ,         TB_REGS_BASE + 0x0010
    # Register used to send pass/fail messages to the TB (tb_core only!).
    .set TB_RESULT,         TB_REGS_BASE + 0x0018
    

    .include "test_macros.inc.s"

   
    #---------------------------------------------------------------------------
    # Start of executable.
    
    .text
    .align  2
    .globl  entry
    .ent    entry
    
    #---------------------------------------------------------------------------
    # Reset vector.
    
entry:
    .set    noreorder

    b       init
    nop

    #---------------------------------------------------------------------------
    # Trap handler address. 
    .org    0x0180
    
    # Upon entry, if the exception cause is SYSCALL...
    # We'll do a few changes in the registers (see below) so that the main 
    # program can be sure the ISR executed and the cause code was right, etc.
interrupt_vector:
    mfc0    $26,$13             # 
    andi    $26,$26,0x007c
    addi    $26,$26,-(8<<2)
    beqz    $26,syscall_test
    nop
interrupt_test:
    mfc0    $26,$13             # Return with trap cause register in $26.
    move    $25,$24             # Copy $24 into $25.
    addi    $27,$27,1           # Increment exception count.
    eret
    addi    $27,$27,1           # Increment exception count. Should NOT execute.
syscall_test:    
    .ifgt   TEST_COP2_IF
    mfc0    $26,$14
    lw      $26,-4($26)
    andi    $26,$26,0xffc0
    xori    $26,$26,0x0040
    bnez    $26, interrupt_test
    move    $26,$31
    jal     cop2_test_function
    nop
    move    $31,$26
    .endif  # TEST_COP2_IF
    b       interrupt_test
    nop

init:
    # Display a welcome message. Remember all output is line buffered!
    PUTS    msg_welcome

    # Reset error and exception counters.
    ori     $28,$0,0            # Error count for the test in course. 
    ori     $30,$0,0            # Total test error count.
    ori     $27,$0,0            # Total exception count.


    .ifndef RTL_UNDER_CONSTRUCTION
    #---------------------------------------------------------------------------
    # Test entry in user mode and access to MFC0 from user mode.
    
    # So far, we were in supervisor mode and ERL=1, which means we'll be unable 
    # to return from exceptions properly. 
    # We'll run the rest of the test in user mode. 
    # Note only HW interrupts 7 and 2 are enabled, and SR.IE is 1.
    PUTS    msg_user_mode
    li      $2,0x00408411       # Enter user mode...
    mtc0    $2,$12              # ...NOW
    nop                         # @hack7: COP0 hazard, we need a nop here.

    mfc0    $3,$12              # This should trigger a COP0 missing exception.
    nop
    CMP     $4,$27,1            # Check that we got an exception...
    CMP     $4,$26,0x0b << 2    # ...and check the cause code.
    
    PRINT_RESULT 
    

    .include "break_syscall.inc.s"
    .include "hw_interrupts.inc.s"
    .include "debug_regs.inc.s"
    .include "gpio_regs.inc.s"
    .include "interlock.inc.s"
    .include "data_cache.inc.s"
    .include "instruction_cache.inc.s"
    .endif # RTL_UNDER_CONSTRUCTION
    .include "addsub.inc.s"
    .include "slt.inc.s"
    .include "logic.inc.s"
    .ifndef RTL_UNDER_CONSTRUCTION
    .include "muldiv.inc.s"
    .endif # RTL_UNDER_CONSTRUCTION
    .include "mac.inc.s"
    .include "branch.inc.s"
    .include "jump.inc.s"
    .include "load_store.inc.s"
    .include "shift.inc.s"
    .include "cop2.inc.s"

    
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

    
    #---- Support functions invoked form test macros ---------------------------

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
    
    .data  
msg_welcome:            .asciiz     "ION MIPS opcode tester\n\n"
msg_pass:               .asciiz     "OK\n"
msg_fail:               .asciiz     "ERROR\n"
msg_program_pass:       .asciiz     "\nTest PASSED\n\n"
msg_program_fail:       .asciiz     "\nTest FAILED\n\n"
msg_user_mode:          .asciiz     "Entering user mode........... "
    .text

    .end entry
 
 