/*
 * Copyright (c) 2008-2012 Martin Hedenfalk <martin@vicoapp.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <sys/time.h>

#import "Vico-Swift.h"

#import "ViDocument.h"
#import "ViDocumentView.h"
#import "ViBundleStore.h"
#import "ViCharsetDetector.h"
#import "ViTextStorage.h"
#import "NSString-additions.h"
#import "NSString-scopeSelector.h"
#import "NSArray-patterns.h"
#import "ViRulerView.h"
#import "ViScope.h"
#import "ViSymbolTransform.h"
#import "ViThemeStore.h"
#import "SFTPConnection.h" /* Only for SSH2_FX_NO_SUCH_FILE constant. */
#import "ViError.h"
#import "NSObject+SPInvocationGrabbing.h"
#import "ViAppController.h"
#import "ViPreferencePaneEdit.h"
#import "ViEventManager.h"
#import "ViDocumentController.h"
#import "NSURL-additions.h"
#import "ViTextView.h"
#import "ViFold.h"

BOOL __makeNewWindowInsteadOfTab = NO;

@interface ViDocument (internal)
- (void)highlightEverything;
- (void)setWrapping:(BOOL)flag;
- (void)enableLineNumbers:(BOOL)flag relative:(BOOL)relative forScrollView:(NSScrollView *)aScrollView;
- (void)enableLineNumbers:(BOOL)flag relative:(BOOL)relative;
- (void)setTypingAttributes;
- (NSString *)suggestEncoding:(NSStringEncoding *)outEncoding forData:(NSData *)data;
- (BOOL)addData:(NSData *)data;
- (void)invalidateSymbolsInRange:(NSRange)range;
- (void)pushMarks:(NSInteger)delta fromLocation:(NSUInteger)location;
- (void)updateTabSize;
- (void)updateWrapping;
- (void)eachTextView:(void (^)(ViTextView *))callback;
@end

@implementation ViDocument

@synthesize symbols = _symbols;
@synthesize filteredSymbols = _filteredSymbols;
@synthesize symbolScopes = _symbolScopes;
@synthesize symbolTransforms = _symbolTransforms;
@synthesize views = _views;
@synthesize bundle = _bundle;
@synthesize theme = _theme;
@synthesize language = _language;
@synthesize encoding = _encoding;
@synthesize isTemporary = _isTemporary;
@synthesize snippet = _snippet;
@synthesize busy = _busy;
@synthesize loader = _loader;
@synthesize closeCallback = _closeCallback;
@synthesize ignoreChangeCountNotification = _ignoreChangeCountNotification;
@synthesize textStorage = _textStorage;
@synthesize matchingParenRange = _matchingParenRange;
@synthesize hiddenView = _hiddenView;
@synthesize syntaxParser = _syntaxParser;
@synthesize marks = _marks;
@synthesize modified = _modified;
@synthesize localMarks = _localMarks;

+ (BOOL)canConcurrentlyReadDocumentsOfType:(NSString *)typeName
{
	return NO;
}

- (id)init
{
	if ((self = [super init]) != nil) {
		_symbols = [[NSMutableArray alloc] init];
		_views = [[NSMutableSet alloc] init];
		_localMarks = [[ViMarkManager sharedManager] makeStack];
		_localMarks.name = [NSString stringWithFormat:@"Local marks for document %p", self];
		_marks = [[NSMutableSet alloc] init];

		NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
		[userDefaults addObserver:self forKeyPath:@"number" options:0 context:NULL];
		[userDefaults addObserver:self forKeyPath:@"relativenumber" options:0 context:NULL];
		[userDefaults addObserver:self forKeyPath:@"tabstop" options:0 context:NULL];
		[userDefaults addObserver:self forKeyPath:@"fontsize" options:0 context:NULL];
		[userDefaults addObserver:self forKeyPath:@"fontname" options:0 context:NULL];
		[userDefaults addObserver:self forKeyPath:@"linebreak" options:0 context:NULL];
		[userDefaults addObserver:self forKeyPath:@"wrap" options:0 context:NULL];
		[userDefaults addObserver:self forKeyPath:@"list" options:0 context:NULL];
		[userDefaults addObserver:self forKeyPath:@"matchparen" options:0 context:NULL];

		_textStorage = [[ViTextStorage alloc] init];
		[_textStorage setDelegate:self];

		[[NSNotificationCenter defaultCenter] addObserver:self
							 selector:@selector(textStorageDidChangeLines:)
							     name:ViTextStorageChangedLinesNotification
							   object:_textStorage];

		[[NSNotificationCenter defaultCenter] addObserver:self
							 selector:@selector(editPreferenceChanged:)
							     name:ViEditPreferenceChangedNotification
							   object:nil];

		NSString *symbolIconsFile = [[ViAppController supportDirectory] stringByAppendingPathComponent:@"symbol-icons.plist"] ;
		if (![[NSFileManager defaultManager] fileExistsAtPath:symbolIconsFile])
			symbolIconsFile = [[NSBundle mainBundle] pathForResource:@"symbol-icons"
									  ofType:@"plist"];
		_symbolIcons = [[NSDictionary alloc] initWithContentsOfFile:symbolIconsFile];

		[self configureForURL:nil];
		_forcedEncoding = 0;
		_encoding = NSUTF8StringEncoding;

		_theme = [[ViThemeStore defaultStore] defaultTheme];
		[self setTypingAttributes];

		/*
		 * Disable automatic undo groups created in each pass of the run loop.
		 * This duplicates our own undo grouping and makes the document never
		 * regain its un-edited state.
		 */
		[[self undoManager] setGroupsByEvent:NO];

		MEMDEBUG(@"init %@", self);
	}

	DEBUG_INIT();
	return self;
}

DEBUG_FINALIZE();

- (void)dealloc
{
	DEBUG_DEALLOC();

	[[ViEventManager defaultManager] clearFor:self];

	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults removeObserver:self forKeyPath:@"number"];
	[userDefaults removeObserver:self forKeyPath:@"relativenumber"];
	[userDefaults removeObserver:self forKeyPath:@"tabstop"];
	[userDefaults removeObserver:self forKeyPath:@"fontsize"];
	[userDefaults removeObserver:self forKeyPath:@"fontname"];
	[userDefaults removeObserver:self forKeyPath:@"linebreak"];
	[userDefaults removeObserver:self forKeyPath:@"wrap"];
	[userDefaults removeObserver:self forKeyPath:@"list"];
	[userDefaults removeObserver:self forKeyPath:@"matchparen"];

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	for (ViDocumentView *view in _views) {
		MEMDEBUG(@"got remaining view %@", view);
		[_textStorage removeLayoutManager:[(ViTextView *)[view innerView] layoutManager]];
		[view setDocument:nil];
	}
	[_hiddenView setDocument:nil];


}

- (BOOL)dataAppearsBinary:(NSData *)data
{
	NSString *string = nil;
	if (_forcedEncoding)
		string = [[NSString alloc] initWithData:data encoding:_forcedEncoding];
	if (string == nil)
		string = [self suggestEncoding:NULL forData:data];

	return ([string rangeOfString:[NSString stringWithFormat:@"%C", (unichar)0]].location != NSNotFound);
}

- (void)openFailedAlertDidEnd:(NSAlert *)alert
                   returnCode:(NSInteger)returnCode
                  contextInfo:(void *)contextInfo
{
	DEBUG(@"alert is %@", alert);
}

- (void)deferred:(id<ViDeferred>)deferred status:(NSString *)statusMessage
{
	[self message:@"%@", statusMessage];
}

- (BOOL)readFromURL:(NSURL *)absoluteURL
	     ofType:(NSString *)typeName
	      error:(NSError **)outError
{
	[self setSymbols:[NSMutableArray array]];

	[[ViEventManager defaultManager] emit:ViEventWillLoadDocument for:self with:self, absoluteURL, nil];

	DEBUG(@"read from %@", absoluteURL);
	__block BOOL firstChunk = YES;

	void (^dataCallback)(NSData *data) = ^(NSData *data) {
		if (firstChunk && [self dataAppearsBinary:data]) {
			NSAlert *alert = [[NSAlert alloc] init];
			[alert setMessageText:[NSString stringWithFormat:@"%@ appears to be a binary file",
				[absoluteURL lastPathComponent]]];
			[alert addButtonWithTitle:@"Continue"];
			[alert addButtonWithTitle:@"Cancel"];
			[alert setInformativeText:@"Are you sure you want to continue opening the file?"];
			NSUInteger ret = [alert runModal];
			if (ret == NSAlertSecondButtonReturn) {
				DEBUG(@"cancelling deferred %@", _loader);
				[_loader cancel];
				[self setLoader:nil];
				return;
			}
		}

		if (firstChunk)
			[self setString:@""]; /* Make sure document is empty before appending data. */
		[self addData:data];
		firstChunk = NO;

		if ([_loader respondsToSelector:@selector(progress)]) {
			CGFloat progress = [_loader progress];
			if (progress >= 0)
				[self message:@"%.1f%% loaded", progress * 100.0];
		}
	};

	/* If the completion callback is called immediately, we can return an error directly. */
	__block NSError *returnError = nil;

	void (^completionCallback)(NSURL *, NSDictionary *, NSError *error) = ^(NSURL *normalizedURL, NSDictionary *attributes, NSError *error) {
		DEBUG(@"error is %@", error);
		returnError = error;
		[self setBusy:NO];
		[self setLoader:nil];

		if (error) {
			/* If the file doesn't exist, treat it as an untitled file. */
			if ([error isFileNotFoundError]) {
				DEBUG(@"treating non-existent file %@ as untitled file", normalizedURL);
				[self setFileURL:normalizedURL];
				[self message:@"%@: new file", [self title]];
				[[ViEventManager defaultManager] emitDelayed:ViEventDidLoadDocument for:self with:self, nil];
				returnError = nil;
			} else if ([error isOperationCancelledError]) {
				DEBUG(@"cancelled loading of %@", normalizedURL);
				DEBUG(@"self is %p", self);
				DEBUG(@"self is %@", self);
				[self message:@"cancelled loading of %@", normalizedURL];
				[self setFileURL:nil];
				if (_closeCallback)
					_closeCallback(2);
				[self setCloseCallback:nil];
			} else {
				/* Make sure this document has focus, then show an alert sheet. */
				[_windowController displayDocument:self positioned:ViViewPositionDefault];
				[self setFileURL:nil];

				NSAlert *alert = [[NSAlert alloc] init];
				[alert setMessageText:[NSString stringWithFormat:@"Couldn't open %@",
					normalizedURL]];
				[alert addButtonWithTitle:@"OK"];
				[alert setInformativeText:[error localizedDescription]];
				[alert beginSheetModalForWindow:[_windowController window]
						  modalDelegate:self
						 didEndSelector:@selector(openFailedAlertDidEnd:returnCode:contextInfo:)
						    contextInfo:nil];
				if (_closeCallback)
					_closeCallback(3);
				[self setCloseCallback:nil];
			}
		} else {
			DEBUG(@"loaded %@ with attributes %@", normalizedURL, attributes);
			[self setFileModificationDate:[attributes fileModificationDate]];
			[self setIsTemporary:NO];
			[self setFileURL:normalizedURL];
			[self message:@"%@: %lu lines", [self title], [_textStorage lineCount]];

			[[NSNotificationCenter defaultCenter] postNotificationName:ViDocumentLoadedNotification 
									    object:self];
			[self eachTextView:^(ViTextView *tv) {
				[tv documentDidLoad:self];
			}];
			[[ViEventManager defaultManager] emitDelayed:ViEventDidLoadDocument
								 for:self
								with:self, nil];
		}
	};

	[self setFileType:@"Document"];
	[self setFileURL:absoluteURL];
	[self setIsTemporary:YES]; /* Prevents triggering checkDocumentChanged in window controller. */

	[self eachTextView:^(ViTextView *tv) {
		[tv prepareRevertDocument];
	}];

	[self setBusy:YES];
	[self setLoader:[[ViURLManager defaultManager] dataWithContentsOfURL:absoluteURL
								      onData:dataCallback
								onCompletion:completionCallback]];
	DEBUG(@"got deferred loader %@", _loader);
	[_loader setDelegate:self];

	if (outError)
		*outError = returnError;

	return returnError == nil ? YES : NO;
}

