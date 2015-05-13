#-------------------------------------------------------------------------------
# This makefile fragment contains all the toolchain-related variables common to 
# all makefiles within the project.
# It is meant to be included and not used standalone.
#
# You will need to tailor these variables to your particular development 
# platform setup.
#
#-------------------------------------------------------------------------------

# Some common shell commands (Cygwin/sh version, use your own)
CP = copy
RM = rm -f


# MIPS GCC cross-toolchain -- replace with your own

# CodeSourcery
#TOOLCHAIN = D:\dev\embedded\CodeSourcery\MIPS
#TOOLBASE = mips-sde-elf

# Codescape for baremetal.
TOOLCHAIN = D:\dev\embedded\Codescape\Toolchains\mips-mti-elf\2014.07-1
TOOLBASE = mips-mti-elf


# Toolchain executables
BIN_MIPS = $(TOOLCHAIN)/bin
CC = $(BIN_MIPS)/$(TOOLBASE)-gcc.exe $(CFLAGS)
AS = $(BIN_MIPS)/$(TOOLBASE)-as
AR = $(BIN_MIPS)/$(TOOLBASE)-ar
LD = $(BIN_MIPS)/$(TOOLBASE)-ld
DUMP = $(BIN_MIPS)/$(TOOLBASE)-objdump
COPY = $(BIN_MIPS)/$(TOOLBASE)-objcopy

LIBPATH = $(TOOLCHAIN)/$(TOOLBASE)/lib/sof

# Python interpreter -- replace with your own
PYTHON = D:\dev\util\Python27\python

