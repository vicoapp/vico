#import "ViMarkManager.h"
#import "ViCommon.h"
#include "logging.h"

@implementation ViMarkGroup

+ (ViMarkGroup *)markGroupWithSelector:(SEL)aSelector
{
	return [[[ViMarkGroup alloc] initWithSelector:aSelector] autorelease];
}

- (ViMarkGroup *)initWithSelector:(SEL)aSelector
{
	if ((self = [super init]) != nil) {
		_groupSelector = aSelector;
		_groups = [[NSMutableDictionary alloc] init];
		DEBUG(@"created group %@", self);
	}
	return self;
}

- (void)dealloc
{
	DEBUG_DEALLOC();
	[_groups release];
	[super dealloc];
}

- (NSString *)attribute
{
	return NSStringFromSelector(_groupSelector);
}

- (NSArray *)groups
{
	return [_groups allValues];
}

- (void)rebuildFromMarks:(NSArray *)marks
{
	[self clear];
	[self addMarksFromArray:marks];

	DEBUG(@"grouped by attribute %@: %@", [self attribute], [self groups]);
}

- (void)addMark:(ViMark *)mark
{
	id key = nil;
	if ([mark respondsToSelector:_groupSelector])
		key = [mark performSelector:_groupSelector];
	if (key == nil)
		key = [NSNull null];
	ViMarkList *group = [_groups objectForKey:key];
	if (group == nil) {
		[self willChangeValueForKey:@"groups"];
		group = [ViMarkList markListWithIdentifier:key];
		[_groups setObject:group forKey:key];
		[self didChangeValueForKey:@"groups"];
	}
	[group addMark:mark];
}

- (void)addMarksFromArray:(NSArray *)marksToAdd
{
	NSMapTable *groupsToAdd = [NSMapTable mapTableWithWeakToStrongObjects];
	BOOL didAddGroup = NO;
	for (ViMark *mark in marksToAdd) {
		id key = nil;
		if ([mark respondsToSelector:_groupSelector])
			key = [mark performSelector:_groupSelector];
		if (key == nil)
			key = [NSNull null];
		ViMarkList *group = [_groups objectForKey:key];
		if (group == nil) {
			if (!didAddGroup) {
				[self willChangeValueForKey:@"groups"];
				didAddGroup = YES;
			}
			group = [ViMarkList markListWithIdentifier:key];
			[_groups setObject:group forKey:key];
		}

		NSMutableArray *addArray = [groupsToAdd objectForKey:group];
		if (addArray == nil) {
			addArray = [NSMutableArray arrayWithObject:mark];
			[groupsToAdd setObject:addArray forKey:group];
		} else
			[addArray addObject:mark];
	}
	for (ViMarkList *group in groupsToAdd)
		[group addMarksFromArray:[groupsToAdd objectForKey:group]];
	if (didAddGroup)
		[self didChangeValueForKey:@"groups"];
}

- (void)removeMark:(ViMark *)mark
{
	id key = nil;
	if ([mark respondsToSelector:_groupSelector])
		key = [mark performSelector:_groupSelector];
	if (key == nil)
		key = [NSNull null];
	ViMarkList *group = [_groups objectForKey:key];
	[group removeMark:mark];
	if ([[group marks] count] == 0) {
		[self willChangeValueForKey:@"groups"];
		[_groups removeObjectForKey:key];
		[self didChangeValueForKey:@"groups"];
	}
}

- (void)clear
{
	if ([_groups count] > 0) {
		[self willChangeValueForKey:@"groups"];
		[_groups removeAllObjects];
		[self didChangeValueForKey:@"groups"];
	}
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViMarkGroup by %@ (%lu groups)>",
		[self attribute], [[self groups] count]];
}

@end




@implementation ViMarkList

@synthesize marks = _marks;
@synthesize userParameter = _userParameter;

+ (ViMarkList *)markListWithIdentifier:(id)anIdentifier
{
	return [[[ViMarkList alloc] initWithIdentifier:anIdentifier] autorelease];
}

+ (ViMarkList *)markList
{
	return [[[ViMarkList alloc] init] autorelease];
}

- (ViMarkList *)initWithIdentifier:(id)anIdentifier
{
	if ((self = [super init]) != nil) {
		_identifier = [anIdentifier retain]; // XXX: copy?
		_marks = [[NSMutableArray alloc] init];
		_marksByName = [[NSMutableDictionary alloc] init];
		_groups = [[NSMutableDictionary alloc] init];
		_currentIndex = NSNotFound;
	}
	return self;
}

- (void)dealloc
{
	DEBUG_DEALLOC();
	[_identifier release];
	[_marks release];
	[_marksByName release];
	[_groups release];
	[_icon release];
	[_userParameter release];
	[super dealloc];
}

