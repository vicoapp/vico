#include <sys/time.h>

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
#import "ViLayoutManager.h"
#import "ViError.h"
#import "NSObject+SPInvocationGrabbing.h"
#import "ViAppController.h"
#import "ViPreferencePaneEdit.h"
#import "ViEventManager.h"
#import "ViDocumentController.h"
#import "NSURL-additions.h"
#import "ViTextView.h"

BOOL makeNewWindowInsteadOfTab = NO;

@interface ViDocument (internal)
- (void)highlightEverything;
- (void)setWrapping:(BOOL)flag;
- (void)enableLineNumbers:(BOOL)flag forScrollView:(NSScrollView *)aScrollView;
- (void)enableLineNumbers:(BOOL)flag;
- (void)setTypingAttributes;
- (NSDictionary *)typingAttributes;
- (NSString *)suggestEncoding:(NSStringEncoding *)outEncoding forData:(NSData *)data;
- (BOOL)addData:(NSData *)data;
- (void)invalidateSymbolsInRange:(NSRange)range;
- (void)pushSymbols:(NSInteger)delta fromLocation:(NSUInteger)location;
- (void)pushMarks:(NSInteger)delta fromLocation:(NSUInteger)location;
- (void)updateTabSize;
- (void)updateWrapping;
- (void)eachTextView:(void (^)(ViTextView *))callback;
@end

@implementation ViDocument

@synthesize symbols;
@synthesize filteredSymbols;
@synthesize views;
@synthesize bundle;
@synthesize encoding;
@synthesize isTemporary;
@synthesize snippet;
@synthesize busy;
@synthesize loader;
@synthesize closeCallback;
@synthesize ignoreChangeCountNotification;
@synthesize textStorage;
@synthesize matchingParenRange;

+ (BOOL)canConcurrentlyReadDocumentsOfType:(NSString *)typeName
{
	return NO;
}

- (id)init
{
	self = [super init];
	if (self) {
		symbols = [NSMutableArray array];
		views = [NSMutableSet set];
		localMarks = [[ViMarkManager sharedManager] makeStack];
		localMarks.name = [NSString stringWithFormat:@"Local marks for document %p", self];

		NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
		[userDefaults addObserver:self forKeyPath:@"number" options:0 context:NULL];
		[userDefaults addObserver:self forKeyPath:@"tabstop" options:0 context:NULL];
		[userDefaults addObserver:self forKeyPath:@"fontsize" options:0 context:NULL];
		[userDefaults addObserver:self forKeyPath:@"fontname" options:0 context:NULL];
		[userDefaults addObserver:self forKeyPath:@"linebreak" options:0 context:NULL];
		[userDefaults addObserver:self forKeyPath:@"wrap" options:0 context:NULL];
		[userDefaults addObserver:self forKeyPath:@"list" options:0 context:NULL];
		[userDefaults addObserver:self forKeyPath:@"matchparen" options:0 context:NULL];

		textStorage = [[ViTextStorage alloc] init];
		[textStorage setDelegate:self];

		[[NSNotificationCenter defaultCenter] addObserver:self
							 selector:@selector(textStorageDidChangeLines:)
							     name:ViTextStorageChangedLinesNotification
							   object:textStorage];

		[[NSNotificationCenter defaultCenter] addObserver:self
							 selector:@selector(editPreferenceChanged:)
							     name:ViEditPreferenceChangedNotification
							   object:nil];

		NSString *symbolIconsFile = [[ViAppController supportDirectory] stringByAppendingPathComponent:@"symbol-icons.plist"];
		if (![[NSFileManager defaultManager] fileExistsAtPath:symbolIconsFile])
			symbolIconsFile = [[NSBundle mainBundle] pathForResource:@"symbol-icons"
									  ofType:@"plist"];
		symbolIcons = [NSDictionary dictionaryWithContentsOfFile:symbolIconsFile];

		[self configureForURL:nil];
		forcedEncoding = 0;
		encoding = NSUTF8StringEncoding;

		theme = [[ViThemeStore defaultStore] defaultTheme];
		[self setTypingAttributes];

		/*
		 * Disable automatic undo groups created in each pass of the run loop.
		 * This duplicates our own undo grouping and makes the document never
		 * regain is un-edited state.
		 */
		[[self undoManager] setGroupsByEvent:NO];
	}

	return self;
}

