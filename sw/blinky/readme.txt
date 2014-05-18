This is the classic "BLINKY" LED blinker demo program. It will blink a pattern 
of values on GPIO port 0.

Build with "make tb_app".

Can be simulated on Modelsim with "application_tb" and synthesized to a hardware
demo running on the DE-1 demoboard. 

It can be simulated on the SW simulator; you'll not see any IO pattern (because 
GPIO port values are not displayed in the SW simulator) but the logs can be 
compared to the RTL simmulation for debugging.
