CONFIGURATION ?= DEBUG

VPATH = app app/en.lproj json oniguruma oniguruma/enc universalchardet lemon util par $(BUILDDIR)

JSON_OBJC_SRCS = \
	NSObject+JSON.m \
	SBJsonParser.m \
	SBJsonStreamParser.m \
	SBJsonStreamParserAdapter.m \
	SBJsonStreamParserState.m \
	SBJsonStreamWriter.m \
	SBJsonStreamWriterState.m \
	SBJsonTokeniser.m \
	SBJsonWriter.m

OBJC_SRCS = \
	ExAddress.m \
	ExCommand.m \
	ExCommandCompletion.m \
	ExMap.m \
	ExParser.m \
	ExTextField.m \
	MHTextIconCell.m \
	NSArray-patterns.m \
	NSEvent-keyAdditions.m \
	NSMenu-additions.m \
	NSObject+SPInvocationGrabbing.m \
	NSOutlineView-vimotions.m \
	NSScanner-additions.m \
	NSString-additions.m \
	NSString-scopeSelector.m \
	NSTableView-vimotions.m \
	NSTask-streaming.m \
	NSURL-additions.m \
	NSView-additions.m \
        NSWindow-additions.m \
	PSMMetalTabStyle.m \
	PSMOverflowPopUpButton.m \
	PSMProgressIndicator.m \
	PSMRolloverButton.m \
	PSMTabBarCell.m \
	PSMTabBarControl.m \
	PSMTabDragAssistant.m \
	SFTPConnection.m \
	SFTPConnectionPool.m \
	TMFileURLProtocol.m \
	TxmtURLProtocol.m \
	ViAppController.m \
	ViBgView.m \
	ViBufferCompletion.m \
	ViBufferedStream.m \
	ViBundle.m \
	ViBundleCommand.m \
	ViBundleItem.m \
	ViBundleSnippet.m \
	ViBundleStore.m \
	ViCommand.m \
	ViCommandMenuItemView.m \
	ViCommandOutputController.m \
	ViCompletion.m \
	ViCompletionController.m \
	ViCompletionView.m \
	ViCompletionWindow.m \
	ViDocument.m \
	ViDocumentController.m \
	ViDocumentView.m \
	ViError.m \
	ViEventManager.m \
	ViFile.m \
	ViFileCompletion.m \
	ViFileExplorer.m \
	ViFileURLHandler.m \
	ViHTTPURLHandler.m \
	ViJumpList.m \
	ViKeyManager.m \
	ViLanguage.m \
	ViLayoutManager.m \
	ViMacro.m \
	ViMap.m \
	ViMark.m \
	ViMarkInspector.m \
	ViMarkManager.m \
	ViOutlineView.m \
	ViParser.m \
	ViPathCell.m \
	ViPathComponentCell.m \
	ViPathControl.m \
	ViPreferencePane.m \
	ViPreferencePaneAdvanced.m \
	ViPreferencePaneBundles.m \
	ViPreferencePaneEdit.m \
	ViPreferencePaneGeneral.m \
	ViPreferencePaneTheme.m \
	ViPreferencesController.m \
	ViProject.m \
	ViRegexp.m \
	ViRegisterManager.m \
	ViRulerView.m \
	ViSFTPURLHandler.m \
	ViScope.m \
	ViSeparatorCell.m \
	ViSnippet.m \
	ViSymbolController.m \
	ViSymbolTransform.m \
	ViSyntaxCompletion.m \
	ViSyntaxContext.m \
	ViSyntaxMatch.m \
	ViSyntaxParser.m \
	ViTabController.m \
	ViTagsDatabase.m \
	ViTaskRunner.m \
	ViTextStorage.m \
	ViTextView-bundle_commands.m \
	ViTextView-cursor.m \
	ViTextView-ex_commands.m \
	ViTextView-snippets.m \
	ViTextView-vi_commands.m \
	ViTextView.m \
	ViTheme.m \
	ViThemeStore.m \
	ViToolbarPopUpButtonCell.m \
	ViTransformer.m \
	ViURLManager.m \
	ViWebView.m \
	ViWindow.m \
	ViWindowController.m \
	ViWordCompletion.m \
	main.m \
	$(JSON_OBJC_SRCS)

OBJCXX_SRCS = \
	ViCharsetDetector.mm

