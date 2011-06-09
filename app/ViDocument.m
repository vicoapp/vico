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
#import "ExEnvironment.h"
#import "ViScope.h"
#import "ViSymbolTransform.h"
#import "ViThemeStore.h"
#import "SFTPConnection.h" /* Only for SSH2_FX_NO_SUCH_FILE constant. */
#import "ViLayoutManager.h"
#import "ViError.h"
#import "NSObject+SPInvocationGrabbing.h"
#import "ViAppController.h"
#import "ViPreferencePaneEdit.h"

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
- (void)updateTabSize;
- (void)updateWrapping;
@end

@implementation ViDocument

@synthesize symbols;
@synthesize filteredSymbols;
@synthesize views;
@synthesize bundle;
@synthesize encoding;
@synthesize isTemporary;
@synthesize snippet;
@synthesize proxy;
@synthesize busy;
@synthesize loader;
@synthesize closeCallback;

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

		NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
		[userDefaults addObserver:self forKeyPath:@"number" options:0 context:NULL];
		[userDefaults addObserver:self forKeyPath:@"tabstop" options:0 context:NULL];
		[userDefaults addObserver:self forKeyPath:@"fontsize" options:0 context:NULL];
		[userDefaults addObserver:self forKeyPath:@"fontname" options:0 context:NULL];
		[userDefaults addObserver:self forKeyPath:@"wrap" options:0 context:NULL];
		[userDefaults addObserver:self forKeyPath:@"list" options:0 context:NULL];

		sym_q = dispatch_queue_create("se.bzero.vico.sym", NULL);

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

		proxy = [[ViScriptProxy alloc] initWithObject:self];
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
			[proxy emitDelayed:@"didLoad" with:self, nil];
			[self message:@"%@: %lu lines", [self title], [textStorage lineCount]];

			for (ViDocumentView *dv in views) {
				ViTextView *tv = [dv textView];
				[tv documentDidLoad:self];
			}
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

	if (outError)
		*outError = returnError;

	return returnError == nil ? YES : NO;
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

- (void)finalize
{
	dispatch_release(sym_q);
	[super finalize];
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
		   [keyPath isEqualToString:@"fontname"])
		[self setTypingAttributes];
	else if ([keyPath isEqualToString:@"list"]) {
		for (ViDocumentView *dv in views) {
			ViLayoutManager *lm = (ViLayoutManager *)[[dv textView] layoutManager];
			[lm setShowsInvisibleCharacters:[userDefaults boolForKey:@"list"]];
			[lm invalidateDisplayForCharacterRange:NSMakeRange(0, [textStorage length])];
		}
	}
}

- (void)editPreferenceChanged:(NSNotification *)notification
{
	if (language == nil)
		return;

	NSDictionary *info = [notification userInfo];

	if ([[info objectForKey:@"key"] isEqualToString:@"wrap"]) {
		[self updateWrapping];
		return;
	}

	if ([[info objectForKey:@"key"] isEqualToString:@"tabstop"]) {
		[self updateTabSize];
		return;
	}
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

- (ViDocumentView *)makeViewInWindow:(NSWindow *)aWindow
{
	if (hiddenView) {
		hiddenView.window = aWindow;
		return hiddenView;
	}

	ViDocumentView *documentView = [[ViDocumentView alloc] initWithDocument:self];
	[NSBundle loadNibNamed:@"ViDocument" owner:documentView];
	[self addView:documentView];

	documentView.window = aWindow;

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

	return documentView;
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
				[proxy emit:@"didSave" with:self, nil];
			}

			if (isTemporary)
				[[ViURLManager defaultManager] notifyChangedDirectoryAtURL:[normalizedURL URLByDeletingLastPathComponent]];
			isTemporary = NO;
		}
	}];

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
	return [self writeSafelyToURL:absoluteURL
			       ofType:typeName
		     forSaveOperation:saveOperation
				error:outError];
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
	[self configureSyntax];

	/* Force incremental syntax parsing. */
	[self highlightEverything];
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
		return [NSString stringWithFormat:@"• %@", displayName];

	return displayName;
}

