/**
    @file hello.c
    @brief 'Hello World' basic test.
    
    This program is meant to verify that the build system works. It is meant to 
    be run on the HW simulation test benches -- it writes to a simulated UART 
    port at address 0x20000000, which is implemented in the TB entities.
    
    This test needs no libc stubs other than puts, which is provided, and with
    the provided makefiles it should generate no MIPS32 opcodes at all.

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
    printf("\n\nHello World!\n\n");
    printf("compile time: " __DATE__ " -- " __TIME__ "\n");
    printf("gcc version:  " __VERSION__ "\n");
    return 0;
}

/*---- Local functions -------------------------------------------------------*/

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
