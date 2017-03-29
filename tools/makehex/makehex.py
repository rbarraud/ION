#!/usr/bin/env python
#
# This file came from cliffordwolf's great PicoRISC-V project:
# https://github.com/cliffordwolf/picorv32
#
# This is free and unencumbered software released into the public domain.
#
# Anyone is free to copy, modify, publish, use, compile, sell, or
# distribute this software, either in source code form or as a compiled
# binary, for any purpose, commercial or non-commercial, and by any
# means.

from sys import argv

binfile = argv[1]
nwords = int(argv[2])

bigendian = 1

with open(binfile, "rb") as f:
    bindata = f.read()

assert len(bindata) < 4*nwords

for i in range(nwords):
    if i < len(bindata) // 4:
        w = bindata[4*i : 4*i+4]
        if bigendian:
            print("%02x%02x%02x%02x" % (int(w[0].encode('hex'), 16), int(w[1].encode('hex'), 16), int(w[2].encode('hex'), 16), int(w[3].encode('hex'), 16)))
        else:
            print("%02x%02x%02x%02x" % (int(w[3].encode('hex'), 16), int(w[2].encode('hex'), 16), int(w[1].encode('hex'), 16), int(w[0].encode('hex'), 16)))
    else:
        print("0")

