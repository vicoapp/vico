#include <sys/time.h>

#import "ViDocument.h"
#import "ViDocumentView.h"
#import "ExTextView.h"
#import "ViLanguageStore.h"
#import "NSTextStorage-additions.h"
#import "NSArray-patterns.h"
#import "ViScope.h"
#import "ViSymbolTransform.h"

#import "NoodleLineNumberView.h"
#import "NoodleLineNumberMarker.h"
#import "MarkerLineNumberView.h"

BOOL makeNewWindowInsteadOfTab = NO;

@interface ViDocument (internal)
- (ViWindowController *)windowController;
- (void)setSymbolScopes;
@end

@implementation ViDocument

@synthesize symbols;
@synthesize filteredSymbols;
@synthesize views;
@synthesize visibleViews;

- (id)init
{
	self = [super init];
	if (self)
	{
		symbols = [NSArray array];
		views = [[NSMutableArray alloc] init];
	}
	return self;
}

#pragma mark -
#pragma mark NSDocument interface

- (void)makeWindowControllers
{
	if (makeNewWindowInsteadOfTab)
	{
		windowController = [[ViWindowController alloc] init];
		makeNewWindowInsteadOfTab = NO;
	}
	else
	{
		windowController = [ViWindowController currentWindowController];
	}

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
	{
		return [views objectAtIndex:0];
	}

	ViDocumentView *documentView = [[ViDocumentView alloc] initWithDocument:self];
	[NSBundle loadNibNamed:@"ViDocument" owner:documentView];
	ViTextView *textView = [documentView textView];
	[views addObject:documentView];

	if ([views count] == 1)
	{
		// this is the first view
		[textView setString:readContent];
		readContent = nil;
		textStorage = [textView textStorage];
		[self configureSyntax];
	}
	else
	{
		// alternative views, make them share the same text storage
		[[textView layoutManager] replaceTextStorage:textStorage];
	}
	[textStorage setDelegate:self];
	ignoreEditing = YES;
	[textView initEditorWithDelegate:self documentView:documentView];

	[syntaxParser updateScopeRanges];
	[documentView applyScopes:[syntaxParser scopeArray] inRange:NSMakeRange(0, [textStorage length])];

	[self enableLineNumbers:[[NSUserDefaults standardUserDefaults] boolForKey:@"number"] forScrollView:[textView enclosingScrollView]];

	return documentView;
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
	return [[textStorage string] dataUsingEncoding:NSUTF8StringEncoding];
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	readContent = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	return YES;
}

- (void)setFileURL:(NSURL *)absoluteURL
{
	[super setFileURL:absoluteURL];
	if (textStorage)
		[self configureSyntax];
}

- (ViWindowController *)windowController
{
	return [[self windowControllers] objectAtIndex:0];
}

- (void)canCloseDocumentWithDelegate:(id)aDelegate shouldCloseSelector:(SEL)shouldCloseSelector contextInfo:(void *)contextInfo
{
	[super canCloseDocumentWithDelegate:self shouldCloseSelector:@selector(document:shouldClose:contextInfo:) contextInfo:contextInfo];
}

- (void)document:(NSDocument *)doc shouldClose:(BOOL)shouldClose contextInfo:(void *)contextInfo
{
	if (shouldClose)
	{
		INFO(@"closing document %@", self);
		[windowController closeDocumentViews:self];

		/* Remove the window controller so the document doesn't automatically
		 * close the window.
		 */
		[self removeWindowController:windowController];
		[self close];
	}
}

#pragma mark -
#pragma mark Syntax parsing

- (void)applySyntaxResult:(ViSyntaxContext *)context
{
	[syntaxParser updateScopeRangesInRange:[context range]];

	DEBUG(@"applying syntax scopes, range = %@", NSStringFromRange([context range]));
	ViDocumentView *dv;
	for (dv in views)
	{
		[dv applyScopes:[syntaxParser scopeArray] inRange:[context range]];
	}

	[updateSymbolsTimer invalidate];
	updateSymbolsTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:updateSymbolsTimer == nil ? 0 : 0.4]
						      interval:0
							target:self
						      selector:@selector(updateSymbolList:)
						      userInfo:nil
						       repeats:NO];
	[[NSRunLoop currentRunLoop] addTimer:updateSymbolsTimer forMode:NSDefaultRunLoopMode];
}