- (BOOL)dataAppearsBinary:(NSData *)data
{
	NSString *string = nil;
	if (forcedEncoding)
		string = [[NSString alloc] initWithData:data encoding:forcedEncoding];
	if (string == nil)
		string = [self suggestEncoding:NULL forData:data];

	if ([string rangeOfString:[NSString stringWithFormat:@"%C", 0]].location != NSNotFound)
		return YES;

	return NO;
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
	symbols = [NSMutableArray array];

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
				DEBUG(@"cancelling deferred %@", loader);
				[loader cancel];
				return;
			}
		}
		if (firstChunk)
			[self setString:@""]; /* Make sure document is empty before appending data. */
		[self addData:data];
		firstChunk = NO;

		if ([loader respondsToSelector:@selector(progress)]) {
			CGFloat progress = [loader progress];
			if (progress >= 0)
				[self message:@"%.1f%% loaded", progress * 100.0];
		}
	};

	/* If the completion callback is called immediately, we can return an error directly. */
	__block NSError *returnError = nil;

	void (^completionCallback)(NSURL *, NSDictionary *, NSError *error) = ^(NSURL *normalizedURL, NSDictionary *attributes, NSError *error) {
		DEBUG(@"error is %@", error);
		returnError = error;
		busy = NO;
		loader = nil;
		if (error) {
			/* If the file doesn't exist, treat it as an untitled file. */
			if ([error isFileNotFoundError]) {
				DEBUG(@"treating non-existent file %@ as untitled file", normalizedURL);
				[self setFileURL:normalizedURL];
				[self message:@"%@: new file", [self title]];
				[[ViEventManager defaultManager] emitDelayed:ViEventDidLoadDocument for:self with:self, nil];
				returnError = nil;
			} else if ([error isOperationCancelledError]) {
				[self message:@"cancelled loading of %@", normalizedURL];
				[self setFileURL:nil];
				if (closeCallback)
					closeCallback(2);
				closeCallback = NULL;
			} else {
				/* Make sure this document has focus, then show an alert sheet. */
				[windowController selectDocument:self];
				[self setFileURL:nil];

				NSAlert *alert = [[NSAlert alloc] init];
				[alert setMessageText:[NSString stringWithFormat:@"Couldn't open %@",
					normalizedURL]];
				[alert addButtonWithTitle:@"OK"];
				[alert setInformativeText:[error localizedDescription]];
				[alert beginSheetModalForWindow:[windowController window]
						  modalDelegate:self
						 didEndSelector:@selector(openFailedAlertDidEnd:returnCode:contextInfo:)
						    contextInfo:nil];
				if (closeCallback)
					closeCallback(3);
				closeCallback = NULL;
			}
		} else {
			DEBUG(@"loaded %@ with attributes %@", normalizedURL, attributes);
			[self setFileModificationDate:[attributes fileModificationDate]];
			[self setIsTemporary:NO];
			[self setFileURL:normalizedURL];
			[[ViEventManager defaultManager] emitDelayed:ViEventDidLoadDocument for:self with:self, nil];
			[self message:@"%@: %lu lines", [self title], [textStorage lineCount]];

			[self eachTextView:^(ViTextView *tv) {
				[tv documentDidLoad:self];
			}];
		}
	};

	[self setFileType:@"Document"];
	[self setFileURL:absoluteURL];
	[self setIsTemporary:YES]; /* Prevents triggering checkDocumentChanged in window controller. */

	busy = YES;
	loader = [[ViURLManager defaultManager] dataWithContentsOfURL:absoluteURL
							       onData:dataCallback
							 onCompletion:completionCallback];
	DEBUG(@"got deferred loader %@", loader);
	[loader setDelegate:self];

	[self eachTextView:^(ViTextView *tv) {
		[tv setCaret:0];
	}];

	if (outError)
		*outError = returnError;

	return returnError == nil ? YES : NO;
}

- (BOOL)isEntireFileLoaded
{
	return (loader == nil);
}

