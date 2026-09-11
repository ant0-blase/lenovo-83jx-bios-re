CC ?= cc
CFLAGS ?= -O2 -Wall -Wextra -Wpedantic -std=c11

all: lnl-uvp-pcode

lnl-uvp-pcode: lnl-uvp-pcode.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f lnl-uvp-pcode

.PHONY: all clean
