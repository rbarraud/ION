#-------------------------------------------------------------------------------
# This makefile fragment contains all the hardware-related variables common 
# to all ther makefiles in the project.
# It is meant to be included and not used standalone.
# 
# This information must be made available to the RTL building script, 
# linker, assembler and ompiler. 
# This is why it is not defined in a header file.
#-------------------------------------------------------------------------------
# WARNING: The RAM and ROM area locations are also defined in the link script.
#-------------------------------------------------------------------------------

### Useful Hardware Addresses ## All sizes in 32-bit words! ####################

# These addresses are defined in the core and application VHDL entities.
# The TCM sizes will be overriden in the makefile for each test sample, and
# the overriden value will be used in the RTL.
# All other values are hardcoded in the RTL. If you modify them there you need 
# to modify them here too.

# Code memory parameters -- Code TCM. Size in WORDS!
CODE_TCM_BASE = 0xbfc00000
CODE_TCM_SIZE = 4096

# Data memory parameters -- Data TCM. Size in WORDS!
DATA_TCM_BASE = 0xa0000000
DATA_TCM_SIZE = 1024

# Cached RAM area parameters. Size in WORDS!
CACHED_AREA_BASE = 0x80000000
CACHED_AREA_SIZE = 0x04000000   # 256MB

# Test Bench register block -- support simulated HW fo the TB SW. Size in WORDS!
TB_REGS_BASE = 0xffff8000
TB_REGS_SIZE = 0x00002000       # 32KB or 8 Kwords

# GPIO register block in application entity -- 16 words reserved.
IO_GPIO_BASE = 0xffff0020
IO_GPIO_SIZE = 0x00000010



# Build the list of HW symbols that will be passed to the toolchain.
# This list will be expanded properly and passed to AS, CC and LD.
HWSYMS = CODE_TCM DATA_TCM CACHED_AREA TB_REGS IO_GPIO

