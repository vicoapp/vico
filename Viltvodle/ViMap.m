#import "ViMap.h"
#import "ViError.h"
#import "NSString-scopeSelector.h"
#import "NSString-additions.h"
#import "NSArray-patterns.h"
#include "logging.h"

@implementation ViMapping

@synthesize scopeSelector;
@synthesize keySequence;
@synthesize keyString;
@synthesize action;
@synthesize flags;
@synthesize recursive;
@synthesize macro;
@synthesize parameter;

+ (ViMapping *)mappingWithKeySequence:(NSArray *)aKeySequence
			       action:(SEL)anAction
				flags:(NSUInteger)flags
			    parameter:(id)param
				scope:(NSString *)aSelector
{
	return [[ViMapping alloc] initWithKeySequence:aKeySequence
					       action:anAction
					        flags:flags
					    parameter:param
					        scope:aSelector];
}

+ (ViMapping *)mappingWithKeySequence:(NSArray *)aKeySequence
				macro:(NSString *)aMacro
			    recursive:(BOOL)recursiveFlag
				scope:(NSString *)aSelector
{
	return [[ViMapping alloc] initWithKeySequence:aKeySequence
						macro:aMacro
					    recursive:recursiveFlag
					        scope:aSelector];
}

- (ViMapping *)initWithKeySequence:(NSArray *)aKeySequence
			    action:(SEL)anAction
			     flags:(NSUInteger)actionFlags
			 parameter:(id)param
			     scope:(NSString *)aSelector
{
	if ((self = [super init]) != nil) {
		keySequence = aKeySequence;
		action = anAction;
		flags = actionFlags;
		scopeSelector = aSelector ? [aSelector copy] : @"";
		keyString = [NSString stringWithKeySequence:keySequence];
		parameter = param;
	}
	return self;
}

- (ViMapping *)initWithKeySequence:(NSArray *)aKeySequence
			     macro:(NSString *)aMacro
			 recursive:(BOOL)recursiveFlag
			     scope:(NSString *)aSelector
{
	if ((self = [super init]) != nil) {
		keySequence = aKeySequence;
		macro = [aMacro copy];
		recursive = recursiveFlag;
		scopeSelector = aSelector ? [aSelector copy] : @"";
		keyString = [NSString stringWithKeySequence:keySequence];
	}
	return self;
}

#define has_flag(flag) ((flags & flag) == flag)

- (BOOL)isAction
{
	return macro == nil;
}

- (BOOL)isMacro
{
	return !!macro;
}

- (BOOL)isOperator
{
	return has_flag(ViMapNeedMotion);
}

- (BOOL)isMotion
{
	return has_flag(ViMapIsMotion);
}

- (BOOL)isLineMode
{
	return has_flag(ViMapLineMode);
}

- (BOOL)needsArgument
{
	return has_flag(ViMapNeedArgument);
}

- (BOOL)wantsKeys
{
	return [self isOperator] || [self needsArgument];
}

- (NSString *)description
{
	if ([self isAction])
		return [NSString stringWithFormat:@"<ViMapping %@: \"%@\", flags 0x%02x>",
		    keyString, NSStringFromSelector(action), flags];
	else
		return [NSString stringWithFormat:@"<ViMapping %@: macro \"%@\">",
		    keyString, macro];
}

@end

@implementation ViMap

@synthesize name;
@synthesize actions;
@synthesize operatorMap;
@synthesize acceptsCounts;
@synthesize defaultAction;

static NSMutableDictionary *maps = nil;

+ (void)clearAll
{
	maps = nil;
}

+ (ViMap *)mapWithName:(NSString *)mapName
{
	if (maps == nil)
		maps = [NSMutableDictionary dictionary];

	ViMap *map = [maps objectForKey:mapName];
	if (map == nil) {
		map = [[ViMap alloc] initWithName:mapName];
		[maps setObject:map forKey:mapName];
	}

	return map;
}

+ (ViMap *)insertMap
{
	return [ViMap mapWithName:@"insertMap"];
}