- (void)setBusy:(BOOL)value
{
	_busy = value;

	// Also post a mode change notification.
	NSNotification *notification = [NSNotification notificationWithName:ViDocumentBusyChangedNotification object:self];
	[[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostASAP];
}

- (BOOL)isEntireFileLoaded
{
	return (_loader == nil);
}

- (id)initWithContentsOfURL:(NSURL *)absoluteURL
                     ofType:(NSString *)typeName
                      error:(NSError **)outError
{
	DEBUG(@"init with URL %@ of type %@", absoluteURL, typeName);

	if ((self = [self init]) != nil) {
		[self readFromURL:absoluteURL ofType:typeName error:outError];
	}

	return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
		      ofObject:(id)object
			change:(NSDictionary *)change
		       context:(void *)context
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

	if ([keyPath isEqualToString:@"number"])
		[self enableLineNumbers:[userDefaults boolForKey:keyPath] relative:[userDefaults boolForKey:@"relativenumber"]];
	else if ([keyPath isEqualToString:@"relativenumber"]) {
		[self enableLineNumbers:[userDefaults boolForKey:@"number"] relative:[userDefaults boolForKey:keyPath]];
	} else if ([keyPath isEqualToString:@"wrap"])
		[self updateWrapping];
	else if ([keyPath isEqualToString:@"tabstop"]) {
		[self updateTabSize];
	} else if ([keyPath isEqualToString:@"fontsize"] ||
		   [keyPath isEqualToString:@"fontname"] ||
		   [keyPath isEqualToString:@"linebreak"]) {
		[self eachTextView:^(ViTextView *tv) {
			ViLayoutManager *lm = (ViLayoutManager *)[tv layoutManager];
			[lm setAttributesForInvisibles:[_theme invisiblesAttributes]];
			[lm invalidateDisplayForCharacterRange:NSMakeRange(0, [_textStorage length])];
			[tv updateFont];
		}];
		[self setTypingAttributes];
		[self updatePageGuide];
	} else if ([keyPath isEqualToString:@"list"]) {
		[self eachTextView:^(ViTextView *tv) {
			ViLayoutManager *lm = (ViLayoutManager *)[tv layoutManager];
			[lm setShowsInvisibleCharacters:[userDefaults boolForKey:@"list"]];
			[lm invalidateDisplayForCharacterRange:NSMakeRange(0, [_textStorage length])];
		}];
	} else if ([keyPath isEqualToString:@"matchparen"]) {
		if ([userDefaults boolForKey:keyPath])
			[self eachTextView:^(ViTextView *tv) {
				[tv highlightSmartPairAtLocation:[tv caret]];
			}];
		else
			[self setMatchingParenRange:NSMakeRange(NSNotFound, 0)];
	}
}

- (void)editPreferenceChanged:(NSNotification *)notification
{
	[self updateWrapping];
	[self updateTabSize];
	[self setTypingAttributes];
}

#pragma mark -
#pragma mark NSDocument interface

- (BOOL)keepBackupFile
{
	return YES;
}

- (void)showWindows
{
	[super showWindows];
	[_windowController displayDocument:self positioned:ViViewPositionDefault];
}

- (ViWindowController *)windowController
{
	return _windowController;
}

- (void)closeWindowController:(ViWindowController *)aController
{
	[self removeWindowController:aController]; // XXX: does this release aController ?
	if (aController == _windowController) {
		/*
		 * XXX: This is a f*cking disaster!
		 * Find a new default window controller.
		 * Ask each windows' window controller if it contains this document.
		 */
		_windowController = nil;
		for (NSWindow *window in [NSApp windows]) {
			ViWindowController *wincon = [window windowController];
			if (wincon == aController || ![wincon isKindOfClass:[ViWindowController class]])
				continue;
			if ([[wincon documents] containsObject:self]) {
				_windowController = wincon;
				break;
			}
		}
	}
}

- (void)addWindowController:(NSWindowController *)aController
{
	[super addWindowController:aController];

	_windowController = (ViWindowController *)aController;
}

- (void)makeWindowControllers
{
	ViWindowController *winCon = nil;
	if (__makeNewWindowInsteadOfTab) {
		winCon = [[ViWindowController alloc] init];
		__makeNewWindowInsteadOfTab = NO;
	} else {
		winCon = [ViWindowController currentWindowController];
		if (winCon == nil)
			winCon = [[ViWindowController alloc] init];
	}

	[self addWindowController:winCon];
	[winCon addNewTab:self];
}

- (void)eachTextView:(void (^)(ViTextView *))callback
{
	for (ViDocumentView *docView in _views) {
		NSView *view = [docView innerView];
		if ([view isKindOfClass:[ViTextView class]])
			callback((ViTextView *)view);
	}
	if (_hiddenView) {
		NSView *view = [_hiddenView innerView];
		if ([view isKindOfClass:[ViTextView class]])
			callback((ViTextView *)view);
	}
}

- (void)removeView:(ViDocumentView *)aDocumentView
{
	if ([_views count] == 1) {
		DEBUG(@"set hidden view to %@", aDocumentView);
		[self setHiddenView:aDocumentView];
	} else {
		[_textStorage removeLayoutManager:[[aDocumentView textView] layoutManager]];
		[aDocumentView setDocument:nil];
	}
	DEBUG(@"remove view %@", aDocumentView);
	[_views removeObject:aDocumentView];
}

- (void)addView:(ViDocumentView *)docView
{
	if (docView && ![_views containsObject:docView]) {
		[_views addObject:docView];
		[self setHiddenView:nil];
	}
}

- (ViTextView *)text
{
	if (_scriptView == nil) {
		ViLayoutManager *layoutManager = [[ViLayoutManager alloc] init];
		[_textStorage addLayoutManager:layoutManager];

		[layoutManager setDelegate:self];

		NSRect frame = NSMakeRect(0, 0, 10, 10);
		NSTextContainer *container = [[NSTextContainer alloc] initWithContainerSize:frame.size];
		[layoutManager addTextContainer:container];

		_scriptView = [[ViTextView alloc] initWithFrame:frame textContainer:container];
		[_scriptView initWithDocument:self viParser:[ViParser parserWithDefaultMap:[ViMap normalMap]]];

		[[ViEventManager defaultManager] emit:ViEventDidMakeView for:self with:self, [NSNull null], _scriptView, nil];
	}
	return _scriptView;
}

- (ViDocumentView *)makeViewWithParser:(ViParser *)aParser
{
	if (_hiddenView) {
		DEBUG(@"returning hidden view %@", _hiddenView);
		_hiddenView.textView.keyManager.parser = aParser;
		return _hiddenView;
	}

	ViDocumentView *documentView = [[ViDocumentView alloc] initWithDocument:self];
	if (documentView == nil)
		return nil;
	[self addView:documentView];

	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

	/*
	 * Recreate the text system hierarchy with our text storage and layout manager.
	 */
	ViLayoutManager *layoutManager = [[ViLayoutManager alloc] init];
	[_textStorage addLayoutManager:layoutManager];
	[layoutManager setDelegate:self];
	[layoutManager setShowsInvisibleCharacters:[userDefaults boolForKey:@"list"]];
	[layoutManager setShowsControlCharacters:YES];
	[layoutManager setAttributesForInvisibles:[_theme invisiblesAttributes]];

	NSView *innerView = [documentView innerView];
	NSRect frame = [innerView frame];
	NSTextContainer *container = [[NSTextContainer alloc] initWithContainerSize:frame.size];
	[layoutManager addTextContainer:container];
	[container setWidthTracksTextView:YES];
	[container setHeightTracksTextView:YES];

	ViTextView *textView = [[ViTextView alloc] initWithFrame:frame textContainer:container];
	[documentView replaceTextView:textView];

	[textView initWithDocument:self viParser:aParser];

	[self enableLineNumbers:[userDefaults boolForKey:@"number"]
	               relative:[userDefaults boolForKey:@"relativenumber"]
	          forScrollView:[textView enclosingScrollView]];
	[self updatePageGuide];
	[textView setWrapping:_wrap duringInit:YES];

	[[ViEventManager defaultManager] emit:ViEventDidMakeView for:self with:self, documentView, textView, nil];

	return documentView;
}

- (ViDocumentView *)makeView
{
	return [self makeViewWithParser:[_windowController parser]];
}

- (ViDocumentView *)cloneView:(ViDocumentView *)oldView
{
	ViDocumentView *newView = [self makeView];
	[[newView textView] setCaret:[[oldView textView] caret]];
	return newView;
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
	NSStringEncoding enc = _encoding;
	if (_retrySaveOperation)
		enc = NSUTF8StringEncoding;
	DEBUG(@"using encoding %@", [NSString localizedNameOfStringEncoding:enc]);
	NSData *data = [[_textStorage string] dataUsingEncoding:enc];
	if (data == nil && outError)
		*outError = [ViError errorWithFormat:@"The %@ encoding is not appropriate.",
		    [NSString localizedNameOfStringEncoding:_encoding]];
	return data;
}

- (BOOL)attemptRecoveryFromError:(NSError *)error
                     optionIndex:(NSUInteger)recoveryOptionIndex
{
	if (recoveryOptionIndex == 1) {
		_retrySaveOperation = YES;
		return YES;
	}

	return NO;
}

- (void)didPresentErrorWithRecovery:(BOOL)didRecover
                        contextInfo:(void *)contextInfo
{
	DEBUG(@"didRecover = %s", didRecover ? "YES" : "NO");
}

- (void)continueSavingAfterError:(NSError *)error
{
	BOOL didSave = NO;
	if (error == nil) {
		didSave = [self saveToURL:[self fileURL]
				   ofType:[self fileType]
			 forSaveOperation:NSSaveOperation
				    error:&error];
	}

	if (error && !([[error domain] isEqualToString:NSCocoaErrorDomain] && [error code] == NSUserCancelledError))
		[NSApp presentError:error];

	DEBUG(@"calling delegate %@ with selector %@", _didSaveDelegate, NSStringFromSelector(_didSaveSelector));
	if (_didSaveDelegate && _didSaveSelector) {
		ViDocument __unsafe_unretained *thisDocument = self;

		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
		    [_didSaveDelegate methodSignatureForSelector:_didSaveSelector]];
		[invocation setSelector:_didSaveSelector];
		[invocation setArgument:&thisDocument atIndex:2];
		[invocation setArgument:&didSave atIndex:3];
		[invocation setArgument:&_didSaveContext atIndex:4];
		[invocation invokeWithTarget:_didSaveDelegate];
	}

	_didSaveDelegate = nil;
	_didSaveSelector = nil;
	_didSaveContext = NULL;
}