- (void)updateChangeCount:(NSDocumentChangeType)changeType
{
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

	[self willChangeValueForKey:@"title"];
	[super setFileURL:absoluteURL];
	[self didChangeValueForKey:@"title"];
	[self configureSyntax];
	[proxy emitDelayed:@"changedURL" with:self, absoluteURL, nil];
}

- (ViWindowController *)windowController
{
	return windowController;
}

- (void)closeAndWindow:(BOOL)canCloseWindow
{
	int code = 1; /* not saved */

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
	[windowController closeDocument:self andWindow:canCloseWindow];

	/* Remove the window controller so the document doesn't automatically
	 * close the window.
	 */
	[self removeWindowController:windowController];
	[super close];
	[proxy emitDelayed:@"didClose" with:self, nil];
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

	if ([aWindowController windowShouldClose:[aWindowController window]])
		[[aWindowController window] close];
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
	for (ViDocumentView *dv in views) {
		ViTextView *tv = [dv textView];
		if ([tv isKindOfClass:[ViTextView class]])
			[tv invalidateCaretRect];
	}
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
                attributes = [theme attributesForScopes:[scope scopes] inBundle:bundle];
                if ([attributes count] == 0)
                        attributes = [self defaultAttributes];
                [scope setAttributes:attributes];
        }

        NSRange r = [scope range];
        if (r.location < charIndex) {
                DEBUG(@"index = %u, r = %@", charIndex, NSStringFromRange(r));
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

        return mergedAttributes ?: attributes;
}

- (void)highlightEverything
{
	/* Invalidate all document views. */
	NSRange r = NSMakeRange(0, [textStorage length]);
	for (ViDocumentView *dv in views)
		[[[dv textView] layoutManager] invalidateDisplayForCharacterRange:r];

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
	if (ctx.restarting)
		for (ViDocumentView *dv in views)
			[[[dv textView] layoutManager] invalidateDisplayForCharacterRange:range];

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
	if (context.range.length > 0)
	{
		DEBUG(@"restarting parse context at line %u, range %@",
		    startLocation, NSStringFromRange(context.range));
		[self performSyntaxParsingWithContext:context];
	}
}

- (ViLanguage *)language
{
	return language;
}

