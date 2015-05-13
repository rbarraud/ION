WARNING
=======

This project is in the middle of a refactor-within-a-refactor as I try to re-start it. In the unlikely case there's someone watching this, be aware that until further notice the project will probably be broken -- the RTL and/or the SW samples.

ION
===

MIPS32r1 compatible CPU.

This is a refactor of the [ION project available in Opencores] (http://opencores.org/project,ion).

The original project is a MIPS-I implementation whereas this one is meant to be MIPS32r1 compatible.

This project is eventually to be backported to OpenCores.


## Feature wish list

* Compatible to MIPS32r1 architecture.
* Generic COP2 interface.
* Configurable D-Cache (direct mapped, writethrough).
* Configurable I-Cache (direct mapped).
* Configurable data TCM meant for BRAM implementation.
* Configurable, initializable code TCM meant for BRAM implementation and bootstrap.
* Optimized for area (currently less than 2100 LEs in a Cyclone-2 at 43MHz).
* Whishbone pipelined interface for memory refills (code and data).
* Whishbone pipelined interface for uncached peripherals.



## Status

Things already done:
* Basic operation (MIPS-I) in place, including HW interrupts, exceptions, etc.
* Caches done and tested with basic configuration.
* Small "demo" core including 16-bit SRAM interface for cache refill ports.
* COP2 interface almost there.


Things missing:
* New version not tried yet on real hardware.
* No documentation yet.
* Some MIPS32r1 opcodes not implemented yet.
* Some MIPS32r1 COP0 registers not implemented yet.
* Peripheral WB port missing.