- (id)initWithContentsOfURL:(NSURL *)absoluteURL
                     ofType:(NSString *)typeName
                      error:(NSError **)outError
{
	DEBUG(@"init with URL %@ of type %@", absoluteURL, typeName);

	self = [self init];
	if (self) {
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
		[self enableLineNumbers:[userDefaults boolForKey:keyPath]];
	else if ([keyPath isEqualToString:@"wrap"])
		[self updateWrapping];
	else if ([keyPath isEqualToString:@"tabstop"]) {
		[self updateTabSize];
	} else if ([keyPath isEqualToString:@"fontsize"] ||
		   [keyPath isEqualToString:@"fontname"] ||
		   [keyPath isEqualToString:@"linebreak"]) {
		[self setTypingAttributes];
		[self updatePageGuide];
	} else if ([keyPath isEqualToString:@"list"]) {
		[self eachTextView:^(ViTextView *tv) {
			ViLayoutManager *lm = (ViLayoutManager *)[tv layoutManager];
			[lm setShowsInvisibleCharacters:[userDefaults boolForKey:@"list"]];
			[lm invalidateDisplayForCharacterRange:NSMakeRange(0, [textStorage length])];
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
	[windowController selectDocument:self];
}

- (ViWindowController *)windowController
{
	return windowController;
}

- (void)closeWindowController:(ViWindowController *)aController
{
	[self removeWindowController:aController];
	if (aController == windowController) {
		/*
		 * XXX: This is a f*cking disaster!
		 * Ask each windows' window controller if it contains this document.
		 */
		windowController = nil;
		for (NSWindow *window in [NSApp windows]) {
			ViWindowController *wincon = [window windowController];
			if (wincon == aController || ![wincon isKindOfClass:[ViWindowController class]])
				continue;
			if ([[wincon documents] containsObject:self]) {
				windowController = wincon;
				break;
			}
		}
	}
}

- (void)addWindowController:(NSWindowController *)aController
{
	[super addWindowController:aController];
	windowController = (ViWindowController *)aController;
}

- (void)makeWindowControllers
{
	ViWindowController *winCon = nil;
	if (makeNewWindowInsteadOfTab) {
		winCon = [[ViWindowController alloc] init];
		makeNewWindowInsteadOfTab = NO;
	} else
		winCon = [ViWindowController currentWindowController];

	[self addWindowController:winCon];
	[winCon addNewTab:self];
}

- (void)eachTextView:(void (^)(ViTextView *))callback
{
	for (ViDocumentView *docView in views) {
		NSView *view = [docView innerView];
		if ([view isKindOfClass:[ViTextView class]])
			callback((ViTextView *)view);
	}
	if (hiddenView) {
		NSView *view = [hiddenView innerView];
		if ([view isKindOfClass:[ViTextView class]])
			callback((ViTextView *)view);
	}
}

- (void)removeView:(ViDocumentView *)aDocumentView
{
	if ([views count] == 1)
		hiddenView = aDocumentView;
	[views removeObject:aDocumentView];
}

- (void)addView:(ViDocumentView *)docView
{
	[views addObject:docView];
	hiddenView = nil;
}

- (ViTextView *)text
{
	if (scriptView == nil) {
		ViLayoutManager *layoutManager = [[ViLayoutManager alloc] init];
		[textStorage addLayoutManager:layoutManager];
		[layoutManager setDelegate:self];
		NSRect frame = NSMakeRect(0, 0, 10, 10);
		NSTextContainer *container = [[NSTextContainer alloc] initWithContainerSize:frame.size];
		[layoutManager addTextContainer:container];
		scriptView = [[ViTextView alloc] initWithFrame:frame textContainer:container];
		ViParser *parser = [[ViParser alloc] initWithDefaultMap:[ViMap normalMap]];
		[scriptView initWithDocument:self viParser:parser];
		[[ViEventManager defaultManager] emit:ViEventDidMakeView for:self with:self, [NSNull null], scriptView, nil];
	}
	return scriptView;
}

- (ViDocumentView *)makeView
{
	if (hiddenView)
		return hiddenView;

	ViDocumentView *documentView = [[ViDocumentView alloc] initWithDocument:self];
	[self addView:documentView];

	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

	/*
	 * Recreate the text system hierarchy with our text storage and layout manager.
	 */
	ViLayoutManager *layoutManager = [[ViLayoutManager alloc] init];
	[textStorage addLayoutManager:layoutManager];
	[layoutManager setDelegate:self];
	[layoutManager setShowsInvisibleCharacters:[userDefaults boolForKey:@"list"]];
	[layoutManager setShowsControlCharacters:YES];
	[layoutManager setInvisiblesAttributes:[theme invisiblesAttributes]];

	NSView *innerView = [documentView innerView];
	NSRect frame = [innerView frame];
	NSTextContainer *container = [[NSTextContainer alloc] initWithContainerSize:frame.size];
	[layoutManager addTextContainer:container];
	[container setWidthTracksTextView:YES];
	[container setHeightTracksTextView:YES];

	ViTextView *textView = [[ViTextView alloc] initWithFrame:frame textContainer:container];
	[documentView replaceTextView:textView];

	[textView initWithDocument:self viParser:[windowController parser]];

	[self enableLineNumbers:[userDefaults boolForKey:@"number"]
	          forScrollView:[textView enclosingScrollView]];
	[self updatePageGuide];
	[textView setWrapping:wrap];

	[[ViEventManager defaultManager] emit:ViEventDidMakeView for:self with:self, documentView, textView, nil];

	return documentView;
}

- (ViDocumentView *)cloneView:(ViDocumentView *)oldView
{
	ViDocumentView *newView = [self makeView];
	[[newView textView] setCaret:[[oldView textView] caret]];
	return newView;
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
	NSStringEncoding enc = encoding;
	if (retrySaveOperation)
		enc = NSUTF8StringEncoding;
	DEBUG(@"using encoding %@", [NSString localizedNameOfStringEncoding:enc]);
	NSData *data = [[textStorage string] dataUsingEncoding:enc];
	if (data == nil && outError)
		*outError = [ViError errorWithFormat:@"The %@ encoding is not appropriate.",
		    [NSString localizedNameOfStringEncoding:encoding]];
	return data;
}

- (BOOL)attemptRecoveryFromError:(NSError *)error
                     optionIndex:(NSUInteger)recoveryOptionIndex
{
	if (recoveryOptionIndex == 1) {
		retrySaveOperation = YES;
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

	DEBUG(@"calling delegate %@ with selector %@", didSaveDelegate, NSStringFromSelector(didSaveSelector));
	if (didSaveDelegate && didSaveSelector) {
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
		    [didSaveDelegate methodSignatureForSelector:didSaveSelector]];
		[invocation setSelector:didSaveSelector];
		[invocation setArgument:&self atIndex:2];
		[invocation setArgument:&didSave atIndex:3];
		[invocation setArgument:&didSaveContext atIndex:4];
		[invocation invokeWithTarget:didSaveDelegate];
	}
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
			if (_err && ![_err isFileNotFoundError])
				error = _err;
			else
				attributes = _attrs;
		}];

		if ([deferred respondsToSelector:@selector(waitInWindow:message:)])
			[deferred waitInWindow:[windowController window]
				       message:[NSString stringWithFormat:@"Saving %@...",
					       [[self fileURL] lastPathComponent]]];
		else
			[deferred wait];
		DEBUG(@"done getting attributes of %@, error is %@", [self fileURL], error);

		didSaveDelegate = delegate;
		didSaveSelector = selector;
		didSaveContext = contextInfo;

		if (!error && attributes && ![[attributes fileType] isEqualToString:NSFileTypeRegular])
			error = [ViError errorWithFormat:@"%@ is not a regular file.", [[self fileURL] lastPathComponent]];

		if (!error && attributes && ![[attributes fileModificationDate] isEqual:[self fileModificationDate]]) {
			NSAlert *alert = [[NSAlert alloc] init];
			[alert setMessageText:@"This document’s file has been changed by another application since you opened or saved it."];
			[alert addButtonWithTitle:@"Don't Save"];
			[alert addButtonWithTitle:@"Save"];
			[alert setInformativeText:@"The changes made by the other application will be lost if you save. Save anyway?"];
			[alert beginSheetModalForWindow:[windowController window]
					  modalDelegate:self
					 didEndSelector:@selector(fileModifiedAlertDidEnd:returnCode:contextInfo:)
					    contextInfo:nil];
		} else
			[self continueSavingAfterError:error];
	} else
		[super saveDocumentWithDelegate:delegate
				didSaveSelector:didSaveSelector
				    contextInfo:contextInfo];
}

- (BOOL)writeSafelyToURL:(NSURL *)url
		  ofType:(NSString *)typeName
	forSaveOperation:(NSSaveOperationType)saveOperation
		   error:(NSError **)outError
{
	DEBUG(@"write to %@", url);
	retrySaveOperation = NO;

	if (![[textStorage string] canBeConvertedToEncoding:encoding]) {
		NSString *reason = [NSString stringWithFormat:
		    @"The %@ encoding is not appropriate.",
		    [NSString localizedNameOfStringEncoding:encoding]];
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
			encoding = NSUTF8StringEncoding;
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

			if (isTemporary)
				[[ViURLManager defaultManager] notifyChangedDirectoryAtURL:[normalizedURL URLByDeletingLastPathComponent]];
			isTemporary = NO;
		}
	}];

	if ([deferred respondsToSelector:@selector(waitInWindow:message:)])
		[deferred waitInWindow:[windowController window]
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
		ignoreChangeCountNotification = YES;
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
	if (forcedEncoding != 0) {
		aString = [[NSString alloc] initWithData:data encoding:forcedEncoding];
		if (aString == nil) {
			NSString *description = [NSString stringWithFormat:
			    @"The file can't be interpreted in %@ encoding.",
			    [NSString localizedNameOfStringEncoding:forcedEncoding]];
			NSString *suggestion = [NSString stringWithFormat:@"Keeping the %@ encoding.",
			    [NSString localizedNameOfStringEncoding:encoding]];
			NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
			    description, NSLocalizedDescriptionKey,
			    suggestion, NSLocalizedRecoverySuggestionErrorKey,
			    nil];
			NSError *err = [NSError errorWithDomain:ViErrorDomain code:2 userInfo:userInfo];
			[self presentError:err];
			aString = [[NSString alloc] initWithData:data encoding:encoding];
		} else {
			encoding = forcedEncoding;

			/* Save the user-overridden encoding in preferences. */
			NSMutableDictionary *encodingOverride = [NSMutableDictionary dictionaryWithDictionary:
			    [userDefaults dictionaryForKey:@"encodingOverride"]];
			[encodingOverride setObject:[NSNumber numberWithUnsignedInteger:encoding]
			                     forKey:[[self fileURL] absoluteString]];
			[userDefaults setObject:encodingOverride
			                 forKey:@"encodingOverride"];
		}
		forcedEncoding = 0;
	} else
		aString = [self suggestEncoding:&encoding forData:data];

	NSUInteger len = [textStorage length];
	if (len == 0)
		[self setString:aString];
	else {
		[textStorage replaceCharactersInRange:NSMakeRange(len, 0) withString:aString];
		NSRange r = NSMakeRange(len, [aString length]);
		[textStorage setAttributes:[self typingAttributes] range:r];
	}

	return YES;
}