- (void)highlightEverything
{
	if (language == nil)
	{
		ViDocumentView *dv;
		for (dv in views)
			[dv resetAttributesInRange:NSMakeRange(0, [textStorage length])];
		return;
	}

	NSInteger endLocation = [textStorage locationForStartOfLine:100];
	if (endLocation == -1)
		endLocation = [textStorage length];

	[self dispatchSyntaxParserWithRange:NSMakeRange(0, endLocation) restarting:NO];
}

- (void)performContext:(ViSyntaxContext *)ctx
{
	NSRange range = ctx.range;
	unichar *chars = malloc(range.length * sizeof(unichar));
	DEBUG(@"allocated %u bytes characters %p", range.length * sizeof(unichar), chars);
	[[textStorage string] getCharacters:chars range:range];

	ctx.characters = chars;
	unsigned startLine = ctx.lineOffset;

	// unsigned endLine = [textStorage lineNumberAtLocation:NSMaxRange(range) - 1];
	// INFO(@"parsing line %u -> %u (ctx = %@)", startLine, endLine, ctx);

	[syntaxParser parseContext:ctx];
	[self performSelector:@selector(applySyntaxResult:) withObject:ctx afterDelay:0.0];

	if (ctx.lineOffset > startLine)
	{
		// INFO(@"line endings have changed at line %u", endLine);
		
		if (nextContext && nextContext != ctx)
		{
			if (nextContext.lineOffset < startLine)
			{
				DEBUG(@"letting previous scheduled parsing from line %u continue", nextContext.lineOffset);
				return;
			}
			DEBUG(@"cancelling scheduled parsing from line %u (nextContext = %@)", nextContext.lineOffset, nextContext);
			[nextContext setCancelled:YES];
		}
		
		nextContext = ctx;
		[self performSelector:@selector(restartContext:) withObject:ctx afterDelay:0.0025];
	}
	// FIXME: probably need a stack here
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

	[self performContext:ctx];
}

- (void)restartContext:(ViSyntaxContext *)context
{
	nextContext = nil;

	if (context.cancelled)
	{
		DEBUG(@"context %@, from line %u, is cancelled", context, context.lineOffset);
		return;
	}

	NSUInteger startLocation = [textStorage locationForStartOfLine:context.lineOffset];
	NSInteger endLocation = [textStorage locationForStartOfLine:context.lineOffset + 50];
	if (endLocation == -1)
		endLocation = [textStorage length];

	context.range = NSMakeRange(startLocation, endLocation - startLocation);
	DEBUG(@"restarting parse context at line %u, range %@", startLocation, NSStringFromRange(context.range));
	[self performContext:context];
}

- (IBAction)setLanguage:(id)sender
{
	DEBUG(@"sender = %@, title = %@", sender, [sender title]);

	[self setLanguageFromString:[sender title]];
	if (language && [self fileURL])
	{
		NSMutableDictionary *syntaxOverride = [NSMutableDictionary dictionaryWithDictionary:
			[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"syntaxOverride"]];
		[syntaxOverride setObject:[sender title] forKey:[[self fileURL] path]];
		[[NSUserDefaults standardUserDefaults] setObject:syntaxOverride forKey:@"syntaxOverride"];
	}
}

- (void)setLanguageFromString:(NSString *)aLanguage
{
	ViLanguage *newLanguage = nil;
	bundle = [[ViLanguageStore defaultStore] bundleForLanguage:aLanguage language:&newLanguage];
	[newLanguage patterns];
	if (newLanguage != language)
	{
		language = newLanguage;
		syntaxParser = [[ViSyntaxParser alloc] initWithLanguage:language];
		[self setSymbolScopes];
		[self highlightEverything];
	}
}

- (void)configureForURL:(NSURL *)aURL
{
	ViLanguage *newLanguage = nil;
	if (aURL)
	{
		NSString *firstLine = nil;
		NSUInteger eol;
		[[textStorage string] getLineStart:NULL end:NULL contentsEnd:&eol forRange:NSMakeRange(0, 0)];
		if (eol > 0)
			firstLine = [[textStorage string] substringWithRange:NSMakeRange(0, eol)];

		bundle = nil;
		if ([firstLine length] > 0)
			bundle = [[ViLanguageStore defaultStore] bundleForFirstLine:firstLine language:&newLanguage];
		if (bundle == nil)
			bundle = [[ViLanguageStore defaultStore] bundleForFilename:[aURL path] language:&newLanguage];
	}

	if (bundle == nil)
	{
		bundle = [[ViLanguageStore defaultStore] defaultBundleLanguage:&newLanguage];
	}

	DEBUG(@"new language = %@, (%@)", newLanguage, language);

	[newLanguage patterns];
	if (newLanguage != language)
	{
		language = newLanguage;
		syntaxParser = [[ViSyntaxParser alloc] initWithLanguage:language];
		[self setSymbolScopes];
		[self highlightEverything];
	}
}

