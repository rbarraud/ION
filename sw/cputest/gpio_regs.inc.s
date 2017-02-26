
    #---------------------------------------------------------------------------
    # Test access to GPIO registers over uncached data WB bridge.
    # This test relies on GPIO_0_OUT being connected to GPIO_0_IN in the TB, 
    # so that GPIO_0_INP = GPIO_0_OUT + 0x2901.
    .ifgt   TARGET_HARDWARE
gpio_regs:
    INIT_TEST msg_gpio
    ori     $2,$0,0x1234
    ori     $3,$0,0x1234 + 0x2901   
    la      $9,IO_GPIO          # Base of GPIO register block.
    
    sw      $2,0x0($9)          # Ok, let's see if the GPIO is there.
    lw      $4,0x0($9)
    CMPR    $3,$4
    
gpio_regs_0:       
    PRINT_RESULT
    .endif

    .data 
msg_gpio:               .asciiz     "Access to GPIO registers..... "
    .text