- (IBAction)setLanguageAction:(id)sender
{
	ViLanguage *lang = [sender representedObject];
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

- (void)updateWrapping
{
	NSInteger tmp = [[ViPreferencePaneEdit valueForKey:@"wrap" inScope:[language name]] integerValue];
	if (tmp != wrap) {
		INFO(@"wrap changed from %li -> %li", wrap, tmp);
		wrap = tmp;
		[self setWrapping:wrap];
	}
}

- (void)updateTabSize
{
	NSInteger tmp = [[ViPreferencePaneEdit valueForKey:@"tabstop" inScope:[language name]] integerValue];
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
			language = nil;
			[self updateTabSize];
			[self updateWrapping];
			[self highlightEverything];
		}
		return;
	}

	/* Force compilation. */
	[lang patterns];

	if (lang != language) {
		language = lang;
		bundle = [language bundle];
		symbolScopes = [[ViBundleStore defaultStore] preferenceItem:@"showInSymbolList"];
		symbolTransforms = [[ViBundleStore defaultStore] preferenceItem:@"symbolTransformation"];
		[self updateTabSize];
		[self updateWrapping];
		[self highlightEverything];
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
	if (diff > 0) {
		[syntaxParser pushScopes:NSMakeRange(area.location, diff)];
		// FIXME: also push jumps and marks
	} else if (diff < 0) {
		[syntaxParser pullScopes:NSMakeRange(area.location, -diff)];
		// FIXME: also pull jumps and marks
	}

	if (diff != 0)
		[self pushSymbols:diff fromLocation:area.location];

	// emit (delayed) event to javascript
	[proxy emitDelayed:@"modify" with:self,
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
	ViDocumentView *dv;
	for (dv in views)
		[self enableLineNumbers:flag forScrollView:[[dv textView] enclosingScrollView]];
}

- (IBAction)toggleLineNumbers:(id)sender
{
	[self enableLineNumbers:[sender state] == NSOffState];
}

#pragma mark -
#pragma mark Other interesting stuff

- (void)setWrapping:(BOOL)flag
{
	ViDocumentView *dv;
	for (dv in views)
		[[dv textView] setWrapping:flag];
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

	typingAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
	    style, NSParagraphStyleAttributeName,
	    [ViThemeStore font], NSFontAttributeName,
	    nil];

	NSRange r = NSMakeRange(0, [textStorage length]);
	[textStorage setAttributes:typingAttributes range:r];
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

	for (ViDocumentView *dv in views)
		[[dv textView] setPageGuide:pageGuideColumn];
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

- (ExEnvironment *)environment
{
	return [windowController environment];
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

- (NSImage *)matchSymbolIconForScope:(NSArray *)scopes
{
	NSString *scopeSelector = [[symbolIcons allKeys] bestMatchForScopes:scopes];
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
		ViScope *s = [scopeArray objectAtIndex:i];
		NSArray *scopes = s.scopes;
		NSRange range = s.range;

		if ([lastSelector matchesScopes:scopes]) {
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
				if ([scopeSelector matchesScopes:scopes]) {
					lastSelector = scopeSelector;
					NSRange backRange = [self rangeOfScopeSelector:scopeSelector forward:NO fromLocation:i];
					if (backRange.length > 0) {
						DEBUG(@"EXTENDED WITH backRange = %@ from %@", NSStringFromRange(backRange), NSStringFromRange(range));
						wholeRange = NSUnionRange(range, backRange);
					} else
						wholeRange = range;
					img = [self matchSymbolIconForScope:scopes];
					break;
				}
			}
		}

		i += range.length;
	}

	[symbols sortUsingComparator:^(id obj1, id obj2) {
		ViSymbol *sym1 = obj1, *sym2 = obj2;
		return (NSComparisonResult)(sym1.range.location - sym2.range.location);
	}];

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

#pragma mark -

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViDocument %p: %@>", self, [self fileURL]];
}

- (NSArray *)scopesAtLocation:(NSUInteger)aLocation
{
	if (aLocation >= [textStorage length]) {
		/* use document scope at EOF */
		DEBUG(@"document language is %@ (%@)", [self language], [[self language] name]);
		NSString *scope = [[self language] name];
		return scope ? [NSArray arrayWithObject:scope] : nil;
	}

	return [[self scopeAtLocation:aLocation] scopes];
}

- (ViScope *)scopeAtLocation:(NSUInteger)aLocation
{
	NSArray *scopeArray = [syntaxParser scopeArray];
	if ([scopeArray count] > aLocation)
		return [scopeArray objectAtIndex:aLocation];
	return nil;
}

- (NSString *)bestMatchingScope:(NSArray *)scopeSelectors
                    atLocation:(NSUInteger)aLocation
{
	NSArray *scopes = [self scopesAtLocation:aLocation];
	return [scopeSelectors bestMatchForScopes:scopes];
}

- (NSRange)rangeOfScopeSelector:(NSString *)scopeSelector
                        forward:(BOOL)forward
                   fromLocation:(NSUInteger)aLocation
{
	NSArray *lastScopes = nil, *scopes;
	NSUInteger i = aLocation;
	for (;;) {
		if (forward && i >= [textStorage length])
			break;
		else if (!forward && i == 0)
			break;

		if (!forward)
			i--;

		if ((scopes = [self scopesAtLocation:i]) == nil)
			break;

		if (lastScopes != scopes && ![scopeSelector matchesScopes:scopes]) {
			if (!forward)
				i++;
			break;
		}

		if (forward)
			i++;

		lastScopes = scopes;
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

@end

