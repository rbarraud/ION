#-------------------------------------------------------------------------------
# This makefile does not contain any targets, only definitions used by the 
# makefiles of all the code samples. 
# It is meant to be included and not used standalone.
#-------------------------------------------------------------------------------
# SYSTEM PARAMETERS
#
# You can define here the default size and address of the memory blocks of the 
# system as seen by the linker, though you can't change the number and type of 
# blocks here (see /vhdl/mips_cache_*.vhdl and /vhdl/mips_pkg.vhdl).
#
# The samples' makefiles will probably redefine the values, anyway.
#
#-------------------------------------------------------------------------------
# NOTE:
# 
# See info on flag -G0 in ion_noxram.lds
#-------------------------------------------------------------------------------


### Toolchain config ###########################################################

ifeq ($(LANG),)
#****  Customize for Windows/Cygwin

# Some common file commands (Cygwin/sh version, use your own)
CP = copy
RM = del
DWIN32 = -DWIN32
LINUX_PWD =


# MIPS GCC cross-toolchain: CodeSourcery -- replace with your own

PYTHON = c:/devel/tools/Python27/python.exe
BIN_MIPS = C:/devel/tools/CS_MIPS/bin
#BIN_MIPS = C:/dev/embedded/SourceryGpp/mips-elf-11-03.52/bin
CC = $(BIN_MIPS)/mips-sde-elf-gcc.exe $(CFLAGS)
AS = $(BIN_MIPS)/mips-sde-elf-as
LD = $(BIN_MIPS)/mips-sde-elf-ld
DUMP = $(BIN_MIPS)/mips-sde-elf-objdump
COPY = $(BIN_MIPS)/mips-sde-elf-objcopy

else
#**** Customize for Linux

# MIPS GCC cross-toolchain: BuildRoot toolchain in my home directory -- replace with your own
# NOTE: we will not use gcc builtin functions or libc

BIN_MIPS = /home/jaruiz/desarrollo/uClinux/MIPS/buildroot/buildroot-2010.11/output/staging/usr/bin
CC = $(BIN_MIPS)/mips-unknown-linux-uclibc-gcc $(CFLAGS)
AS = $(BIN_MIPS)/mips-unknown-linux-uclibc-as
LD = $(BIN_MIPS)/mips-unknown-linux-uclibc-ld
DUMP = $(BIN_MIPS)/mips-unknown-linux-uclibc-objdump
COPY = $(BIN_MIPS)/mips-unknown-linux-uclibc-objcopy

endif

### VHDL source file manipulation tools ########################################
ION_TOOLS = ../../tools
VHDL_OBJ_PKG = $(PYTHON) $(ION_TOOLS)/build_pkg/build_pkg.py -t $(ION_TOOLS)/build_pkg/templates

### Default system parameters -- to be replaced in application makefile ########

# Code memory parameters -- Code TCM.
CODE_MEM_START  = 0xbfc00000
CODE_MEM_SIZE   = 2048
# Data memory parameters -- Data TCM.
DATA_MEM_START  = 0x00000000
DATA_MEM_SIZE   = 2048

### Project directories -- to be replaced in application makefile ##############

# Root test code source directory, where python script and vhdl templates are
SRC_DIR = ..
# VHDL test bench directory, where VHDL output files will be created
TB_DIR = ../../src/testbench
# Directory for object code package, to be used in synthesis.
OBJ_DIR = ../../src/rtl/obj
# Path to local libraries
LIB_PATH = $(SRC_DIR)/common/libsoc
# Link script to be used: by default, link for internal memory mode.
LINK_SCRIPT ?= $(SRC_DIR)/common/link/internal.lds

### Build options -- to be replaced in application makefile ####################

# Don't use gcc builtin functions, and try to target MIPS-I architecture.
# This will prevent usage of unimplemented opcodes but will insert nops after
# load instructions, which Ion does not need.
# (See comment above about -G0 flag)
#CFLAGS = -O2 -Wall -c -s -fno-builtin -mips1 -G0 -nodefaultlibs -nostdlib
CFLAGS = -O2 -Wall -c -s -mips1 -G0
# LFLAGS: linker options are in the respective makefiles
