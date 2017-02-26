###ionsim32 -- ISS for ION (MIPS32r1 clone).
This is a heavily modified version of Steve Rhoads' MIPS simulator, part of his Plasma project that you can find here:

https://opencores.org/project,plasma

It was originally a MIPS-I-compliant simulator tailored to his RTL. I've modified it to support most of the MIPS32r1 opcodes and to tailor it to my own RTL.
In the process it has become very messy. But it works and can be used to run the SW samples included in the project.

BTW, I've modified the simulator to produce an execution log that can be matched against a similar log output by the RTL test bench. 
Any mismatches between the logs point directly to a misbehaving instruction -- this SW simulator is used as a golden model because it is based on Rhoads' 'known good' simulator. 


###TBD

Eventually some minimal information will be available here. Also, the source code and the command line interface of the simulator need a good clean up.