- (void)fileModifiedAlertDidEnd:(NSAlert *)alert
		     returnCode:(NSInteger)returnCode
		    contextInfo:(void *)contextInfo
{
	NSError *error = nil;
	if (returnCode == NSAlertFirstButtonReturn)
		error = [ViError operationCancelled];
	[self continueSavingAfterError:error];
}

- (BOOL)shouldRunSavePanelWithAccessoryView
{
	/* Do not show the "File Formats" accessory view. */
	return NO;
}

- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel
{
	[savePanel setDirectoryURL:[[self windowController] baseURL]];
	return YES;
}

- (void)saveDocumentWithDelegate:(id)delegate
		 didSaveSelector:(SEL)selector
		     contextInfo:(void *)contextInfo
{
	if ([self fileURL]) {
		__block NSError *error = nil;
		__block NSDictionary *attributes = nil;
		ViURLManager *urlman = [ViURLManager defaultManager];
		id<ViDeferred> deferred = [urlman attributesOfItemAtURL:[self fileURL]
							   onCompletion:^(NSURL *_url, NSDictionary *_attrs, NSError *_err) {
			if (_err && ![_err isFileNotFoundError]) {
				error = _err;
			} else {
				attributes = _attrs;
			}
		}];

		if ([deferred respondsToSelector:@selector(waitInWindow:message:)])
			[deferred waitInWindow:[_windowController window]
				       message:[NSString stringWithFormat:@"Saving %@...",
					       [[self fileURL] lastPathComponent]]];
		else
			[deferred wait];
		DEBUG(@"done getting attributes of %@, error is %@", [self fileURL], error);

		_didSaveDelegate = delegate;
		_didSaveSelector = selector;
		_didSaveContext = contextInfo;

		if (!error && attributes && ![[attributes fileType] isEqualToString:NSFileTypeRegular])
			error = [ViError errorWithFormat:@"%@ is not a regular file.", [[self fileURL] lastPathComponent]];

		if (!error && attributes && ![[attributes fileModificationDate] isEqual:[self fileModificationDate]]) {
			NSAlert *alert = [[NSAlert alloc] init];
			[alert setMessageText:@"This document’s file has been changed by another application since you opened or saved it."];
			[alert addButtonWithTitle:@"Don't Save"];
			[alert addButtonWithTitle:@"Save"];
			[alert setInformativeText:@"The changes made by the other application will be lost if you save. Save anyway?"];
			[alert beginSheetModalForWindow:[_windowController window]
					  modalDelegate:self
					 didEndSelector:@selector(fileModifiedAlertDidEnd:returnCode:contextInfo:)
					    contextInfo:nil];
		} else {
			[self continueSavingAfterError:error];
		}
	} else
		[super saveDocumentWithDelegate:delegate
				didSaveSelector:selector
				    contextInfo:contextInfo];
}

- (BOOL)writeSafelyToURL:(NSURL *)url
		  ofType:(NSString *)typeName
	forSaveOperation:(NSSaveOperationType)saveOperation
		   error:(NSError **)outError
{
	DEBUG(@"write to %@", url);
	_retrySaveOperation = NO;

	if (![[_textStorage string] canBeConvertedToEncoding:_encoding]) {
		NSString *reason = [NSString stringWithFormat:
		    @"The %@ encoding is not appropriate.",
		    [NSString localizedNameOfStringEncoding:_encoding]];
		NSString *suggestion = @"Consider saving the file as UTF-8 instead.";
		NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
		   reason, NSLocalizedFailureReasonErrorKey,
		   suggestion, NSLocalizedRecoverySuggestionErrorKey,
		   self, NSRecoveryAttempterErrorKey,
		   [NSArray arrayWithObjects:@"OK", @"Save as UTF-8", nil], NSLocalizedRecoveryOptionsErrorKey,
		   nil];
		NSError *err = [NSError errorWithDomain:ViErrorDomain code:1 userInfo:userInfo];
		if (![self presentError:err]) {
			if (outError)	/* Suppress the callers error. */
				*outError = [ViError operationCancelled];
			return NO;
		}

		if (saveOperation == NSSaveOperation || saveOperation == NSSaveAsOperation)
			_encoding = NSUTF8StringEncoding;
	}

	NSData *data = [self dataOfType:typeName error:outError];
	if (data == nil)
		/* Should not happen. We've already checked for encoding problems. */
		return NO;

	__block NSError *returnError = nil;
	ViURLManager *urlman = [ViURLManager defaultManager];
	id<ViDeferred> deferred = [urlman writeDataSafely:data
						    toURL:url
					     onCompletion:^(NSURL *normalizedURL, NSDictionary *attributes, NSError *error) {
		if (error) {
			returnError = error;
		} else {
			[self message:@"%@: wrote %lu byte", normalizedURL, [data length]];
			if (saveOperation == NSSaveOperation || saveOperation == NSSaveAsOperation) {
				DEBUG(@"setting normalized URL %@", normalizedURL);
				[self setFileURL:normalizedURL];
				[self setFileModificationDate:[attributes fileModificationDate]];
				[self updateChangeCount:NSChangeCleared];
				if (saveOperation == NSSaveOperation)
					[[ViEventManager defaultManager] emitDelayed:ViEventDidSaveDocument for:self with:self, nil];
				else if (saveOperation == NSSaveAsOperation)
					[[ViEventManager defaultManager] emit:ViEventDidSaveAsDocument for:self with:self, normalizedURL, nil];
			}

			if (_isTemporary)
				[[ViURLManager defaultManager] notifyChangedDirectoryAtURL:[normalizedURL URLByDeletingLastPathComponent]];
			_isTemporary = NO;
		}
	}];

	if ([deferred respondsToSelector:@selector(waitInWindow:message:)])
		[deferred waitInWindow:[_windowController window]
			       message:[NSString stringWithFormat:@"Saving %@...",
				       [url lastPathComponent]]];
	else
		[deferred wait];
	DEBUG(@"done saving file, error is %@", returnError);

	if (returnError) {
		if (outError)
			*outError = returnError;
		return NO;
	}

	return YES;
}

- (BOOL)saveToURL:(NSURL *)absoluteURL
           ofType:(NSString *)typeName
 forSaveOperation:(NSSaveOperationType)saveOperation
            error:(NSError **)outError
{
	DEBUG(@"saving %@ to %@", self, absoluteURL);

	if (saveOperation == NSSaveOperation)
		[[ViEventManager defaultManager] emit:ViEventWillSaveDocument for:self with:self, nil];
	else if (saveOperation == NSSaveAsOperation)
		[[ViEventManager defaultManager] emit:ViEventWillSaveAsDocument for:self with:self, absoluteURL, nil];
	[self endUndoGroup];

	if ([self writeSafelyToURL:absoluteURL
			    ofType:typeName
		  forSaveOperation:saveOperation
			     error:outError]) {
		_ignoreChangeCountNotification = YES;
		[[self nextRunloop] setIgnoreChangeCountNotification:NO];
		return YES;
	}
	return NO;
}

- (NSString *)suggestEncoding:(NSStringEncoding *)outEncoding forData:(NSData *)data
{
	NSString *string = nil;
	NSStringEncoding enc = 0;
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

	/* Check for a user-overridden encoding in preferences. */
	NSDictionary *encodingOverride = [userDefaults dictionaryForKey:@"encodingOverride"];
	NSNumber *savedEncoding = [encodingOverride objectForKey:[[self fileURL] absoluteString]];
	if (savedEncoding) {
		enc = [savedEncoding unsignedIntegerValue];
		string = [[NSString alloc] initWithData:data encoding:enc];
	}

	if (string == nil) {
		/* Try to auto-detect the encoding. */
		enc = [[ViCharsetDetector defaultDetector] encodingForData:data];
		if (enc == 0)
			/* Try UTF-8 if auto-detecting fails. */
			enc = NSUTF8StringEncoding;
		string = [[NSString alloc] initWithData:data encoding:enc];
		if (string == nil) {
			/* If all else fails, use iso-8859-1. */
			enc = NSISOLatin1StringEncoding;
			string = [[NSString alloc] initWithData:data encoding:enc];
		}
	}

	if (outEncoding)
		*outEncoding = enc;

	return string;
}

- (BOOL)addData:(NSData *)data
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	NSString *aString = nil;
	if (_forcedEncoding != 0) {
		aString = [[NSString alloc] initWithData:data encoding:_forcedEncoding];
		if (aString == nil) {
			NSString *description = [NSString stringWithFormat:
			    @"The file can't be interpreted in %@ encoding.",
			    [NSString localizedNameOfStringEncoding:_forcedEncoding]];
			NSString *suggestion = [NSString stringWithFormat:@"Keeping the %@ encoding.",
			    [NSString localizedNameOfStringEncoding:_encoding]];
			NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
			    description, NSLocalizedDescriptionKey,
			    suggestion, NSLocalizedRecoverySuggestionErrorKey,
			    nil];
			NSError *err = [NSError errorWithDomain:ViErrorDomain code:2 userInfo:userInfo];
			[self presentError:err];
			aString = [[NSString alloc] initWithData:data encoding:_encoding];
		} else {
			_encoding = _forcedEncoding;

			/* Save the user-overridden encoding in preferences. */
			NSMutableDictionary *encodingOverride = [NSMutableDictionary dictionaryWithDictionary:
			    [userDefaults dictionaryForKey:@"encodingOverride"]];
			[encodingOverride setObject:[NSNumber numberWithUnsignedInteger:_encoding]
			                     forKey:[[self fileURL] absoluteString]];
			[userDefaults setObject:encodingOverride
			                 forKey:@"encodingOverride"];
		}
		_forcedEncoding = 0;
	} else
		aString = [self suggestEncoding:&_encoding forData:data];

	NSUInteger len = [_textStorage length];
	if (len == 0)
		[self setString:aString];
	else {
		[_textStorage replaceCharactersInRange:NSMakeRange(len, 0) withString:aString];
		NSRange r = NSMakeRange(len, [aString length]);
		[_textStorage setAttributes:[self typingAttributes] range:r];
	}

	return YES;
}

