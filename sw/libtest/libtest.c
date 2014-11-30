/**
    @file libtest.c
    @brief 'Hello World' basic test.
    
    This program is meant to verify that the build system works AND is capable
    of linking to whatever libc we are using. 
    It is meant to be run on the HW simulation test benches -- it writes to a 
    simulated UART port at address 0x20000000, which is implemented in the TB 
    entities.
    
    IMPORTANT: 
	The way we are using printf precludes use of gcc's intrinsic version of 
	printf; this is the main difference with the "Hellow World" program. See
	the comments in hello.c.

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


