################################################################################
# boot_rom.s -- Bootstrap code for booting from internal ROM.
#
# Includes reset code and basic trap handler with calls for all the trap causes.
#
# Initializes the caches and jumps to 'entry' in kernel mode and with interrupts
# disabled.
#
# This code is meant to be placed at the reset vector address (0xbfc00000).
#-------------------------------------------------------------------------------
# FIXME The code still has plenty of remnants from the original ION, refactor!
#-------------------------------------------------------------------------------
# FIXME: exception handling is incomplete (nothing is done on exception).
################################################################################

    #---- Cache parameters -----------------------------------------------------
    .set ICACHE_NUM_LINES, 256              # no. of lines in the I-Cache
    .set DCACHE_NUM_LINES, 256              # no. of lines in the D-Cache
    .set DCACHE_LINE_SIZE, 4                # D-Cache line size in words

    #---------------------------------------------------------------------------

    .text
    .align  2
    .global reset
    .ent    reset
reset:
    .set    noreorder

    b       start_boot
    nop

    #--- Trap handler ----------------------------------------------------------
    
    # We have three trap sources: syscall, break and unimplemented opcode
    # Plus we have to account for a faulty cause code; that's 4 causes.
    # Besides, we have to look out for the branch delay flag (BD).
    .org    0x0180
interrupt_vector:
    mfc0    $k0,$13             # Get trap cause code
    srl     $k0,$k0,2
    andi    $k0,$k0,0x01f
    ori     $k1,$zero,0x8       # was it a syscall?
    beq     $k0,$k1,trap_syscall
    addi    $k1,$k1,0x1         # was it a break?
    beq     $k0,$k1,trap_break
    addi    $k1,$k1,0x1         # was it a bad opcode?
    bne     $k0,$k1,trap_invalid
    nop
    
    # Unimplemented instruction
trap_unimplemented:
    .ifdef  NO_EMU_MIPS32
    j       trap_return         # FIXME should flag the bad opcode?
    nop
    .else
    j       opcode_emu
    nop
    .endif

    # Break instruction
trap_break:
    j       trap_return         # FIXME no support for break opcode
    nop
    
    # Syscall instruction
trap_syscall:
    j       trap_return         # FIXME no support for syscall opcode
    nop

    # Invalid trap cause code, most likely hardware bug
trap_invalid:
    j       trap_return         # FIXME should do something about this
    nop

trap_return:
    mfc0    $k1,$14             # C0_EPC=14 (Exception PC)
    mfc0    $k0,$13             # Get bit 31 (BD) from C0 cause register
    srl     $k0,31
    andi    $k0,$k0,1
    bnez    $k0,trap_return_delay_slot
    addi    $k1,$k1,4           # skip trap instruction
    jr      $k1
    nop
trap_return_delay_slot:
    addi    $k1,$k1,4           # skip jump instruction too
    jr      $k1                 # (we just added 8 to epc)
    rfe
    
    
#-------------------------------------------------------------------------------

start_boot:
    # FIXME this, and all the file indeed, is a temp hack!
    li      $3,0x00408410       # Enter user mode...
    mtc0    $3,$12              # ...NOW
    nop                         # @hack7: COP0 hazard, we need a nop here.

    #jal     setup_cache         # Initialize the caches
    #nop

    # Hardware initialization done. Now we should jump to the main program.
    # Note that if this file was linked separately from the main program (for
    # example to be loaded in different memory areas) then the makefile will
    # have to provide a suitable value for symbol 'entry'.
    la      $a0,entry
    jr      $a0
    nop
    # We won't be coming back...


#---- Functions ----------------------------------------------------------------


    # icache_init:
    # Initialize the cache with CACHE Hit Invalidate instructions.
#icache_init:
#    li      $9,CACHED_RAM_BOT   # Any base address will do.
#    li      $8,DCACHE_NUM_LINES
#icache_init_0:
#    cache   IndexInvalidateD,0x0($9)
#    addi    $8,$8,-1
#    bnez    $8,cache_init_0
#    addi    $9,$9,DCACHE_LINE_SIZE*4

.ifndef  NO_EMU_MIPS32
.include "opcode_emu.s"
.endif


    .set    reorder
    .end    reset