- (void)configureSyntax
{
	/* update syntax definition */
	NSDictionary *syntaxOverride = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"syntaxOverride"];
	NSString *syntax = [syntaxOverride objectForKey:[[self fileURL] path]];
	if (syntax)
		[self setLanguageFromString:syntax];
	else
		[self configureForURL:[self fileURL]];
	// [languageButton selectItemWithTitle:[[textView language] displayName]];
}

- (void)pushContinuationsFromLocation:(NSUInteger)aLocation string:(NSString *)aString forward:(BOOL)flag
{
	int n = 0;
	NSInteger i = 0;

        /* Count number of affected lines.
         */
        while (i < [aString length])
        {
		NSUInteger eol, end;
		[aString getLineStart:NULL end:&end contentsEnd:&eol forRange:NSMakeRange(i, 0)];
		if (end == eol)
			break;
		n++;
		i = end;
        }

	if (n == 0)
		return;

	unsigned lineno = 0;
	if (aLocation > 1)
		lineno = [textStorage lineNumberAtLocation:aLocation - 1];

	if (flag)
		[syntaxParser pushContinuations:[NSValue valueWithRange:NSMakeRange(lineno, n)]];
	else
		[syntaxParser pullContinuations:[NSValue valueWithRange:NSMakeRange(lineno, n)]];
}

#pragma mark -
#pragma mark NSTextStorage delegate method

- (BOOL)textView:(NSTextView *)aTextView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString
{
	DEBUG(@"range = %@, string = [%@]", NSStringFromRange(affectedCharRange), replacementString);

	if ([replacementString length] > 0)
	{
		DEBUG(@"pushing string [%@] from %u", replacementString, affectedCharRange.location);
		[self pushContinuationsFromLocation:affectedCharRange.location
		                             string:replacementString
		                            forward:YES];
		[syntaxParser pushScopes:NSMakeRange(affectedCharRange.location, [replacementString length])];
	}
	else
	{
		NSString *deletedString = [[textStorage string] substringWithRange:affectedCharRange];
		DEBUG(@"pulling string [%@] from %u", deletedString, affectedCharRange.location);
		[self pushContinuationsFromLocation:affectedCharRange.location
		                             string:deletedString
		                            forward:NO];
		[syntaxParser pullScopes:affectedCharRange];
	}

	return YES;
}

- (void)textStorageDidProcessEditing:(NSNotification *)notification
{
	if (ignoreEditing)
	{
		ignoreEditing = NO;
		return;
	}

	NSRange area = [textStorage editedRange];
	DEBUG(@"got notification for changes in area %@, change length = %i, storage = %p, self = %@",
		NSStringFromRange(area), [textStorage changeInLength],
		textStorage, self);

	if (language == nil)
	{
		ViDocumentView *dv;
		for (dv in views)
			[dv resetAttributesInRange:area];
		return;
	}
	
	// extend our range along line boundaries.
	NSUInteger bol, eol;
	[[textStorage string] getLineStart:&bol end:&eol contentsEnd:NULL forRange:area];
	area.location = bol;
	area.length = eol - bol;
	DEBUG(@"extended area to %@", NSStringFromRange(area));

	[self dispatchSyntaxParserWithRange:area restarting:NO];
}

#pragma mark -
#pragma mark Line numbers

- (void)enableLineNumbers:(BOOL)flag forScrollView:(NSScrollView *)aScrollView
{
	if (flag)
	{
		NoodleLineNumberView *lineNumberView = [[MarkerLineNumberView alloc] initWithScrollView:aScrollView];
		[aScrollView setVerticalRulerView:lineNumberView];
		[aScrollView setHasHorizontalRuler:NO];
		[aScrollView setHasVerticalRuler:YES];
		[aScrollView setRulersVisible:YES];
	}
	else
		[aScrollView setRulersVisible:NO];
}

- (void)enableLineNumbers:(BOOL)flag
{
	ViDocumentView *dv;
	for (dv in views)
	{
		[self enableLineNumbers:flag forScrollView:[[dv textView] enclosingScrollView]];
	}
}