- (void)setString:(NSString *)aString
{
	/*
	 * Disable the processing in textStorageDidProcessEditing,
	 * otherwise we'll parse the document multiple times.
	 */
	_ignoreEditing = YES;
	[[_textStorage mutableString] setString:aString ?: @""];
	[_textStorage setAttributes:[self typingAttributes]
	                            range:NSMakeRange(0, [aString length])];
	/* Force incremental syntax parsing. */
	[self setLanguage:nil];
	[self configureSyntax];
}

- (void)setData:(NSData *)data
{
	[self setString:@""];
	[self addData:data];
}

- (void)setEncoding:(id)sender
{
	_forcedEncoding = [[sender representedObject] unsignedIntegerValue];
	[self revertDocumentToSaved:nil];
}

- (void)setDisplayName:(NSString *)displayNameOrNil
{
	[super setDisplayName:displayNameOrNil];
	[_windowController synchronizeWindowTitleWithDocumentName];
}

- (NSString *)title
{
	NSString *displayName = [self displayName];
	if ([displayName length] == 0) {
		displayName = [[self fileURL] lastPathComponent];
		if ([displayName length] == 0)
			displayName = [[self fileURL] host];
	}

	return displayName;
}

- (void)updateChangeCount:(NSDocumentChangeType)changeType
{
	DEBUG(@"called from %@", [NSThread callStackSymbols]);
	if (_ignoreChangeCountNotification) {
		DEBUG(@"%s", "ignoring change count notification");
		_ignoreChangeCountNotification = NO;
		return;
	}
	BOOL edited = [self isDocumentEdited];
	[super updateChangeCount:changeType];
	[self setModified:[self isDocumentEdited]];
	if (edited != _modified)
		[[NSNotificationCenter defaultCenter] postNotificationName:ViDocumentEditedChangedNotification
								    object:self
								  userInfo:nil];
}

- (void)setFileURL:(NSURL *)absoluteURL
{
	DEBUG(@"set url %@ (was %@)", absoluteURL, [self fileURL]);
	if ([absoluteURL isEqual:[self fileURL]])
		return;

	[[ViDocumentController sharedDocumentController] updateURL:absoluteURL ofDocument:self];

	[[ViEventManager defaultManager] emit:ViEventWillChangeURL for:self with:self, absoluteURL, nil];
	[self willChangeValueForKey:@"title"];
	[super setFileURL:absoluteURL];
	[self didChangeValueForKey:@"title"];
	[self configureSyntax];

	_localMarks.name = [NSString stringWithFormat:@"Local marks in %@", [self title]];

	[[ViEventManager defaultManager] emit:ViEventDidChangeURL for:self with:self, absoluteURL, nil];
}

- (void)closeAndWindow:(BOOL)canCloseWindow
{
	if (_closed) {
		DEBUG(@"already closed document %@", self);
		return;
	}
	int code = 1; /* not saved */

	[[ViEventManager defaultManager] emit:ViEventWillCloseDocument for:self with:self, nil];

	DEBUG(@"closing, w/window: %s", canCloseWindow ? "YES" : "NO");
	if (_loader) {
		DEBUG(@"cancelling load callback %@", _loader);
		[_loader cancel];
		[self setLoader:nil];
		code = 2; /* not loaded */
	} else if (![self isDocumentEdited])
		code = 0; /* saved */

	DEBUG(@"calling close callback %p", _closeCallback);
	if (_closeCallback)
		_closeCallback(code);
	[self setCloseCallback:nil];

	_closed = YES;

	BOOL didCloseWindowController = YES;
	while (didCloseWindowController) {
		didCloseWindowController = NO;
		for (NSWindow *window in [NSApp windows]) {
			ViWindowController *wincon = [window windowController];
			if (![wincon isKindOfClass:[ViWindowController class]])
				continue;
			if ([[wincon documents] containsObject:self]) {
				[wincon didCloseDocument:self andWindow:canCloseWindow];
				didCloseWindowController = YES;
				break;
			}
		}
	}

	if (_hiddenView) {
		[_textStorage removeLayoutManager:[[_hiddenView textView] layoutManager]];
		[_hiddenView setDocument:nil];
	}

	[_localMarks clear];
	[[ViMarkManager sharedManager] removeStack:_localMarks];

	// on :bwipeout :
	// while ([_symbols count] > 0) {
	// 	ViMark *sym = [_symbols objectAtIndex:0];
	// 	[_symbols removeObjectAtIndex:0];
	// 	[sym remove];
	// }

	[super close];
	[[ViEventManager defaultManager] emit:ViEventDidCloseDocument for:self with:self, nil];

        if ([self isDocumentEdited])
		[[NSNotificationCenter defaultCenter] postNotificationName:ViDocumentEditedChangedNotification
								    object:self
								  userInfo:nil];
}

- (void)close
{
	[self closeAndWindow:YES];
}

- (void)shouldCloseWindowController:(NSWindowController *)aWindowController
			   delegate:(id)delegate
		shouldCloseSelector:(SEL)shouldCloseSelector
			contextInfo:(void *)contextInfo
{
	DEBUG(@"should close window controller %@?", aWindowController);

	/*
	 * Invoke the selector with an unconditional NO flag.
	 * Instead we trigger the window to close, which checks all
	 * documents in the window.
	 */
	BOOL flag = NO;
	ViDocument __unsafe_unretained *thisDocument = self;

	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[delegate methodSignatureForSelector:shouldCloseSelector]];
	[invocation setSelector:shouldCloseSelector];
	[invocation setArgument:&thisDocument atIndex:2];
	[invocation setArgument:&flag atIndex:3];
	[invocation setArgument:&contextInfo atIndex:4];
	[invocation invokeWithTarget:delegate];

	/* This also closes the window if all documents get closed.
	 * See -documentController:didCloseAll:contextInfo:.
	 */
	[(ViWindowController *)aWindowController windowShouldClose:[aWindowController window]];
}

#pragma mark -

- (void)endUndoGroup
{
	if (_hasUndoGroup) {
		DEBUG(@"%s", "====================> Ending undo-group");
		[[self undoManager] endUndoGrouping];
		_hasUndoGroup = NO;
	}
}

- (void)beginUndoGroup
{
	if (!_hasUndoGroup) {
		DEBUG(@"%s", "====================> Beginning undo-group");
		[[self undoManager] beginUndoGrouping];
		_hasUndoGroup = YES;
	}
}

#pragma mark -
#pragma mark Syntax parsing

- (NSDictionary *)defaultAttributes
{
	return [NSDictionary dictionaryWithObject:[_theme foregroundColor]
					   forKey:NSForegroundColorAttributeName];
}

- (void)layoutManager:(NSLayoutManager *)aLayoutManager
didCompleteLayoutForTextContainer:(NSTextContainer *)aTextContainer
                atEnd:(BOOL)flag
{
	[self eachTextView:^(ViTextView *tv) {
		[tv invalidateCaretRect];
	}];
}

- (void)setMatchingParenRange:(NSRange)range
{
	if (_matchingParenRange.location != NSNotFound)
		[self eachTextView:^(ViTextView *tv) {
			[[tv layoutManager] invalidateDisplayForCharacterRange:_matchingParenRange];
		}];

	_matchingParenRange = range;

	if (_matchingParenRange.location != NSNotFound)
		[self eachTextView:^(ViTextView *tv) {
			[[tv layoutManager] invalidateDisplayForCharacterRange:_matchingParenRange];
		}];
}

- (NSDictionary *)layoutManager:(NSLayoutManager *)layoutManager
   shouldUseTemporaryAttributes:(NSDictionary *)attrs
             forDrawingToScreen:(BOOL)toScreen
               atCharacterIndex:(NSUInteger)charIndex
                 effectiveRange:(NSRangePointer)effectiveCharRange
{
	if (!toScreen)
		return nil;

	NSArray *scopeArray = [_syntaxParser scopeArray];
	if (charIndex >= [scopeArray count]) {
		*effectiveCharRange = NSMakeRange(charIndex, [_textStorage length] - charIndex);
		return [self defaultAttributes];
	}

	ViScope *scope = [scopeArray objectAtIndex:charIndex];
	NSDictionary *attributes = [scope attributes];
	if ([attributes count] == 0) {
		attributes = [_theme attributesForScope:scope inBundle:_bundle];
		if ([attributes count] == 0)
			attributes = [self defaultAttributes];
		[scope setAttributes:attributes];
	}

	NSRange r = [scope range];
	if (r.location < charIndex) {
		r.length -= charIndex - r.location;
		r.location = charIndex;
	}
	*effectiveCharRange = r;

	/*
	 * If there is an active snippet in this range, merge in attributes to
	 * mark the snippet placeholders.
	 */
	NSMutableDictionary *mergedAttributes = nil;
	NSRange sel = _snippet.selectedRange;

	if (NSIntersectionRange(r, sel).length > 0) {
		DEBUG(@"selected snippet range %@", NSStringFromRange(sel));
		if (sel.location > r.location) {
			r.length = sel.location - r.location;
		} else {
			if (mergedAttributes == nil)
				mergedAttributes = [NSMutableDictionary dictionaryWithDictionary:attributes];
			[mergedAttributes setObject:[_theme selectionColor]
					     forKey:NSBackgroundColorAttributeName];
			/*
			 * Adjust *effectiveCharRange if r != sel
			 */
			if (NSMaxRange(sel) < NSMaxRange(r))
				r.length = NSMaxRange(sel) - r.location;
		}
		DEBUG(@"merged %@ with %@ -> %@",
		    NSStringFromRange(sel),
		    NSStringFromRange(*effectiveCharRange),
		    NSStringFromRange(r));
		*effectiveCharRange = r;

		DEBUG(@"merged attributes = %@", mergedAttributes);
	}

	/*
	 * If we're highlighting a matching paren, merge in attributes
	 * to mark the paren.
	 */
	sel = _matchingParenRange;

	if (NSIntersectionRange(r, sel).length > 0) {
		DEBUG(@"matching paren range %@", NSStringFromRange(sel));
		if (sel.location > r.location) {
			r.length = sel.location - r.location;
		} else {
			if (mergedAttributes == nil)
				mergedAttributes = [NSMutableDictionary dictionaryWithDictionary:attributes];
			[mergedAttributes addEntriesFromDictionary:[_theme smartPairMatchAttributes]];
			/*[mergedAttributes setObject:[NSNumber numberWithInteger:NSUnderlinePatternSolid | NSUnderlineStyleDouble]
					     forKey:NSUnderlineStyleAttributeName];
			[mergedAttributes setObject:[_theme selectionColor]
					     forKey:NSBackgroundColorAttributeName];*/
			/*
			 * Adjust *effectiveCharRange if r != sel
			 */
			if (NSMaxRange(sel) < NSMaxRange(r))
				r.length = NSMaxRange(sel) - r.location;
		}
		DEBUG(@"merged %@ with %@ -> %@",
		    NSStringFromRange(sel),
		    NSStringFromRange(*effectiveCharRange),
		    NSStringFromRange(r));
		*effectiveCharRange = r;

		DEBUG(@"merged attributes = %@", mergedAttributes);
	}


	return mergedAttributes ?: attributes;
}

