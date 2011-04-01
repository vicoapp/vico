debug:
	xcodebuild -configuration Debug

run: debug
	./build/Debug/Vico.app/Contents/MacOS/Vico

build:
	xcodebuild -scheme archive

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

