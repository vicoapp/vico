#import "ViDocumentView.h"
#import "ViScope.h"
#import "ViThemeStore.h"

@implementation ViDocumentView

@synthesize view;
@synthesize textView;
@synthesize document;

- (ViDocumentView *)initWithDocument:(ViDocument *)aDocument
{
	self = [super init];
	if (self)
	{
		document = aDocument;
	}
	return self;
}

/* Always executed on the main thread.
 */
- (void)applyScopes:(NSArray *)scopeArray inRange:(NSRange)applyRange
{
#if 0
	struct timeval start;
	struct timeval stop;
	struct timeval diff;
	gettimeofday(&start, NULL);
#endif

	ViTheme *theme = [[ViThemeStore defaultStore] defaultTheme];

	DEBUG(@"resetting attributes in range %@", NSStringFromRange(applyRange));
	[self resetAttributesInRange:applyRange];

	NSUInteger i;
	for (i = applyRange.location; i < NSMaxRange(applyRange);)
	{
		if (i >= [[textView textStorage] length] || i >= [scopeArray count])
			break;

		ViScope *scope = [scopeArray objectAtIndex:i];
		DEBUG(@"%@", scope);
		NSArray *names = [scope scopes];
		NSRange range = [scope range];

		if (range.location < i)
		{
			range.length = NSMaxRange(range) - i;
			range.location = i;
			if (range.length == 0)
			{
				INFO(@"*** probably something weired, range.length == 0");
				break;
			}
		}
	
		// Get the theme attributes for this collection of scopes.
		NSDictionary *attributes = [theme attributesForScopes:names];
		if (attributes)
		{
			[[textView layoutManager] addTemporaryAttributes:attributes forCharacterRange:range];
		}

		i += range.length;
	}

#if 0
	gettimeofday(&stop, NULL);
	timersub(&stop, &start, &diff);
	unsigned ms = diff.tv_sec * 1000 + diff.tv_usec / 1000;
	INFO(@"applied %u scopes in range %@ => %.3f s",
		[[context scopes] count], NSStringFromRange([context range]), (float)ms / 1000.0);
#endif
}

- (void)reapplyThemeWithScopes:(NSArray *)scopeArray
{
	[self applyScopes:scopeArray inRange:NSMakeRange(0, [[textView textStorage] length])];
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
				  nil];
	[[textView layoutManager] addTemporaryAttributes:defaultAttributes forCharacterRange:aRange];
}

@end