- (void)highlightEverything
{
	/* Invalidate all document views. */
	NSRange r = NSMakeRange(0, [_textStorage length]);
	[self eachTextView:^(ViTextView *tv) {
		[[tv layoutManager] invalidateDisplayForCharacterRange:r];
	}];

	if (_language == nil) {
		[self setSyntaxParser:nil];
		[self willChangeValueForKey:@"symbols"];
		[_symbols removeAllObjects];
		[self didChangeValueForKey:@"symbols"];
		return;
	}

	/* Ditch the old syntax scopes and start with a fresh parser. */
	[self setSyntaxParser:[ViSyntaxParser syntaxParserWithLanguage:_language]];

	NSInteger endLocation = [_textStorage locationForStartOfLine:100];
	if (endLocation == -1)
		endLocation = [_textStorage length];

	[self dispatchSyntaxParserWithRange:NSMakeRange(0, endLocation) restarting:NO];
}

- (void)performSyntaxParsingWithContext:(ViSyntaxContext *)ctx
{
	NSRange range = ctx.range;
	unichar *chars = malloc(range.length * sizeof(unichar));
	DEBUG(@"allocated %u bytes, characters %p, range %@, length %u",
		range.length * sizeof(unichar), chars,
		NSStringFromRange(range), [_textStorage length]);
	[[_textStorage string] getCharacters:chars range:range];

	free(ctx.characters);
	ctx.characters = chars;
	NSUInteger startLine = ctx.lineOffset;

	// unsigned endLine = [_textStorage lineNumberAtLocation:NSMaxRange(range) - 1];
	// INFO(@"parsing line %u -> %u, range %@", startLine, endLine, NSStringFromRange(range));

	[_syntaxParser parseContext:ctx];

	// Invalidate the layout(s).
	if (ctx.restarting) {
		[self eachTextView:^(ViTextView *tv) {
			[[tv layoutManager] invalidateDisplayForCharacterRange:range];
		}];
	}

	[self invalidateSymbolsInRange:range];

	if (ctx.lineOffset > startLine) {
		// INFO(@"line endings have changed at line %u", endLine);

		if (_nextContext && _nextContext != ctx) {
			if (_nextContext.lineOffset < startLine) {
				DEBUG(@"letting previous scheduled parsing from line %u continue",
				    _nextContext.lineOffset);
				return;
			}
			DEBUG(@"cancelling scheduled parsing from line %u (nextContext = %@)",
			    _nextContext.lineOffset, _nextContext);
			[_nextContext setCancelled:YES];
		}

		_nextContext = ctx;

		[self performSelector:@selector(restartSyntaxParsingWithContext:)
		           withObject:ctx
		           afterDelay:0.0025];
	}
}

- (void)dispatchSyntaxParserWithRange:(NSRange)aRange restarting:(BOOL)flag
{
	if (aRange.length == 0)
		return;

	NSUInteger line = [_textStorage lineNumberAtLocation:aRange.location];
	DEBUG(@"dispatching from line %lu", line);
	ViSyntaxContext *ctx = [ViSyntaxContext syntaxContextWithLine:line];
	ctx.range = aRange;
	ctx.restarting = flag;

	[self performSyntaxParsingWithContext:ctx];
}

- (void)restartSyntaxParsingWithContext:(ViSyntaxContext *)context
{
	_nextContext = nil;

	if (context.cancelled || _closed) {
		DEBUG(@"context %@, from line %u, is cancelled", context, context.lineOffset);
		return;
	}

	NSInteger startLocation = [_textStorage locationForStartOfLine:context.lineOffset];
	if (startLocation == -1)
		return;
	NSInteger endLocation = [_textStorage locationForStartOfLine:context.lineOffset + 100];
	if (endLocation == -1)
		endLocation = [_textStorage length];

	context.range = NSMakeRange(startLocation, endLocation - startLocation);
	context.restarting = YES;
	if (context.range.length > 0) {
		DEBUG(@"restarting parse context at line %u, range %@",
		    context.lineOffset, NSStringFromRange(context.range));
		[self performSyntaxParsingWithContext:context];
	}
}

- (void)setLanguageAndRemember:(ViLanguage *)lang
{
	[self setLanguage:lang];
	if ([self fileURL] != nil) {
		NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
		NSMutableDictionary *syntaxOverride = [NSMutableDictionary dictionaryWithDictionary:
			[userDefaults dictionaryForKey:@"syntaxOverride"]];
		[syntaxOverride setObject:lang ? [lang name] : @""
		                   forKey:[[self fileURL] absoluteString]];
		[userDefaults setObject:syntaxOverride forKey:@"syntaxOverride"];
	}
}

- (IBAction)setLanguageAction:(id)sender
{
	ViLanguage *lang = [sender representedObject];
	[self setLanguageAndRemember:lang];
}

- (void)updateWrapping
{
	NSInteger tmp = [[ViPreferencePaneEdit valueForKey:@"wrap" inScope:_language.scope] integerValue];
	if (tmp != _wrap) {
		_wrap = tmp;
		[self setWrapping:_wrap];
	}
}

- (void)updateTabSize
{
	NSInteger tmp = [[ViPreferencePaneEdit valueForKey:@"tabstop" inScope:_language.scope] integerValue];
	if (tmp != _tabSize) {
		_tabSize = tmp;
		[self setTypingAttributes];
	}
}

- (void)setLanguage:(ViLanguage *)lang
{
	if ([_textStorage lineCount] > 10000) {
		[self message:@"Disabling syntax highlighting for large document."];
		if (_language) {
			[[ViEventManager defaultManager] emit:ViEventWillChangeSyntax for:self with:self, [NSNull null], nil];
			_language = nil;
			[self updateTabSize];
			[self updateWrapping];
			[self setTypingAttributes];
			[self highlightEverything];
			[[ViEventManager defaultManager] emit:ViEventDidChangeSyntax for:self with:self, [NSNull null], nil];
		}
		return;
	}

	/* Force compilation. */
	[lang patterns];

	if (lang != _language) {
		[[ViEventManager defaultManager] emit:ViEventWillChangeSyntax for:self with:self, lang ?: [NSNull null], nil];

		_language = lang;

		[self setBundle:_language.bundle];
		[self setSymbolScopes:[[ViBundleStore defaultStore] preferenceItem:@"showInSymbolList"]];
		[self setSymbolTransforms:[[ViBundleStore defaultStore] preferenceItem:@"symbolTransformation"]];
		[self updateTabSize];
		[self updateWrapping];
		[self setTypingAttributes];
		[self highlightEverything];
		[[ViEventManager defaultManager] emit:ViEventDidChangeSyntax for:self with:self, lang ?: [NSNull null], nil];
	}
}

- (void)configureForURL:(NSURL *)aURL
{
	ViBundleStore *langStore = [ViBundleStore defaultStore];
	ViLanguage *newLanguage = nil;

	NSString *firstLine = nil;
	NSUInteger eol;
	[[_textStorage string] getLineStart:NULL
				       end:NULL
			       contentsEnd:&eol
				  forRange:NSMakeRange(0, 0)];
	if (eol > 0)
		firstLine = [[_textStorage string] substringWithRange:NSMakeRange(0, eol)];
	if ([firstLine length] > 0)
		newLanguage = [langStore languageForFirstLine:firstLine];
	if (newLanguage == nil && aURL)
		newLanguage = [langStore languageForFilename:[aURL path]];

	if (newLanguage == nil)
		newLanguage = [langStore defaultLanguage];

	[self setLanguage:newLanguage];
}

- (void)configureSyntax
{
	/* Check if the user has overridden a syntax for this URL. */
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSDictionary *syntaxOverride = [defs dictionaryForKey:@"syntaxOverride"];
	NSString *syntax = [syntaxOverride objectForKey:[[self fileURL] absoluteString]];
	if (syntax) {
		ViLanguage *lang = [[ViBundleStore defaultStore] languageWithScope:syntax];
		if (lang) {
			[self setLanguage:lang];
			return;
		}
	}

	[self configureForURL:[self fileURL]];
}

#pragma mark -
#pragma mark NSTextStorage delegate methods

- (void)textStorageDidChangeLines:(NSNotification *)notification
{
	NSDictionary *userInfo = [notification userInfo];

	NSUInteger lineIndex = [[userInfo objectForKey:@"lineIndex"] unsignedIntegerValue];
	NSUInteger linesRemoved = [[userInfo objectForKey:@"linesRemoved"] unsignedIntegerValue];
	NSUInteger linesAdded = [[userInfo objectForKey:@"linesAdded"] unsignedIntegerValue];

	if (!_ignoreEditing) {
		NSInteger diff = linesAdded - linesRemoved;
		if (diff == 0)
			return;

		if (diff > 0)
			[_syntaxParser pushContinuations:diff fromLineNumber:lineIndex + 1];
		else
			[_syntaxParser pullContinuations:-diff fromLineNumber:lineIndex + 1];
	}
}

- (void)textStorageDidProcessEditing:(NSNotification *)notification
{
	if (([_textStorage editedMask] & NSTextStorageEditedCharacters) != NSTextStorageEditedCharacters)
		return;

	NSRange area = [_textStorage editedRange];
	NSInteger diff = [_textStorage changeInLength];

	DEBUG(@"edited range %@, diff is %li", NSStringFromRange(area), diff);

	if (_ignoreEditing) {
		DEBUG(@"ignoring changes in area %@", NSStringFromRange(area));
		_ignoreEditing = NO;
		return;
	}

	if (_language == nil)
		return;

	/*
	 * Incrementally update the scope array.
	 */
	if (diff > 0)
		[_syntaxParser pushScopes:NSMakeRange(area.location, diff)];
	else if (diff < 0)
		[_syntaxParser pullScopes:NSMakeRange(area.location, -diff)];

	if (diff != 0)
		[self pushMarks:diff fromLocation:area.location];

	// emit (delayed) event to Nu
	[[ViEventManager defaultManager] emitDelayed:ViEventDidModifyDocument for:self with:self,
	    [NSValue valueWithRange:area],
	    [NSNumber numberWithInteger:diff],
	    nil];

	/*
	 * Extend our range along affected line boundaries and re-parse.
	 */
	NSUInteger bol, end, eol;
	[[_textStorage string] getLineStart:&bol end:&end contentsEnd:&eol forRange:area];
	if (eol == area.location) {
		/* Change at EOL, include another line to make sure
		 * we get the line continuations right. */
		[[_textStorage string] getLineStart:NULL
						end:&end
					contentsEnd:NULL
					   forRange:NSMakeRange(end, 0)];
	}
	area.location = bol;
	area.length = end - bol;

	[self dispatchSyntaxParserWithRange:area restarting:NO];
}