- (void)setString:(NSString *)aString
{
	/*
	 * Disable the processing in textStorageDidProcessEditing,
	 * otherwise we'll parse the document multiple times.
	 */
	ignoreEditing = YES;
	[[textStorage mutableString] setString:aString ?: @""];
	[textStorage setAttributes:[self typingAttributes]
	                            range:NSMakeRange(0, [aString length])];
	/* Force incremental syntax parsing. */
	language = nil;
	[self configureSyntax];
}

- (void)setEncoding:(id)sender
{
	forcedEncoding = [[sender representedObject] unsignedIntegerValue];
	[self revertDocumentToSaved:nil];
}

- (NSString *)title
{
	NSString *displayName = [self displayName];
	if ([displayName length] == 0) {
		displayName = [[self fileURL] lastPathComponent];
		if ([displayName length] == 0)
			displayName = [[self fileURL] host];
	}

	if ([self isDocumentEdited])
		return [NSString stringWithFormat:@"%@ •", displayName];

	return displayName;
}

- (void)updateChangeCount:(NSDocumentChangeType)changeType
{
	DEBUG(@"called from %@", [NSThread callStackSymbols]);
	if (ignoreChangeCountNotification) {
		DEBUG(@"%s", "ignoring change count notification");
		ignoreChangeCountNotification = NO;
		return;
	}
	BOOL edited = [self isDocumentEdited];
	[super updateChangeCount:changeType];
	if (edited != [self isDocumentEdited]) {
		[self willChangeValueForKey:@"title"];
		[self didChangeValueForKey:@"title"];

		[[NSNotificationCenter defaultCenter] postNotificationName:ViDocumentEditedChangedNotification
								    object:self
								  userInfo:nil];
	}
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

	localMarks.name = [NSString stringWithFormat:@"Local marks in %@", [self title]];

	[[ViEventManager defaultManager] emit:ViEventDidChangeURL for:self with:self, absoluteURL, nil];
}

- (void)closeAndWindow:(BOOL)canCloseWindow
{
	int code = 1; /* not saved */

	[[ViEventManager defaultManager] emit:ViEventWillCloseDocument for:self with:self, nil];

	DEBUG(@"closing, w/window: %s", canCloseWindow ? "YES" : "NO");
	if (loader) {
		DEBUG(@"cancelling load callback %@", loader);
		[loader cancel];
		loader = nil;
		code = 2; /* not loaded */
	} else if (![self isDocumentEdited])
		code = 0; /* saved */

	if (closeCallback)
		closeCallback(code);

	closed = YES;

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

	windowController = nil;
	hiddenView = nil;

	[[ViMarkManager sharedManager] removeStack:localMarks];

	[super close];
	[[ViEventManager defaultManager] emitDelayed:ViEventDidCloseDocument for:self with:self, nil];
	[[[ViEventManager defaultManager] nextRunloop] clearFor:self];

	[textStorage setDelegate:nil];
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

	// BOOL flag = [[(ViWindowController *)aWindowController documents] count] == 0;
	BOOL flag = NO;
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[delegate methodSignatureForSelector:shouldCloseSelector]];
	[invocation setSelector:shouldCloseSelector];
	[invocation setArgument:&self atIndex:2];
	[invocation setArgument:&flag atIndex:3];
	[invocation setArgument:&contextInfo atIndex:4];
	[invocation invokeWithTarget:delegate];

	if ([(ViWindowController *)aWindowController windowShouldClose:[aWindowController window]])
		[[aWindowController window] close];
}

