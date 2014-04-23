@rem Run software simulator in hands-off mode
..\..\tools\ion32sim\bin\ion32sim.exe ^
    --bram=cputest.bin ^
    --trigger=bfc00000 ^
    --noprompt ^
    --nomips32
    