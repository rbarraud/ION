
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
    andi    $25,$26,0x007c
    CMP     $23,$25,\code << 2
    CMP     $23,$27,\count
    .endm
    
    TRAP_OP break, 0x09, 2
    TRAP_OP "syscall 0", 0x08, 3
    
break_syscall_0:
    PRINT_RESULT

    .data 
msg_break_syscall:      .asciiz     "Break/Syscall opcodes........ "
    .text 