- (ViMarkList *)init
{
	return [self initWithIdentifier:nil];
}

- (void)eachGroup:(void (^)(ViMarkGroup *))callback
{
	for (ViMarkGroup *group in [_groups allValues]) {
		callback(group);
	}
}

- (void)clear
{
	if ([_marks count] > 0) {
		[self willChangeValueForKey:@"marks"];
		[_marks removeAllObjects];
		[_marksByName removeAllObjects];
		[self didChangeValueForKey:@"marks"];
	}

	[self eachGroup:^(ViMarkGroup *group) { [group clear]; }];
}

- (void)addMark:(ViMark *)mark
{
	NSUInteger lastIndex = [_marks count];
	NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:lastIndex];
	[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"marks"];
	if (mark.name) {
		ViMark *oldMark = [_marksByName objectForKey:mark.name];
		if (oldMark) {
			[_marks removeObject:oldMark]; // XXX: linear search!
			[self eachGroup:^(ViMarkGroup *group) { [group removeMark:oldMark]; }];
		}
		[_marksByName setObject:mark forKey:mark.name];
	}
	[_marks addObject:mark];
	[mark registerList:self];
	[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"marks"];

	[self eachGroup:^(ViMarkGroup *group) { [group addMark:mark]; }];
}

- (void)addMarksFromArray:(NSArray *)marksToAdd
{
	NSUInteger numToAdd = [marksToAdd count];
	if (numToAdd == 0)
		return;

	NSUInteger lastIndex = [_marks count];
	NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(lastIndex, numToAdd)];
	[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"marks"];
	for (ViMark *mark in marksToAdd) {
		if (mark.name) {
			ViMark *oldMark = [_marksByName objectForKey:mark.name];
			if (oldMark)
				[_marks removeObject:oldMark]; // XXX: linear search!
			[_marksByName setObject:mark forKey:mark.name];
		}
		[mark registerList:self];
	}
	[_marks addObjectsFromArray:marksToAdd];
	[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"marks"];

	[self eachGroup:^(ViMarkGroup *group) { [group addMarksFromArray:marksToAdd]; }];
}

- (void)removeMarkAtIndex:(NSUInteger)index
{
	ViMark *mark = [_marks objectAtIndex:index];
	NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:index];

	[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"marks"];
	[_marks removeObjectAtIndex:index];
	if (mark.name)
		[_marksByName removeObjectForKey:mark.name];
	[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"marks"];

	[self eachGroup:^(ViMarkGroup *group) { [group removeMark:mark]; }];
}

- (void)removeMark:(ViMark *)mark
{
	NSUInteger index = [_marks indexOfObject:mark]; // XXX: linear search!
	if (index == NSNotFound)
		return;
	[self removeMarkAtIndex:index];
}

- (ViMark *)lookup:(NSString *)aName
{
	return [_marksByName objectForKey:aName];
}

- (NSUInteger)count
{
	return [_marks count];
}

- (ViMarkGroup *)groupBy:(NSString *)selectorString
{
	ViMarkGroup *group = [_groups objectForKey:selectorString];
	if (group == nil) {
		group = [ViMarkGroup markGroupWithSelector:NSSelectorFromString(selectorString)];
		[group rebuildFromMarks:_marks];
		[_groups setObject:group forKey:selectorString];
	}
	DEBUG(@"returning group %@", group);
	return group;
}

- (id)valueForUndefinedKey:(NSString *)key
{
	DEBUG(@"request for key %@ in mark list %@", key, self);
	if ([key hasPrefix:@"group_by_"])
		return [self groupBy:[key substringFromIndex:9]];
	return [super valueForUndefinedKey:key];
}

- (void)setSelectionIndexes:(NSIndexSet *)indexSet
{
	DEBUG(@"got selection indexes %@", indexSet);
	_currentIndex = [indexSet firstIndex];
}

- (NSIndexSet *)selectionIndexes
{
	if (_currentIndex >= 0 && _currentIndex < [_marks count])
		return [NSIndexSet indexSetWithIndex:_currentIndex];
	return [NSIndexSet indexSet];
}

- (ViMark *)markAtIndex:(NSInteger)anIndex
{
	if (anIndex >= 0 && anIndex < [_marks count]) {
		if (_currentIndex != anIndex) {
			[self willChangeValueForKey:@"selectionIndexes"];
			_currentIndex = anIndex;
			[self didChangeValueForKey:@"selectionIndexes"];
		}
		return [_marks objectAtIndex:_currentIndex];
	}
	return nil;
}

- (ViMark *)next
{
	return [self markAtIndex:_currentIndex + 1];
}

