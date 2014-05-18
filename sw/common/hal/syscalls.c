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

/*-- Local macros ------------------------------------------------------------*/

// FIXME using TB stuff; should ifdef!

/* This macro is meant to be overriden from the makefile. */
#ifndef TB_REGS_BASE
#define TB_REGS_BASE (0xffff8000)
#endif

#define UART_TXD_ADDRESS (TB_REGS_BASE + 0)



/*-- Libc syscalls -----------------------------------------------------------*/

// FIXME incomplete, obviously...


/*-- Functions invoked from gcc intrinsic functions --------------------------*/

/**
    Standard C puts stub. 
    Writes to TB-supplied UART port with no flow control.
    @arg str Zero-terminated string to be printed to stdout.
    @retval > 0 on success.
    @retval EOF on error.    
*/
int puts (const char * str) {
    int i = 0;
    volatile char *UART = (volatile char *)UART_TXD_ADDRESS;
    
    while(str[i]!='\0'){
        *(UART) = str[i];
        i++;
    }
    // puts has to append an extra CR. 
    *(UART) = '\n';
    // Return success code.
    return 1;
}
