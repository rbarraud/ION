# Targets: all, clean.

# Executable names, adapt to your platform.
CC = cc
RM = rm -f


SRC := $(wildcard src/*.c)
OBJ := $(SRC:src/%.c=%.o)


.PHONY: all
all:
	$(CC) $(SRC) -o ./bin/ion32sim


.PHONY: clean
clean:
	-$(RM) *.o 
	-$(RM) bin\*