#import "ViDocumentView.h"
#import "ViScope.h"
#import "ViThemeStore.h"

@implementation ViDocumentView

@synthesize view;
@synthesize textView;

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

	DEBUG(@"applying range %@ context %p", NSStringFromRange([context range]), context);

	DEBUG(@"resetting attributes in range %@", NSStringFromRange([context range]));
	[self resetAttributesInRange:[context range]];

	ViTheme *theme = [[ViThemeStore defaultStore] defaultTheme];
	ViScope *scope;
	for (scope in [context scopes])
	{
		NSArray *scopes = [scope scopes];
		NSRange range = [scope range];
	
		DEBUG(@"[%@] (%p) range %@", [scopes componentsJoinedByString:@" "], scopes, NSStringFromRange(range));
	
		[[textView layoutManager] addTemporaryAttribute:ViScopeAttributeName value:scopes forCharacterRange:range];
	
		// Get the theme attributes for this collection of scopes.
		NSDictionary *attributes = [theme attributesForScopes:scopes];
		[[textView layoutManager] addTemporaryAttributes:attributes forCharacterRange:range];
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
							target:textView
						      selector:@selector(updateSymbolList:)
						      userInfo:nil
						       repeats:NO];
	[[NSRunLoop currentRunLoop] addTimer:updateSymbolsTimer forMode:NSDefaultRunLoopMode];
}

- (void)reapplyTheme
{
	ViTheme *theme = [[ViThemeStore defaultStore] defaultTheme];
	NSUInteger i, length = [[textView textStorage] length];
	[self resetAttributesInRange:NSMakeRange(0, length)];
	for (i = 0; i < length;)
	{
		NSRange range;
		NSArray *scopes = [[textView layoutManager] temporaryAttribute:ViScopeAttributeName
					                  atCharacterIndex:i
						            effectiveRange:&range];
	
		if (scopes == nil)
		{
			break;
		}

		NSDictionary *attributes = [theme attributesForScopes:scopes];
		[[textView layoutManager] addTemporaryAttributes:attributes forCharacterRange:range];
		
		i += range.length;
	}
}

- (NSFont *)font
{
	return [NSFont userFixedPitchFontOfSize:12.0];
}

- (void)resetAttributesInRange:(NSRange)aRange
{
	if (aRange.length == 0)
		return;

	[[textView layoutManager] removeTemporaryAttribute:NSForegroundColorAttributeName forCharacterRange:aRange];
	[[textView layoutManager] removeTemporaryAttribute:NSBackgroundColorAttributeName forCharacterRange:aRange];

	[[textView layoutManager] removeTemporaryAttribute:NSUnderlineStyleAttributeName forCharacterRange:aRange];
	[[textView layoutManager] removeTemporaryAttribute:NSObliquenessAttributeName forCharacterRange:aRange];

	ViTheme *theme = [[ViThemeStore defaultStore] defaultTheme];
	NSDictionary *defaultAttributes = nil;
	defaultAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
				  [theme foregroundColor], NSForegroundColorAttributeName,
				  [self font], NSFontAttributeName,
				  nil];
	[[textView layoutManager] addTemporaryAttributes:defaultAttributes forCharacterRange:aRange];
}

@end
