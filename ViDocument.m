#include <sys/time.h>

#import "ViDocument.h"
#import "ViDocumentView.h"
#import "ViLanguageStore.h"
#import "ViCharsetDetector.h"
#import "NSTextStorage-additions.h"
#import "NSString-additions.h"
#import "NSString-scopeSelector.h"
#import "NSArray-patterns.h"

#import "ViScope.h"
#import "ViSymbolTransform.h"
#import "ViThemeStore.h"
#import "SFTPConnectionPool.h"

#import "NoodleLineNumberView.h"
#import "NoodleLineNumberMarker.h"
#import "MarkerLineNumberView.h"

BOOL makeNewWindowInsteadOfTab = NO;

@interface ViDocument (internal)
- (void)resetTypingAttributes;
- (void)highlightEverything;
- (void)setWrapping:(BOOL)flag;
@end

@implementation ViDocument

@synthesize symbols;
@synthesize filteredSymbols;
@synthesize views;
@synthesize visibleViews;
@synthesize activeSnippet;
@synthesize encoding;

- (id)init
{
	self = [super init];
	if (self)
	{
		symbols = [NSArray array];
		views = [[NSMutableArray alloc] init];
		exCommandHistory = [[NSMutableArray alloc] init];

		[[NSUserDefaults standardUserDefaults] addObserver:self
							forKeyPath:@"number"
							   options:NSKeyValueObservingOptionNew
							   context:NULL];
		[[NSUserDefaults standardUserDefaults] addObserver:self
							forKeyPath:@"tabstop"
							   options:NSKeyValueObservingOptionNew
							   context:NULL];
		[[NSUserDefaults standardUserDefaults] addObserver:self
							forKeyPath:@"fontsize"
							   options:NSKeyValueObservingOptionNew
							   context:NULL];
		[[NSUserDefaults standardUserDefaults] addObserver:self
							forKeyPath:@"fontname"
							   options:NSKeyValueObservingOptionNew
							   context:NULL];
		[[NSUserDefaults standardUserDefaults] addObserver:self
							forKeyPath:@"wrap"
							   options:NSKeyValueObservingOptionNew
							   context:NULL];
	
		textStorage = [[NSTextStorage alloc] initWithString:@""];
		[textStorage setDelegate:self];

		symbolIcons = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"symbol-icons" ofType:@"plist"]];

		[self configureForURL:nil];
		forcedEncoding = 0;
		encoding = NSUTF8StringEncoding;
	}
	return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
		      ofObject:(id)object
			change:(NSDictionary *)change
		       context:(void *)context

{
	if ([keyPath isEqualToString:@"number"])
		[self enableLineNumbers:[[NSUserDefaults standardUserDefaults] boolForKey:keyPath]];
	else if ([keyPath isEqualToString:@"wrap"])
		[self setWrapping:[[NSUserDefaults standardUserDefaults] boolForKey:keyPath]];
	else if ([keyPath isEqualToString:@"tabstop"] ||
		 [keyPath isEqualToString:@"fontsize"] ||
		 [keyPath isEqualToString:@"fontname"])
		[self resetTypingAttributes];
}

#pragma mark -
#pragma mark NSDocument interface

- (void)makeWindowControllers
{
	if (makeNewWindowInsteadOfTab) {
		windowController = [[ViWindowController alloc] init];
		makeNewWindowInsteadOfTab = NO;
	}
	else
		windowController = [ViWindowController currentWindowController];

	[self addWindowController:windowController];
	[windowController addNewTab:self];
}

- (void)removeView:(ViDocumentView *)aDocumentView
{
	// Keep one view around for delegate methods.
	if ([views count] > 1)
		[views removeObject:aDocumentView];
	--visibleViews;
}

