
    #---------------------------------------------------------------------------
    # Test HW interrupts using the support logic in the TB.
    # FIXME Not tested with COP0.Status.IE = 0.
    .ifle   TARGET_HARDWARE
hardware_interrupts:
    INIT_TEST msg_hw_interrupts
    
    .macro CHECK_HW_IRQ cnt, index 
    CMP     $4,$27,\cnt         # Check that we got an exception...
    andi    $25,$26,0x007c      # ...check the cause code...
    CMP     $4,$25,0x00
    andi    $25,$26,0xfc00      # ...and check the IP bits.
    li      $4,1 << (\index + 10)
    CMPR    $4,$25
    sb      $0,($9)             # Clear HW IRQ source.
    .endm
    
    # First test HW IRQ on delay slot instruction.
    la      $9,TB_HW_IRQ        # Prepare to load value in the IRQ test reg.
    li      $2,1 << (2-2)       # We'll trigger HW IRQ 2.
    # (Subtract 2 because HW interrupts go from 2 to 7 but the HW trigger 
    # register has them arranged from 0 to 5.)
    sb      $2,0($9)            # Triggering the IRQ countdown.
    li      $2,0x42
    beqz    $0,hardware_interrupts_1
    li      $11,0x79            # THIS is the HW IRQ victim.
    li      $12,0x85
hardware_interrupts_1:
    CHECK_HW_IRQ 4, 0           # Make sure we got it right.
    #-- 
    li      $2,1 << (6-2)       # Try HW IRQ 6, which is blocked...
    sb      $2,0($9)
    nop
    nop
    li      $11,0x79            # THIS would be the HW IRQ victim.
    nop
    CMP     $11,$27,4           # Make sure we got no exceptions.
    # --
    li      $2,1 << (7-2)       # Try HW IRQ 7, which is enabled.
    sb      $2,0($9)
    nop
    nop
    li      $11,0x79            # (THIS will be the HW IRQ victim.)
    nop
    CHECK_HW_IRQ 5, 5           # Make sure we got it right. 

    # FIXME test HW IRQ on jump instruction.
    # FIXME test HW IRQ on mul/div instruction.
    
hardware_interrupts_0:
    PRINT_RESULT

    .data 
msg_hw_interrupts:      .asciiz     "HW interrupts (TB only)...... "
    .text 

    .endif
    