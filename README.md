WARNING
=======

_This project is stalled in the middle of an unfinished, messy refactor. It won't build and it looks terrible. Don't branch it and don't use it at all at least until you see this warning notice go away. 
If you're really desperate for a MIPS-I and none of the other many many MIPS-I cores out there will do, then you can take a look at the [Opencores] (http://opencores.org/project,ion) version of this core._


ION
===

This project started as a copy of my [ION project available in Opencores] (http://opencores.org/project,ion) which is a MIPS-I R3000 clone.

I don't think the world really needs another MIPS clone. I started this thing for fun back in 2011 and I did have lots of fun. But the original code is too messy to really be worth finishing, much less evolving. So it has been abandoned.

In this project I'm aiming at a brand new MIPS32r1 implementation which will share no RTL with the original project.


This is a work in progress. There's only a basic Verilog implementation of a canonic 5-stage pipeline, along with a crude test bench and a similarly basic 'opcode tester' program. Development will advance as leisure time permits and will be tracked in the [wiki page](https://github.com/jaruiz/ION/wiki).

