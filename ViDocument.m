#include <sys/time.h>

#import "ViDocument.h"
#import "ViDocumentView.h"
#import "ViLanguageStore.h"
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
#import "SFTPConnectionPool.h"
#import "ViLayoutManager.h"
#import "ViError.h"
#import "NSObject+SPInvocationGrabbing.h"

BOOL makeNewWindowInsteadOfTab = NO;

@interface ViDocument (internal)
- (void)highlightEverything;
- (void)setWrapping:(BOOL)flag;
- (void)enableLineNumbers:(BOOL)flag forScrollView:(NSScrollView *)aScrollView;
- (void)enableLineNumbers:(BOOL)flag;
- (void)setTypingAttributes;
- (NSDictionary *)typingAttributes;
@end

@implementation ViDocument

@synthesize symbols;
@synthesize filteredSymbols;
@synthesize views;
@synthesize bundle;
@synthesize encoding;
@synthesize jumpList;
@synthesize isTemporary;
@synthesize snippet;
@synthesize proxy;

- (id)init
{
	self = [super init];
	if (self) {
		symbols = [NSArray array];
		views = [NSMutableArray array];

		NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
		[userDefaults addObserver:self forKeyPath:@"number" options:0 context:NULL];
		[userDefaults addObserver:self forKeyPath:@"tabstop" options:0 context:NULL];
		[userDefaults addObserver:self forKeyPath:@"fontsize" options:0 context:NULL];
		[userDefaults addObserver:self forKeyPath:@"fontname" options:0 context:NULL];
		[userDefaults addObserver:self forKeyPath:@"wrap" options:0 context:NULL];
		[userDefaults addObserver:self forKeyPath:@"list" options:0 context:NULL];

		sym_q = dispatch_queue_create("se.bzero.vibrant.sym", NULL);

		textStorage = [[ViTextStorage alloc] init];
		[textStorage setDelegate:self];

		[[NSNotificationCenter defaultCenter] addObserver:self
							 selector:@selector(textStorageDidChangeLines:)
							     name:ViTextStorageChangedLinesNotification 
							   object:textStorage];

		NSString *symbolIconsFile = [[NSBundle mainBundle] pathForResource:@"symbol-icons"
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

- (void)finalize
{
	dispatch_release(sym_q);
	[super finalize];
}

- (NSDictionary *)proxyForJson
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
	    [self fileURL], @"fileURL",
	    [[self language] name], @"language",
	    nil];
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
		[self setWrapping:[userDefaults boolForKey:keyPath]];
	else if ([keyPath isEqualToString:@"tabstop"] ||
		 [keyPath isEqualToString:@"fontsize"] ||
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

#pragma mark -
#pragma mark NSDocument interface

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
	[views removeObject:aDocumentView];
}

- (void)addView:(ViDocumentView *)aDocumentView
{
	[views addObject:aDocumentView];
}

- (ViDocumentView *)makeView
{
	ViDocumentView *documentView = [[ViDocumentView alloc] initWithDocument:self];
	[NSBundle loadNibNamed:@"ViDocument" owner:documentView];
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

	[textView initEditorWithDelegate:self viParser:[windowController parser]];

	[self enableLineNumbers:[userDefaults boolForKey:@"number"]
	          forScrollView:[textView enclosingScrollView]];
	[self updatePageGuide];

	return documentView;
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
	NSStringEncoding enc = encoding;
	if (retrySaveOperation)
		enc = NSUTF8StringEncoding;
	DEBUG(@"using encoding %@", [NSString localizedNameOfStringEncoding:enc]);
	return [[textStorage string] dataUsingEncoding:enc];
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

- (BOOL)writeSafelyToURL:(NSURL *)url
                  ofType:(NSString *)typeName
        forSaveOperation:(NSSaveOperationType)saveOperation
                   error:(NSError **)outError
{
	BOOL ret = NO;

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
				*outError = [NSError errorWithDomain:NSCocoaErrorDomain
				                                code:NSUserCancelledError
				                            userInfo:nil];
			return NO;
		}

		if (saveOperation == NSSaveOperation || saveOperation == NSSaveAsOperation)
			encoding = NSUTF8StringEncoding;
	}

	if ([url isFileURL]) {
		ret = [super writeSafelyToURL:url
		                       ofType:typeName
		             forSaveOperation:saveOperation
		                        error:outError];
		if (ret) {
			isTemporary = NO;
			[proxy emit:@"didSave" with:self, nil];
		}
		return ret;
	}

	if (![[url scheme] isEqualToString:@"sftp"]) {
		INFO(@"unsupported URL scheme: %@", [url scheme]);
		// XXX: set outError
		return NO;
	}

	NSData *data = [self dataOfType:typeName error:nil];
	if (data == nil)
		/* Should not happen. We've already checked for encoding problems. */
		return NO;

	SFTPConnection *conn = [[SFTPConnectionPool sharedPool] connectionWithURL:url
	                                                                    error:outError];
	if (conn == nil)
		return NO;
	ret = [conn writeData:data toFile:[url path] error:outError];
	if (ret) {
		[proxy emit:@"didSave" with:self, nil];
		isTemporary = NO;
	}
	return ret;
}

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError
{
	DEBUG(@"type = %@, url = %@, scheme = %@", typeName, [url absoluteString], [url scheme]);

	NSData *data = nil;
	if ([url isFileURL])
		data = [NSData dataWithContentsOfFile:[url path] options:0 error:outError];
	else if ([[url scheme] isEqualToString:@"sftp"]) {
		if ([url host] == nil) {
			if (outError)
				*outError = [ViError errorWithFormat:@"Missing host in URL."];
			return NO;
		}

		SFTPConnection *conn = [[SFTPConnectionPool sharedPool] connectionWithURL:url error:outError];
		if (conn == nil)
			return NO;
		data = [conn dataWithContentsOfFile:[url path] error:outError];
	}

	if (data == nil)
		return NO;

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
	} else {
		/* Check for a user-overridden encoding in preferences. */
		NSDictionary *encodingOverride = [userDefaults dictionaryForKey:@"encodingOverride"];
		NSNumber *savedEncoding = [encodingOverride objectForKey:[[self fileURL] absoluteString]];
		if (savedEncoding) {
			encoding = [savedEncoding unsignedIntegerValue];
			aString = [[NSString alloc] initWithData:data encoding:encoding];
		}

		if (aString == nil) {
			/* Try to auto-detect the encoding. */
			encoding = [[ViCharsetDetector defaultDetector] encodingForData:data];
			if (encoding == 0)
				/* Try UTF-8 if auto-detecting fails. */
				encoding = NSUTF8StringEncoding;
			aString = [[NSString alloc] initWithData:data encoding:encoding];
			if (aString == nil) {
				/* If all else fails, use iso-8859-1. */
				encoding = NSISOLatin1StringEncoding;
				aString = [[NSString alloc] initWithData:data encoding:encoding];
			}
		}
	}

	[self setString:aString];

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

	[proxy emitDelayed:@"didLoad" with:self, nil];
}

