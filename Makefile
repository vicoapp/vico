debug:
#	rm -rf build/Debug/Vico.app
	xcodebuild -configuration Debug

run: debug
	./build/Debug/Vico.app/Contents/MacOS/Vico $(HOME)/src/vico/app/ViDocument.m

build:
	rm -rf build/Release/Vico.app
	xcodebuild -scheme archive EXPIRATION=$$(date -v +1w +%s)

test:
	xcodebuild -configuration Debug -target Tests

release:
	./release.sh

tarball:
	FILE="vico-hg-$(date +%Y%m%d%H).tar.gz" \
	tar zcvf $FILE .hg && \
	gpg -r martin -e $FILE && \
	rm $FILE

clean:
	xcodebuild -configuration Debug clean

distclean:
	rm -rf build

.PHONY: build
