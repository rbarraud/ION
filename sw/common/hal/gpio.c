/**
    @file  gpio.c
    @brief Implementation of GPIO interface functions.
*/

#include "gpio.h"

/*-- Local macros ------------------------------------------------------------*/

/* This macro is meant to be overriden from the makefile. */
#ifndef IO_GPIO_BASE
#define IO_GPIO_BASE (0xffff0020)
#endif

/*-- Public functions --------------------------------------------------------*/

/* Read GPIO input port. */
uint32_t hal_gpio_read(uint8_t index) {
    return *((volatile uint32_t *)(IO_GPIO_BASE + (index << 2)));
}

/* Write GPIO output port. */
void hal_gpio_write(uint8_t index, uint32_t value) {
    *((volatile uint32_t *)(IO_GPIO_BASE + (index << 2))) = value;
}
