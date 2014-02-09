ARCH ?= x86_64
CONFIGURATION ?= Debug

BUILDDIRPATH=$(CURDIR)/build
BUILDDIR=$(shell mkdir -p $(BUILDDIRPATH) && echo $(BUILDDIRPATH))
BINDIR=$(BUILDDIR)/$(CONFIGURATION)/Vico.app/Contents/MacOS

VPATH = app app/en.lproj json oniguruma oniguruma/enc universalchardet lemon \
	util par help
	

HELP_SRCS = \
	basics.md \
	change.md \
	change_indent.md \
	delete.md \
	dot.md \
	ex.md \
	ex_cmds.md \
	ex_ranges.md \
	explorer.md \
	indent_settings.md \
	insert.md \
	jumplist.md \
	line_search.md \
	move_chars.md \
	move_lines.md \
	move_symbols.md \
	move_words.md \
	movement.md \
	open_line.md \
	operators.md \
	remote.md \
	scrolling.md \
	searching.md \
	splits.md \
	ssh_keygen.md \
	symbols.md \
	terminal.md \
	visual.md

HELP_HTMLS = $(addprefix $(HELP_EN)/,$(HELP_SRCS:.md=.html))

$(HELP_EN)/%.html: %.md
	mkdir -p $(@D)
	help/md2html $< > $@

app: submodules
	xcodebuild -scheme "Vico app" -configuration Debug SYMROOT=$(BUILDDIR)

submodules: $(BUILDDIR)/gitmodules.stamp
$(BUILDDIR)/gitmodules.stamp:
	git submodule update --init --recursive -- .
	touch $@

binaries: $(OBJDIR)/Vico $(OBJDIR)/vicotool $(OBJDIR)/par

$(OBJDIR)/Vico: $(OBJS)
	mkdir -p $(OBJDIR)
	$(CXX) $(LDFLAGS) $(LDLIBS) $(APP_LDLIBS) $(addprefix -framework ,$(APP_FRAMEWORKS)) $^ -o $@

$(OBJDIR)/vicotool: $(TOOL_OBJS)
	mkdir -p $(OBJDIR)
	$(CC) $(LDFLAGS) $(TOOL_LDLIBS) $^ -o $@

TMPDMG		= $(BUILDDIR)/vico-tmp.dmg
VOLNAME		= vico-$(SHORT_VERSION)
DMGFILE		= $(VOLNAME).dmg
DMG		= $(BUILDDIR)/$(DMGFILE)
DMGDIR		= "$(BUILDDIR)/Vico $(SHORT_VERSION)"
APPCAST_BASE	= http://www.vicoapp.com/relnotes
DOWNLOAD_BASE	= http://www.vicoapp.com/download
KSIZE		= $(shell du -ks $(APPDIR) | cut -f1)
SIZE		= $(shell echo $$(($(KSIZE) * 1024)) )
SPARKLE_PKEY	= sparkle_priv.pem
SIGNATURE	= $(shell /usr/bin/openssl dgst -sha1 -binary < $(DMG) | \
		    /usr/bin/openssl dgst -dss1 -sign $(SPARKLE_PKEY) | \
		    /usr/bin/openssl enc -base64)
APPCAST_XML	= $(DMG).xml

#dmg: $(DMG)
#$(DMG): app
#	@echo "Creating disk image $(VOLNAME)"
#	/bin/rm -rf $(TMPDMG) $(DMGDIR) $(DMG)
#	mkdir -p $(DMGDIR)
#	/bin/cp -a $(APPDIR) $(DMGDIR)
#	ln -s /Applications $(DMGDIR)/Applications
#	hdiutil makehybrid -o $(TMPDMG) $(DMGDIR) -hfs
#	hdiutil convert -format UDBZ $(TMPDMG) -o $(DMG)
#	/bin/rm -rf $(TMPDMG) $(DMGDIR)
#	ls -lh $(DMG)

#### Create and sign a zip file for automatic updates.
#appcast: $(DMG)
#	@sed -e 's,@SHORT_VERSION@,$(SHORT_VERSION),g' \
#	    -e 's,@REPO_VERSION@,$(REPO_VERSION),g' \
#	    -e 's,@RELNOTES_LINK@,$(APPCAST_BASE)/$(SHORT_VERSION),g' \
#	    -e 's/@DATE@/$(shell LC_TIME=en_US date +"%a, %d %b %G %T %z")/g' \
#	    -e 's,@DOWNLOAD_FILE@,$(DOWNLOAD_BASE)/$(DMGFILE),g' \
#	    -e 's,@SIGNATURE@,$(SIGNATURE),g' \
#	    -e 's,@SIZE@,$(SIZE),g' < appcast.xml.in > $(APPCAST_XML)
#	@cat $(APPCAST_XML)

