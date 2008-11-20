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

- (void)reapplyTheme
{
	NSUInteger i, length = [storage length];
	[self resetAttributesInRange:NSMakeRange(0, length)];
	for (i = 0; i < length;)
	{
		NSRange range;
		NSArray *scopes = [[self layoutManager] temporaryAttribute:ViScopeAttributeName
					                  atCharacterIndex:i
						            effectiveRange:&range];
	
		if (scopes == nil)
		{
			break;
		}

		NSDictionary *attributes = [theme attributesForScopes:scopes];
		[[self layoutManager] addTemporaryAttributes:attributes forCharacterRange:range];
		
		i += range.length;
	}
}

/* Always executed on the main thread.
 */
- (void)applySyntaxResult:(ViSyntaxContext *)context
{
#if 0
	struct timeval start;
	struct timeval stop;
	struct timeval diff;
	gettimeofday(&start, NULL);
#endif

	//INFO(@"applying range %@ context %p", NSStringFromRange([context range]), context);

	DEBUG(@"resetting attributes in range %@", NSStringFromRange([context range]));
	[self resetAttributesInRange:[context range]];

	ViScope *scope;
	for (scope in [context scopes])
	{
		NSArray *scopes = [scope scopes];
		NSRange range = [scope range];
	
		DEBUG(@"[%@] (%p) range %@", [scopes componentsJoinedByString:@" "], scopes, NSStringFromRange(range));
	
		[[self layoutManager] addTemporaryAttribute:ViScopeAttributeName value:scopes forCharacterRange:range];
	
		// Get the theme attributes for this collection of scopes.
		NSDictionary *attributes = [theme attributesForScopes:scopes];
		[[self layoutManager] addTemporaryAttributes:attributes forCharacterRange:range];
	}

#if 0
	gettimeofday(&stop, NULL);
	timersub(&stop, &start, &diff);
	unsigned ms = diff.tv_sec * 1000 + diff.tv_usec / 1000;
	INFO(@"applied %u scopes in range %@ => %.3f s",
		[[context scopes] count], NSStringFromRange([context range]), (float)ms / 1000.0);
#endif

	[updateSymbolsTimer invalidate];
	updateSymbolsTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:updateSymbolsTimer == nil ? 0 : 0.6]
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

	[[self layoutManager] removeTemporaryAttribute:NSForegroundColorAttributeName forCharacterRange:aRange];
	[[self layoutManager] removeTemporaryAttribute:NSBackgroundColorAttributeName forCharacterRange:aRange];

	if (language)
	{
		[[self layoutManager] removeTemporaryAttribute:NSUnderlineStyleAttributeName forCharacterRange:aRange];
		[[self layoutManager] removeTemporaryAttribute:NSObliquenessAttributeName forCharacterRange:aRange];

		NSDictionary *defaultAttributes = nil;
		defaultAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
					  [theme foregroundColor], NSForegroundColorAttributeName,
					  [self font], NSFontAttributeName,
					  nil];
		[[self layoutManager] addTemporaryAttributes:defaultAttributes forCharacterRange:aRange];
	}

	if (resetFont)
	{
		// FIXME: this is an embarrasing hack, please fix properly!
		[self setFont:[self font]];
		resetFont = NO;
	}
}

- (void)performContext:(ViSyntaxContext *)ctx
{
	NSRange range = ctx.range;
	unichar *chars = malloc(range.length * sizeof(unichar));
	DEBUG(@"allocated %u bytes characters %p", range.length * sizeof(unichar), chars);
	[[storage string] getCharacters:chars range:range];

	ctx.characters = chars;
	unsigned startLine = ctx.lineOffset;

	// unsigned endLine = [self lineNumberAtLocation:NSMaxRange(range) - 1];
	// INFO(@"parsing line %u -> %u (ctx = %@)", startLine, endLine, ctx);

	[syntaxParser parseContext:ctx];
	[self performSelector:@selector(applySyntaxResult:) withObject:ctx afterDelay:0.0];

	if (ctx.lineOffset > startLine)
	{
		// INFO(@"line endings have changed at line %u", endLine);
		
		if (nextContext && nextContext != ctx)
		{
			INFO(@"cancelling scheduled parsing from line %u (nextContext = %@)", nextContext.lineOffset, nextContext);
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

	unsigned line = [self lineNumberAtLocation:aRange.location];
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
		INFO(@"context %@, from line %u, is cancelled", context, context.lineOffset);
		return;
	}

	NSUInteger startLocation = [self locationForStartOfLine:context.lineOffset];
	NSInteger endLocation = [self locationForStartOfLine:context.lineOffset + 10];
	if (endLocation == -1)
		endLocation = [storage length];

	context.range = NSMakeRange(startLocation, endLocation - startLocation);
	DEBUG(@"restarting parse context at line %u, range %@", startLocation, NSStringFromRange(context.range));
	[self performContext:context];
}

/*
 * Update syntax colors for the affected lines.
 */
- (void)textStorageDidProcessEditing:(NSNotification *)notification
{
	if (ignoreEditing)
	{
		ignoreEditing = NO;
		return;
	}

	NSRange area = [storage editedRange];
	DEBUG(@"got notification for changes in area %@, change length = %i", NSStringFromRange(area), [storage changeInLength]);
	
	if ([storage length] == 0)
		resetFont = YES;
	
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

	[self dispatchSyntaxParserWithRange:area restarting:NO];
}

- (void)highlightEverything
{
	if (language == nil)
	{
		[self resetAttributesInRange:NSMakeRange(0, [storage length])];
		return;
	}

	NSInteger endLocation = [self locationForStartOfLine:10];
	if (endLocation == -1)
		endLocation = [storage length];

	[self dispatchSyntaxParserWithRange:NSMakeRange(0, endLocation) restarting:NO];
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
		[syntaxParser pushContinuations:[NSValue valueWithRange:NSMakeRange(lineno, n)]];
	else
		[syntaxParser pullContinuations:[NSValue valueWithRange:NSMakeRange(lineno, n)]];
}

@end

