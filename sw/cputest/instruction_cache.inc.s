
    #---------------------------------------------------------------------------
    # Test code cache minimally.
    # (We're just gonna execute only a few instructions off the cache.)
    .ifgt   TEST_ICACHE
icache:
    INIT_TEST msg_icache

    # Initialize the CODE cache with CACHE Hit Invalidate instructions.
icache_init:
    li      $9,CACHED_AREA_BASE
    li      $8,ICACHE_NUM_LINES
icache_init_0:
    cache   IndexStoreTagI,0x0($9)
    addi    $8,$8,-1
    bnez    $8,icache_init_0
    addi    $9,$9,ICACHE_LINE_SIZE*4

    # First, we write a single "JR RA" (a return) instruction at the start of
    # the cached RAM, and jump to it. 
    # Failure in this test will crash the program, of course.
    li      $9,CACHED_AREA_BASE
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

    .data
msg_icache:             .asciiz     "Code Cache basic test........ "  
    .text 

    .endif # TEST_ICACHE
    