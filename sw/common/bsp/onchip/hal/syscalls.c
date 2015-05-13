/**
    @file  syscalls.c
    @brief Low level functions invoked by libc and gcc intrinsic functions.
    
    Here we will define the low-level interface functions used by our libc to 
    access the hardware.

    These syscalls have been tailored to Newlib; any libc we choose to use will 
    have to fit on the same interface.
    
    Stubs required by intrinsic gcc functions (such as the puts stub required 
    by gcc's intrinsic printf) will be implemented here too.  
    
    FIXME this file is obviously incomplete.
    
    REFERENCES:
    
    [1] http://eehusky.wordpress.com/2012/12/17/using-gcc-with-the-ti-stellaris-launchpad-newlib/
    [2] http://www.embecosm.com/appnotes/ean9/ean9-howto-newlib-1.0.html#sec_namespace_reent
*/

#include <stdint.h>
#include <stdio.h>

/*-- Local macros ------------------------------------------------------------*/

/* 
  One of the toolchain headers defines putchar as a macro; we need to undefine
  it or it'll wreak havoc in the following code.
*/
#undef putchar

// FIXME using TB stuff; should ifdef!

/* This macro is meant to be overriden from the makefile. */
#ifndef TB_REGS_BASE
#define TB_REGS_BASE (0xffff8000)
#endif

#define UART_TXD_ADDRESS (TB_REGS_BASE + 0)


/*-- Syscalls for Clib replacement elib --------------------------------------*/

/*
    Some of these functions are actually invoked from gcc intrinsics and not
    from the c library. E.g. puts which is called from gcc's printf intrinsic 
    code.
*/


// FIXME incomplete, obviously...
// FIXME document stubs in README file in the library.

/**
    @brief Standard C puts stub.
    
    Writes to TB-supplied UART port with no flow control, appends CR at end.
    
    @arg str Zero-terminated string to be printed to stdout.
    @retval > 0 on success.
    @retval EOF on error.    
*/
int puts (const char * str) {
    int i = 0;
    
    while(str[i]!='\0'){
        putchar(str[i]);
        i++;
    }
    // puts has to append an extra CR. 
    putchar('\n');
    // Return success code.
    return 1;
}

/**
    @brief Standard C putchar stub.
    
    Writes a character to stdout.
    
    @arg c Character to be written.
    @return Character just written. 
*/
int putchar(int c){    
    *((volatile char *)UART_TXD_ADDRESS) = c;
    return c;
};
