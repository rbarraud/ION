@rem Run software simulator in hands-off mode
..\..\tools\ion32sim\bin\ion32sim.exe ^
    --bram=hello.bin ^
    --trigger=bfc00000 ^
    --noprompt ^
    --nomips32 ^
    --map=hello.map ^
    --trace_log=trace_log.txt
    