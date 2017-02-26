
MAKEHEX = ../../tools/makehex/makehex.py

GCC_WARNS  = -Werror -Wall -Wextra -Wshadow -Wundef -Wpointer-arith -Wcast-qual -Wcast-align -Wwrite-strings
GCC_WARNS += -Wredundant-decls -Wstrict-prototypes -Wmissing-prototypes -pedantic # -Wconversion
TOOLCHAIN_PREFIX = /home/jaruiz/dev/tools/buildRoot/buildroot-2016.11.2/output/host/usr/bin/mipsel-buildroot-linux-uclibc-