C_SRCS = \
	ber.c \
	debug.c \
	regcomp.c \
	regenc.c \
	regerror.c \
	regexec.c \
	regext.c \
	reggnu.c \
	regparse.c \
	regposerr.c \
	regposix.c \
	regsyntax.c \
	regtrav.c \
	regversion.c \
	st.c \
	ascii.c \
	big5.c \
	cp1251.c \
	euc_jp.c \
	euc_kr.c \
	euc_tw.c \
	gb18030.c \
	iso8859_1.c \
	iso8859_10.c \
	iso8859_11.c \
	iso8859_13.c \
	iso8859_14.c \
	iso8859_15.c \
	iso8859_16.c \
	iso8859_2.c \
	iso8859_3.c \
	iso8859_4.c \
	iso8859_5.c \
	iso8859_6.c \
	iso8859_7.c \
	iso8859_8.c \
	iso8859_9.c \
	koi8.c \
	koi8_r.c \
	sjis.c \
	unicode.c \
	utf16_be.c \
	utf16_le.c \
	utf32_be.c \
	utf32_le.c \
	utf8.c

GENERATED_C_SRCS = \
	scope_selector.c

RELEASE_C_SRCS = \
	receipt.c

ALL_C_SRCS = $($(CONFIGURATION)_C_SRCS) $(C_SRCS) $(GENERATED_C_SRCS)

CXX_SRCS = \
	CharDistribution.cpp \
	JpCntx.cpp \
	LangBulgarianModel.cpp \
	LangCyrillicModel.cpp \
	LangGreekModel.cpp \
	LangHebrewModel.cpp \
	LangHungarianModel.cpp \
	LangThaiModel.cpp \
	nsBig5Prober.cpp \
	nsCharSetProber.cpp \
	nsEUCJPProber.cpp \
	nsEUCKRProber.cpp \
	nsEUCTWProber.cpp \
	nsEscCharsetProber.cpp \
	nsEscSM.cpp \
	nsGB2312Prober.cpp \
	nsHebrewProber.cpp \
	nsLatin1Prober.cpp \
	nsMBCSGroupProber.cpp \
	nsMBCSSM.cpp \
	nsSBCSGroupProber.cpp \
	nsSBCharSetProber.cpp \
	nsSJISProber.cpp \
	nsUTF8Prober.cpp \
	nsUniversalDetector.cpp

XIBS = \
	AdvancedPrefs.xib \
	BundlePrefs.xib \
	CommandOutputWindow.xib \
	CompletionWindow.xib \
	EditPrefs.xib \
	GeneralPrefs.xib \
	MainMenu.xib \
	MarkInspector.xib \
	PreferenceWindow.xib \
	ThemePrefs.xib \
	ViDocument.xib \
	ViDocumentWindow.xib \
	WaitProgress.xib

NU = \
	app/ex.nu \
	app/keys.nu \
	app/vico.nu

IMAGES = \
	Images/AliasBadgeIcon.icns \
	Images/TabClose_Front.tif \
	Images/TabClose_Front_Pressed.tif \
	Images/TabClose_Front_Rollover.tif \
	Images/TabCloseModified_Front.png \
	Images/TabCloseModified_Front_Pressed.png \
	Images/TabCloseModified_Front_Rollover.png \
	Images/TabNewMetal.png \
	Images/TabNewMetalPressed.png \
	Images/TabNewMetalRollover.png \
	Images/actionbarbg.png \
	Images/actionmenu.png \
	Images/add.png \
	Images/bookmark.png \
	Images/class.png \
	Images/define.png \
	Images/function.png \
	Images/header.png \
	Images/module.png \
	Images/overflowImage.tiff \
	Images/overflowImagePressed.tif \
	Images/pi.png \
	Images/resizehandle.png \
	Images/tag.png \
	vico.icns

RESOURCES = \
	Support \
	Themes \
	Bundles \
	$(IMAGES) \
	app/symbol-icons.plist \
	$(NU) \
	par/par.doc \
	Credits.txt

TOOL_OBJC_SRCS = \
	vico.m \
	$(JSON_OBJC_SRCS)

PAR_C_SRCS = \
	buffer.c \
	charset.c \
	errmsg.c \
	par.c \
	reformat.c

CC = clang
CXX = clang++
IBTOOL = /Developer/usr/bin/ibtool

