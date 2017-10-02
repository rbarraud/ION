WARNING
=======

_This project is a work in progress, advancing at a leisurely pace. Not much to see here at the moment, unless you'd like to take a look at a skinny MIPS32r1 CPU implemented in under 900 lines of code. It goes without saying that the project is not yet fit for any practical purpose. I would not branch it or use it at all if I were you, at least not until this warning notice goes away. 
If you're really desperate for a MIPS-I and none of the other many many MIPS-I cores out there will do, then you can take a look at the [Opencores](http://opencores.org/project,ion) ancestor of this core._


ION
===

This project started as a copy of my [ION project available in Opencores](http://opencores.org/project,ion) which is a MIPS-I R3000 clone.

I don't think the world really needs another MIPS clone. I started this thing for fun back in 2011 and I did have lots of fun. But the original code is too messy to really be worth finishing, much less evolving. So it has been abandoned.

In this project I'm aiming at a brand new MIPS32r1 implementation which will share no RTL with the original project.


This is a work in progress. There's only a basic Verilog implementation of a canonic 5-stage pipeline, along with a crude test bench and a similarly basic 'opcode tester' program. Development will advance as leisure time permits and will be tracked in the [wiki page](https://github.com/jaruiz/ION/wiki).


Quick Start
-----------

There's a makefile that will run tests on the RTL core and/or on a software simulator or 'iss' which is part of this project.  
I'm sure it all will be self-evident to you as you look at the makefile but let me explain how the test scheme is meant to work -- it's the only piece of the project that actually does anything at this moment.

### 1. Build the ISS that comes with this project.


This project ships with an Instruction Set Simulator (ISS) meant to be used as a golden model in the tests. It's a simple application with few dependencies and with any luck will build as-is in any machine that has gcc:

```
cd ./tools/ionsim32
make all
```

Except for a few warnings, that's should do it. The executable should be at `./tools/ionsim32/ionsim32` ready for use.

### 2. Run the main test case 'cputest'.

Just `cd` to directory `./sim/iv` and run `make all TEST=cputest`. 

The name of the test must be one of the directories within `./sw` and by default `TEST=cputest`.  Test `cputest` is the main test case, an opcode tester.

_As it happens, that's the only test that works right now. Please ignore the others!_

Now, for that to work you will need Icarus Verilog on your path. And you will also have to edit the makefile a bit: you need to put in makefile fragment `./sw/Toolchain.mk` the path to a MIPS toolchain which will be invoked to build the test programs.

As you can see in my makefile, I am using a recent-ish version of Buildroot's toolchain. I haven't tried any other recently  but any gcc-based toolchain that's not too old should work, the tests use no feature out of the ordinary.

### 3. Take a look at the console output and the execution log files.

The test makefile will do all of this for a given test program:

1. Build the test program, in this case `./sw/cputest`, by invoking its makefile.
2. Run the program on the ISS.
3. Run the program on the simulated RTL using a simplistic TB that looks like the ISS to the SW.

Now, both the ISS and the RTL simulation will output what I have called _execution logs_: a text file that contains a line for each change to the CPU state. Both files end up in the simulation directory:

* `/sim/iv/rtl_sim_log.txt`
* `/sim/iv/sw_sim_log.txt`

You see where I'm going here. The makefile will compare the log files and declare the test `PASSED` only if the logs match.

The opcode tester program `cputest` also has a minimal self-checking ability so it would be able to catch some errors even without the ISS. But the idea here is that we'll run every test against both platforms.

Of course, this means the RTL will only be as good as the golden model. But given that the code for the ISS is a modified version of the ISS supplied with the PLASMA project that I lifted whole, I have a lot of confidence in it.


Status
------

While the project is a work in progress in a very early stage of development, there's already a basic version of the CPU capable of passing an equally basic CPU opcode test (`sw/cputest`).

There's a _test driver makefile_ in `sim/iv` that makes use of Icarus Verilog to simulate the RTL. It'll run a given SW test on the RTL simulation and on the ISS (`tools/ion32sim`, part of this project) and match the execution logs. This makes for a very easy development flow.

Apart from Icarus Verilog, youl'll need a MIPS32r1 toolchain to play with this _unmodified_ testbench. I'm using a recent version of [BuildRoot](https://buildroot.org/)'s.

Note that while the old RTL from a previous, abandoned version of this project has been deleted from the repo I still haven't deleted the old test SW and other bits and pieces. The only sw test useable right now is `sw/cputest`.
