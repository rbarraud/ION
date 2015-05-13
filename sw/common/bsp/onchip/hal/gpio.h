/**
    @file gpio.h  
    @brief GPIO interface.
        
    This is the part of the HAL code that deals with the GPIO ports. 
    
    FIXME an explanation of the GPIO port HW is in needed here!
*/

#ifndef HAL_GPIO_H_INCLUDED
#define HAL_GPIO_H_INCLUDED

#include <stdint.h>

/*-- Public functions --------------------------------------------------------*/

/**
    @brief Read GPIO input port.
    
    Note that output ports can't be read.
    
    @arg index Index of port to be read.
*/
uint32_t hal_gpio_read(uint8_t index);

/**
    @brief Write GPIO output port.

    @arg index Index of port to write to.
    @arg value Value to be written on port.
*/
void hal_gpio_write(uint8_t index, uint32_t value);

#endif /* include guard */
