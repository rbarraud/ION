

    #---------------------------------------------------------------------------
    # Mul/Div instructions: mul, mulu, div, divu.
    # WARNING: the assembler expands div instructions, see 'as' manual.
muldiv:
    INIT_TEST msg_muldiv
   
    # Test DIV or DIVU with some arguments. 
    # Will use the same register set in all tests. Oh well...
    .macro TEST_DIV op, num, den, remainder, quotient
    li      $4,\num             # Load regs with test arguments...
    li      $5,\den
    # (By using $0 as first op we tell as not to expand the div opcode.)
    \op     $0,$4,$5            # ...do the div operation...
    mflo    $8
    mfhi    $9
    CMP     $7,$8, \quotient    # ...and check result.
    CMP     $6,$9, \remainder
    .endm

   
    # Remember, our divider follows C99 rules:
    # 1.- The quotient is negative iif dividend and divisor have different sign.
    # 2.- The remainder has the same sign as the dividend.

    TEST_DIV divu,  0x00000100, 0x00000020, 0x00000000, 0x00000008
    TEST_DIV divu,  0x00000101, 0x00000020, 0x00000001, 0x00000008
    TEST_DIV div,   0x00000101, 0x00000020, 0x00000001, 0x00000008
    TEST_DIV div,   0x00000100, 0xfffffff9, 0x00000004, 0xffffffdc
    TEST_DIV div,   0xffffff00, 0x00000007, 0xfffffffc, 0xffffffdc
    TEST_DIV div,   0xffffff01, 0x00000007, 0xfffffffd, 0xffffffdc

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
    
    # FIXME MUL (3-op version) untested!
    
muldiv_end:
    PRINT_RESULT

    .data
msg_muldiv:             .asciiz     "Mul*/Div* opcodes............ "
    .text  