- (IBAction)toggleLineNumbers:(id)sender
{
	[self enableLineNumbers:[sender state] == NSOffState];
}


#pragma mark -
#pragma mark Other interesting stuff

- (void)changeTheme:(ViTheme *)theme
{
	[syntaxParser updateScopeRanges];
	ViDocumentView *dv;
	for (dv in views)
	{
		[[dv textView] setTheme:theme];
		[dv reapplyThemeWithScopes:[syntaxParser scopeArray]];
	}
}

- (void)setPageGuide:(int)pageGuideValue
{
	ViDocumentView *dv;
	for (dv in views)
	{
		[[dv textView] setPageGuide:pageGuideValue];
	}
}

#pragma mark -
#pragma mark ViTextView delegate methods

- (void)message:(NSString *)fmt, ...
{
	va_list ap;
	va_start(ap, fmt);
	NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
	va_end(ap);

	[[windowController statusbar] setStringValue:msg];
}

- (IBAction)finishedExCommand:(id)sender
{
	NSString *exCommand = [[windowController statusbar] stringValue];
	INFO(@"got ex command [%@]", exCommand);
	[[windowController statusbar] setStringValue:@""];
	[[windowController statusbar] setEditable:NO];
	[[[self windowController] window] makeFirstResponder:exCommandView];
	if ([exCommand length] > 0)
		[exCommandView performSelector:exCommandSelector withObject:exCommand];
	exCommandView = nil;
}

- (void)getExCommandForTextView:(ViTextView *)aTextView selector:(SEL)aSelector prompt:(NSString *)aPrompt
{
	[[windowController statusbar] setStringValue:aPrompt];
	[[windowController statusbar] setEditable:YES];
	[[windowController statusbar] setDelegate:self];
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
	if (location == nil)
	{
		[self message:@"The tags stack is empty"];
		return;
	}

	NSString *file = [location objectForKey:@"file"];
	ViDocument *document = [[NSDocumentController sharedDocumentController]
		openDocumentWithContentsOfURL:[NSURL fileURLWithPath:file] display:YES error:nil];

	if (document)
	{
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
	{
		if ([rx matchInString:[s symbol]])
		{
			[fs addObject:s];
		}
	}
	[self setFilteredSymbols:fs];
	return [fs count];
}

- (void)setSymbolScopes
{
	symbolSettings = [[ViLanguageStore defaultStore] preferenceItems:@"showInSymbolList" includeAllSettings:YES];
	NSString *selector;
	symbolScopes = [[NSMutableArray alloc] init];
	for (selector in symbolSettings)
	{
		if ([[[symbolSettings objectForKey:selector] objectForKey:@"showInSymbolList"] integerValue] == 1)
			[symbolScopes addObject:[selector componentsSeparatedByString:@" "]];
	}
}

- (void)updateSymbolList:(NSTimer *)timer
{
	NSArray *lastSelector = nil;
	NSRange wholeRange;

#if 0
	struct timeval start;
	struct timeval stop;
	struct timeval diff;
	gettimeofday(&start, NULL);
#endif

	[syntaxParser updateScopeRanges];

	NSMutableArray *syms = [[NSMutableArray alloc] init];

	NSArray *scopeArray = [syntaxParser scopeArray];
	NSUInteger i;
	for (i = 0; i < [scopeArray count];)
	{
		ViScope *s = [scopeArray objectAtIndex:i];
		NSArray *scopes = s.scopes;
		NSRange range = s.range;

		if ([lastSelector matchesScopes:scopes])
		{
			wholeRange.length += range.length;
		}
		else
		{
			if (lastSelector)
			{
				NSString *symbol = [[textStorage string] substringWithRange:wholeRange];
				NSDictionary *d = [symbolSettings objectForKey:[lastSelector componentsJoinedByString:@" "]];
				NSString *transform = [d objectForKey:@"symbolTransformation"];
				if (transform)
				{
					ViSymbolTransform *tr = [[ViSymbolTransform alloc] initWithTransformationString:transform];
					symbol = [tr transformSymbol:symbol];
				}

				[syms addObject:[[ViSymbol alloc] initWithSymbol:symbol range:wholeRange]];
			}
			lastSelector = nil;

			NSArray *descendants;
			for (descendants in symbolScopes)
			{
				if ([descendants matchesScopes:scopes])
				{
					lastSelector = descendants;
					wholeRange = range;
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

@end

