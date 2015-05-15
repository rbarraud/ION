
# This makefile fragment must define the following variables:
# CC AS LD
include ../toolchain.mak


#-- Common variables -----------------------------------------------------------

CFLAGS  = -O2 -Wall -c -s -fno-builtin -nostdlib -nodefaultlibs \
          -msoft-float -mips1 -G0

# The FP functions are special: a single file, and we compile it twice. 
# We define the targets manually. 
DIRFP := src/fp
OBJFP := obj/fp-bit-float.o obj/fp-bit-double.o

DIRSTDIO := ./src/stdio
SRCSTDIO := $(wildcard ${DIRSTDIO}/*.c)  
OBJSTDIO := $(SRCSTDIO:$(DIRSTDIO)/%.c=obj/%.o)

DIRSTRING := ./src/stdio
SRCSTRING := $(wildcard ${DIRSTRING}/*.c)  
OBJSTRING := $(SRCSTRING:$(DIRSTRING)/%.c=obj/%.o)

          
#-- List of object files to be included in the library
OBJS    = $(OBJFP) $(OBJSTDIO) $(OBJSTRING)


#-- Targets & rules ------------------------------------------------------------

all: lib/libe.a

lib/libe.a: objdirs $(OBJS)
	$(AR) rvs lib/libe.a $(OBJS)

objdirs:
	mkdir -p obj
	mkdir -p lib

# The FP math library is compiled separately for float support...
obj/fp-bit-float.o: $(DIRFP)/fp-bit.c
	$(CC) $(CFLAGS) -DFLOAT=1 $(DIRFP)/fp-bit.c -o obj/fp-bit-float.o
# ...and for double support
obj/fp-bit-double.o: $(DIRFP)/fp-bit.c
	$(CC) $(CFLAGS) $(DIRFP)/fp-bit.c -o obj/fp-bit-double.o

# All other object files are compiled in the usual way.
obj/%.o: $(DIRSTDIO)/%.c
	$(CC) $(CFLAGS) -o $@ $^    

obj/%.o: $(DIRSTRING)/%.c
	$(CC) $(CFLAGS) -o $@ $^    


#-- And now the usual housekeeping stuff ---------------------------------------

.PHONY: clean

clean:
	-$(RM) obj/*.o lib/*.a