+ (ViMap *)normalMap
{
	return [ViMap mapWithName:@"normalMap"];
}

+ (ViMap *)operatorMap
{
	return [ViMap mapWithName:@"operatorMap"];
}

+ (ViMap *)visualMap
{
	return [ViMap mapWithName:@"visualMap"];
}

+ (ViMap *)explorerMap
{
	return [ViMap mapWithName:@"explorerMap"];
}

+ (ViMap *)symbolMap
{
	return [ViMap mapWithName:@"symbolMap"];
}

- (ViMap *)initWithName:(NSString *)aName
{
	if ((self = [super init]) != nil) {
		name = aName;
		actions = [NSMutableArray array];
		includes = [NSMutableSet set];
		acceptsCounts = YES;
	}
	return self;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViMap %@>", name];
}

- (ViMapping *)lookupKeySequence:(NSArray *)keySequence
                          inMaps:(NSArray *)maps
                       withScope:(NSArray *)scopeArray
                     allowMacros:(BOOL)allowMacros
                      excessKeys:(NSArray **)excessKeys
                         timeout:(BOOL *)timeout
                           error:(NSError **)outError
{
	ViMapping *candidate = nil;
	ViMapping *exact_candidate = nil;
	ViMapping *op = nil; /* fully matched operator */
	for (ViMap *map in maps) {
		for (ViMapping *m in map.actions) {
			u_int64_t rank = [m.scopeSelector matchesScopes:scopeArray];
			if (rank == 0)
				continue;
			if (!allowMacros && [m isMacro])
				continue;

//			DEBUG(@"testing key [%@] against %@", keySequence, m);

			if ([keySequence hasPrefix:m.keySequence] && [m wantsKeys]) {
				/*
				 * We found an action that requires additional (dynamic) keys.
				 * Remember the most significant match.
				 */
				if ([m.keySequence count] > [op.keySequence count]) {
					op = m;
					DEBUG(@"got operator candidate %@", op);
				}
			} else if ([keySequence isEqual:m.keySequence] &&
				  ([m isAction] || allowMacros) &&
				  ![m wantsKeys]) {
				/* 
				 * If we get an exact match, but there are longer key
				 * sequences that might match if we get more keys, we
				 * set a timeout and then go with the exact match.
				 * Only do this if the exact match doesn't require
				 * additional keys, because in that case we must wait
				 * for keys anyway.
				 */
				if (exact_candidate && [exact_candidate isAction] == [m isAction]) {
					/*
					 * This should not happen inside a single map as we make
					 * sure there are no duplicate key sequences of the same type
					 * that either does or does not require additional keys.
					 *
					 * However, since we iterate over multiple included maps,
					 * we might now get duplicates between maps.
					 *
					 * What to do?
					 *  - overwrite the old one (or skip the new one)
					 *    (maps are not iterated in a predictable order)
					 *  - offer a menu of choices (ugh, feels fugly)
					 *  - bail?
					 */
					if (([m isAction] && m.action == exact_candidate.action) ||
					    (![m isAction] && [m.macro isEqualToString:exact_candidate.macro])) {
						/* Pjuh, they are identical! */
					} else {
						DEBUG(@"Ouch! already got an exact match %@", exact_candidate);
						if (outError)
							*outError = [ViError errorWithCode:ViErrorMapInternal
										    format:@"Duplicate mapping %@.", [m keyString]];
						return nil;
					}
				}

				/* Macros override regular actions. */
				if (exact_candidate == nil || [exact_candidate isAction]) {
					DEBUG(@"got exact candidate %@", m);
					exact_candidate = m;
				}
			}

			/* Check for possibly partial matches. */
			if ([m.keySequence hasPrefix:keySequence]) {
				DEBUG(@"got candidate %@", m);
				/*
				 * Check for a macro overriding an action with the same key sequence.
				 */
				if (candidate &&
				    [m.keySequence count] == [candidate.keySequence count] &&
				    [m isAction] != [candidate isAction]) {
					if ([m isMacro])
						candidate = m;
					continue;
				}

				if (candidate || [m.keySequence count] != [keySequence count]) {
					/* Need more keys to disambiguate. */
					if (candidate)
						DEBUG(@"%s", "multiple matches, need more keys");
					else
						DEBUG(@"%s", "partial match, need more keys");

					if (exact_candidate) {
						if (*timeout == YES) {
							DEBUG(@"timeout: returning exact match %@",
							    exact_candidate);
							return exact_candidate;
						}
						DEBUG(@"setting timeout for exact candidate %@",
						    exact_candidate);
						*timeout = YES;
					}

					if (outError)
						*outError = [ViError errorWithCode:ViErrorMapAmbiguous
									    format:@"Ambiguous match."];

					return nil;
				}
				candidate = m;
			}
		}
	}

	if (candidate == nil && op != nil) {
		NSUInteger oplen = [op.keySequence count];
		NSRange r = NSMakeRange(oplen, [keySequence count] - oplen);
		*excessKeys = [keySequence subarrayWithRange:r];
		DEBUG(@"mapped [%@] to %@ with excess keys [%@]",
		    keySequence, op, *excessKeys);
		return op;
	}

	/*
	 * Problem: if there is an operator and another mapping with the same
	 * prefix as the operator, we need to decide whether the keys after the
	 * prefix is a motion for the operator, or a specialization of another
	 * mapping.
	 *
	 * When we know this, it's sort of too late to match the operator,
	 * and we need to backtrack and return the excess keys back to the parser
	 * to check for a motion command.
	 */

	/*
	 * Not only operators might need to return excess keys, but also actions
	 * with arguments!
	 */

	if (candidate == nil && outError)
		*outError = [ViError errorWithCode:ViErrorMapNotFound
					    format:@"%@ is not mapped.", [NSString stringWithKeySequence:keySequence]];

	return candidate;
}

