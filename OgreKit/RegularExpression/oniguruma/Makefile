VERSION=5.9.0

all: libonig.a

UB_CFLAGS = -isysroot /Developer/SDKs/MacOSX10.4u.sdk -arch i386 -arch ppc -mmacosx-version-min=10.4
UB_LDFLAGS = -Wl,-syslibroot,/Developer/SDKs/MacOSX10.4u.sdk -arch ppc -arch i386 -mmacosx-version-min=10.4

libonig.a: unpack configure compile
	cp onig-$(VERSION)/.libs/libonig.a $@

unpack: onig-$(VERSION)/configure
onig-$(VERSION)/configure:
	tar zxf onig-$(VERSION).tar.gz

configure: onig-$(VERSION)/Makefile
onig-$(VERSION)/Makefile:
	cd onig-$(VERSION) && \
	CFLAGS="$(UB_CFLAGS)" LDFLAGS="$(UB_LDFLAGS)" \
	./configure --disable-shared --disable-dependency-tracking

compile: onig-$(VERSION)/.libs/libonig.a 
onig-$(VERSION)/.libs/libonig.a:
	cd onig-$(VERSION) && make

clean:
	-rm -rf onig-$(VERSION)
	-rm -f libonig.a
	-rm -f unpack configure

