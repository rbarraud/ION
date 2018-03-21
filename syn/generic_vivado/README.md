Build scripts -- ION demo on Digilent's ZYBO board using Vivado.

These scripts will build the project bit stream file using Vivado's non-project 
flow mode. The only step not covered in the scripts is loading the bit stream on 
the target board itself.

The main build script has been mostly copied from the example in page 11 of the
Vivado Tcl scripting guide (ug894, 'Using Tcl Scripting'). 

Output files, including the bit stream, will be created within ./zybo_demo.


USAGE
-----

./build.sh will launch the synthesis flow. 
./delete.sh will clean the directory.


FILES
-----

settings.sh         -- Run Vivado's 'settings' shell script.
build.sh            -- Invoke build.tcl in Vivado.
build.tcl           -- Run synth and implementation, create bitstream file.
delete.sh           -- Deletes all output, leaves dir in repo condition.
quickreport.sh      -- Greps run log for errors and warnings.
README.txt          -- This file.


TARGET
------

Script build.tcl contains a list of source files and constraint file(s).
All the target HW dependencies (ZYBO board) ard contained in the constraints
file. These scripts should be target-agnostic, mostly.


BUILD ION CODE BEFORE SYNTHESIS
-------------------------------

The build needs a Verilog include file to initialize the code memory. 
Script build.tcl will point to one of the test samples supplied with the ION
project (see variable OBJ_CODE_DIR in build.tcl). You need to make sure the SW
is built before the synthesis is launched.


COMPATIBILITY
-------------

This has been tested with Vivado 2015.4 running on a Linux machine.


