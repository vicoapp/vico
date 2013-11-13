#import "ViTypesetter.h"
#import "ViFold.h"

@implementation ViTypesetter

- (NSTypesetterControlCharacterAction)actionForControlCharacterAtIndex:(NSUInteger)characterIndex
{
	NSNumber *foldedAttribute =
	  [[self attributedString] attribute:ViFoldedAttributeName
								 atIndex:characterIndex
						  effectiveRange:NULL];

	if (foldedAttribute && [foldedAttribute boolValue]) {
		return NSTypesetterZeroAdvancementAction;
	} else {
		NSLog(@"Got a yummy control character with no folded attribute at %lu!", characterIndex);
		return [super actionForControlCharacterAtIndex:characterIndex];
	}
}

@end
