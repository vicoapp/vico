#import "NSString-additions.h"

@implementation NSString (additions)

- (NSInteger)numberOfLines
{
	NSInteger i, n;
	NSUInteger eol, end;

	for (i = n = 0; i < [self length]; i = end, n++) {
		[self getLineStart:NULL end:&end contentsEnd:&eol forRange:NSMakeRange(i, 0)];
		if (end == eol)
			break;
        }

        return n;
}

@end