- (void)setEncoding:(id)sender
{
	forcedEncoding = [[sender representedObject] unsignedIntegerValue];
	[self revertDocumentToSaved:nil];
}

- (NSString *)title
{
	return [self displayName];
}

- (void)setFileURL:(NSURL *)absoluteURL
{
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

- (void)close
{
	closed = YES;
	[windowController closeDocument:self];

	/* Remove the window controller so the document doesn't automatically
	 * close the window.
	 */
	[self removeWindowController:windowController];
	[super close];
	[proxy emitDelayed:@"didClose" with:self, nil];
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
		[self setSymbols:nil];
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
	unsigned startLine = ctx.lineOffset;

	// unsigned endLine = [textStorage lineNumberAtLocation:NSMaxRange(range) - 1];
	// INFO(@"parsing line %u -> %u, range %@", startLine, endLine, NSStringFromRange(range));

	[syntaxParser parseContext:ctx];

	// Invalidate the layout(s).
	if (ctx.restarting)
		for (ViDocumentView *dv in views)
			[[[dv textView] layoutManager] invalidateDisplayForCharacterRange:range];

	[updateSymbolsTimer invalidate];
	NSDate *fireDate = [NSDate dateWithTimeIntervalSinceNow:updateSymbolsTimer == nil ? 0 : 0.4];
	updateSymbolsTimer = [[NSTimer alloc] initWithFireDate:fireDate
						      interval:0
							target:self
						      selector:@selector(updateSymbolList:)
						      userInfo:nil
						       repeats:NO];
	[[NSRunLoop currentRunLoop] addTimer:updateSymbolsTimer
	                             forMode:NSDefaultRunLoopMode];

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

	unsigned line = [textStorage lineNumberAtLocation:aRange.location];
	DEBUG(@"dispatching from line %u", line);
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
	NSInteger endLocation = [textStorage locationForStartOfLine:context.lineOffset + 50];
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

- (void)setLanguage:(ViLanguage *)lang
{
	if ([textStorage lineCount] > 10000) {
		[self message:@"Disabling syntax highlighting for large document."];
		if (language) {
			language = nil;
			[self highlightEverything];
		}
		return;
	}

	/* Force compilation. */
	[lang patterns];

	if (lang != language) {
		language = lang;
		bundle = [language bundle];
		symbolScopes = [[ViLanguageStore defaultStore] preferenceItem:@"showInSymbolList"];
		symbolTransforms = [[ViLanguageStore defaultStore] preferenceItem:@"symbolTransformation"];
		[self highlightEverything];
	}
}

- (void)configureForURL:(NSURL *)aURL
{
	ViLanguageStore *langStore = [ViLanguageStore defaultStore];
	ViLanguage *newLanguage = nil;
	if (aURL) {
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
		if (newLanguage == nil)
			newLanguage = [langStore languageForFilename:[aURL path]];
	}

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
		ViLanguage *lang = [[ViLanguageStore defaultStore] languageWithScope:syntax];
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

	NSUInteger len = [textStorage length];
	for (ViDocumentView *dv in views) {
		ViTextView *tv = [dv textView];
		if ([tv caret] > len)
			[[tv nextRunloop] setCaret:len];
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

	// emit (delayed) event to javascript
	[proxy emitDelayed:@"modify" with:self,
	    [NSValue valueWithRange:area],
	    [NSNumber numberWithInteger:diff],
	    nil];

	/*
	 * Extend our range along affected line boundaries and re-parse.
	 */
	NSUInteger bol, end, eol;
	NSRange prevRange = area;
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

- (NSFont *)font
{
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSFont *font = [NSFont fontWithName:[defs stringForKey:@"fontname"]
	                               size:[defs floatForKey:@"fontsize"]];
	if (font == nil)
		font = [NSFont userFixedPitchFontOfSize:11.0];
	return font;
}

- (NSDictionary *)typingAttributes
{
	if (typingAttributes == nil)
		[self setTypingAttributes];
	return typingAttributes;
}

- (void)setTypingAttributes
{
	int tabSize = [[NSUserDefaults standardUserDefaults] integerForKey:@"tabstop"];
	NSString *tab = [@"" stringByPaddingToLength:tabSize withString:@" " startingAtIndex:0];

	NSDictionary *attrs = [NSDictionary dictionaryWithObject:[self font]
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
	    [self font], NSFontAttributeName,
	    nil];
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

	/* Change the theme and invalidate all layout.
	 */
	for (ViDocumentView *dv in views) {
		[[dv textView] setTheme:theme];
		ViLayoutManager *lm = (ViLayoutManager *)[[dv textView] layoutManager];
		[lm setInvisiblesAttributes:[theme invisiblesAttributes]];
		[lm invalidateDisplayForCharacterRange:NSMakeRange(0, [textStorage length])];
	}
}

- (void)updatePageGuide
{
	int pageGuideColumn = 0;
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	if ([defs boolForKey:@"showguide"] == NSOnState)
		pageGuideColumn = [defs integerForKey:@"guidecolumn"];

	for (ViDocumentView *dv in views)
		[[dv textView] setPageGuide:pageGuideColumn];
}

#pragma mark -
#pragma mark ViTextView delegate methods

- (void)message:(NSString *)fmt, ...
{
	va_list ap;
	va_start(ap, fmt);
	[[windowController environment] message:fmt arguments:ap];
	va_end(ap);
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
	ViSymbol *s;
	for (s in symbols)
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

- (void)updateSymbolList:(NSTimer *)timer
{
	NSString *string = [[textStorage string] copy];
	NSMutableArray *scopeArray = [[NSMutableArray alloc] initWithArray:[syntaxParser scopeArray]
	                                                         copyItems:YES];

	dispatch_async(sym_q, ^{

		NSString *lastSelector = nil;
		NSImage *img = nil;
		NSRange wholeRange;

#if 0
		struct timeval start;
		struct timeval stop;
		struct timeval diff;
		gettimeofday(&start, NULL);
#endif

		NSMutableArray *syms = [[NSMutableArray alloc] init];

		NSUInteger i;
		for (i = 0; i < [scopeArray count];)
		{
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
										   range:wholeRange
										   image:img];
					[syms addObject:sym];
				}
				lastSelector = nil;

				for (NSString *scopeSelector in symbolScopes) {
					if ([scopeSelector matchesScopes:scopes]) {
						lastSelector = scopeSelector;
						wholeRange = range;
						img = [self matchSymbolIconForScope:scopes];
						break;
					}
				}
			}

			i += range.length;
		}

#if 0
		gettimeofday(&stop, NULL);
		timersub(&stop, &start, &diff);
		unsigned ms = diff.tv_sec * 1000 + diff.tv_usec / 1000;
		INFO(@"updated %u symbols => %.3f s", [symbols count], (float)ms / 1000.0);
#endif

		dispatch_sync(dispatch_get_main_queue(), ^{
			[self setSymbols:syms];
		});
	});
}

#pragma mark -

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViDocument %p: %@>", self, [self fileURL]];
}

- (NSArray *)scopesAtLocation:(NSUInteger)aLocation
{
	NSArray *scopeArray = [syntaxParser scopeArray];
	if ([scopeArray count] > aLocation)
		return [[scopeArray objectAtIndex:aLocation] scopes];
	return nil;
}

@end

