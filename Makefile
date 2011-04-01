debug:
	xcodebuild -configuration Debug

run: debug
	./build/Debug/Viltvodle.app/Contents/MacOS/Viltvodle 

build:
	xcodebuild -scheme archive

test:
	xcodebuild -configuration Debug -target ViltvodleTests

release:
	./release.sh

tarball:
	FILE="viltvodle-hg-$(date +%Y%m%d%H).tar.gz" \
	tar zcvf $FILE .hg && \
	gpg -r martin -e $FILE && \
	rm $FILE