- (void)resolveIncludedMaps:(NSMutableArray *)includeMaps
{
	for (ViMap *m in includes) {
		DEBUG(@"adding included map %@", m);
		[includeMaps addObject:m];
		[m resolveIncludedMaps:includeMaps];
	}
}

- (ViMapping *)lookupKeySequence:(NSArray *)keySequence
                       withScope:(NSArray *)scopeArray
                     allowMacros:(BOOL)allowMacros
                      excessKeys:(NSArray **)excessKeys
                         timeout:(BOOL *)timeoutPtr
                           error:(NSError **)outError
{
	ViMapping *m = nil;

	NSMutableArray *resolved = [NSMutableArray arrayWithObject:self];
	[self resolveIncludedMaps:resolved];

	DEBUG(@"looking up [%@] in maps %@", keySequence, resolved);

	NSError *error = nil;
	m = [self lookupKeySequence:keySequence
			     inMaps:resolved
			  withScope:scopeArray
			allowMacros:allowMacros
			 excessKeys:excessKeys
			    timeout:timeoutPtr
			      error:&error];

	if (outError && error.code != ViErrorMapAmbiguous)
		*outError = error;

	if (m == nil) {
		if (error.code == ViErrorMapNotFound && defaultAction) {
			/* Nothing matched. Return the default action, if there is one. */
			if (outError)
				*outError = nil;
			m = [ViMapping mappingWithKeySequence:keySequence
						       action:defaultAction
						        flags:0
						    parameter:nil
						        scope:nil];
			DEBUG(@"using default action %@", m);
			return m;
		}
	}

	DEBUG(@"found action %@", m);

	return m;
}

- (void)addMapping:(ViMapping *)nm
{
	for (ViMapping *m in actions)
		if ([m.keySequence isEqual:nm.keySequence] &&
		    [m.scopeSelector isEqualToString:nm.scopeSelector] &&
		    [m isAction] == [nm isAction] &&
		    (![m isAction] ||
		     ([m wantsKeys] == [nm wantsKeys]))) {
			[actions removeObject:m];
			break;
		}

	[actions addObject:nm];
	DEBUG(@"added mapping %@", nm);
}

- (void)map:(NSString *)keySequence
         to:(NSString *)macro
