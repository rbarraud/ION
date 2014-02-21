/**
    @file libtest.c
    @brief 'Hello World' basic test.
    
    This program is meant to verify that the build system works AND is capable
    of linking to libc. 
    It is meant to be run on the HW simulation test benches -- it writes to a 
    simulated UART port at address 0x20000000, which is implemented in the TB 
    entities.
    
    IMPORTANT: 
    We're using gcc's intrinsic printf, whuch 'knows' it'll be using puts to 
    output the string; puts appends a mandatory '\n' at the end of the
    string, so THE LINK WILL FAIL if we try to printf a string that does not 
    end in '\n'.

*/

#include <stdio.h>

#ifndef UART_TXD_ADDRESS
#define UART_TXD_ADDRESS (0x20000000)
#endif

/*---- Public functions ------------------------------------------------------*/

int main()
{   
    printf("\n\nLibC Test\n\n");
    printf("compile time: " __DATE__ " -- " __TIME__ "\n");
    printf("gcc version:  " __VERSION__ "\n");
    printf("\n\nThis is a printf test: %d\n\n", 42);
    return 0;
}

/*---- Local functions -------------------------------------------------------*/


