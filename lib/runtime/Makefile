#
# ARTICo3 Runtime Library
#
# Author   : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
# Date     : March 2020
#
# Notes:
#     - This Makefile requires the following environment variables to
#       be previously set (by the user, or the ARTICo3 toolchain):
#       CROSS_COMPILE
#
#       CROSS_COMPILE = /opt/Xilinx/SDK/<version>/gnu/aarch32/lin/gcc-arm-linux-gnueabi/bin/arm-linux-gnueabihf-
#       CROSS_COMPILE = /opt/Xilinx/SDK/<version>/gnu/aarch64/lin/aarch64-linux/bin/aarch64-linux-gnu-
#

CC = $(CROSS_COMPILE)gcc
AR = $(CROSS_COMPILE)ar

CFLAGS = -Wall -Wextra -O3 -fpic -I ../../linux
LDFLAGS = -Wl,-R,. -shared
LDLIBS = -lm -lpthread

OBJS = artico3_rcfg.o artico3_hw.o artico3.o

ZYNQ_OBJS = $(OBJS:%=aarch32/_build/%)
ZYNQMP_OBJS = $(OBJS:%=aarch64/_build/%)
AU250_OBJS = $(OBJS_AU250:%=x86/_build/%)

MKDIRP = mkdir -p
CPF = cp -f

.PHONY: zynq
zynq: $(ZYNQ_OBJS)
	$(CC) $(LDFLAGS) $^ $(LDLIBS) -o aarch32/libartico3.so
	$(AR) rcs aarch32/libartico3.a $^
	$(MKDIRP) aarch32/include
	$(CPF) artico3.h aarch32/include

.PHONY: zynqmp
zynqmp: $(ZYNQMP_OBJS)
	$(CC) $(LDFLAGS) $^ $(LDLIBS) -o aarch64/libartico3.so
	$(AR) rcs aarch64/libartico3.a $^
	$(MKDIRP) aarch64/include
	$(CPF) artico3.h aarch64/include

.PHONY: au250
au250: $(AU250_OBJS)
	$(CC) $(LDFLAGS) $^ $(LDLIBS) -o x86/libartico3.so
	$(AR) rcs x86/libartico3.a $^
	$(MKDIRP) x86/include
	$(CPF) artico3.h x86/include

.PHONY: clean
clean:
	rm -rf aarch32 aarch64 x86

aarch32/_build/%.o: %.c
	$(MKDIRP) $(@D)
	$(CC) $(CFLAGS) -c $< -o $@

aarch64/_build/%.o: %.c
	$(MKDIRP) $(@D)
	$(CC) -DZYNQMP $(CFLAGS) -c $< -o $@

x86/_build/%.o: %.c
	$(MKDIRP) $(@D)
	$(CC) -DAU250 $(CFLAGS) -c $< -o $@
