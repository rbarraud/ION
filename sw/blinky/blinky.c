/**
    @file blinky.c
    @brief LED blinker.
    
*/

#include <stdio.h>

#include "hal.h"


/*---- Public functions ------------------------------------------------------*/

int main()
{   
    volatile int i, count;
    
    /* display a message on the console, if there's any... */
    printf("\n\nBlinky: free running counter on GPIO 0 port pins.\n\n");
    printf("compile time: " __DATE__ " -- " __TIME__ "\n");
    printf("gcc version:  " __VERSION__ "\n");
    
    /* ...and run a count on the pins of GPIO port 0. */
    count = 0;
    while(1){
        hal_gpio_write(0, count++);
        for(i=0;i<1000;i++);
    }
    
    
    return 0;
}

/*---- Local functions -------------------------------------------------------*/