# warning flags
CFLAGS	+= -Wreturn-type \
	   -Wparentheses \
	   -Wswitch \
	   -Wno-unused-parameter \
	   -Wunused-variable \
	   -Wunused-value \
	   -Wshorten-64-to-32
CFLAGS	+= -Wall

REPO_VERSION := $(shell MACOSX_DEPLOYMENT_TARGET="" hg identify -n .)

ifeq ($(CONFIGURATION),DEBUG)
SHORT_VERSION = r$(REPO_VERSION)
CFLAGS = -O0 -DDEBUG_BUILD=1 -gdwarf-2
ARCH_CFLAGS = -arch x86_64
else
CFLAGS = -Os -DRELEASE_BUILD=1
SHORT_VERSION = $(shell cat version.h)
ARCH_CFLAGS = -arch x86_64 -arch i386
endif

SDK = /Developer/SDKs/MacOSX10.7.sdk

ARCH_CFLAGS += -isysroot $(SDK) -mmacosx-version-min=10.6 -fasm-blocks -fobjc-gc-only
CFLAGS	+= $(ARCH_CFLAGS)
LDFLAGS	+= $(ARCH_CFLAGS)

OBJCPPFLAGS = -include-pch $(OBJDIR)/Vico-prefix.objc.pth
OBJCXXPPFLAGS = -include-pch $(OBJDIR)/Vico-prefix.objcxx.pth
CPPFLAGS = -Iapp -Ijson -Ioniguruma -Iuniversalchardet -F.

#OBJCPPFLAGS	+= "-DIBOutlet=__attribute__((iboutlet))" \
#		   "-DIBOutletCollection(ClassName)=__attribute__((iboutletcollection(ClassName)))" \
#		   "-DIBAction=void)__attribute__((ibaction)"

LDFLAGS	+= -F.

TOOL_LDLIBS = -framework ApplicationServices -framework Foundation
APP_LDLIBS = -lcrypto -lresolv -lffi -framework Carbon -framework WebKit -framework Cocoa -framework Nu
PAR_LDLIBS =

# paths
BUILDDIR=./build/$(CONFIGURATION)
OBJDIR=$(BUILDDIR)/obj
DEPDIR=$(BUILDDIR)/dep
APPDIR=$(BUILDDIR)/Vico.app
BINDIR=$(APPDIR)/Contents/MacOS
RESDIR=$(APPDIR)/Contents/Resources
FWDIR=$(APPDIR)/Contents/Frameworks
INFOPLIST=$(APPDIR)/Contents/Info.plist
NIBDIR=$(RESDIR)/en.lproj
 
# object files
OBJC_OBJS = $(addprefix $(OBJDIR)/,$(OBJC_SRCS:.m=.o))
OBJCXX_OBJS = $(addprefix $(OBJDIR)/,$(OBJCXX_SRCS:.mm=.o))
C_OBJS = $(addprefix $(OBJDIR)/,$(ALL_C_SRCS:.c=.o))
CXX_OBJS = $(addprefix $(OBJDIR)/,$(CXX_SRCS:.cpp=.o))
OBJS = $(OBJC_OBJS) $(OBJCXX_OBJS) $(C_OBJS) $(CXX_OBJS)
TOOL_OBJC_OBJS = $(addprefix $(OBJDIR)/,$(TOOL_OBJC_SRCS:.m=.o))
TOOL_OBJS = $(TOOL_OBJC_OBJS)
PAR_C_OBJS = $(addprefix $(OBJDIR)/,$(PAR_C_SRCS:.c=.o))
PAR_OBJS = $(PAR_C_OBJS)
NIBS = $(addprefix $(NIBDIR)/,$(XIBS:.xib=.nib))

DEPS = -MMD -MT $@ -MF $(addsuffix .d,$(basename $@))

$(OBJDIR)/%.o: %.m
	$(CC) $(CFLAGS) $(OBJCPPFLAGS) $(CPPFLAGS) $(DEPS) $< -c -o $@
$(OBJDIR)/%.o: %.mm
	$(CXX) $(CFLAGS) $(OBJCXXPPFLAGS) $(CPPFLAGS) $(DEPS) $< -c -o $@
$(OBJDIR)/%.o: %.c
	$(CC) $(CFLAGS) $(CPPFLAGS) $(DEPS) $< -c -o $@
$(OBJDIR)/%.o: %.cpp
	$(CXX) $(CFLAGS) $(CPPFLAGS) $(DEPS) $< -c -o $@
