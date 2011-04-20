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

HELP_SRC = $(CURDIR)/help
HELP_DST = $(CURDIR)/help/Vico.help/Contents/Resources
HELP_EN  = $(HELP_DST)/en.lproj
help:
	rm -rf help/Vico.help
	mkdir -p $(HELP_EN)
	cp -f help/index.html $(HELP_EN)
	cp -rf help/img $(HELP_DST)
	cd $(HELP_EN) && $(HELP_SRC)/md2html $(HELP_SRC)/*.md
	hiutil -vg -s en -Caf $(HELP_EN)/Vico.helpindex $(HELP_EN)

clean:
	xcodebuild -configuration Debug clean

distclean:
	rm -rf build

.PHONY: build help
