@rem Run software simulator in hands-off mode
..\..\tools\ion32sim\bin\ion32sim.exe ^
    --bram=libtest.code ^
    --trigger=bfc00000 ^
    --noprompt ^
    --nomips32 ^
    --map=libtest.map ^
    --stop_on_unimplemented ^
    --trace_log=trace_log.txt
    