#!/usr/bin/python
# Reads a hex file (with a single 8-digit hex word per line) produced by script 
# makehex, and outputs a chunk of array assignments meant to initialize a ROM
# variable. 
# Simulation and synthesis.
#
# Usage:
#
# hex2rom.py <hex file name> <size of ROM in words> <name of ROM> 
#
#

from sys import argv


hexfile = argv[1]
maxwords = int(argv[2])
rom_name = argv[3]


with open(hexfile) as f:
    lines = f.readlines()


base_address = 0
numwords = 0
for line in lines:
    word = int(line.strip(), 16)
    if numwords+1 >= maxwords:
        break
    print " "*4 + "%s[32'h%08x] = 32'h%08x;" % (rom_name, (base_address + numwords*4)/4, word)
    numwords += 1