#pragma mark -
#pragma mark Line numbers

- (void)enableLineNumbers:(BOOL)flag relative:(BOOL)relative forScrollView:(NSScrollView *)aScrollView
{
	if (flag) {
		ViRulerView *rulerView = [[ViRulerView alloc] initWithScrollView:aScrollView];
		[aScrollView setVerticalRulerView:rulerView];
		[rulerView setRelativeLineNumbers:relative];
		[aScrollView setHasHorizontalRuler:NO];
		[aScrollView setHasVerticalRuler:YES];
		[aScrollView setRulersVisible:YES];
	} else {
		[aScrollView setRulersVisible:NO];
	}
}

- (void)enableLineNumbers:(BOOL)flag relative:(BOOL)relative
{
	[self eachTextView:^(ViTextView *tv) {
		[self enableLineNumbers:flag relative:relative forScrollView:[tv enclosingScrollView]];
	}];
}

- (IBAction)toggleLineNumbers:(id)sender
{
	[self enableLineNumbers:[sender state] == NSOffState relative:[[NSUserDefaults standardUserDefaults] boolForKey:@"relativenumber"]];
}

#pragma mark -
#pragma mark Other interesting stuff

- (void)setWrapping:(BOOL)flag
{
	[self eachTextView:^(ViTextView *tv) {
		[tv setWrapping:flag];
	}];
}

- (NSDictionary *)typingAttributes
{
	if (_typingAttributes == nil)
		[self setTypingAttributes];
	return _typingAttributes;
}

- (void)setTypingAttributes
{
	NSString *tab = [@"" stringByPaddingToLength:_tabSize withString:@" " startingAtIndex:0];

	NSDictionary *attrs = [NSDictionary dictionaryWithObject:[ViThemeStore font]
							  forKey:NSFontAttributeName];
	NSSize tabSizeInPoints = [tab sizeWithAttributes:attrs];

	NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	// remove all previous tab stops
	for (NSTextTab *tabStop in [style tabStops])
		[style removeTabStop:tabStop];

	/* "Tabs after the last specified in tabStops are placed
	 *  at integral multiples of this distance."
	 */
	[style setDefaultTabInterval:tabSizeInPoints.width];

	if ([[ViPreferencePaneEdit valueForKey:@"linebreak" inScope:_language.scope] boolValue])
		[style setLineBreakMode:NSLineBreakByWordWrapping];
	else
		[style setLineBreakMode:NSLineBreakByCharWrapping];

	_typingAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:
	    style, NSParagraphStyleAttributeName,
	    [ViThemeStore font], NSFontAttributeName,
	    nil];

	NSRange r = NSMakeRange(0, [_textStorage length]);
	[_textStorage setAttributes:_typingAttributes range:r];

	[self eachTextView:^(ViTextView *tv) {
		[(ViRulerView *)[[tv enclosingScrollView] verticalRulerView] resetTextAttributes];
	}];
}

- (void)changeTheme:(ViTheme *)aTheme
{
	[self setTheme:aTheme];

	/* Reset the cached attributes.
	 */
	NSArray *scopeArray = [_syntaxParser scopeArray];
	for (NSUInteger i = 0; i < [scopeArray count];) {
		[[scopeArray objectAtIndex:i] setAttributes:nil];
		i += [[scopeArray objectAtIndex:i] range].length;
	}
}

- (void)updatePageGuide
{
	NSInteger pageGuideColumn = 0;
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	if ([defs boolForKey:@"showguide"] == NSOnState)
		pageGuideColumn = [defs integerForKey:@"guidecolumn"];

	[self eachTextView:^(ViTextView *tv) {
		[tv setPageGuide:pageGuideColumn];
	}];
}

- (void)message:(NSString *)fmt, ...
{
	if (fmt) {
		va_list ap;
		va_start(ap, fmt);
		[_windowController message:fmt arguments:ap];
		va_end(ap);
	}
}

#pragma mark -
#pragma mark Symbol List

- (NSUInteger)filterSymbols:(ViRegexp *)rx
{
	NSMutableArray *fs = [[NSMutableArray alloc] initWithCapacity:[_symbols count]];
	for (ViMark *s in _symbols)
		if ([rx matchInString:s.title])
			[fs addObject:s];
	[self setFilteredSymbols:fs];
	return [fs count];
}

- (NSImage *)matchSymbolIconForScope:(ViScope *)scope
{
	NSString *scopeSelector = [scope bestMatch:[_symbolIcons allKeys]];
	if (scopeSelector)
		return [NSImage imageNamed:[_symbolIcons objectForKey:scopeSelector]];
	return nil;
}

- (void)invalidateSymbolsInRange:(NSRange)updateRange
{
	NSString *string = [_textStorage string];
	NSArray *scopeArray = [_syntaxParser scopeArray];
	DEBUG(@"invalidate symbols in range %@", NSStringFromRange(updateRange));

	NSString *lastSelector = nil;
	NSImage *img = nil;
	NSRange wholeRange;

	[self willChangeValueForKey:@"symbols"];

	NSUInteger maxRange = NSMaxRange(updateRange);

	NSUInteger i;
	/* Remove old symbols in the range. Assumes the symbols are sorted on location. */
	for (i = 0; i < [_symbols count];) {
		ViMark *sym = [_symbols objectAtIndex:i];
		NSRange r = sym.range;
		if (r.location > maxRange)
			/* we're past our range */
			break;
		if (NSMaxRange(r) <= updateRange.location)
			/* the symbol doesn't intersect the range */
			i++;
		else {
			DEBUG(@"remove symbol %@", sym);
			[_symbols removeObjectAtIndex:i];
		}
	}

	/* Parse new symbols in the range. */
	for (i = updateRange.location; (i <= maxRange || lastSelector) && i < [scopeArray count];) {
		ViScope *scope = [scopeArray objectAtIndex:i];
		NSRange range = scope.range;

		if ([lastSelector match:scope] > 0) {
			/* Continue with the last scope selector, it matched this scope too. */
			wholeRange.length += range.length;
		} else {
			if (lastSelector) {
				/*
				 * Finalize the last symbol. Apply any symbol transformation.
				 */
				NSString *symbol = [string substringWithRange:wholeRange];
				NSString *transform = [_symbolTransforms objectForKey:lastSelector];
				if (transform) {
					ViSymbolTransform *tr = [[ViSymbolTransform alloc]
					    initWithTransformationString:transform];
					symbol = [tr transformSymbol:symbol];
				}

				ViMark *sym = [ViMark markWithDocument:self
								  name:nil
								 range:wholeRange];
				sym.icon = img;
				sym.title = symbol;
				DEBUG(@"adding symbol %@", sym);
				[_symbols addObject:sym];
			}
			lastSelector = nil;

			NSString *scopeSelector = [scope bestMatch:[_symbolScopes allKeys]];
			if (scopeSelector) {
				id obj = [_symbolScopes objectForKey:scopeSelector];
				if ([obj respondsToSelector:@selector(boolValue)] && [obj boolValue]) {
					lastSelector = scopeSelector;
					NSRange backRange = [self rangeOfScopeSelector:scopeSelector forward:NO fromLocation:i];
					if (backRange.length > 0) {
						DEBUG(@"EXTENDED WITH backRange = %@ from %@",
						    NSStringFromRange(backRange), NSStringFromRange(range));
						wholeRange = NSUnionRange(range, backRange);
					} else
						wholeRange = range;
					img = [self matchSymbolIconForScope:scope];
				}
			}
		}

		i = NSMaxRange(range);
	}

	[_symbols sortUsingComparator:^(id obj1, id obj2) {
		ViMark *sym1 = obj1, *sym2 = obj2;
		return (NSComparisonResult)(sym1.range.location - sym2.range.location);
	}];

	if ([_symbols count] > 0) {
		// XXX: remove duplicates, ie hide bugs
		NSUInteger i;
		NSUInteger prevLocation = ((ViMark *)[_symbols objectAtIndex:0]).range.location;
		for (i = 1; i < [_symbols count];) {
			ViMark *sym = [_symbols objectAtIndex:i];
			if (sym.range.location == prevLocation)
				[_symbols removeObjectAtIndex:i];
			else {
				i++;
				prevLocation = sym.range.location;
			}
		}
	}

	[self didChangeValueForKey:@"symbols"];
}

#pragma mark -
#pragma mark Associated views (preview and stuff)

- (void)associatedViewClosed:(NSNotification *)notification
{
	ViViewController *viewController = [notification object];
	DEBUG(@"removing associated view %@", viewController);
	for (NSMutableSet *set in [_associatedViews objectEnumerator]) {
		[set removeObject:viewController];
	}
	[[NSNotificationCenter defaultCenter] removeObserver:self
							name:ViViewClosedNotification
						      object:viewController];
}

- (void)associateView:(ViViewController *)viewController forKey:(NSString *)key
{
	NSMutableSet *set;

	if (_associatedViews == nil) {
		_associatedViews = [[NSMutableDictionary alloc] init];
	}
	set = [_associatedViews objectForKey:key];
	if (set == nil) {
		set = [[NSMutableSet alloc] init];
		[_associatedViews setObject:set forKey:key];
	}
	[set addObject:viewController];

	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(associatedViewClosed:)
						     name:ViViewClosedNotification
						   object:viewController];
}

- (NSSet *)associatedViewsForKey:(NSString *)key
{
	return [_associatedViews objectForKey:key];
}

#pragma mark -
#pragma mark Marks

- (ViMark *)markNamed:(unichar)key
{
	NSString *name = [NSString stringWithFormat:@"%C", key];
	if ([name isUppercase])
		return [[[ViMarkManager sharedManager] stackWithName:@"Global Marks"].list lookup:name];
	return [_localMarks.list lookup:name];
}

- (ViMark *)setMark:(unichar)key toRange:(NSRange)range
{
	NSString *name = [NSString stringWithFormat:@"%C", key];
	ViMark *m = [_localMarks.list lookup:name];
	if (m) {
		[m setRange:range];
	} else {
		m = [ViMark markWithDocument:self name:name range:range];
		[_localMarks.list addMark:m];
	}

	if ([name isUppercase])
		[[[ViMarkManager sharedManager] stackWithName:@"Global Marks"].list addMark:m];

	return m;
}

