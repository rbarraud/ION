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
RM = rm


# MIPS GCC cross-toolchain: CodeSourcery -- replace with your own
TOOLCHAIN = C:/dev/embedded/SourceryGpp/mips-elf-11-03.52
#TOOLCHAIN = C:/devel/tools/CS_MIPS

# Toolchain executables
BIN_MIPS = $(TOOLCHAIN)/bin
CC = $(BIN_MIPS)/mips-sde-elf-gcc.exe $(CFLAGS)
AS = $(BIN_MIPS)/mips-sde-elf-as
LD = $(BIN_MIPS)/mips-sde-elf-ld
DUMP = $(BIN_MIPS)/mips-sde-elf-objdump
COPY = $(BIN_MIPS)/mips-sde-elf-objcopy

LIBPATH = $(TOOLCHAIN)/mips-sde-elf/lib/sof

# Python interpreter -- replace with your own
#PYTHON = c:/devel/tools/Python27/python.exe
PYTHON = python

