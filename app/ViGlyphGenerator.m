#import "ViGlyphGenerator.h"
#import "ViFold.h"

@implementation ViGlyphGenerator

#pragma mark -
#pragma mark NSGlyphGenerator interface

- (void)generateGlyphsForGlyphStorage:(id<NSGlyphStorage>)destinationStorage
			desiredNumberOfCharacters:(NSUInteger)numberOfCharacters
						   glyphIndex:(NSUInteger *)glyphIndex
					   characterIndex:(NSUInteger *)characterIndex
{
	// Store the original destination (likely a ViLayoutManager).
	_originalStorage = destinationStorage;

	// Call the usual glyph generator to generate the glyphs, but tell it the requesting
	// NSGlyphStorage object is us, so that we can intercept the changes and do whatever
	// we need to there.
	[[NSGlyphGenerator sharedGlyphGenerator] generateGlyphsForGlyphStorage:self
											desiredNumberOfCharacters:numberOfCharacters
														   glyphIndex:glyphIndex
													   characterIndex:characterIndex];

	_originalStorage = nil;
}

#pragma mark -
#pragma mark NSGlyphStorage interface

- (void)insertGlyphs:(const NSGlyph *)glyphs length:(NSUInteger)incomingGlyphLength forStartingGlyphAtIndex:(NSUInteger)glyphIndex characterIndex:(NSUInteger)characterIndex
{
	NSNumber *foldedAttribute;
	NSRange effectiveRange;
	NSGlyph *buffer = NULL;

	foldedAttribute =
	  (NSNumber *)[[self attributedString] attribute:ViFoldedAttributeName
											 atIndex:characterIndex
							   longestEffectiveRange:&effectiveRange
											 inRange:NSMakeRange(0, characterIndex + incomingGlyphLength)];

	// Fill in all folded characters with NSNullGlyphs.
	if (foldedAttribute && [foldedAttribute boolValue]) {
		NSInteger size = sizeof(NSGlyph) * incomingGlyphLength;
		NSGlyph nullGlyph = NSNullGlyph;

		buffer = malloc(size);
		memset_pattern4(buffer, &nullGlyph, effectiveRange.length);

		for (NSUInteger i = effectiveRange.length; i < incomingGlyphLength; ++i) {
			buffer[i] = glyphs[i];
		}

		glyphs = buffer;
	}

	[_originalStorage insertGlyphs:glyphs length:incomingGlyphLength forStartingGlyphAtIndex:glyphIndex characterIndex:characterIndex];

	if (buffer)
		free(buffer);
}

- (void)setIntAttribute:(NSInteger)attributeTag value:(NSInteger)value forGlyphAtIndex:(NSUInteger)glyphIndex
{
    [_originalStorage setIntAttribute:attributeTag value:value forGlyphAtIndex:glyphIndex];
}

- (NSAttributedString *)attributedString
{
	return [_originalStorage attributedString];
}

- (NSUInteger)layoutOptions {
	return [_originalStorage layoutOptions];
}

@end
