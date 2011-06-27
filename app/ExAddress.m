#import "ExAddress.h"

@implementation ExAddress

@synthesize type;
@synthesize offset;
@synthesize line;
@synthesize pattern;
@synthesize backwards;
@synthesize mark;

- (id)copyWithZone:(NSZone *)zone
{
	ExAddress *copy = [[ExAddress alloc] init];
	copy.type = type;
	copy.offset = offset;
	copy.line = line;
	copy.pattern = [pattern copy];
	copy.mark = mark;
	return copy;
}

- (NSString *)description
{
	switch (type) {
	default:
	case ExAddressNone:
		return [NSString stringWithFormat:@"<ExAddress %p: none>", self, offset];
	case ExAddressAbsolute:
		return [NSString stringWithFormat:@"<ExAddress %p: line %li, offset %li>", self, line, offset];
	case ExAddressSearch:
		return [NSString stringWithFormat:@"<ExAddress %p: pattern %@, offset %li>", self, pattern, offset];
	case ExAddressMark:
		return [NSString stringWithFormat:@"<ExAddress %p: mark %C, offset %li>", self, mark, offset];
	case ExAddressCurrent:
		return [NSString stringWithFormat:@"<ExAddress %p: current line, offset %li>", self, offset];
	case ExAddressRelative:
		return [NSString stringWithFormat:@"<ExAddress %p: relative, offset %li>", self, offset];
	}
}

@end