recursively:(BOOL)recursiveFlag
      scope:(NSString *)scopeSelector
{
	NSArray *keyCodes = [keySequence keyCodes];
	if (keyCodes == nil) {
		INFO(@"invalid key sequence: %@", keySequence);
		return;
	}
	[self addMapping:[ViMapping mappingWithKeySequence:keyCodes
						     macro:macro
						 recursive:recursiveFlag
						     scope:scopeSelector]];
}

- (void)map:(NSString *)keySequence
         to:(NSString *)macro
      scope:(NSString *)scopeSelector
{
	[self map:keySequence
	       to:macro
      recursively:NO
	    scope:scopeSelector];
}

- (void)map:(NSString *)keySequence
         to:(NSString *)macro
{
	[self map:keySequence
	       to:macro
      recursively:NO
	    scope:nil];
}

- (void)unmap:(NSString *)keySequence
        scope:(NSString *)scopeSelector
{
	NSArray *keyCodes = [keySequence keyCodes];
	if (keyCodes == nil) {
		INFO(@"invalid key sequence: %@", keySequence);
		return;
	}

	for (ViMapping *m in actions)
		if ([m.keySequence isEqual:keySequence] &&
		    [m.scopeSelector isEqualToString:(scopeSelector ?: @"")] &&
		    [m isMacro]) {
			[actions removeObject:m];
			break;
		}
}

- (void)unmap:(NSString *)keySequence
{
	[self unmap:keySequence scope:nil];
}

- (void)setKey:(NSString *)keySequence
      toAction:(SEL)selector
         flags:(NSUInteger)flags
     parameter:(id)param
         scope:(NSString *)scopeSelector
{
	NSArray *keyCodes = [keySequence keyCodes];
	if (keyCodes == nil) {
		INFO(@"invalid key sequence: %@", keySequence);
		return;
	}
	[self addMapping:[ViMapping mappingWithKeySequence:keyCodes
						    action:selector
						     flags:flags
						 parameter:param
						     scope:scopeSelector]];
}

- (void)setKey:(NSString *)keySequence
      toAction:(SEL)selector
{
	[self setKey:keySequence
	    toAction:selector
	       flags:0
	   parameter:nil
	       scope:nil];
}

- (void)setKey:(NSString *)keySequence
      toMotion:(SEL)selector
         flags:(NSUInteger)flags
     parameter:(id)param
         scope:(NSString *)scopeSelector
{
	[self setKey:keySequence
	    toAction:selector
	       flags:flags|ViMapIsMotion
	   parameter:param
	       scope:scopeSelector];
}

- (void)setKey:(NSString *)keySequence
      toMotion:(SEL)selector
{
	[self setKey:keySequence
	    toMotion:selector
	       flags:0
	   parameter:nil
	       scope:nil];
}

- (void)setKey:(NSString *)keySequence
  toEditAction:(SEL)selector
         flags:(NSUInteger)flags
     parameter:(id)param
         scope:(NSString *)scopeSelector
{
	[self setKey:keySequence
	    toAction:selector
	       flags:flags|ViMapSetsDot
	   parameter:param
	       scope:scopeSelector];
}

- (void)setKey:(NSString *)keySequence
  toEditAction:(SEL)selector
{
	[self setKey:keySequence
	toEditAction:selector
	       flags:0
	   parameter:nil
	       scope:nil];
}

- (void)setKey:(NSString *)keySequence
    toOperator:(SEL)selector
         flags:(NSUInteger)flags
     parameter:(id)param
         scope:(NSString *)scopeSelector
{
	[self setKey:keySequence
	toEditAction:selector
	       flags:flags|ViMapNeedMotion
	   parameter:param
	       scope:scopeSelector];
}

- (void)setKey:(NSString *)keySequence
    toOperator:(SEL)selector
{
	[self setKey:keySequence
	  toOperator:selector
	       flags:0
	   parameter:nil
	       scope:nil];
}

- (void)include:(ViMap *)map
{
	DEBUG(@"including map %@ in map %@", map, self);
	[includes addObject:map];
}

@end