- (ViMark *)setMark:(unichar)key atLocation:(NSUInteger)aLocation
{
	return [self setMark:key toRange:NSMakeRange(aLocation, 1)];
}

- (void)pushMarks:(NSInteger)delta fromLocation:(NSUInteger)location
{
	DEBUG(@"pushing marks from %lu", location);
	NSHashTable *toDelete = nil;
	for (ViMark *mark in _marks) {

		// XXX: weird hack. avoid pushing already updated marks
		// that was just restored from undo.
		if (mark.recentlyRestored) {
			mark.recentlyRestored = NO;
			continue;
		}

		NSRange r = mark.range;
		if (NSMaxRange(r) < location) {
			/* The changed area is completely after the mark and doesn't affect it at all. */
			continue;
		}

		/* The change was either completely before the mark (needs push/pull),
		 * or the changed area intersects the mark.
		 */
		if (delta < 0) {
			NSRange deletedRange = NSMakeRange(location, -delta);

			if (NSMaxRange(deletedRange) <= r.location) {
				/* The changed area is completely before the mark. */
				r.location += delta;
				DEBUG(@"pushing mark %@ to %@", mark, NSStringFromRange(r));
				[mark setRange:r];
			} else if (NSEqualRanges(deletedRange, NSUnionRange(deletedRange, r)) &&
				   NSMaxRange(r) > location) {
				if (!mark.persistent) {
					/*
					 * The mark is completely contained within the changed area.
					 * Remove the mark.
					 */
					DEBUG(@"remove mark %@", mark);
					if (toDelete == nil)
						toDelete = [NSHashTable hashTableWithOptions:0];
					[toDelete addObject:mark];
				} else
					DEBUG(@"keeping persistent mark %@", mark);
			} else {
				/*
				 * The changed area intersects the mark at either end.
				 * FIXME: update the range or not?
				 */
			}
		} else { /* delta > 0 */
			if (NSMaxRange(r) > location) {
				/* The changed area is completely before the mark. */
				r.location += delta;
				DEBUG(@"pushing mark %@ to %@", mark, NSStringFromRange(r));
				[mark setRange:r];
			}
		}
	}

	for (ViMark *mark in toDelete)
		[mark remove];
}

- (void)registerMark:(ViMark *)mark
{
	[_marks addObject:mark];
}

- (void)unregisterMark:(ViMark *)mark
{
	[_marks removeObject:mark];
}

#pragma mark -
#pragma mark Folding
- (void)createFoldForRange:(NSRange)range
{
	// The incoming range includes the last newline; however, we don't consider
	// the last newline part of the fold, so we're not going to operate on it
	// at all.
	range = NSMakeRange(range.location, range.length - 1);

	ViFold *newFold = [ViFold fold];

	ViFold *foldAtStart = [self.textStorage attribute:ViFoldAttributeName atIndex:range.location effectiveRange:NULL];
	ViFold *foldAtEnd = [self.textStorage attribute:ViFoldAttributeName atIndex:NSMaxRange(range) + 1 effectiveRange:NULL];

	ViFold *newFoldParent = closestCommonParentFold(foldAtStart, foldAtEnd);
	if (newFoldParent) {
		addChildToFold(newFoldParent, newFold);
	}

	// The list of ranges that we won't be setting to have the new fold.
	[self.textStorage enumerateAttribute:ViFoldAttributeName
								 inRange:range
								 options:NULL
							  usingBlock:^(ViFold *overlappingFold, NSRange overlappingFoldRange, BOOL *stop) {
		if (overlappingFold == newFold.parent) {
			// If the overlapping fold is the same as the new fold's parent, then
			// the fold at this location will be the new fold (note that this
			// includes cases where the new fold is at the root level).
			[self.textStorage addAttribute:ViFoldAttributeName value:newFold range:overlappingFoldRange];
		} else {
			// Otherwise, the new fold becomes a parent to the overlapping fold's
			// topmost parent that has the new fold's parent as its parent.
			ViFold *candidateChildFold = [overlappingFold topmostParentWithParent:newFold.parent];

			addChildToFold(newFold, candidateChildFold);
		}
	}];

	// If the fold at the start has the same start point as the new fold, mark
	// it and all its parents as such until we hit the new fold we inserted.
	if (foldAtStart && foldAtStart != newFoldParent) {
		do {
			foldAtStart.sameStartAsParent = YES;
		} while ((foldAtStart = foldAtStart.parent) && foldAtStart != newFold);
	}
	// If the fold at the end has the same end point as the new fold, mark
	// it and all its parents as such until we hit the new fold we inserted.
	if (foldAtEnd && foldAtEnd != newFoldParent) {
		do {
			foldAtEnd.sameEndAsParent = YES;
		} while ((foldAtEnd = foldAtEnd.parent) && foldAtEnd != newFold);
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:ViFoldsChangedNotification object:self userInfo:nil];
}

- (NSRange)closeFoldAtLocation:(NSUInteger)aLocation levels:(NSUInteger)levels
{
	NSRange foldRange;
	ViFold *fold = [self.textStorage attribute:ViFoldAttributeName
									   atIndex:aLocation
						 longestEffectiveRange:&foldRange
									   inRange:NSMakeRange(0, [self.textStorage length])];

	// Pop up the hierarchy to the bottommost open fold with the same start
	// point, if any.
	while (fold.hasSameStartAsParent && ! fold.isOpen)
		fold = fold.parent;

	while (fold.hasSameEndAsParent && ! fold.isOpen)
		fold = fold.parent;

	if (fold) {
		return [self closeFold:fold inRange:foldRange levels:levels];
	} else {
		return NSMakeRange(NSNotFound, -1);
	}
}

- (NSRange)openFoldAtLocation:(NSUInteger)aLocation levels:(NSUInteger)levels
{
	NSRange foldRange;
	ViFold *fold = [self.textStorage attribute:ViFoldAttributeName
									   atIndex:aLocation
						 longestEffectiveRange:&foldRange
									   inRange:NSMakeRange(0, [self.textStorage length])];

	// Pop up the hierarchy to the topmost closed fold with the same start
	// point, if any.
	while (fold.hasSameStartAsParent && fold.isOpen)
		fold = fold.parent;
	while (fold.hasSameStartAsParent && ! fold.parent.isOpen)
		fold = fold.parent;

	while (fold.hasSameEndAsParent && fold.isOpen)
		fold = fold.parent;
	while (fold.hasSameEndAsParent && ! fold.parent.isOpen)
		fold = fold.parent;

	if (fold && fold.isOpen) {
		return foldRange;
	} else if (fold) {
		return [self openFold:fold inRange:foldRange levels:levels];
	} else {
		return NSMakeRange(NSNotFound, -1);
	}
}

- (void)toggleFoldAtLocation:(NSUInteger)aLocation
{
	NSRange foldRange;
	ViFold *fold = [self.textStorage attribute:ViFoldAttributeName
						   atIndex:aLocation
			 longestEffectiveRange:&foldRange
						   inRange:NSMakeRange(0, [self.textStorage length])];

	if (fold && fold.isOpen) {
		[self closeFold:fold inRange:foldRange];
	} else if (fold) {
		[self openFold:fold inRange:foldRange];
	}
}

- (NSRange)closeFold:(ViFold *)foldToClose inRange:(NSRange)foldRange
{
	return [self closeFold:foldToClose inRange:foldRange levels:1];
}

- (NSRange)closeFold:(ViFold *)foldToClose inRange:(NSRange)foldRange levels:(NSUInteger)levels
{
	NSUInteger maxCloseDepth = foldToClose.depth;
	NSUInteger minCloseDepth = (levels - 1 > foldToClose.depth) ? 1 : foldToClose.depth - (levels - 1);
	NSUInteger foldStart = NSNotFound;
	ViFold *currentFold = nil;
	do {
		foldStart = foldRange.location;
		currentFold = [self.textStorage attribute:ViFoldAttributeName
										   atIndex:foldStart - 1
							 longestEffectiveRange:&foldRange
										   inRange:NSMakeRange(0, foldStart)];
	} while (currentFold &&
			 (currentFold = closestCommonParentFold(currentFold, foldToClose)) &&
			 currentFold.depth >= minCloseDepth);

	__block ViFold *lastFold = nil;
	__block NSValue *totalClosedRange = [NSValue valueWithRange:NSMakeRange(foldStart, 0)];
	[self.textStorage enumerateAttribute:ViFoldAttributeName
								 inRange:NSMakeRange(foldStart, [self.textStorage length] - foldStart)
								 options:NULL
							  usingBlock:^(ViFold *currentFold, NSRange currentFoldRange, BOOL *stop) {
		if (! currentFold) {
			*stop = YES;

			return;
		}

		BOOL startOfCurrentFold = ! lastFold || lastFold.depth < currentFold.depth;
		ViFold *foldToClose = nil;
		if (startOfCurrentFold && currentFold.depth <= maxCloseDepth) {
			foldToClose = currentFold;
		} else if (currentFold.hasSameStartAsParent && currentFold.depth > minCloseDepth) {
			foldToClose = currentFold;
			do {
				foldToClose = foldToClose.parent;
			} while (foldToClose &&
					 foldToClose.hasSameStartAsParent &&
					 foldToClose.depth > maxCloseDepth);

			if (foldToClose && foldToClose.depth > maxCloseDepth) {
				foldToClose = nil;
			}
		} else if (currentFold.hasSameEndAsParent && currentFold.depth > minCloseDepth) {
			foldToClose = currentFold;
			do {
				foldToClose = foldToClose.parent;
			} while (foldToClose &&
					 foldToClose.hasSameEndAsParent &&
					 foldToClose.depth > maxCloseDepth);

			if (foldToClose && foldToClose.depth > maxCloseDepth) {
				foldToClose = nil;
			}
		}
		ViFold *foldToMark = foldToClose;
		do {
			foldToMark.open = NO;
		} while (foldToMark.hasSameStartAsParent && (foldToMark = foldToMark.parent) && foldToMark.depth >= minCloseDepth);

		ViFold *closestCommonParent = nil;
		// Stop if this isn't the first fold and the current fold isn't
		// contiguous with the previous one, or if this isn't the first fold
		// and the current fold doesn't share a parent of depth < maxCloseDepth
		// with the previous one.
		if (lastFold &&
				(currentFoldRange.location != NSMaxRange([totalClosedRange rangeValue]) ||
				 ((closestCommonParent = closestCommonParentFold(lastFold, currentFold)) &&
				  closestCommonParent.depth < minCloseDepth))) {
			*stop = YES;

			return;
		}

		if (foldToClose && currentFoldRange.location == foldStart) {
			[self.textStorage addAttributes:@{ NSAttachmentAttributeName: [ViFold foldAttachment] }
									  range:NSMakeRange(currentFoldRange.location, 1)];

			currentFoldRange = NSMakeRange(currentFoldRange.location + 1, currentFoldRange.length - 1);
		}
		if (startOfCurrentFold && currentFoldRange.location != foldStart) {
			[self.textStorage removeAttribute:NSAttachmentAttributeName
										range:NSMakeRange(currentFoldRange.location, 1)];
		}

		[self.textStorage addAttributes:@{ ViFoldedAttributeName: @YES }
								  range:currentFoldRange];

		lastFold = currentFold;
		totalClosedRange = [NSValue valueWithRange:NSUnionRange([totalClosedRange rangeValue], currentFoldRange)];
	}];

	[[NSNotificationCenter defaultCenter] postNotificationName:ViFoldClosedNotification object:self userInfo:nil];

	return [totalClosedRange rangeValue];
}

