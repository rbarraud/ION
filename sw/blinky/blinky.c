/**
    @file blinky.c
    @brief LED blinker.
    
    This program is meant to sanity-check a board. Since it never terminates,
    it is not really suitable for use in automated tests or regression tests. 
*/

#include <stdio.h>

#include "hal.h"


/*---- Public functions ------------------------------------------------------*/

int main()
{   
    volatile int i, count;
    
    /* display a message on the console, if there's any... */
    printf("\nBlinky: free running counter on GPIO 0 port pins.\n\n");
    printf("compile time: " __DATE__ " -- " __TIME__ "\n");
    printf("gcc version:  " __VERSION__ "\n\n");
    
    /* ...and run a count on the pins of GPIO port 0. */
    printf("ENTERING ENDLESS LOOP. This program is not suitable for automated tests!\n\n");
    count = 0;
    while(1){
        hal_gpio_write(0, count++);
        for(i=0;i<1000;i++);
    }
    
    return 0;
}

/*---- Local functions -------------------------------------------------------*/

