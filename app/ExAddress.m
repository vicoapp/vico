#import "ExAddress.h"

@implementation ExAddress

@synthesize type = _type;
@synthesize offset = _offset;
@synthesize line = _line;
@synthesize pattern = _pattern;
@synthesize backwards = _backwards;
@synthesize mark = _mark;

- (id)copyWithZone:(NSZone *)zone
{
	ExAddress *copy = [[ExAddress allocWithZone:zone] init];
	copy.type = _type;
	copy.offset = _offset;
	copy.line = _line;
	copy.pattern = _pattern;
	copy.mark = _mark;
	return copy;
}

+ (ExAddress *)address
{
	return [[[ExAddress alloc] init] autorelease];
}

- (void)dealloc
{
	[_pattern release];
	[super dealloc];
}

- (NSString *)description
{
	switch (_type) {
	default:
	case ExAddressNone:
		return [NSString stringWithFormat:@"<ExAddress %p: none>", self, _offset];
	case ExAddressAbsolute:
		return [NSString stringWithFormat:@"<ExAddress %p: line %li, offset %li>", self, _line, _offset];
	case ExAddressSearch:
		return [NSString stringWithFormat:@"<ExAddress %p: pattern %@, offset %li>", self, _pattern, _offset];
	case ExAddressMark:
		return [NSString stringWithFormat:@"<ExAddress %p: mark %C, offset %li>", self, _mark, _offset];
	case ExAddressCurrent:
		return [NSString stringWithFormat:@"<ExAddress %p: current line, offset %li>", self, _offset];
	case ExAddressRelative:
		return [NSString stringWithFormat:@"<ExAddress %p: relative, offset %li>", self, _offset];
	}
}

@end
