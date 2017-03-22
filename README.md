WARNING
=======

_This project is a work in progress, advancing at a leisurely pace. Not much to see here at the moment, unless you'd like to take a look at a skinny MIPS32r1 CPU implemented in under 900 lines of code. It goes without saying that the project is not yet fit for any practical purpose. I would not branch it or use it at all if I were you, at least not until this warning notice goes away. 
If you're really desperate for a MIPS-I and none of the other many many MIPS-I cores out there will do, then you can take a look at the [Opencores] (http://opencores.org/project,ion) ancestor of this core._


ION
===

This project started as a copy of my [ION project available in Opencores] (http://opencores.org/project,ion) which is a MIPS-I R3000 clone.

I don't think the world really needs another MIPS clone. I started this thing for fun back in 2011 and I did have lots of fun. But the original code is too messy to really be worth finishing, much less evolving. So it has been abandoned.

In this project I'm aiming at a brand new MIPS32r1 implementation which will share no RTL with the original project.


This is a work in progress. There's only a basic Verilog implementation of a canonic 5-stage pipeline, along with a crude test bench and a similarly basic 'opcode tester' program. Development will advance as leisure time permits and will be tracked in the [wiki page](https://github.com/jaruiz/ION/wiki).


Status
------

While the project is a work in progress in a very early stage of development, there's already a basic version of the CPU capable of passing an equally basic CPU opcode test (`sw/cputest`).

There's a _test driver makefile_ in `sim/iv` that makes use of Icarus Verilog to simulate the RTL. It'll run a given SW test on the RTL simulation and on the ISS (`tools/ion32sim`, part of this project) and match the execution logs. This makes for a very easy development flow.

Apart from Icarus Verilog, youl'll need a MIPS32r1 toolchain to play with this _unmodified_ testbench. I'm using a recent version of [BuildRoot](https://buildroot.org/)'s.

Note that while the old RTL from a previous, abandoned version of this project has been deleted from the repo I still haven't deleted the old test SW and other bits and pieces. The only sw test useable right now is `sw/cputest`.
