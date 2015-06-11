WARNING
=======

This project is in the middle of a refactor-within-a-refactor as I try to re-start it. In the unlikely case there's someone watching this, be aware that until further notice the project will probably be broken -- the RTL and/or the SW samples.

ION
===

MIPS-I compatible CPU.

This is a refactor of the [ION project available in Opencores] (http://opencores.org/project,ion).

The aim here is to make this project actually useable and competitive with or1k for deeply embedded applications.

This project is eventually to be backported to OpenCores.


## These are the changes that we plan to include in this refactor:

* Compatible to <strike>MIPS32r1</strike>MIPS-I architecture -- MIPS-I is safe from legal hassles and powerful enough.
* Generic COP2 interface.
* Configurable D-Cache (direct mapped, writethrough).
* Configurable I-Cache (direct mapped).
* Configurable data TCM meant for BRAM implementation.
* Configurable, initializable code TCM meant for BRAM implementation and bootstrap.
* Minimalistic, easy to use MCU module with TCMs and caches.
* 4-stage pipeline (rather than the current, messy 3-stages).
* Cpu entity rewritten from scratch with clean, readable RTL -- submodules remain unchanged.
* Optimized for area.
* Whishbone pipelined interface for memory refills (code and data).
* Whishbone pipelined interface for uncached peripherals.
* Totally rewritten TB with RTL that is actually readable.


## Status

Things already done:
* Basic operation (MIPS-I) in place, including HW interrupts, exceptions, etc.
* Caches done and tested with basic configuration.
* Small "demo" core including 16-bit SRAM interface for cache refill ports.
* COP2 interface almost there.


Things missing:
* New version not tried yet on real hardware.
* No documentation yet.
* Peripheral WB port missing.