- (ViDocumentView *)makeView
{
	++visibleViews;
	if (visibleViews == 1 && [views count] > 0)
		return [views objectAtIndex:0];

	ViDocumentView *documentView = [[ViDocumentView alloc] initWithDocument:self];
	[NSBundle loadNibNamed:@"ViDocument" owner:documentView];
	ViTextView *textView = [documentView textView];
	[[textView layoutManager] setDelegate:self];
	[views addObject:documentView];

	/* Make all views share the same text storage. */
	[[textView layoutManager] replaceTextStorage:textStorage];
	[textView initEditorWithDelegate:self documentView:documentView];

	[self enableLineNumbers:[[NSUserDefaults standardUserDefaults] boolForKey:@"number"] forScrollView:[textView enclosingScrollView]];
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

- (BOOL)attemptRecoveryFromError:(NSError *)error optionIndex:(NSUInteger)recoveryOptionIndex
{
	if (recoveryOptionIndex == 1) {
		retrySaveOperation = YES;
		return YES;
	}

	return NO;
}

- (void)didPresentErrorWithRecovery:(BOOL)didRecover contextInfo:(void *)contextInfo
{
	DEBUG(@"didRecover = %s", didRecover ? "YES" : "NO");
}

- (BOOL)writeSafelyToURL:(NSURL *)url ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError
{
	retrySaveOperation = NO;

	if (![[textStorage string] canBeConvertedToEncoding:encoding]) {
		NSString *reason = [NSString stringWithFormat:@"The %@ encoding is not appropriate.", [NSString localizedNameOfStringEncoding:encoding]];
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
				*outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil];
			return NO;
		}

		if (saveOperation == NSSaveOperation || saveOperation == NSSaveAsOperation)
			encoding = NSUTF8StringEncoding;
	}

	if ([url isFileURL])
		return [super writeSafelyToURL:url ofType:typeName forSaveOperation:saveOperation error:outError];

	if (![[url scheme] isEqualToString:@"sftp"]) {
		INFO(@"unsupported URL scheme: %@", [url scheme]);
		// XXX: set outError
		return NO;
	}

	NSData *data = [self dataOfType:typeName error:nil];
	if (data == nil)
		/* Should not happen. We've already checked for encoding problems. */
		return NO;

	SFTPConnection *conn = [[SFTPConnectionPool sharedPool] connectionWithURL:url error:outError];
	if (conn == nil)
		return NO;
	return [conn writeData:data toFile:[url path] error:outError];
}

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError
{
	DEBUG(@"type = %@, url = %@, scheme = %@", typeName, [url absoluteString], [url scheme]);

	NSData *data = nil;
	if ([url isFileURL])
		data = [NSData dataWithContentsOfFile:[url path] options:0 error:outError];
	else if ([[url scheme] isEqualToString:@"sftp"]) {
		if ([url user] == nil || [url host] == nil) {
			if (outError)
				*outError = [SFTPConnection errorWithDescription:@"Missing user or host in URL."];
			return NO;
		}

		SFTPConnection *conn = [[SFTPConnectionPool sharedPool] connectionWithURL:url error:outError];
		if (conn == nil)
			return NO;
		data = [conn dataWithContentsOfFile:[url path] error:outError];
	}

	if (data == nil)
		return NO;

	NSString *aString = nil;
	if (forcedEncoding != 0) {
		aString = [[NSString alloc] initWithData:data encoding:forcedEncoding];
		if (aString == nil) {
			NSString *description = [NSString stringWithFormat:@"The file can't be interpreted in %@ encoding.",
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
				[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"encodingOverride"]];
			[encodingOverride setObject:[NSNumber numberWithUnsignedInteger:encoding] forKey:[[self fileURL] absoluteString]];
			[[NSUserDefaults standardUserDefaults] setObject:encodingOverride forKey:@"encodingOverride"];
		}
		forcedEncoding = 0;
	} else {
		/* Check for a user-overridden encoding in preferences. */
		NSDictionary *encodingOverride = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"encodingOverride"];
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

	/*
	 * Disable the processing in textStorageDidProcessEditing,
	 * otherwise we'll parse the document multiple times.
	 */
	ignoreEditing = YES;
	[[textStorage mutableString] setString:aString ?: @""];
	[self resetTypingAttributes];

	/* Force incremental syntax parsing. */
	[self highlightEverything];

	return YES;
}

- (void)setEncoding:(id)sender
{
	forcedEncoding = [[sender representedObject] unsignedIntegerValue];
	INFO(@"sender = %@, rep.obj = %@, forcedEncoding = 0x%llx", sender, [sender representedObject], forcedEncoding);
	[self revertDocumentToSaved:nil];
}

