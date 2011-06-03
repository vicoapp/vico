#! /usr/bin/make

BIN=$(DESTDIR)/usr/bin
DOC=$(DESTDIR)/usr/share/doc/par
MAN=$(DESTDIR)/usr/share/man/man1

include protoMakefile

CC = cc $(CFLAGS) -c

install: par par.doc
	install -o root -g root -m 0755 par $(BIN)/par
	install -d $(DOC) -o root -g root -m 0755
	install -o root -g root -m 0644 par.doc $(DOC)
	install -d $(MAN) -o root -g root -m 0755
	install -o root -g root -m 0644 par.1 $(MAN)