$(NIBDIR)/%.nib: %.xib
	mkdir -p $(NIBDIR)
	$(IBTOOL) --errors --warnings --notices --output-format human-readable-text --compile $@ $< --sdk $(SDK)

.PHONY: app
app: $(BINDIR)/Vico $(NIBS) $(BINDIR)/vicotool $(BINDIR)/par
	cp -f app/Vico-Info.plist $(INFOPLIST)
	rsync -a --delete --exclude ".git" $(RESOURCES) $(RESDIR)
	# find $(RESDIR)/Bundles \( -iname "*.plist" -or -iname "*.tmCommand" -or -iname "*.tmSnippet" -or -iname "*.tmPreferences" \) -exec /usr/bin/plutil -convert binary1 "{}" \;
	mkdir -p $(FWDIR)
	rsync -a --delete --exclude ".git" Nu.framework $(FWDIR)
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(REPO_VERSION)" $(INFOPLIST)
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(SHORT_VERSION)" $(INFOPLIST)

$(OBJC_OBJS): $(OBJDIR)/Vico-prefix.objc.pth
$(OBJCXX_SRCS): $(OBJDIR)/Vico-prefix.objcxx.pth

$(OBJDIR)/Vico-prefix.objc.pth: app/Vico-prefix.pch
	mkdir -p $(OBJDIR)
	$(CC) -x objective-c-header $(ARCH_CFLAGS) $< -o $@

$(OBJDIR)/Vico-prefix.objcxx.pth: app/Vico-prefix.pch
	mkdir -p $(OBJDIR)
	$(CC) -x objective-c++-header $(ARCH_CFLAGS) $< -o $@

$(OBJDIR)/lemon: lemon.o
	$(CC) $(LDFLAGS) $^ -o $@

app/scope_selector.c: scope_selector.lemon $(OBJDIR)/lemon
	LEMPAR=lemon/lempar.c $(OBJDIR)/lemon -s $<

$(BINDIR)/Vico: $(OBJS)
	mkdir -p $(BINDIR)
	$(CXX) $(LDFLAGS) $(LDLIBS) $(APP_LDLIBS) $^ -o $@
	install_name_tool -change Nu.framework/Versions/A/Nu \
	    @executable_path/../Frameworks/Nu.framework/Versions/A/Nu \
	    $(BINDIR)/Vico

$(BINDIR)/vicotool: $(TOOL_OBJS)
	mkdir -p $(BINDIR)
	$(CC) $(LDFLAGS) $(TOOL_LDLIBS) $^ -o $@

$(BINDIR)/par: $(PAR_OBJS)
	mkdir -p $(BINDIR)
	$(CC) $(LDFLAGS) $(PAR_LDLIBS) $^ -o $@

# include automatic dependencies...
-include $(OBJS:.o=.d)

run: app
	$(BINDIR)/Vico $(HOME)/src/vico

leaks: app
	# MallocStackLoggingNoCompact=YES
	MallocStackLogging=YES \
	  $(BINDIR)/Vico $(HOME)/src/vico

zombie: app
	# MallocStackLoggingNoCompact=YES
	NSZombieEnabled=YES NSDebugEnabled=YES \
	  $(BINDIR)/Vico $(HOME)/src/vico

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
	rm -rf doc/html
	appledoc --project-name "Vico API" \
		--project-company "Martin Hedenfalk" \
		--company-id se.bzero \
		--no-repeat-first-par \
		--output doc \
		--create-html \
		--no-create-docset \
		--merge-categories \
		app/ViRegisterManager.h \
		app/ViScope.h \
		app/ViWindowController.h \
		app/ViTabController.h \
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
		app/NSString-additions.h \
		app/ExParser.h \
		app/ExCommand.h \
		app/ExMap.h

syncapi: api
	rsync -av --delete  doc/html/ www:/var/www/feedback.vicoapp.com/public/api

release: test
	./release.sh

TARDATE := $(shell date +%Y%m%d%H)
TARBALL  = vico-hg-$(TARDATE).tar.gz
tarball:
	tar zcvf $(TARBALL) .hg && \
	gpg -r martin -e $(TARBALL) && \
	rm $(TARBALL)

upload_tarball: tarball
	scp $(TARBALL).gpg mx.bzero.se:

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
	rm -rf $(OBJDIR) $(APPDIR)

distclean:
	rm -rf $(BUILDDIR)

.PHONY: build help clean