#pragma mark -

- (void)endUndoGroup
{
	if (hasUndoGroup) {
		DEBUG(@"%s", "====================> Ending undo-group");
		[[self undoManager] endUndoGrouping];
		hasUndoGroup = NO;
	}
}

- (void)beginUndoGroup
{
	if (!hasUndoGroup) {
		DEBUG(@"%s", "====================> Beginning undo-group");
		[[self undoManager] beginUndoGrouping];
		hasUndoGroup = YES;
	}
}

#pragma mark -
#pragma mark Syntax parsing

- (NSDictionary *)defaultAttributes
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
		[theme foregroundColor], NSForegroundColorAttributeName,
		// [theme backgroundColor], NSBackgroundColorAttributeName,
		nil];
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
	if (matchingParenRange.location != NSNotFound)
		[self eachTextView:^(ViTextView *tv) {
			[[tv layoutManager] invalidateDisplayForCharacterRange:matchingParenRange];
		}];

	matchingParenRange = range;

	if (matchingParenRange.location != NSNotFound)
		[self eachTextView:^(ViTextView *tv) {
			[[tv layoutManager] invalidateDisplayForCharacterRange:matchingParenRange];
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

	NSArray *scopeArray = [syntaxParser scopeArray];
	if (charIndex >= [scopeArray count]) {
		*effectiveCharRange = NSMakeRange(charIndex, [textStorage length] - charIndex);
		return [self defaultAttributes];
	}

	ViScope *scope = [scopeArray objectAtIndex:charIndex];
	NSDictionary *attributes = [scope attributes];
	if ([attributes count] == 0) {
		attributes = [theme attributesForScope:scope inBundle:bundle];
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
	NSRange sel = snippet.selectedRange;

	if (NSIntersectionRange(r, sel).length > 0) {
		DEBUG(@"selected snippet range %@", NSStringFromRange(sel));
		if (sel.location > r.location)
			r.length = sel.location - r.location;
		else {
			if (mergedAttributes == nil)
				mergedAttributes = [[NSMutableDictionary alloc] initWithDictionary:attributes];
			[mergedAttributes setObject:[theme selectionColor]
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
	sel = matchingParenRange;

	if (NSIntersectionRange(r, sel).length > 0) {
		DEBUG(@"matching paren range %@", NSStringFromRange(sel));
		if (sel.location > r.location)
			r.length = sel.location - r.location;
		else {
			if (mergedAttributes == nil)
				mergedAttributes = [[NSMutableDictionary alloc] initWithDictionary:attributes];
			[mergedAttributes addEntriesFromDictionary:[theme smartPairMatchAttributes]];
			/*[mergedAttributes setObject:[NSNumber numberWithInteger:NSUnderlinePatternSolid | NSUnderlineStyleDouble]
					     forKey:NSUnderlineStyleAttributeName];
			[mergedAttributes setObject:[theme selectionColor]
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
	NSRange r = NSMakeRange(0, [textStorage length]);
	[self eachTextView:^(ViTextView *tv) {
		[[tv layoutManager] invalidateDisplayForCharacterRange:r];
	}];

	if (language == nil) {
		syntaxParser = nil;
		[self willChangeValueForKey:@"symbols"];
		[symbols removeAllObjects];
		[self didChangeValueForKey:@"symbols"];
		return;
	}

	/* Ditch the old syntax scopes and start with a fresh parser. */
	syntaxParser = [[ViSyntaxParser alloc] initWithLanguage:language];

	NSInteger endLocation = [textStorage locationForStartOfLine:100];
	if (endLocation == -1)
		endLocation = [textStorage length];

	[self dispatchSyntaxParserWithRange:NSMakeRange(0, endLocation) restarting:NO];
}

- (void)performSyntaxParsingWithContext:(ViSyntaxContext *)ctx
{
	NSRange range = ctx.range;
	unichar *chars = malloc(range.length * sizeof(unichar));
	DEBUG(@"allocated %u bytes, characters %p, range %@, length %u",
		range.length * sizeof(unichar), chars,
		NSStringFromRange(range), [textStorage length]);
	[[textStorage string] getCharacters:chars range:range];

	ctx.characters = chars;
	NSUInteger startLine = ctx.lineOffset;

	// unsigned endLine = [textStorage lineNumberAtLocation:NSMaxRange(range) - 1];
	// INFO(@"parsing line %u -> %u, range %@", startLine, endLine, NSStringFromRange(range));

	[syntaxParser parseContext:ctx];

	// Invalidate the layout(s).
	if (ctx.restarting) {
		[self eachTextView:^(ViTextView *tv) {
			[[tv layoutManager] invalidateDisplayForCharacterRange:range];
		}];
	}

	[self invalidateSymbolsInRange:range];

	if (ctx.lineOffset > startLine) {
		// INFO(@"line endings have changed at line %u", endLine);

		if (nextContext && nextContext != ctx) {
			if (nextContext.lineOffset < startLine) {
				DEBUG(@"letting previous scheduled parsing from line %u continue",
				    nextContext.lineOffset);
				return;
			}
			DEBUG(@"cancelling scheduled parsing from line %u (nextContext = %@)",
			    nextContext.lineOffset, nextContext);
			[nextContext setCancelled:YES];
		}

		nextContext = ctx;
		[self performSelector:@selector(restartSyntaxParsingWithContext:)
		           withObject:ctx
		           afterDelay:0.0025];
	}
}

- (void)dispatchSyntaxParserWithRange:(NSRange)aRange restarting:(BOOL)flag
{
	if (aRange.length == 0)
		return;

	NSUInteger line = [textStorage lineNumberAtLocation:aRange.location];
	DEBUG(@"dispatching from line %lu", line);
	ViSyntaxContext *ctx = [[ViSyntaxContext alloc] initWithLine:line];
	ctx.range = aRange;
	ctx.restarting = flag;

	[self performSyntaxParsingWithContext:ctx];
}

- (void)restartSyntaxParsingWithContext:(ViSyntaxContext *)context
{
	nextContext = nil;

	if (context.cancelled || closed) {
		DEBUG(@"context %@, from line %u, is cancelled", context, context.lineOffset);
		return;
	}

	NSInteger startLocation = [textStorage locationForStartOfLine:context.lineOffset];
	if (startLocation == -1)
		return;
	NSInteger endLocation = [textStorage locationForStartOfLine:context.lineOffset + 100];
	if (endLocation == -1)
		endLocation = [textStorage length];

	context.range = NSMakeRange(startLocation, endLocation - startLocation);
	context.restarting = YES;
	if (context.range.length > 0) {
		DEBUG(@"restarting parse context at line %u, range %@",
		    context.lineOffset, NSStringFromRange(context.range));
		[self performSyntaxParsingWithContext:context];
	}
}

- (ViLanguage *)language
{
	return language;
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
	NSInteger tmp = [[ViPreferencePaneEdit valueForKey:@"wrap" inScope:language.scope] integerValue];
	if (tmp != wrap) {
		wrap = tmp;
		[self setWrapping:wrap];
	}
}

- (void)updateTabSize
{
	NSInteger tmp = [[ViPreferencePaneEdit valueForKey:@"tabstop" inScope:language.scope] integerValue];
	if (tmp != tabSize) {
		tabSize = tmp;
		[self setTypingAttributes];
	}
}

- (void)setLanguage:(ViLanguage *)lang
{
	if ([textStorage lineCount] > 10000) {
		[self message:@"Disabling syntax highlighting for large document."];
		if (language) {
			[[ViEventManager defaultManager] emitDelayed:ViEventWillChangeSyntax for:self with:self, [NSNull null], nil];
			language = nil;
			[self updateTabSize];
			[self updateWrapping];
			[self setTypingAttributes];
			[self highlightEverything];
			[[ViEventManager defaultManager] emitDelayed:ViEventDidChangeSyntax for:self with:self, [NSNull null], nil];
		}
		return;
	}

	/* Force compilation. */
	[lang patterns];

	if (lang != language) {
		[[ViEventManager defaultManager] emitDelayed:ViEventWillChangeSyntax for:self with:self, lang ?: [NSNull null], nil];
		language = lang;
		bundle = [language bundle];
		symbolScopes = [[ViBundleStore defaultStore] preferenceItem:@"showInSymbolList"];
		symbolTransforms = [[ViBundleStore defaultStore] preferenceItem:@"symbolTransformation"];
		[self updateTabSize];
		[self updateWrapping];
		[self setTypingAttributes];
		[self highlightEverything];
		[[ViEventManager defaultManager] emitDelayed:ViEventDidChangeSyntax for:self with:self, lang ?: [NSNull null], nil];
	}
}

- (void)configureForURL:(NSURL *)aURL
{
	ViBundleStore *langStore = [ViBundleStore defaultStore];
	ViLanguage *newLanguage = nil;

	NSString *firstLine = nil;
	NSUInteger eol;
	[[textStorage string] getLineStart:NULL
				       end:NULL
			       contentsEnd:&eol
				  forRange:NSMakeRange(0, 0)];
	if (eol > 0)
		firstLine = [[textStorage string] substringWithRange:NSMakeRange(0, eol)];
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

	if (!ignoreEditing) {
		NSUInteger lineIndex = [[userInfo objectForKey:@"lineIndex"] unsignedIntegerValue];
		NSUInteger linesRemoved = [[userInfo objectForKey:@"linesRemoved"] unsignedIntegerValue];
		NSUInteger linesAdded = [[userInfo objectForKey:@"linesAdded"] unsignedIntegerValue];

		NSInteger diff = linesAdded - linesRemoved;
		if (diff == 0)
			return;

		if (diff > 0)
			[syntaxParser pushContinuations:diff fromLineNumber:lineIndex + 1];
		else
			[syntaxParser pullContinuations:-diff fromLineNumber:lineIndex + 1];
	}
}

- (void)textStorageDidProcessEditing:(NSNotification *)notification
{
	if (([textStorage editedMask] & NSTextStorageEditedCharacters) != NSTextStorageEditedCharacters)
		return;

	NSRange area = [textStorage editedRange];
	NSInteger diff = [textStorage changeInLength];

	if (ignoreEditing) {
		DEBUG(@"ignoring changes in area %@", NSStringFromRange(area));
		ignoreEditing = NO;
		return;
	}

	if (language == nil)
		return;

	/*
	 * Incrementally update the scope array.
	 */
	if (diff > 0)
		[syntaxParser pushScopes:NSMakeRange(area.location, diff)];
	else if (diff < 0)
		[syntaxParser pullScopes:NSMakeRange(area.location, -diff)];

	if (diff != 0) {
		[self pushSymbols:diff fromLocation:area.location];
		[self pushMarks:diff fromLocation:area.location];
		// FIXME: also push jumps
	}

	// emit (delayed) event to Nu
	[[ViEventManager defaultManager] emitDelayed:ViEventDidModifyDocument for:self with:self,
	    [NSValue valueWithRange:area],
	    [NSNumber numberWithInteger:diff],
	    nil];

	/*
	 * Extend our range along affected line boundaries and re-parse.
	 */
	NSUInteger bol, end, eol;
	[[textStorage string] getLineStart:&bol end:&end contentsEnd:&eol forRange:area];
	if (eol == area.location) {
		/* Change at EOL, include another line to make sure
		 * we get the line continuations right. */
		[[textStorage string] getLineStart:NULL
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

- (void)enableLineNumbers:(BOOL)flag forScrollView:(NSScrollView *)aScrollView
{
	if (flag) {
		ViRulerView *lineNumberView = [[ViRulerView alloc] initWithScrollView:aScrollView];
		[aScrollView setVerticalRulerView:lineNumberView];
		[aScrollView setHasHorizontalRuler:NO];
		[aScrollView setHasVerticalRuler:YES];
		[aScrollView setRulersVisible:YES];
	} else
		[aScrollView setRulersVisible:NO];
}

- (void)enableLineNumbers:(BOOL)flag
{
	[self eachTextView:^(ViTextView *tv) {
		[self enableLineNumbers:flag forScrollView:[tv enclosingScrollView]];
	}];
}

- (IBAction)toggleLineNumbers:(id)sender
{
	[self enableLineNumbers:[sender state] == NSOffState];
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
	if (typingAttributes == nil)
		[self setTypingAttributes];
	return typingAttributes;
}

- (void)setTypingAttributes
{
	NSString *tab = [@"" stringByPaddingToLength:tabSize withString:@" " startingAtIndex:0];

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

	if ([[ViPreferencePaneEdit valueForKey:@"linebreak" inScope:language.scope] boolValue])
		[style setLineBreakMode:NSLineBreakByWordWrapping];
	else
		[style setLineBreakMode:NSLineBreakByCharWrapping];

	typingAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
	    style, NSParagraphStyleAttributeName,
	    [ViThemeStore font], NSFontAttributeName,
	    nil];

	NSRange r = NSMakeRange(0, [textStorage length]);
	[textStorage setAttributes:typingAttributes range:r];

	[self eachTextView:^(ViTextView *tv) {
		[(ViRulerView *)[[tv enclosingScrollView] verticalRulerView] resetTextAttributes];
	}];
}

- (void)changeTheme:(ViTheme *)aTheme
{
	theme = aTheme;

	/* Reset the cached attributes.
	 */
	NSArray *scopeArray = [syntaxParser scopeArray];
	NSUInteger i;
	for (i = 0; i < [scopeArray count];) {
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
		[windowController message:fmt arguments:ap];
		va_end(ap);
	}
}

#pragma mark -
#pragma mark Symbol List

- (NSUInteger)filterSymbols:(ViRegexp *)rx
{
	NSMutableArray *fs = [[NSMutableArray alloc] initWithCapacity:[symbols count]];
	for (ViSymbol *s in symbols)
		if ([rx matchInString:[s symbol]])
			[fs addObject:s];
	[self setFilteredSymbols:fs];
	return [fs count];
}

- (NSImage *)matchSymbolIconForScope:(ViScope *)scope
{
	NSString *scopeSelector = [scope bestMatch:[symbolIcons allKeys]];
	if (scopeSelector)
		return [NSImage imageNamed:[symbolIcons objectForKey:scopeSelector]];
	return nil;
}

- (void)invalidateSymbolsInRange:(NSRange)updateRange
{
	NSString *string = [textStorage string];
	NSArray *scopeArray = [syntaxParser scopeArray];
	DEBUG(@"invalidate symbols in range %@", NSStringFromRange(updateRange));

	NSString *lastSelector = nil;
	NSImage *img = nil;
	NSRange wholeRange;

	[self willChangeValueForKey:@"symbols"];

	NSUInteger maxRange = NSMaxRange(updateRange);

	NSUInteger i;
	/* Remove old symbols in the range. Assumes the symbols are sorted on location. */
	for (i = 0; i < [symbols count];) {
		ViSymbol *sym = [symbols objectAtIndex:i];
		NSRange r = sym.range;
		if (r.location > maxRange)
			/* we're past our range */
			break;
		if (NSMaxRange(r) <= updateRange.location)
			/* the symbol doesn't intersect the range */
			i++;
		else {
			DEBUG(@"remove symbol %@", sym);
			[symbols removeObjectAtIndex:i];
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
				NSString *transform = [symbolTransforms objectForKey:lastSelector];
				if (transform) {
					ViSymbolTransform *tr = [[ViSymbolTransform alloc]
					    initWithTransformationString:transform];
					symbol = [tr transformSymbol:symbol];
				}

				ViSymbol *sym = [[ViSymbol alloc] initWithSymbol:symbol
									document:self
									   range:wholeRange
									   image:img];
				DEBUG(@"adding symbol %@", sym);
				[symbols addObject:sym];
			}
			lastSelector = nil;

			for (NSString *scopeSelector in symbolScopes) {
				if ([scopeSelector match:scope] > 0) {
					lastSelector = scopeSelector;
					NSRange backRange = [self rangeOfScopeSelector:scopeSelector forward:NO fromLocation:i];
					if (backRange.length > 0) {
						DEBUG(@"EXTENDED WITH backRange = %@ from %@", NSStringFromRange(backRange), NSStringFromRange(range));
						wholeRange = NSUnionRange(range, backRange);
					} else
						wholeRange = range;
					img = [self matchSymbolIconForScope:scope];
					break;
				}
			}
		}

		i = NSMaxRange(range);
	}

	[symbols sortUsingComparator:^(id obj1, id obj2) {
		ViSymbol *sym1 = obj1, *sym2 = obj2;
		return (NSComparisonResult)(sym1.range.location - sym2.range.location);
	}];

	if ([symbols count] > 0) {
		// XXX: remove duplicates, ie hide bugs
		NSUInteger i;
		NSUInteger prevLocation = ((ViSymbol *)[symbols objectAtIndex:0]).range.location;
		for (i = 1; i < [symbols count];) {
			ViSymbol *sym = [symbols objectAtIndex:i];
			if (sym.range.location == prevLocation)
				[symbols removeObjectAtIndex:i];
			else {
				i++;
				prevLocation = sym.range.location;
			}
		}
	}

	[self didChangeValueForKey:@"symbols"];
}

- (void)pushSymbols:(NSInteger)delta fromLocation:(NSUInteger)location
{
	DEBUG(@"pushing symbols from %lu", location);
	[self willChangeValueForKey:@"symbols"];
	for (NSUInteger i = 0; i < [symbols count];) {
		ViSymbol *sym = [symbols objectAtIndex:i];
		NSRange r = sym.range;
		if (delta < 0) {
			NSRange deletedRange = NSMakeRange(location, -delta);
			if (r.location < location) {
				/* the symbol isn't contained in the range */
				i++;
			} else if (NSIntersectionRange(deletedRange, r).length > 0) {
				DEBUG(@"remove symbol %@", sym);
				[symbols removeObjectAtIndex:i];
			} else {
				/* we're past our range */
				r.location += delta;
				DEBUG(@"pushing symbol %@ to %@", sym, NSStringFromRange(r));
				sym.range = r;
				i++;
			}
		} else { /* delta > 0 */
			if (r.location >= location) {
				r.location += delta;
				DEBUG(@"pushing symbol %@ to %@", sym, NSStringFromRange(r));
				sym.range = r;
				i++;
			/*} else if (NSMaxRange(r) >= location) {
				DEBUG(@"remove symbol %@", sym);
				[symbols removeObjectAtIndex:i];*/
			} else {
				/* the symbol doesn't intersect the range */
				i++;
			}
		}
	}
	[self didChangeValueForKey:@"symbols"];
}

#pragma mark Marks
#pragma mark -

- (ViMark *)markNamed:(unichar)key
{
	NSString *name = [NSString stringWithFormat:@"%C", key];
	if ([name isUppercase])
		return [[[ViMarkManager sharedManager] stackWithName:@"Global Marks"].list lookup:name];
	return [localMarks.list lookup:name];
}

- (void)setMark:(unichar)key atLocation:(NSUInteger)aLocation
{
	NSString *name = [NSString stringWithFormat:@"%C", key];
	ViMark *m = [localMarks.list lookup:name];
	if (m)
		[m setLocation:aLocation];
	else {
		m = [ViMark markWithDocument:self name:name location:aLocation];
		[localMarks.list addMark:m];
	}

	if ([name isUppercase])
		[[[ViMarkManager sharedManager] stackWithName:@"Global Marks"].list addMark:m];
}

- (void)pushMarks:(NSInteger)delta fromLocation:(NSUInteger)location
{
	DEBUG(@"pushing marks from %lu", location);
	NSMutableSet *toDelete = nil;
	for (ViMark *mark in localMarks.list.marks) {
		NSRange r = mark.range;
		if (delta < 0) {
			NSRange deletedRange = NSMakeRange(location, -delta);
			if (r.location < location) {
				/* the symbol isn't contained in the range */
			} else if (NSIntersectionRange(deletedRange, r).length > 0) {
				DEBUG(@"remove mark %@", mark);
				if (toDelete == nil)
					toDelete = [NSMutableSet set];
				[toDelete addObject:mark];
			} else {
				/* we're past our range */
				r.location += delta;
				DEBUG(@"pushing mark %@ to %@", mark, NSStringFromRange(r));
				[mark setRange:r];
			}
		} else { /* delta > 0 */
			if (r.location >= location) {
				r.location += delta;
				DEBUG(@"pushing mark %@ to %@", mark, NSStringFromRange(r));
				[mark setRange:r];
			/*} else if (NSMaxRange(r) >= location) {
				DEBUG(@"remove symbol %@", sym);
				[symbols removeObjectAtIndex:i];*/
			} else {
				/* the symbol doesn't intersect the range */
			}
		}
	}

	for (ViMark *mark in toDelete)
		[localMarks.list removeMark:mark];
}

#pragma mark -

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViDocument %p: %@>", self, [self fileURL] ?: [self displayName]];
}

- (ViScope *)scopeAtLocation:(NSUInteger)aLocation
{
	NSArray *scopeArray = [syntaxParser scopeArray];
	if ([scopeArray count] > aLocation)
		return [scopeArray objectAtIndex:aLocation];
	return [self language].scope;
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
		if (forward && i >= [textStorage length])
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
                                                                                    relativeTo:windowController.baseURL
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
			[deferred waitInWindow:[windowController window]
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
	ViRegexp *rx = [[ViRegexp alloc] initWithString:pattern];
	NSMutableSet *matches = [NSMutableSet set];
	for (ViLanguage *lang in [[ViBundleStore defaultStore] languages]) {
		if ([[lang name] isEqualToString:langScope]) {
			/* full match */
			[matches removeAllObjects];
			[matches addObject:lang];
			break;
		} else if ([rx matchesString:[lang name]]) {
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

