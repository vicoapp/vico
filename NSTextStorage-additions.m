#import "NSTextStorage-additions.h"

@implementation NSTextStorage (additions)

static NSMutableCharacterSet *wordSet = nil;

- (NSInteger)locationForStartOfLine:(NSUInteger)aLineNumber
{
	int line = 1;
	NSInteger location = 0;
	while (line < aLineNumber) {
		NSUInteger end;
		[[self string] getLineStart:NULL end:&end contentsEnd:NULL forRange:NSMakeRange(location, 0)];
		if (location == end)
			return -1;
		location = end;
		line++;
	}
	
	return location;
}

- (NSUInteger)lineNumberAtLocation:(NSUInteger)aLocation
{
	int line = 1;
	NSUInteger location = 0;
	while (location < aLocation) {
		NSUInteger bol, end;
		[[self string] getLineStart:&bol end:&end contentsEnd:NULL forRange:NSMakeRange(location, 0)];
		if (end > aLocation)
			break;
		location = end;
		line++;
	}

	return line;
}

- (NSUInteger)skipCharactersInSet:(NSCharacterSet *)characterSet from:(NSUInteger)startLocation to:(NSUInteger)toLocation backward:(BOOL)backwardFlag
{
	NSString *s = [self string];
	NSRange r = [s rangeOfCharacterFromSet:[characterSet invertedSet]
				       options:backwardFlag ? NSBackwardsSearch : 0
					 range:backwardFlag ? NSMakeRange(toLocation, startLocation - toLocation + 1) : NSMakeRange(startLocation, toLocation - startLocation)];
	if (r.location == NSNotFound)
		return backwardFlag ? toLocation : toLocation; // FIXME: this is strange...
	return r.location;
}

- (NSUInteger)skipCharactersInSet:(NSCharacterSet *)characterSet fromLocation:(NSUInteger)startLocation backward:(BOOL)backwardFlag
{
	return [self skipCharactersInSet:characterSet
				    from:startLocation
				      to:backwardFlag ? 0 : [self length]
				backward:backwardFlag];
}

- (NSUInteger)skipWhitespaceFrom:(NSUInteger)startLocation toLocation:(NSUInteger)toLocation
{
	return [self skipCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]
				    from:startLocation
				      to:toLocation
				backward:NO];
}

- (NSUInteger)skipWhitespaceFrom:(NSUInteger)startLocation
{
	return [self skipCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]
			    fromLocation:startLocation
				backward:NO];
}

- (NSString *)wordAtLocation:(NSUInteger)aLocation range:(NSRange *)returnRange
{
	if (aLocation >= [self length]) {
		if (returnRange != nil)
			*returnRange = NSMakeRange(0, 0);
		return @"";
	}

	if (wordSet == nil) {
		wordSet = [NSMutableCharacterSet characterSetWithCharactersInString:@"_"];
		[wordSet formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
	}

	NSUInteger word_start = [self skipCharactersInSet:wordSet fromLocation:aLocation backward:YES];
	if (word_start < aLocation && word_start > 0)
		word_start += 1;

	NSUInteger word_end = [self skipCharactersInSet:wordSet fromLocation:aLocation backward:NO];
	if (word_end > word_start) {
		NSRange range = NSMakeRange(word_start, word_end - word_start);
		if (returnRange)
			*returnRange = range;
		return [[self string] substringWithRange:range];
	}

	if (returnRange)
		*returnRange = NSMakeRange(0, 0);

	return nil;
}

- (NSString *)wordAtLocation:(NSUInteger)aLocation
{
	return [self wordAtLocation:aLocation range:nil];
}

- (NSUInteger)lineIndexAtLocation:(NSUInteger)aLocation
{
	NSUInteger bol, end;
	[[self string] getLineStart:&bol end:&end contentsEnd:NULL forRange:NSMakeRange(aLocation, 0)];
	return aLocation - bol;
}

- (NSUInteger)columnAtLocation:(NSUInteger)aLocation
{
	NSUInteger bol, end;
	[[self string] getLineStart:&bol end:&end contentsEnd:NULL forRange:NSMakeRange(aLocation, 0)];
	NSUInteger c = 0, i;
	int ts = [[NSUserDefaults standardUserDefaults] integerForKey:@"tabstop"];
	for (i = bol; i <= aLocation && i < end; i++)
	{
		unichar ch = [[self string] characterAtIndex:i];
		if (ch == '\t')
			c += ts - (c % ts);
		else
			c++;
	}
	return c;
}

- (NSUInteger)locationForColumn:(NSUInteger)column fromLocation:(NSUInteger)aLocation acceptEOL:(BOOL)acceptEOL
{
	NSUInteger bol, eol;
	[[self string] getLineStart:&bol end:NULL contentsEnd:&eol forRange:NSMakeRange(aLocation, 0)];
	NSUInteger c = 0, i;
	int ts = [[NSUserDefaults standardUserDefaults] integerForKey:@"tabstop"];
	for (i = bol; i < eol; i++)
	{
		unichar ch = [[self string] characterAtIndex:i];
		if (ch == '\t')
			c += ts - (c % ts);
		else
			c++;
		if (c >= column)
			break;
	}
	if (!acceptEOL && i == eol && bol < eol)
		i = eol - 1;
	return i;
}

- (NSString *)lineForLocation:(NSUInteger)aLocation
{
	NSUInteger bol, eol;
	[[self string] getLineStart:&bol end:NULL contentsEnd:&eol forRange:NSMakeRange(aLocation, 0)];
	return [[self string] substringWithRange:NSMakeRange(bol, eol - bol)];
}

- (BOOL)isBlankLineAtLocation:(NSUInteger)aLocation
{
	NSString *line = [self lineForLocation:aLocation];
	return [line rangeOfCharacterFromSet:[[NSCharacterSet whitespaceCharacterSet] invertedSet]].location == NSNotFound;
}

@end

