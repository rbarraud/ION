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

/*---- Public functions ------------------------------------------------------*/

int main()
{   
    int i;
    int integer, fraction;
    float f = 1.0;
    
    printf("\n\nLibC Test\n\n");
    printf("compile time: " __DATE__ " -- " __TIME__ "\n");
    printf("gcc version:  " __VERSION__ "\n");
    printf("Trying printf with int parameters:\n");
    for(i=0;i<4;i++) {
        printf("    [%d] : %d == 0x%02x\n", i, i+42, i+42);
    }
    printf("Trying basic float operations:\n");
    for(i=0;i<4;i++) {
        integer = (int)f;
        fraction = (int)(f*100.0) - integer*100;
        printf("    1.0 + (0.7 * %d) == %d.%d\n", i, integer, fraction);
        f = f + 0.7;
    }
    
    return 0;
}

/*---- Local functions -------------------------------------------------------*/


