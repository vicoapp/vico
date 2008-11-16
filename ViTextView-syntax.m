#import "ViDocument.h"
#import "ViTextView.h"
#import "ViLanguageStore.h"
#import "ViScope.h"
#import "ViSymbol.h"
#import "MHSysTree.h"
#import "logging.h"
#import "NSString-scopeSelector.h"

#include <sys/time.h>

@interface ViTextView (syntax_private)
- (void)resetAttributesInRange:(NSRange)aRange;
- (NSRange)trackSymbolSelector:(NSString *)symbolSelector forward:(BOOL)forward fromLocation:(NSUInteger)aLocation;
@end

@implementation ViTextView (syntax)

/* Always executed on the main thread.
 */
- (void)applyScope:(ViScope *)aScope
{
	NSArray *scopes = [aScope scopes];
	NSRange range = [aScope range];

	DEBUG(@"applying scopes [%@] to range %u + %u", [scopes componentsJoinedByString:@" "], range.location, range.length);		
	[[self layoutManager] addTemporaryAttribute:ViScopeAttributeName value:scopes forCharacterRange:range];

#if 0

	BOOL continuedSymbol = NO;
	if (lastSymbolSelector && (NSMaxRange(lastSymbolRange) == range.location || NSIntersectionRange(lastSymbolRange, range).length > 0))
	{
		// This is (possibly) a continuation of the last symbol.
		if ([lastSymbolSelector matchesScopes:scopes])
		{
			// Yes it is, extend the range.
			lastSymbolRange = NSUnionRange(lastSymbolRange, range);
			continuedSymbol = YES;
		}
	}

	if (!continuedSymbol)
	{
		if (lastSymbolSelector)
		{
			NSString *symbol = [[storage string] substringWithRange:lastSymbolRange];
			INFO(@"got complete symbol %@ at range %@", symbol, NSStringFromRange(lastSymbolRange));
			[pendingSymbols addObject:[[ViSymbol alloc] initWithSymbol:symbol range:lastSymbolRange]];
			lastSymbolSelector = nil;
		}
	
		lastSymbolSelector = [self selectorForSymbolMatchingScope:scopes];
		if (lastSymbolSelector)
		{
			lastSymbolRange = range;
			if (shouldTrackSymbolBackwards)
			{
				NSRange backwardRange = [self trackSymbolSelector:lastSymbolSelector forward:NO fromLocation:lastSymbolRange.location];
				lastSymbolRange = NSUnionRange(lastSymbolRange, backwardRange);
				NSString *symbol = [[storage string] substringWithRange:lastSymbolRange];
				INFO(@"got partial symbol %@", symbol);
			}
		}
	}

	shouldTrackSymbolBackwards = NO;

#endif

	// Get the theme attributes for this collection of scopes.
	NSDictionary *attributes = [theme attributesForScopes:scopes];
	[[self layoutManager] addTemporaryAttributes:attributes forCharacterRange:range];
}

/* Always executed on the main thread.
 */
- (void)applySyntaxResult:(ViSyntaxContext *)aResult
{
#if 1
	struct timeval start;
	struct timeval stop;
	struct timeval diff;
	gettimeofday(&start, NULL);
#endif

	// pendingSymbols = [[NSMutableArray alloc] init];

	DEBUG(@"resetting attributes in range %@", NSStringFromRange([aResult range]));
	[self resetAttributesInRange:[aResult range]];

#if 0
	if ([context count] > 2 && [[context objectAtIndex:2] boolValue] == YES)
	{
		[context removeObjectAtIndex:2];
		shouldTrackSymbolBackwards = YES;
	}
#endif

	// [[aTree tree] performSelectorWithAllObjects:@selector(debugScopes:) target:self];
	ViScope *scope;
	for (scope in [aResult scopes])
	{
		DEBUG(@"[%@] (%p) range %@", [scope.scopes componentsJoinedByString:@" "], scope.scopes, NSStringFromRange(scope.range));
		[self applyScope:scope];
	}

#if 1
	gettimeofday(&stop, NULL);
	timersub(&stop, &start, &diff);
	unsigned ms = diff.tv_sec * 1000 + diff.tv_usec / 1000;
	INFO(@"applied %u scopes in range %@ => %.3f s",
		[[aResult scopes] count], NSStringFromRange([aResult range]), (float)ms / 1000.0);
#endif

	//// [[self delegate] removeSymbolsInRange:wholeRange];
	//// [[self delegate] addSymbolsFromArray:pendingSymbols];
	pendingSymbols = nil;
}

/* Always executed on the main thread.
 */
- (NSRange)trackSymbolSelector:(NSString *)symbolSelector forward:(BOOL)forward fromLocation:(NSUInteger)aLocation
{
	NSRange trackedRange = NSMakeRange(aLocation, 0);
	NSUInteger i = aLocation;
	for (;;)
	{
		if (forward && i >= [storage length])
			break;
		else if (!forward && i == 0)
			break;
	
		NSRange range = NSMakeRange(0, 0);
		NSArray *scopes = [[self layoutManager] temporaryAttribute:ViScopeAttributeName
							  atCharacterIndex:i
							    effectiveRange:&range];
		if (scopes == nil)
			break;

		if ([symbolSelector matchesScopes:scopes])
			trackedRange = NSUnionRange(trackedRange, range);
		else
			break;

		if (forward)
			i += range.length;
		else
			i -= range.length;
	}

	return trackedRange;
}

#if 0
/* Always executed on the main thread.
 */
