# This makefile will invoke the main makefile after configuring the build by 
# setting the value of these variables:
#
# PLATFORM      Name of BSP to use (i.e. subdirectory of common/bsp).
# EXECUTABLE    Name of executable file (MANDATORY).
# DESCRIPTION   String that labels this app in several auto-generated files.
# SIM_LENGTH    RTL simulation timeout in clock cycles.
# LOG_TRIGGER   Address that will trigger RTL execution logging. 
# 
# They are optional unless stated otherwise.
#
# Also, you can override the default value of the folloging variables by giving 
# them any value in this file:
#
# CFLAGS
#
# You can use the following targets to hook into the main build and e.g. set 
# variable values before compilation of each target:
#
# ** target set_tb_app_variables:   Invoked from common target "tb_app".
# ** target set_tb_core_variables:  Invoked form common target "tb_core".

#-- Application setup ----------------------------------------------------------

PLATFORM = onchip
EXECUTABLE = blinky
DESCRIPTION = "LED Blinker"

# Test bench simulation timeout period in clock cycles.
SIM_LENGTH = 90000
# Start logging HW activity after fetching from this address.
LOG_TRIGGER = 0xbfc00000

#-- Build flag overrides -------------------------------------------------------

CFLAGS = -O2 -Wall -c -s -msoft-float -mips1 -G0 $(CC_HWSYMS)

#-- Targets invoked by tb_app and tb_core (see common makefile) ----------------

#-- Set assembler arguments for "tb_application" test bench.
set_tb_app_variables: 
	$(eval TBARGS := --defsym TARGET_HARDWARE=1)    

#-- Set assembler arguments for "tb_core" test bench.
set_tb_core_variables: 
	$(eval TBARGS := )

#-- Application build configuration done, get main makefile --------------------

include ../common/makefile
