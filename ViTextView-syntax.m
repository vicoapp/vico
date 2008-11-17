#import "ViDocument.h"
#import "ViTextView.h"
#import "ViLanguageStore.h"
#import "ViScope.h"
#import "MHSysTree.h"
#import "logging.h"
#import "NSString-scopeSelector.h"

#include <sys/time.h>

@interface ViTextView (syntax_private)
- (void)resetAttributesInRange:(NSRange)aRange;
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

	DEBUG(@"resetting attributes in range %@", NSStringFromRange([aResult range]));
	[self resetAttributesInRange:[aResult range]];

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

	[updateSymbolsTimer invalidate];
	updateSymbolsTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:0.6]
						      interval:0
							target:self
						      selector:@selector(updateSymbolList:)
						      userInfo:nil
						       repeats:NO];
	[[NSRunLoop currentRunLoop] addTimer:updateSymbolsTimer forMode:NSDefaultRunLoopMode];
}

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
	[self dispatchSyntaxParserWithRange:area restarting:NO];
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

/* Dummy message used to interrupt the run loop.
 */
- (void)ping:(id)arg
{
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

