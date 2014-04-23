This is a basic opcode test bench which tries all supported opcodes. See the
source comments.

Unlike the "opcodes" test, this test does not rely on the user checking visually
the console outpt; instead, it will check all opcodes automatically and 
issue a pass/fail message.

This program can be simulated (both Modelsim and SW simulator) but it can't be 
synthesized to a hardware demo (see makefiles). Only a 'sim' target is provided
in the makefile.

WARNING: the gnu assembler expands DIV* instructions, inserting code that 
handles division by zero. Bear that in mind when reading the listing file.