- (void)setFileURL:(NSURL *)absoluteURL
{
	[super setFileURL:absoluteURL];
	[self configureSyntax];
}

- (ViWindowController *)windowController
{
	return windowController;
}

- (void)close
{
	[windowController closeDocumentViews:self];
	
	/* Remove the window controller so the document doesn't automatically
	 * close the window.
	 */
	[self removeWindowController:windowController];
	[super close];
}

#pragma mark -
#pragma mark Syntax parsing

- (NSDictionary *)defaultAttributesForTheme:(ViTheme *)theme
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

        ViTheme *theme = [[ViThemeStore defaultStore] defaultTheme];
        NSArray *scopeArray = [syntaxParser scopeArray];
        if (charIndex >= [scopeArray count]) {
                *effectiveCharRange = NSMakeRange(charIndex, [textStorage length] - charIndex);
                return [self defaultAttributesForTheme:theme];
        }

	ViScope *scope = [scopeArray objectAtIndex:charIndex];
        NSDictionary *attributes = [scope attributes];
        if ([attributes count] == 0) {
                attributes = [theme attributesForScopes:[scope scopes] inBundle:bundle];
                if ([attributes count] == 0)
                        attributes = [self defaultAttributesForTheme:theme];
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
	if (NSIntersectionRange(r, activeSnippet.range).length > 0) {
		NSArray *a;
		BOOL foundPlaceholder = NO;
		for (a in [activeSnippet tabstops]) {
			ViSnippetPlaceholder *ph;
			for (ph in a) {
				if (NSIntersectionRange(r, ph.range).length > 0) {
					if (ph.range.location > r.location)
						r.length = ph.range.location - r.location;
					else {
						if (mergedAttributes == nil)
							mergedAttributes = [[NSMutableDictionary alloc] initWithDictionary:attributes];
						[mergedAttributes setObject:[NSNumber numberWithInteger:NSUnderlinePatternDot | NSUnderlineStyleThick]
								     forKey:NSUnderlineStyleAttributeName];
						[mergedAttributes setObject:[NSColor redColor]
								     forKey:NSUnderlineColorAttributeName];
						/*
						 * Adjust *effectiveCharRange if r != ph.range.
						 */
						if (NSMaxRange(ph.range) < NSMaxRange(r))
							r.length = NSMaxRange(ph.range) - r.location;
					}
					DEBUG(@"merged %@ with %@ -> %@", ph, NSStringFromRange(*effectiveCharRange), NSStringFromRange(r));
					*effectiveCharRange = r;
					foundPlaceholder = YES;
					break;
				}
			}

			if (foundPlaceholder)
				break;
		}

		DEBUG(@"merged attributes = %@", mergedAttributes);
	}

        return mergedAttributes ?: attributes;
}

