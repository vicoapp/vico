debug:
#	rm -rf build/Debug/Vico.app
	xcodebuild -configuration Debug

snapshot:
	xcodebuild -configuration Snapshot

run: debug
	./build/Debug/Vico.app/Contents/MacOS/Vico $(HOME)/src/vico

build: test
	rm -rf build/Snapshot/Vico.app
	xcodebuild -scheme archive -configuration Snapshot

test:
	xcodebuild -configuration Debug -target Tests

test_snippets:
	export OTHER_TEST_FLAGS="-SenTest TestViSnippet" && \
	xcodebuild -configuration Debug -target Tests

test_scopes:
	export OTHER_TEST_FLAGS="-SenTest TestScopeSelectors" && \
	xcodebuild -configuration Debug -target Tests

api:
	appledoc --project-name "Vico API" \
		--project-company "Martin Hedenfalk" \
		--company-id se.bzero \
		--no-repeat-first-par \
		--output doc \
		--create-html \
		--no-create-docset \
		app/ViRegisterManager.h \
		app/ViScope.h \
		app/ViWindowController.h \
		app/ViDocumentTabController.h \
		app/ViMap.h \
		app/ViEventManager.h \
		app/ViTextView.h \
		app/ViTextStorage.h \
		app/ViKeyManager.h \
		app/ViParser.h \
		app/ViCommand.h \
		app/ViDocument.h \
		app/ViMark.h \
		app/ViLanguage.h \
		app/ViPreferencePane.h \
		app/ViPreferencesController.h \
		app/NSEvent-keyAdditions.h \
		app/NSView-additions.h \
		app/NSString-additions.h

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
HELP_EN  = $(HELP_DST)/English.lproj
help:
	rm -rf $(CURDIR)/help/Vico.help
	mkdir -p $(HELP_EN)
	cp -f $(HELP_SRC)/index.html $(HELP_EN)/VicoHelp.html
	cp -rf $(HELP_SRC)/shared $(HELP_DST)
	cp -f $(HELP_SRC)/help-Info.plist $(HELP_DST)/../Info.plist
	cp -f $(HELP_SRC)/help-InfoPlist.strings $(HELP_EN)/InfoPlist.strings
	cd $(HELP_EN) && $(HELP_SRC)/md2html $(HELP_SRC)/*.md
	hiutil -vg -s en -Caf $(HELP_EN)/Vico.helpindex $(HELP_EN)

WWW_HELP_DST = $(CURDIR)/help/www
WWW_HELP_EN  = $(WWW_HELP_DST)/en
wwwhelp:
	rm -rf $(CURDIR)/help/www
	mkdir -p $(WWW_HELP_EN)
	cp -rf $(HELP_SRC)/shared $(WWW_HELP_DST)
	cd $(WWW_HELP_EN) && $(HELP_SRC)/md2html.www $(HELP_SRC)/*.md

synchelp: help
	rsync -avr $(HELP_DST)/ www.vicoapp.com:/var/www/vicoapp.com/help

clean:
	xcodebuild -configuration Debug clean

distclean:
	rm -rf build

.PHONY: build help
