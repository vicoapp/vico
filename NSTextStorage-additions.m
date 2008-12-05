#import "NSTextStorage-additions.h"

@implementation NSTextStorage (additions)

- (NSInteger)locationForStartOfLine:(NSUInteger)aLineNumber
{
	int line = 1;
	NSInteger location = 0;
	while (line < aLineNumber)
	{
		NSUInteger end;
		[[self string] getLineStart:NULL end:&end contentsEnd:NULL forRange:NSMakeRange(location, 0)];
		if (location == end)
		{
			return -1;
		}
		location = end;
		line++;
	}
	
	return location;
}

- (NSUInteger)lineNumberAtLocation:(NSUInteger)aLocation
{
	int line = 1;
	NSUInteger location = 0;
	while (location < aLocation)
	{
		NSUInteger bol, end;
		[[self string] getLineStart:&bol end:&end contentsEnd:NULL forRange:NSMakeRange(location, 0)];
		if (end > aLocation)
		{
			break;
		}
		location = end;
		line++;
	}

	return line;
}

@end
