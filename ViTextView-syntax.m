#import "ViTextView.h"

@implementation ViTextView (syntax)

- (void)initHighlighting
{
	if(!syntax_initialized)
	{
		syntax_initialized = YES;

		commentColor = [[NSColor colorWithCalibratedRed:0 green:102.0/256 blue:1.0 alpha:1.0] retain];
		stringColor = [[NSColor colorWithCalibratedRed:3.0/256 green:106.0/256 blue:7.0/256 alpha:1.0] retain];
		numberColor = [[NSColor colorWithCalibratedRed:0 green:0 blue:205.0/256 alpha:1.0] retain];
		keywordColor = [[NSColor colorWithCalibratedRed:0 green:0 blue:1.0 alpha:1.0] retain];

		keywordRegex = [OGRegularExpression regularExpressionWithString:@"\\b(break|case|continue|default|do|else|for|goto|if|_Pragma|return|switch|while)\\b"];
		storageRegex = [OGRegularExpression regularExpressionWithString:@"\\b(asm|__asm__|auto|bool|_Bool|char|_Complex|double|enum|float|_Imaginary|int|long|short|signed|struct|typedef|union|unsigned|void)\\b"];
		storageModifierRegex = [OGRegularExpression regularExpressionWithString:@"\\b(const|extern|register|restrict|static|volatile|inline)\\b"];
	}	
}

- (void)highlightMatches:(NSArray *)matches withAttributes:(NSDictionary *)attributes
{
	OGRegularExpressionMatch *match;
	for(match in matches)
	{
		[[self layoutManager] addTemporaryAttributes:attributes
					   forCharacterRange:[match rangeOfMatchedString]];
	}
}

- (void)highlightInRange:(NSRange)aRange
{
	NSLog(@"%s range = %u + %u", _cmd, aRange.location, aRange.length);

	if(!syntax_initialized)
		[self initHighlighting];

	[[self layoutManager] removeTemporaryAttribute:NSForegroundColorAttributeName forCharacterRange:aRange];
	[[self layoutManager] removeTemporaryAttribute:@"ViScopeSelector" forCharacterRange:aRange];

	NSDictionary *keywordAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
		keywordColor, NSForegroundColorAttributeName,
		@"keyword", @"ViScopeSelector",
		nil];

	NSArray *matches = [keywordRegex allMatchesInString:[storage string] range:aRange];
	[self highlightMatches:matches withAttributes:keywordAttributes];

	matches = [storageRegex allMatchesInString:[storage string] range:aRange];
	[self highlightMatches:matches withAttributes:keywordAttributes];

	matches = [storageModifierRegex allMatchesInString:[storage string] range:aRange];
	[self highlightMatches:matches withAttributes:keywordAttributes];
}

- (void)highlightInWrappedRange:(NSValue *)wrappedRange
{
	[self highlightInRange:[wrappedRange rangeValue]];
}

/*
 * Update syntax colors.
 */
- (void)textStorageDidProcessEditing:(NSNotification *)notification
{
	NSRange area = [storage editedRange];
	
	// extend our range along line boundaries.
	NSUInteger bol, eol;
	[[storage string] getLineStart:&bol end:NULL contentsEnd:&eol forRange:area];
	area.location = bol;
	area.length = eol - bol;

	if(area.length == 0)
		return;

	// temporary attributes doesn't work right when called from the notification
	[self performSelector:@selector(highlightInWrappedRange:) withObject:[NSValue valueWithRange:area] afterDelay:0];
}

- (void)highlightEverything
{
	//[storage beginEditing];
	[self highlightInRange:NSMakeRange(0, [[storage string] length])];
	//[storage endEditing];
}

@end
