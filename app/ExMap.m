#import "ExMap.h"
#import "NSString-scopeSelector.h"
#include "logging.h"

@implementation ExMapping

@synthesize names = _names;
@synthesize syntax = _syntax;
@synthesize scopeSelector = _scopeSelector;
@synthesize expression = _expression;
@synthesize action = _action;
@synthesize completion = _completion;

- (ExMapping *)initWithNames:(NSArray *)namesArray
		      syntax:(NSString *)aSyntax
		       scope:(NSString *)aScopeSelector
{
	if ((self = [super init]) != nil) {
		if ([namesArray count] == 0) {
			INFO(@"%s", "missing ex mapping name");
			return nil;
		}
		_names = [namesArray mutableCopy];
		_syntax = [aSyntax copy];
		_scopeSelector = [aScopeSelector copy] ?: [@"" retain];
	}
	return self;
}

- (ExMapping *)initWithNames:(NSArray *)namesArray
		      syntax:(NSString *)aSyntax
                  expression:(NuBlock *)anExpression
                       scope:(NSString *)aScopeSelector
{
	if ((self = [self initWithNames:namesArray syntax:aSyntax scope:aScopeSelector]) != nil) {
		_expression = [anExpression retain];
	}
	return self;
}

- (ExMapping *)initWithNames:(NSArray *)namesArray
		      syntax:(NSString *)aSyntax
                      action:(SEL)anAction
                       scope:(NSString *)aScopeSelector
{
	if ((self = [self initWithNames:namesArray syntax:aSyntax scope:aScopeSelector]) != nil) {
		_action = anAction;
	}
	return self;
}

- (void)dealloc
{
	[_names release];
	[_scopeSelector release];
	[_syntax release];
	[_parameter release];
	[_completion release];
	[_expression release];
	[_usage release];
	[_help release];
	[super dealloc];
}

- (NSString *)name
{
	return [_names objectAtIndex:0];
}

- (void)addAlias:(NSString *)aName
{
	/* XXX: when adding an alias, shouldn't we check for duplicate mappings in the same map? */
	[_names addObject:aName];
}

- (void)removeAlias:(NSString *)aName
{
	if ([_names count] > 1)
		[_names removeObject:aName];
}

- (int)matchesName:(NSString *)name exactly:(BOOL)exactMatch
{
	NSUInteger len = [name length];
	int match = 0;
	for (NSString *n in _names) {
		if (exactMatch ? [name isEqualToString:n] : [n hasPrefix:name]) {
			if (len == [n length])
				return 2; /* exact match */
			match = 1;
		}
	}
	return match;
}

- (NSString *)description
{
	if ([_scopeSelector length] > 0)
		return [NSString stringWithFormat:@"<ExMapping %@(%@): %@>",
		    self.name, _scopeSelector, _expression ? [_expression stringValue] : NSStringFromSelector(_action)];
	else
		return [NSString stringWithFormat:@"<ExMapping %@: %@>",
		    self.name, _expression ? [_expression stringValue] : NSStringFromSelector(_action)];
}

@end

@implementation ExMap

@synthesize mappings = _mappings;

- (ExMap *)init
{
	if ((self = [super init]) != nil) {
		_mappings = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[_mappings release];
	[super dealloc];
}

+ (ExMap *)defaultMap
{
	static ExMap *__defaultMap = nil;
	if (__defaultMap == nil)
		__defaultMap = [[ExMap alloc] init];
	return __defaultMap;
}

- (ExMapping *)lookup:(NSString *)aString
	    withScope:(ViScope *)scope
{
	ExMapping *candidate = nil;
	NSMutableSet *dups = nil;
	u_int64_t rank = 0;
	BOOL exactMatch = NO;

	if ([aString length] == 0)
		return nil;

	for (ExMapping *m in _mappings) {
		/*
		 * Check if the name match. We start with partial
		 * matching. If an exact match is found, we continue
		 * only considering exact matches.
		 */
		int match;
		if ((match = [m matchesName:aString exactly:exactMatch]) > 0) {
			if (!exactMatch && match == 2) {
				exactMatch = YES;
				rank = [m.scopeSelector match:scope];
				candidate = m;
				DEBUG(@"got exact match %@ w/rank %lu", candidate, rank);
				dups = nil;
				/* An exact match overrides any partial command with a higher rank. */
				continue;
			}

			u_int64_t r = [m.scopeSelector match:scope];
			if (r > rank) {
				rank = r;
				candidate = m;
				dups = nil;
			} else if (r == rank) {
				if (dups == nil)
					dups = [NSMutableSet set];
				[dups addObject:m];
			}
		}
	}

	if (dups) {
		[dups addObject:candidate];
		INFO(@"ambiguous command; could be %@", dups);
	}

	DEBUG(@"%@ -> %@", aString, candidate);
	return candidate;
}

- (ExMapping *)lookup:(NSString *)aString
{
	return [self lookup:aString withScope:nil];
}

- (void)addMapping:(ExMapping *)mapping
{
	DEBUG(@"adding ex command %@", mapping);
	ExMapping *old = nil;
	for (ExMapping *m in _mappings) {
		if ([m.scopeSelector isEqualToString:mapping.scopeSelector]) {
			for (NSString *n in mapping.names) {
				if ([m matchesName:n exactly:YES]) {
					old = m;
					break;
				}
			}
		}
		if (old)
			break;
	}

	if (old) {
		DEBUG(@"replacing previous ex command %@ w/same scope %@", old, old.scopeSelector);
		[_mappings removeObject:old];
	}
	[_mappings addObject:mapping];
}

- (ExMapping *)define:(id)aName
	       syntax:(NSString *)aSyntax
		   as:(id)implementation
		scope:(NSString *)aScopeSelector
{
	ExMapping *m = nil;

	NSArray *names = aName;
	if ([aName isKindOfClass:[NuCell class]])
		names = [aName array];
	else if ([aName isKindOfClass:[NSString class]])
		names = [NSArray arrayWithObject:aName];
	else if (![aName isKindOfClass:[NSArray class]]) {
		INFO(@"Invalid mapping name class %@", NSStringFromClass([aName class]));
		return nil;
	}

	if ([implementation isKindOfClass:[NSString class]])
		m = [[ExMapping alloc] initWithNames:names
					      syntax:aSyntax
					      action:NSSelectorFromString(implementation)
					       scope:aScopeSelector];
	else if ([implementation isKindOfClass:[NuBlock class]])
		m = [[ExMapping alloc] initWithNames:names
					      syntax:aSyntax
					  expression:implementation
					       scope:aScopeSelector];
	else {
		INFO(@"Invalid mapping implementation class %@",
			NSStringFromClass([implementation class]));
		return nil;
	}

	if (m) {
		[self addMapping:m];
		[m release];
	}

	return m;
}

- (ExMapping *)define:(id)aName
	       syntax:(NSString *)aSyntax
		   as:(id)implementation
{
	return [self define:aName syntax:aSyntax as:implementation scope:nil];
}

@end

