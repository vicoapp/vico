#import "NSCollection-enumeration.h"

#define ENUMERATION_IMPLEMENTATION_FOR(CLASS_NAME, BLOCK_DECLARATION)\
@implementation CLASS_NAME (enumeration)\
\
- (void)eachBlock:(void (^)(id,BOOL *))block\
{\
	[self enumerateObjectsUsingBlock:BLOCK_DECLARATION {\
		block(obj, stop);\
	}];\
}\
\
- (NSSet *)mapBlock:(id (^)(id,BOOL *))block\
{\
	NSMutableSet *collector = [NSMutableSet setWithCapacity:[self count]];\
\
	[self eachBlock:^(id obj, BOOL *stop) {\
		id result = block(obj, stop);\
\
		if (result && ! (*stop)) {\
			[collector addObject:result];\
		}\
    }];\
\
	return collector;\
}\
\
@end

ENUMERATION_IMPLEMENTATION_FOR(NSSet, ^(id obj, BOOL *stop))
ENUMERATION_IMPLEMENTATION_FOR(NSArray, ^(id obj, NSUInteger index, BOOL *stop))