- (ViMark *)previous
{
	return [self markAtIndex:_currentIndex - 1];
}

- (ViMark *)first
{
	return [self markAtIndex:0];
}

- (ViMark *)last
{
	return [self markAtIndex:[_marks count] - 1];
}

- (ViMark *)current
{
	return [self markAtIndex:_currentIndex];
}

- (BOOL)atBeginning
{
	return (_currentIndex <= 0);
}

- (BOOL)atEnd
{
	return (_currentIndex + 1 >= [_marks count]);
}

- (void)push:(ViMark *)mark
{
	DEBUG(@"pushing mark %@", mark);
	[self addMark:mark];
	[self last];
}

- (ViMark *)pop
{
	ViMark *mark = nil;
	if (_currentIndex >= 0 && _currentIndex < [_marks count]) {
		mark = [[_marks objectAtIndex:_currentIndex] retain];
		[self removeMarkAtIndex:_currentIndex];
		[self last];
	}
	DEBUG(@"popped mark %@", mark);
	return mark;
}

- (NSString *)description
{
	if (_identifier)
		return [NSString stringWithFormat:@"<ViMarkList (%@): %lu marks>", _identifier, [_marks count]];
	else
		return [NSString stringWithFormat:@"<ViMarkList %p: %lu marks>", self, [_marks count]];
}

#pragma mark -

- (id)title
{
	return [_identifier description];
}

- (BOOL)isLeaf
{
	return NO;
}

- (id)lineNumber
{
	return nil;
}

- (id)columnNumber
{
	return nil;
}

- (NSUInteger)line
{
	return NSNotFound;
}

- (NSUInteger)column
{
	return NSNotFound;
}

- (NSString *)rangeString
{
	return nil;
}

@end





@implementation ViMarkStack

@synthesize name = _name;
@synthesize maxLists = _maxLists;

+ (ViMarkStack *)markStackWithName:(NSString *)name
{
	return [[[ViMarkStack alloc] initWithName:name] autorelease];
}

- (ViMarkStack *)initWithName:(NSString *)aName
{
	if ((self = [super init]) != nil) {
		_name = [aName copy];
		_lists = [[NSMutableArray alloc] init];
		_currentIndex = -1;
		_maxLists = 10;
		[self makeList];
		DEBUG(@"created mark stack %@", self);
	}
	return self;
}

- (void)dealloc
{
	DEBUG_DEALLOC();
	[_name release];
	[_lists release];
	[super dealloc];
}

- (void)clear
{
	if ([_lists count] > 0) {
		[self willChangeValueForKey:@"selectionIndexes"];
		[self willChangeValueForKey:@"list"];
		[_lists removeAllObjects];
		_currentIndex = -1;
		[self didChangeValueForKey:@"list"];
		[self didChangeValueForKey:@"selectionIndexes"];
	}
}

- (ViMarkList *)list
{
	if (_currentIndex >= 0) {
		DEBUG(@"returning list at index %li for stack %@", _currentIndex, self);
		return [_lists objectAtIndex:_currentIndex];
	}

	DEBUG(@"no lists added in stack %@", self);
	return nil;
}

- (ViMarkList *)makeList
{
	return [self push:[ViMarkList markList]];
}

- (void)trim
{
	while ([_lists count] > _maxLists && _maxLists > 0) {
		DEBUG(@"trimming list %@ at index 0", [_lists objectAtIndex:0]);
		[_lists removeObjectAtIndex:0];
	}
	if (_currentIndex >= [_lists count]) {
		_currentIndex = [_lists count] - 1;
		DEBUG(@"adjusted currentIndex to %li", _currentIndex);
	}
}

- (void)setMaxLists:(NSInteger)num
{
	_maxLists = IMAX(1, num);
	if ([_lists count] > _maxLists) {
		[self willChangeValueForKey:@"selectionIndexes"];
		[self willChangeValueForKey:@"list"];
		[self trim];
		[self didChangeValueForKey:@"list"];
		[self didChangeValueForKey:@"selectionIndexes"];
	}
}

- (void)removeListAtIndex:(NSUInteger)index
{
	if (index < [_lists count]) {
		BOOL changeSelection = (_currentIndex <= index);
		if (changeSelection)
			[self willChangeValueForKey:@"selectionIndexes"];
		[self willChangeValueForKey:@"list"];
		[_lists removeObjectAtIndex:index];
		if (changeSelection)
			_currentIndex--; // this may set _currentIndex to -1
		[self didChangeValueForKey:@"list"];
		if (changeSelection)
			[self didChangeValueForKey:@"selectionIndexes"];
	}
}