- (void)applyContextAndFinalizeSymbols:(NSMutableArray *)context
{
	[self applyContext:context];

	if (lastSymbolSelector)
	{
		/* roll forward until non-match
		 */
		NSRange forwardRange = [self trackSymbolSelector:lastSymbolSelector forward:YES fromLocation:NSMaxRange(lastSymbolRange)];
		lastSymbolRange = NSUnionRange(lastSymbolRange, forwardRange);

		NSString *symbol = [[storage string] substringWithRange:lastSymbolRange];
		INFO(@"got complete symbol %@ at range %@", symbol, NSStringFromRange(lastSymbolRange));
		// [pendingSymbols addObject:[[ViSymbol alloc] initWithSymbol:symbol range:lastSymbolRange]];
		[[self delegate] addSymbol:[[ViSymbol alloc] initWithSymbol:symbol range:lastSymbolRange]];
		lastSymbolSelector = nil;
	}
}
#endif

- (void)resetAttributesInRange:(NSRange)aRange
{
	if (aRange.length == 0)
		return;

	// [[self layoutManager] removeTemporaryAttribute:ViContinuationAttributeName forCharacterRange:aRange];
	// [[self layoutManager] removeTemporaryAttribute:NSFontAttributeName forCharacterRange:aRange];
	[[self layoutManager] removeTemporaryAttribute:NSForegroundColorAttributeName forCharacterRange:aRange];
	[[self layoutManager] removeTemporaryAttribute:NSBackgroundColorAttributeName forCharacterRange:aRange];
	
	NSDictionary *defaultAttributes = nil;
	if (language)
	{
		[[self layoutManager] removeTemporaryAttribute:ViScopeAttributeName forCharacterRange:aRange];
		[[self layoutManager] removeTemporaryAttribute:NSUnderlineStyleAttributeName forCharacterRange:aRange];
		[[self layoutManager] removeTemporaryAttribute:NSObliquenessAttributeName forCharacterRange:aRange];

		defaultAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
					  [theme foregroundColor], NSForegroundColorAttributeName,
					    [self font], NSFontAttributeName,
					  nil];
	}

	[[self layoutManager] addTemporaryAttributes:defaultAttributes forCharacterRange:aRange];

	if (resetFont)
	{
		// FIXME: this is an embarrasing hack, please fix properly!
		[self setFont:[self font]];
		resetFont = NO;
	}
}

- (void)dispatchSyntaxParserWithRange:(NSRange)aRange restarting:(BOOL)flag
{
	if (aRange.length == 0)
		return;

	unichar *chars = malloc(aRange.length * sizeof(unichar));
	DEBUG(@"allocated %u bytes characters %p", aRange.length * sizeof(unichar), chars);
	[[storage string] getCharacters:chars range:aRange];

	unsigned line = [self lineNumberAtLocation:aRange.location];
	ViSyntaxContext *ctx = [[ViSyntaxContext alloc] initWithCharacters:chars range:aRange line:line restarting:flag];

	[syntaxParser performSelector:@selector(parseContext:) onThread:highlightThread withObject:ctx waitUntilDone:NO];
}

- (void)dispatchSyntaxParserFromLine:(NSNumber *)startLine
{
	NSUInteger startLocation = [self locationForStartOfLine:[startLine unsignedIntValue]];
	[self dispatchSyntaxParserWithRange:NSMakeRange(startLocation, [storage length] - startLocation) restarting:YES];
}

/*
 * Update syntax colors.
 */
- (void)textStorageDidProcessEditing:(NSNotification *)notification
{
	NSRange area = [storage editedRange];
	DEBUG(@"got notification for changes in area %@, change length = %i", NSStringFromRange(area), [storage changeInLength]);
	
	if ([storage length] == 0)
		resetFont = YES;
	
	if (ignoreEditing)
	{
		ignoreEditing = NO;
		return;
	}
	
	if (language == nil)
	{
		[self resetAttributesInRange:area];
		return;
	}
	
	// extend our range along line boundaries.
	NSUInteger bol, eol;
	[[storage string] getLineStart:&bol end:&eol contentsEnd:NULL forRange:area];
	area.location = bol;
	area.length = eol - bol;

	DEBUG(@"extended area to %@", NSStringFromRange(area));

#if 0
	if ([highlightThread isExecuting])
	{
		INFO(@"cancelling highlighting thread %p", highlightThread);
		[highlightThread cancel];
		highlightThread = nil;
		// [[NSRunLoop mainRunLoop] cancelPerformSelectorsWithTarget:self];
	}
#endif
	[self dispatchSyntaxParserWithRange:area restarting:YES];
}

- (void)highlightEverything
{
	if (language == nil)
	{
		[self resetAttributesInRange:NSMakeRange(0, [storage length])];
		return;
	}
	[self dispatchSyntaxParserWithRange:NSMakeRange(0, [storage length]) restarting:NO];
}

- (void)highlightMain:(id)arg
{
	NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
	
	// dummy timer so we don't exit the run loop
	[NSTimer scheduledTimerWithTimeInterval:1e8 target:self selector:@selector(doFireTimer:) userInfo:nil repeats:YES];
	INFO(@"run loop for highlight thread %p starts", [NSThread currentThread]);
	while (![[NSThread currentThread] isCancelled])
	{
		[runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
	}
	INFO(@"run loop for highlight thread %p exits", [NSThread currentThread]);
}

- (void)pushContinuationsFromLocation:(NSUInteger)aLocation string:(NSString *)aString forward:(BOOL)flag
{
	int n = 0;
	NSInteger i = 0;

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
		lineno = [self lineNumberAtLocation:aLocation - 1];

	if (flag)
		[syntaxParser performSelector:@selector(pushContinuations:) onThread:highlightThread withObject:[NSValue valueWithRange:NSMakeRange(lineno, n)] waitUntilDone:NO];
	else
		[syntaxParser performSelector:@selector(pullContinuations:) onThread:highlightThread withObject:[NSValue valueWithRange:NSMakeRange(lineno, n)] waitUntilDone:NO];
}

@end

