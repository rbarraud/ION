/**
    @file hello.c
    @brief 'Hello World' basic test.
    
    This program is meant to verify that the build system works. It is meant to 
    be run on the HW simulation test benches -- it writes to a simulated UART 
    port at address 0x20000000, which is implemented in the TB entities.
    
    This test needs no libc stubs other than puts, which is provided, and with
    the provided makefiles it should generate no MIPS32 opcodes at all.

    IMPORTANT: 
    We're using gcc's intrinsic printf, which 'knows' it'll be using puts to 
    output the string; puts appends a mandatory '\n' at the end of the
    string, so THE LINK WILL FAIL if we try to printf a string that does not 
    end in '\n'.

*/

#include <stdio.h>


/*---- Public functions ------------------------------------------------------*/

int main()
{   
    printf("\n\nHello World!\n\n");
    printf("compile time: " __DATE__ " -- " __TIME__ "\n");
    printf("gcc version:  " __VERSION__ "\n");
    return 0;
}

/*---- Local functions -------------------------------------------------------*/