#RELEASE_TAG	?= $(shell git rev-parse --short HEAD)
#RELEASE_DIR	 = build/$(CONFIGURATION)-$(RELEASE_TAG)

#.PHONY: checkout
#checkout:
#	@echo release directory is $(RELEASE_DIR)
#	@if test -d $(RELEASE_DIR); then echo "release directory already exists"; exit 1; fi
#	@echo checking out sources for '$(RELEASE_TAG)'
#	git clone . $(RELEASE_DIR)
#	cd $(RELEASE_DIR) && git co $(RELEASE_TAG)

#release: checkout
#	$(MAKE) -C $(RELEASE_DIR) appcast

# convenience targets
run: app
	$(BINDIR)/Vico $(CURDIR)

gdb: app
	gdb $(BINDIR)/Vico

leaks: app
	MallocStackLogging=YES \
	  $(BINDIR)/Vico $(CURDIR)

zombie: app
	NSZombieEnabled=YES NSDebugEnabled=YES \
	  $(BINDIR)/Vico $(CURDIR)

test:
	xcodebuild -configuration $CONFIGURATION -target Tests

test_snippets:
	export OTHER_TEST_FLAGS="-SenTest TestViSnippet" && \
	xcodebuild -configuration Debug -target Tests

test_scopes:
	export OTHER_TEST_FLAGS="-SenTest TestScopeSelectors" && \
	xcodebuild -configuration Debug -target Tests

api:
	rm -rf doc/html
	appledoc --project-name "Vico API" \
		--project-company "Martin Hedenfalk" \
		--company-id se.bzero \
		--no-repeat-first-par \
		--output doc \
		--create-html \
		--no-create-docset \
		--merge-categories \
		app/ExCommand.h \
		app/ExMap.h \
		app/ExParser.h \
		app/NSEvent-keyAdditions.h \
		app/NSString-additions.h \
		app/NSView-additions.h \
		app/ViCommand.h \
		app/ViDocument.h \
		app/ViDocumentView.h \
		app/ViEventManager.h \
		app/ViKeyManager.h \
		app/ViLanguage.h \
		app/ViMap.h \
		app/ViMark.h \
		app/ViParser.h \
		app/ViPreferencePane.h \
		app/ViPreferencesController.h \
		app/ViRegisterManager.h \
		app/ViScope.h \
		app/ViTabController.h \
		app/ViTextStorage.h \
		app/ViTextView.h \
		app/ViViewController.h \
		app/ViWindowController.h

syncapi: api
	rsync -av --delete  doc/html/ www:/var/www/feedback.vicoapp.com/public/api

HELP_FILES = \
	index.html \
	$(HELP_SRCS) \
	shared/help.css \
	shared/icon_hand.png \
	shared/icon_hand_32.png \
	shared/icon_hand_64.png \
	help-Info.plist \
	help-InfoPlist.strings

help: $(DERIVEDDIR)/help.stamp
HELP_RESDIR = $(RESDIR)/Vico.help/Contents/Resources
HELP_EN = $(HELP_RESDIR)/English.lproj
$(DERIVEDDIR)/help.stamp: $(HELP_FILES)
	mkdir -p $(HELP_EN)
	cp -f help/index.html $(HELP_EN)/VicoHelp.html
	rsync -a --delete --exclude ".DS_Store" help/shared $(HELP_RESDIR)
	cp -f help/help-Info.plist $(HELP_RESDIR)/../Info.plist
	cp -f help/help-InfoPlist.strings $(HELP_EN)/InfoPlist.strings
	for md in $(HELP_SRCS); do \
		./help/md2html help/$$md > $(HELP_EN)/$${md%.md}.html; \
	done
	hiutil -vg -s en -Caf $(HELP_EN)/Vico.helpindex $(HELP_EN)
	touch $(DERIVEDDIR)/help.stamp

HELP_SRC = $(CURDIR)/help
WWW_HELP_DST = $(CURDIR)/help/www
WWW_HELP_EN  = $(WWW_HELP_DST)/en
wwwhelp:
	rm -rf $(CURDIR)/help/www
	mkdir -p $(WWW_HELP_EN)
	cp -rf $(HELP_SRC)/shared $(WWW_HELP_DST)
	cd $(WWW_HELP_EN) && $(HELP_SRC)/md2html.www $(HELP_SRC)/*.md

syncwwwhelp: wwwhelp
	rsync -avr $(WWW_HELP_DST)/ www.vicoapp.com:/var/www/vicoapp.com/help/

synchelp: help
	rsync -avr $(HELP_RESDIR)/ www.vicoapp.com:/var/www/vicoapp.com/help

clean:
	xcodebuild clean

distclean:
	rm -rf $(BUILDDIR)