- (void)highlightEverything
{
	/* Invalidate all document views. */
	ViDocumentView *dv;
	for (dv in views)
		[[[dv textView] layoutManager] invalidateDisplayForCharacterRange:NSMakeRange(0, [textStorage length])];

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
		range.length * sizeof(unichar), chars, NSStringFromRange(range), [textStorage length]);
	[[textStorage string] getCharacters:chars range:range];

	ctx.characters = chars;
	unsigned startLine = ctx.lineOffset;

	// unsigned endLine = [textStorage lineNumberAtLocation:NSMaxRange(range) - 1];
	// INFO(@"parsing line %u -> %u (ctx = %@)", startLine, endLine, ctx);

	[syntaxParser parseContext:ctx];

	// Invalidate the layout(s).
	if (ctx.restarting) {
		ViDocumentView *dv;
		for (dv in views) {
			[[[dv textView] layoutManager] invalidateDisplayForCharacterRange:range];
		}
	}

	[updateSymbolsTimer invalidate];
	updateSymbolsTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:updateSymbolsTimer == nil ? 0 : 0.4]
						      interval:0
							target:self
						      selector:@selector(updateSymbolList:)
						      userInfo:nil
						       repeats:NO];
	[[NSRunLoop currentRunLoop] addTimer:updateSymbolsTimer forMode:NSDefaultRunLoopMode];

	if (ctx.lineOffset > startLine) {
		// INFO(@"line endings have changed at line %u", endLine);
		
		if (nextContext && nextContext != ctx) {
			if (nextContext.lineOffset < startLine) {
				DEBUG(@"letting previous scheduled parsing from line %u continue", nextContext.lineOffset);
				return;
			}
			DEBUG(@"cancelling scheduled parsing from line %u (nextContext = %@)", nextContext.lineOffset, nextContext);
			[nextContext setCancelled:YES];
		}

		nextContext = ctx;
		[self performSelector:@selector(restartSyntaxParsingWithContext:) withObject:ctx afterDelay:0.0025];
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

	if (context.cancelled) {
		DEBUG(@"context %@, from line %u, is cancelled", context, context.lineOffset);
		return;
	}

	NSUInteger startLocation = [textStorage locationForStartOfLine:context.lineOffset];
	NSInteger endLocation = [textStorage locationForStartOfLine:context.lineOffset + 50];
	if (endLocation == -1)
		endLocation = [textStorage length];

	context.range = NSMakeRange(startLocation, endLocation - startLocation);
	context.restarting = YES;
	if (context.range.length > 0)
	{
		DEBUG(@"restarting parse context at line %u, range %@", startLocation, NSStringFromRange(context.range));
		[self performSyntaxParsingWithContext:context];
	}
}

- (ViLanguage *)language
{
	return language;
}

- (IBAction)setLanguage:(id)sender
{
	ViLanguage *lang = nil;
	if ([sender respondsToSelector:@selector(representedObject)])
		lang = [sender representedObject];
	else
		lang = sender;

	/* Force compilation. */
	[lang patterns];

	if (lang != language) {
		language = lang;
		bundle = [language bundle];
		symbolScopes = [[ViLanguageStore defaultStore] preferenceItem:@"showInSymbolList"];
		symbolTransforms = [[ViLanguageStore defaultStore] preferenceItem:@"symbolTransformation"];
		[self highlightEverything];
	}

	if ([self fileURL] != nil) {
		NSMutableDictionary *syntaxOverride = [NSMutableDictionary dictionaryWithDictionary:
			[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"syntaxOverride"]];
		[syntaxOverride setObject:lang ? [lang name] : @"" forKey:[[self fileURL] absoluteString]];
		[[NSUserDefaults standardUserDefaults] setObject:syntaxOverride forKey:@"syntaxOverride"];
	}
}

- (void)configureForURL:(NSURL *)aURL
{
	ViLanguage *newLanguage = nil;
	if (aURL) {
		NSString *firstLine = nil;
		NSUInteger eol;
		[[textStorage string] getLineStart:NULL end:NULL contentsEnd:&eol forRange:NSMakeRange(0, 0)];
		if (eol > 0)
			firstLine = [[textStorage string] substringWithRange:NSMakeRange(0, eol)];

		if ([firstLine length] > 0)
			newLanguage = [[ViLanguageStore defaultStore] languageForFirstLine:firstLine];
		if (newLanguage == nil)
			newLanguage = [[ViLanguageStore defaultStore] languageForFilename:[aURL path]];
	}

	if (newLanguage == nil)
		newLanguage = [[ViLanguageStore defaultStore] defaultLanguage];

	[self setLanguage:newLanguage];
}

- (void)configureSyntax
{
	/* Check if the user has overridden a syntax for this URL. */
	NSDictionary *syntaxOverride = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"syntaxOverride"];
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

- (void)pushContinuationsInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString
{
	NSString *affectedString = [[textStorage string] substringWithRange:affectedCharRange];

	NSInteger affectedLines = [affectedString numberOfLines];
	NSInteger replacementLines = [replacementString numberOfLines];

	NSInteger diff = replacementLines - affectedLines;
	if (diff == 0)
		return;

	unsigned lineno = 0;
	if (affectedCharRange.location > 1)
		lineno = [textStorage lineNumberAtLocation:affectedCharRange.location - 1];

	if (diff > 0)
		[syntaxParser pushContinuations:[NSValue valueWithRange:NSMakeRange(lineno, diff)]];
	else
		[syntaxParser pullContinuations:[NSValue valueWithRange:NSMakeRange(lineno, -diff)]];
}

