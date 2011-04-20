debug:
#	rm -rf build/Debug/Vico.app
	xcodebuild -configuration Debug EXPIRATION=0

run: debug
	./build/Debug/Vico.app/Contents/MacOS/Vico $(HOME)/src/vico

build: test
	rm -rf build/Snapshot/Vico.app
	xcodebuild -scheme archive -configuration Snapshot EXPIRATION=$$(date -v +1d +%s)

test:
	xcodebuild -configuration Debug -target Tests

release: test
	./release.sh

TARDATE := $(shell date +%Y%m%d%H)
TARBALL  = vico-hg-$(TARDATE).tar.gz
tarball:
	tar zcvf $(TARBALL) .hg && \
	gpg -r martin -e $(TARBALL) && \
	rm $(TARBALL)

clean:
	xcodebuild -configuration Debug clean

distclean:
	rm -rf build

.PHONY: build
