

    #---------------------------------------------------------------------------
    # Minimal test for data cache. 
    .ifgt   TEST_DCACHE
dcache:
    INIT_TEST msg_dcache

    # Initialize the cache with CACHE Hit Invalidate instructions.
cache_init:
    li      $9,CACHED_AREA_BASE # Any base address will do.
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
    li      $3,CACHED_AREA_BASE # $3 points to base of cached RAM.
    li      $6,0x18026809 
    sw      $6,0x08($3)         # Store test pattern...
    # (We do back to back SW/LW)
    lw      $7,0x08($3)         # ...and see if we can read it back.
    CMPR    $6,$7
    NOP
    # Now, store a test byte and read it back. Repeat a few times with 
    # different byte alignments. 

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

    .data 
msg_dcache:             .asciiz     "Data Cache basic test........ "    
    .text

    .endif # TEST_DCACHE