#pragma mark -
#pragma mark NSTextStorage delegate methods

- (BOOL)textView:(NSTextView *)aTextView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString
{
	if (!ignoreEditing)
		[self pushContinuationsInRange:affectedCharRange replacementString:replacementString];
	return YES;
}

- (void)textStorageDidProcessEditing:(NSNotification *)notification
{
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

	/*
	 * Extend our range along affected line boundaries and re-parse.
	 */
	NSUInteger bol, end;
	[[textStorage string] getLineStart:&bol end:&end contentsEnd:NULL forRange:area];
	area.location = bol;
	area.length = end - bol;

	[self dispatchSyntaxParserWithRange:area restarting:NO];
}

#pragma mark -
#pragma mark Line numbers

- (void)enableLineNumbers:(BOOL)flag forScrollView:(NSScrollView *)aScrollView
{
	if (flag) {
		NoodleLineNumberView *lineNumberView = [[MarkerLineNumberView alloc] initWithScrollView:aScrollView];
		[aScrollView setVerticalRulerView:lineNumberView];
		[aScrollView setHasHorizontalRuler:NO];
		[aScrollView setHasVerticalRuler:YES];
		[aScrollView setRulersVisible:YES];
		[lineNumberView setBackgroundColor:[NSColor colorWithDeviceRed:(float)0xED/0xFF green:(float)0xED/0xFF blue:(float)0xED/0xFF alpha:1.0]];
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
	NSFont *font = [NSFont fontWithName:[defs stringForKey:@"fontname"] size:[defs floatForKey:@"fontsize"]];
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

	NSDictionary *attrs = [NSDictionary dictionaryWithObject:[self font] forKey:NSFontAttributeName];
	NSSize tabSizeInPoints = [tab sizeWithAttributes:attrs];

	NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	// remove all previous tab stops
	for (NSTextTab *tabStop in [style tabStops])
		[style removeTabStop:tabStop];

	// "Tabs after the last specified in tabStops are placed at integral multiples of this distance."
	[style setDefaultTabInterval:tabSizeInPoints.width];

	typingAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
	    style, NSParagraphStyleAttributeName,
	    [self font], NSFontAttributeName,
	    nil];
}

- (void)resetTypingAttributes
{
	[self setTypingAttributes];
	ignoreEditing = YES;
	[textStorage addAttributes:[self typingAttributes] range:NSMakeRange(0, [textStorage length])];
}

- (void)changeTheme:(ViTheme *)theme
{
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
	ViDocumentView *dv;
	for (dv in views) {
		[[dv textView] setTheme:theme];
		[[[dv textView] layoutManager] invalidateDisplayForCharacterRange:NSMakeRange(0, [textStorage length])];
	}
}

- (void)updatePageGuide
{
	int pageGuideColumn = 0;
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"showguide"] == NSOnState)
		pageGuideColumn = [[NSUserDefaults standardUserDefaults] integerForKey:@"guidecolumn"];

	ViDocumentView *dv;
	for (dv in views)
		[[dv textView] setPageGuide:pageGuideColumn];
}

#pragma mark -
#pragma mark ViTextView delegate methods

- (void)message:(NSString *)fmt, ...
{
	va_list ap;
	va_start(ap, fmt);
	NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
	va_end(ap);

	[[windowController messageField] setStringValue:msg];
}

- (IBAction)finishedExCommand:(id)sender
{
	NSString *exCommand = [[windowController statusbar] stringValue];
	[[windowController statusbar] setStringValue:@""];
	[[windowController statusbar] setEditable:NO];
	[[windowController statusbar] setHidden:YES];
	[[windowController messageField] setHidden:NO];
	[[[self windowController] window] makeFirstResponder:exCommandView];
	if ([exCommand length] == 0)
		return;

	[exCommandView performSelector:exCommandSelector withObject:exCommand];
	exCommandView = nil;

	// add the command to the history
	NSUInteger i = [exCommandHistory indexOfObject:exCommand];
	if (i != NSNotFound)
		[exCommandHistory removeObjectAtIndex:i];
	[exCommandHistory addObject:exCommand];
}

