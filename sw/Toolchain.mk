# Toolchain config. Point this at your own MIPS toolchain.
# (Any will do, we're not using the libraries yet.)
TOOLCHAIN_PREFIX = /home/jaruiz/dev/tools/buildRoot/buildroot-2016.11.2/output/host/usr/bin/mipsel-buildroot-linux-uclibc-

# Utility scripts included with this project.
MAKEHEX = ../../tools/makehex/makehex.py
HEX2ROM = ../../tools/makehex/hex2rom.py
