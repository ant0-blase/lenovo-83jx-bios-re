CC ?= cc
CFLAGS ?= -O2 -Wall -Wextra -Wpedantic -std=c11
LDLIBS ?= -lm

all: lnl-undervolt

lnl-undervolt: lnl-undervolt.c
	$(CC) $(CFLAGS) -o $@ $< $(LDLIBS)

clean:
	rm -f lnl-undervolt