- (void)getExCommandForTextView:(ViTextView *)aTextView selector:(SEL)aSelector prompt:(NSString *)aPrompt
{
	[[windowController messageField] setHidden:YES];
	[[windowController statusbar] setHidden:NO];
	[[windowController statusbar] setStringValue:aPrompt];
	[[windowController statusbar] setEditable:YES];
	[[windowController statusbar] setTarget:self];
	[[windowController statusbar] setAction:@selector(finishedExCommand:)];
	exCommandSelector = aSelector;
	exCommandView = aTextView;
	[[[self windowController] window] makeFirstResponder:[windowController statusbar]];
}

- (void)getExCommandForTextView:(ViTextView *)aTextView selector:(SEL)aSelector
{
	[self getExCommandForTextView:aTextView selector:aSelector prompt:@":"];
}

- (BOOL)findPattern:(NSString *)pattern
	    options:(unsigned)find_options
         regexpType:(int)regexpSyntax
{
	return [(ViTextView *)[[views objectAtIndex:0] textView] findPattern:pattern options:find_options regexpType:regexpSyntax];
}

// tag push
- (void)pushLine:(NSUInteger)aLine column:(NSUInteger)aColumn
{
	[[[self windowController] sharedTagStack] pushFile:[[self fileURL] path] line:aLine column:aColumn];
}

- (void)popTag
{
	NSDictionary *location = [[[self windowController] sharedTagStack] pop];
	if (location == nil) {
		[self message:@"The tags stack is empty"];
		return;
	}

	NSString *file = [location objectForKey:@"file"];
	ViDocument *document = [[NSDocumentController sharedDocumentController]
		openDocumentWithContentsOfURL:[NSURL fileURLWithPath:file] display:YES error:nil];

	if (document) {
		[[self windowController] selectDocument:document];
		[(ViTextView *)[[views objectAtIndex:0] textView] gotoLine:[[location objectForKey:@"line"] unsignedIntegerValue]
				                                    column:[[location objectForKey:@"column"] unsignedIntegerValue]];
	}
}

#pragma mark -
#pragma mark Symbol List

- (void)goToSymbol:(ViSymbol *)aSymbol inView:(ViDocumentView *)aView
{
	NSRange range = [aSymbol range];
	ViTextView *textView = [aView textView];
	[textView setCaret:range.location];
	[textView scrollRangeToVisible:range];
	[[[self windowController] window] makeFirstResponder:textView];
	[textView showFindIndicatorForRange:range];
}

- (void)goToSymbol:(ViSymbol *)aSymbol
{
	[self goToSymbol:aSymbol inView:[views objectAtIndex:0]];
}

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

	NSArray *scopeArray = [syntaxParser scopeArray];
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
				NSString *symbol = [[textStorage string] substringWithRange:wholeRange];
				NSString *transform = [symbolTransforms objectForKey:lastSelector];
				if (transform) {
					ViSymbolTransform *tr = [[ViSymbolTransform alloc] initWithTransformationString:transform];
					symbol = [tr transformSymbol:symbol];
				}

				[syms addObject:[[ViSymbol alloc] initWithSymbol:symbol range:wholeRange image:img]];
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

	[self setSymbols:syms];

#if 0
	gettimeofday(&stop, NULL);
	timersub(&stop, &start, &diff);
	unsigned ms = diff.tv_sec * 1000 + diff.tv_usec / 1000;
	INFO(@"updated %u symbols => %.3f s", [symbols count], (float)ms / 1000.0);
#endif
}

- (void)updateSelectedSymbolForLocation:(NSUInteger)aLocation
{
	[windowController updateSelectedSymbolForLocation:aLocation];
}

#pragma mark -

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViDocument %p: %@>", self, [self displayName]];
}

- (void)setMostRecentDocumentView:(ViDocumentView *)docView
{
	[windowController setMostRecentDocument:self view:docView];
}

- (NSArray *)scopesAtLocation:(NSUInteger)aLocation
{
	NSArray *scopeArray = [syntaxParser scopeArray];
	if ([scopeArray count] > aLocation)
		return [[scopeArray objectAtIndex:aLocation] scopes];
	return nil;
}

@end