- (NSRange)openFold:(ViFold *)foldToOpen inRange:(NSRange)foldRange
{
	return [self openFold:foldToOpen inRange:foldRange levels:1];
}

- (NSRange)openFold:(ViFold *)foldToOpen inRange:(NSRange)foldRange levels:(NSUInteger)levels
{
	NSUInteger maxOpenDepth = foldToOpen.depth + levels;
	NSUInteger minOpenDepth = foldToOpen.depth;
	NSUInteger foldStart = NSNotFound;
	__block ViFold *currentFold = nil;
	do {
		foldStart = foldRange.location;
		currentFold = [self.textStorage attribute:ViFoldAttributeName
										   atIndex:foldStart - 1
							 longestEffectiveRange:&foldRange
										   inRange:NSMakeRange(0, foldStart)];
	} while (currentFold &&
			 (currentFold = closestCommonParentFold(currentFold, foldToOpen)) &&
			 currentFold.depth >= minOpenDepth);

	currentFold = nil;
	__block ViFold *lastFold = nil;
	__block NSValue *totalOpenedRange = [NSValue valueWithRange:NSMakeRange(foldStart, 0)];
	[self.textStorage enumerateAttribute:ViFoldAttributeName
								 inRange:NSMakeRange(foldStart, [self.textStorage length] - foldStart)
								 options:NULL
							  usingBlock:^(ViFold *currentFold, NSRange currentFoldRange, BOOL *stop) {
		if (! currentFold) {
			*stop = YES;

			return;
		}

		BOOL startOfCurrentFold = ! lastFold || lastFold.depth < currentFold.depth;
		BOOL openCurrentFold = currentFold.isOpen || currentFold.depth < maxOpenDepth;

		ViFold *closestCommonParent = nil;
		// Stop if this isn't the first fold and the current fold isn't
		// contiguous with the previous one, or if this isn't the first fold
		// and the current fold doesn't share a parent of depth <= maxCloseDepth
		// with the previous one.
		if (lastFold &&
				(currentFoldRange.location != NSMaxRange([totalOpenedRange rangeValue]) ||
				 ((closestCommonParent = closestCommonParentFold(lastFold, currentFold)) &&
				  closestCommonParent.depth < minOpenDepth))) {
			*stop = YES;

			return;
		}

		if (startOfCurrentFold && openCurrentFold) {
			[self.textStorage removeAttribute:NSAttachmentAttributeName
									    range:NSMakeRange(currentFoldRange.location, 1)];
		} else if (startOfCurrentFold && lastFold.isOpen && ! currentFold.isOpen) {
			NSRange attachmentRange = NSMakeRange(currentFoldRange.location, 1);

			// If this is the start of the current fold and it's not a fold we're going to
			// be opening, go ahead and mark its first character with the fold attachment.
			[self.textStorage addAttribute:NSAttachmentAttributeName
									 value:[ViFold foldAttachment]
									 range:attachmentRange];

			// We won't be opening the rest of this range, but we do want to
			// drop the folded attribute from the attachment character.
			[self.textStorage removeAttribute:ViFoldedAttributeName
										range:attachmentRange];
		}

		if (openCurrentFold) {
			currentFold.open = YES;

			[self.textStorage removeAttribute:ViFoldedAttributeName
										range:currentFoldRange];
		}

		lastFold = currentFold;
		totalOpenedRange = [NSValue valueWithRange:NSUnionRange([totalOpenedRange rangeValue], currentFoldRange)];
	}];

	[[NSNotificationCenter defaultCenter] postNotificationName:ViFoldOpenedNotification object:self userInfo:nil];
	
	return [totalOpenedRange rangeValue];
}

- (ViFold *)foldAtLocation:(NSUInteger)aLocation
{
	return [self.textStorage attribute:ViFoldAttributeName atIndex:aLocation effectiveRange:NULL];
}

- (NSRange)foldRangeAtLocation:(NSUInteger)aLocation
{
	__block NSRange foldRange = NSMakeRange(NSNotFound, -1);
	__block ViFold *lastFold = nil;
	[self.textStorage enumerateAttribute:ViFoldAttributeName
								 inRange:NSMakeRange(aLocation, [self.textStorage length] - aLocation)
								 options:NULL
							  usingBlock:^(ViFold *currentFold, NSRange currentFoldRange, BOOL *stop) {
		// Stop if this isn't the first fold and the current fold isn't
		// contiguous with the previous one, or if this isn't the first fold
		// and the current fold doesn't share a parent with the previous one.
		// We also stop if we've reached a point with no fold.
		if (! currentFold ||
			(lastFold &&
				(currentFoldRange.location - 1 != NSMaxRange(foldRange) ||
				 ! closestCommonParentFold(lastFold, currentFold)))) {
			*stop = YES;

			return;
		}

		if (foldRange.location == NSNotFound) {
			foldRange = currentFoldRange;
		} else {
			foldRange = NSUnionRange(foldRange, currentFoldRange);
		}

		lastFold = currentFold;
	}];

	return foldRange;
}

#pragma mark -

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViDocument %p: %@>",
	    self, [[self fileURL] displayString] ?: [self displayName]];
}

- (ViScope *)scopeAtLocation:(NSUInteger)aLocation
{
	NSArray *scopeArray = [_syntaxParser scopeArray];
	if ([scopeArray count] > aLocation) {
		/* XXX: must retain + autorelease because the scopeArray may
		 * be emptied or changed and the scope would be released.
		 */
		return [scopeArray objectAtIndex:aLocation];
	}
	return _language.scope;
}

- (NSString *)bestMatchingScope:(NSArray *)scopeSelectors
                    atLocation:(NSUInteger)aLocation
{
	ViScope *scope = [self scopeAtLocation:aLocation];
	return [scope bestMatch:scopeSelectors];
}

- (NSRange)rangeOfScopeSelector:(NSString *)scopeSelector
                        forward:(BOOL)forward
                   fromLocation:(NSUInteger)aLocation
{
	NSUInteger i = aLocation;
	ViScope *lastScope = nil, *scope;
	for (;;) {
		if (forward && i >= [_textStorage length])
			break;
		else if (!forward && i == 0)
			break;

		if (!forward)
			i--;

		if ((scope = [self scopeAtLocation:i]) == nil)
			break;

		if (lastScope != scope && [scopeSelector match:scope] == 0) {
			if (!forward)
				i++;
			break;
		}

		if (forward)
			i++;

		lastScope = scope;
	}

	if (forward)
		return NSMakeRange(aLocation, i - aLocation);
	else
		return NSMakeRange(i, aLocation - i);

}

- (NSRange)rangeOfScopeSelector:(NSString *)scopeSelector
                     atLocation:(NSUInteger)aLocation
{
	NSRange rb = [self rangeOfScopeSelector:scopeSelector forward:NO fromLocation:aLocation];
	NSRange rf = [self rangeOfScopeSelector:scopeSelector forward:YES fromLocation:aLocation];
	return NSUnionRange(rb, rf);
}

#pragma mark -
#pragma mark Ex actions

- (id)ex_write:(ExCommand *)command
{
	DEBUG(@"got %i addresses", command.naddr);
	if (command.naddr > 0)
		return [ViError message:@"Partial writing not yet supported"];

	if (command.append)
		return [ViError message:@"Appending not yet supported"];

	if ([command.arg length] == 0) {
		[self saveDocument:self];
	} else {
		__block NSError *error = nil;
		NSURL *newURL = [[ViDocumentController sharedDocumentController] normalizePath:command.arg
										    relativeTo:_windowController.baseURL
											 error:&error];
		if (error != nil)
			return error;

		id<ViDeferred> deferred;
		ViURLManager *urlman = [ViURLManager defaultManager];
		__block NSDictionary *attributes = nil;
		__block NSURL *normalizedURL = nil;
		deferred = [urlman attributesOfItemAtURL:newURL
				      onCompletion:^(NSURL *_url, NSDictionary *_attrs, NSError *_err) {
			normalizedURL = _url;
			attributes = _attrs;
			if (![_err isFileNotFoundError])
				error = _err;
		}];

		if ([deferred respondsToSelector:@selector(waitInWindow:message:)])
			[deferred waitInWindow:[_windowController window]
				       message:[NSString stringWithFormat:@"Saving %@...",
					       [newURL lastPathComponent]]];
		else
			[deferred wait];

		if (error)
			return error;

		if (normalizedURL && ![[attributes fileType] isEqualToString:NSFileTypeRegular])
			return [ViError errorWithFormat:@"%@ is not a regular file", normalizedURL];

		if (normalizedURL && !command.force)
			return [ViError message:@"File exists (add ! to override)"];

		if ([self saveToURL:newURL
			     ofType:nil
		   forSaveOperation:NSSaveAsOperation
			      error:&error] == NO)
			return error;
	}

	return nil;
}

- (id)ex_setfiletype:(ExCommand *)command
{
	NSString *langScope = command.arg;
	NSString *pattern = [NSString stringWithFormat:@"(^|\\.)%@(\\.|$)", [ViRegexp escape:langScope]];
	ViRegexp *rx = [ViRegexp regexpWithString:pattern];
	NSMutableSet *matches = [NSMutableSet set];
	for (ViLanguage *lang in [[ViBundleStore defaultStore] languages]) {
		if ([lang.name isEqualToString:langScope]) {
			/* full match */
			[matches removeAllObjects];
			[matches addObject:lang];
			break;
		} else if ([rx matchesString:lang.name]) {
			/* partial match */
			[matches addObject:lang];
		}
	}

	if ([matches count] == 0)
		return [ViError errorWithFormat:@"Unknown syntax %@", langScope];
	else if ([matches count] > 1)
		return [ViError errorWithFormat:@"More than one match for %@", langScope];

	[self setLanguageAndRemember:[matches anyObject]];
	return nil;
}

- (id)ex_wq:(ExCommand *)command
{
	id ret = [self ex_write:command];
	if (ret)
		return ret;
	return [[self windowController] ex_quit:command];
}

- (id)ex_xit:(ExCommand *)command
{
	if ([self isDocumentEdited]) {
		id ret = [self ex_write:command];
		if (ret)
			return ret;
	}
	return [[self windowController] ex_quit:command];
}

@end
