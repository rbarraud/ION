WARNING
=======

_This project is stalled in the middle of an unfinished, messy refactor. It won't build and it looks terrible. Don't branch it and don't use it at all at least until you see this warning notice go away. 
If you're really desperate for a MIPS-I and none of the other many many MIPS-I cores out there will do, then you can take a look at the [Opencores] (http://opencores.org/project,ion) version of this core._


ION
===

This is a copy of my [ION project available in Opencores] (http://opencores.org/project,ion) which is a MIPS-I R3000 clone.

I don't think the world really needs another MIPS clone. I started this thing for fun back in 2011 and I did have lots of fun. Now I want to preserve it against the possible sudden disappearance of OpenCores, and maybe I will even refactor it into a viable MIPS32r1. Don't hold your breath, though. 

The OpenCores repository is to remain frozen as long as OpenCores lasts. Any further development, if there is any, will happen here.

_(I was about to scrap the entire project except for the ISS (ion32sim) and build a MIPS-I from scratch using what I've learnt in these years. However, I've realized that building a MIPS-I toolchain has become somewhat difficult and is only going to become more difficult. So I'm going to turn this into a MIPS32r1 instead (the ISS already supports that ISA).
The RTL is still going to be entirely scrapped though.)_
