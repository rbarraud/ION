## Software Samples

Eventually we should have here a few SW samples to be run on the core as part of a minimal test bench and as demos. 
For the time being all we have is `cputest`.

If you want to run `cputest` on the RTL or the supplies ISS you need to do this:

+ Build the ISS with `make all` at `tools/ion32sim`. You'll need a regular gcc toolchain for this.
+ Build the SW sample with `make all` at `sw/cputest`.
+ Run the code on the iss with `make iss TEST=cputest` from `sim/iv`.
+ Run the code on the RTL simulation with `make rtl TEST=cputest` from `sim/iv`.

The RTL simulation requires Icarus Verilog and you'll need some MIPS toolchain in order to build the samples.
The makefile fragment `Toolchain.mk` points at the selected toolchain -- edit to suit your setup.

## Execution Logs and the Test Scheme

Both the ISS and the RTL TB generate _execution log files_, basically plain text files that log changes to the CPU state caused by the execution of instructions, one instruction per line.

Goal `all` in the main test makefile at `sim/iv` will do the following:

1. Run the selected test on the ISS (the same as goal `iss`). This builds log file `sim/iv/sw_sim_log.txt`.
2. Run the test on the RTL simulation (the same as goal `rtl`). This builds log file `sim/iv/rtl_sim_log.txt`.
3. Compare the two log files and announce whether or not they match. 

This is a crude form of co-simulation but it is quite effective, in that you can potentially get a lot of testing for almost no effort; and it's also very helpful when diagnosing issues.
_All you need_ is a reliable golden model PLUS a suite of tests that gives you sufficient coverage and you get a decent CPU test suite.

Unfortunately, while the ISS I use was shamelessly lifted from [Steve Rhoads' Plasma project](https://opencores.org/project,plasma) and thus can be sufficiently trusted, my test suite is pitiful -- see below.


### Basic CPU test program `cputest`

A very basic opcode tester. 

A bunch of individual assembly source files, one per opcode or opcode group, will perform a minimal check on each supported instruction and self-check the outcome (in addition to any log matching done afterwards).

Nothing more than a smoke test for development, really.




