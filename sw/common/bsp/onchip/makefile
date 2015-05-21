
# This makefile fragment must define the following variables:
# CC AS LD AR RM
include ../../toolchain.mak


#-- Common variables -----------------------------------------------------------

CFLAGS  = -O2 -Wall -c -s -fno-builtin -nostdlib -nodefaultlibs \
          -msoft-float -mips1 -G0

# TODO Use optimization better than -O0 after we fully debug the code. 
AFLAGS  = -O0 -msoft-float -mips1
          
DIRHAL   := ./hal
SRCHAL   := $(wildcard ${DIRHAL}/*.c)  
OBJHAL   := $(SRCHAL:$(DIRHAL)/%.c=obj/%.o)

DIRCRT   := ./crt
SRCCRT   := $(wildcard ${DIRCRT}/*.s)  
OBJCRT   := $(SRCCRT:$(DIRCRT)/%.s=lib/%.o)

#-- List of object files to be included in the library
LIBOBJS  = $(OBJHAL)


#-- Targets & rules ------------------------------------------------------------

all: lib/libhal.a crtfiles

lib/libhal.a: $(LIBOBJS)
	$(AR) rvs lib/libhal.a $(LIBOBJS)

crtfiles: $(OBJCRT)
    
obj/%.o: $(DIRHAL)/%.c
	$(CC) $(CFLAGS) -o $@ $^    

lib/%.o: $(DIRCRT)/%.s
	$(AS) $(AFLAGS)  -I $(DIRCRT) -o $@ $^


#-- And now the usual housekeeping stuff ---------------------------------------

.PHONY: clean

clean:
	-$(RM) obj/*.o lib/*.a lib/*.o