- (ViMarkList *)push:(ViMarkList *)list
{
	[self willChangeValueForKey:@"selectionIndexes"];
	[self willChangeValueForKey:@"list"];

	DEBUG(@"lists before push: %@, currentIndex = %li", _lists, _currentIndex);

	if (++_currentIndex < 0)
		_currentIndex = 0;

	if (_currentIndex >= [_lists count]) {
		DEBUG(@"appending list %@", list);
		[_lists addObject:list];
		[self trim];
	} else {
		DEBUG(@"insert list %@ at index %li", list, _currentIndex);
		[_lists replaceObjectAtIndex:_currentIndex withObject:list];
	}

	[self didChangeValueForKey:@"list"];
	[self didChangeValueForKey:@"selectionIndexes"];

	DEBUG(@"lists after push: %@, currentIndex = %li", _lists, _currentIndex);

	return list;
}

- (void)setSelectionIndexes:(NSIndexSet *)indexSet
{
	DEBUG(@"got selection indexes %@", indexSet);
	[self willChangeValueForKey:@"list"];
	_currentIndex = [indexSet firstIndex];
	[self didChangeValueForKey:@"list"];
}

- (NSIndexSet *)selectionIndexes
{
	if (_currentIndex >= 0 && _currentIndex < [_lists count])
		return [NSIndexSet indexSetWithIndex:_currentIndex];
	return [NSIndexSet indexSet];
}

- (ViMarkList *)listAtIndex:(NSInteger)anIndex
{
	if (anIndex >= 0 && anIndex < [_lists count]) {
		if (_currentIndex != anIndex) {
			[self willChangeValueForKey:@"selectionIndexes"];
			[self willChangeValueForKey:@"list"];
			_currentIndex = anIndex;
			[self didChangeValueForKey:@"list"];
			[self didChangeValueForKey:@"selectionIndexes"];
		}
		return [_lists objectAtIndex:_currentIndex];
	}
	return nil;
}

- (ViMarkList *)next
{
	return [self listAtIndex:_currentIndex + 1];
}

- (ViMarkList *)previous
{
	return [self listAtIndex:_currentIndex - 1];
}

- (ViMarkList *)last
{
	return [self listAtIndex:[_lists count] - 1];
}

- (ViMarkList *)current
{
	return [self listAtIndex:_currentIndex];
}

- (BOOL)atBeginning
{
	return (_currentIndex <= 0);
}

- (BOOL)atEnd
{
	return (_currentIndex + 1 >= [_lists count]);
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViMarkStack %p: %@, list %li/%lu>", self, _name, _currentIndex, [_lists count]];
}

@end





@implementation ViMarkManager

@synthesize stacks = _stacks;

static ViMarkManager *__sharedManager = nil;

+ (ViMarkManager *)sharedManager
{
	if (__sharedManager == nil)
		__sharedManager = [[ViMarkManager alloc] init];
	return __sharedManager;
}

- (ViMarkManager *)init
{
	DEBUG(@"self is %@, sharedManager is %@", self, __sharedManager);
	if (__sharedManager)
		return [__sharedManager retain];

	if ((self = [super init]) != nil) {
		_stacks = [[NSMutableArray alloc] init];
		_namedStacks = [[NSMutableDictionary alloc] init];
		DEBUG(@"created mark manager %@", self);
		[self stackWithName:@"Global Marks"];
		__sharedManager = self;
	}
	return self;
}

- (void)dealloc
{
	[_stacks release];
	[_namedStacks release];
	[super dealloc];
}

- (void)removeStack:(ViMarkStack *)stack
{
	[self willChangeValueForKey:@"stacks"];
	[_stacks removeObject:stack];
	[self didChangeValueForKey:@"stacks"];
}

- (void)removeStackWithName:(NSString *)name
{
	ViMarkStack *stack = [_namedStacks objectForKey:name];
	if (stack) {
		[_namedStacks removeObjectForKey:name];
		[self removeStack:stack];
	}
}

- (ViMarkStack *)addStack:(ViMarkStack *)stack
{
	[self willChangeValueForKey:@"stacks"];
	[_stacks addObject:stack];
	[self didChangeValueForKey:@"stacks"];
	return stack;
}

- (ViMarkStack *)makeStack
{
	return [self addStack:[ViMarkStack markStackWithName:@"Untitled"]];
}

- (ViMarkStack *)stackWithName:(NSString *)name
{
	ViMarkStack *stack = [_namedStacks objectForKey:name];
	if (stack)
		return stack;

	stack = [ViMarkStack markStackWithName:name];
	[_namedStacks setObject:stack forKey:name];
	return [self addStack:stack];
}

- (id)valueForUndefinedKey:(NSString *)key
{
	DEBUG(@"request for key %@ in mark manager %@", key, self);
	return [self stackWithName:key];
}

@end
