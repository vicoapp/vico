#import "ViMark.h"

@interface ViMarkGroup : NSObject
{
	SEL			 _groupSelector;
	NSMutableDictionary	*_groups;
}

@property (nonatomic, readonly) NSArray *groups;

+ (ViMarkGroup *)markGroupWithSelector:(SEL)aSelector;
- (ViMarkGroup *)initWithSelector:(SEL)aSelector;

- (NSString *)attribute;
- (void)rebuildFromMarks:(NSArray *)marks;
- (void)addMark:(ViMark *)mark;
- (void)addMarksFromArray:(NSArray *)marksToAdd;
- (void)removeMark:(ViMark *)mark;
- (void)clear;

@end




@interface ViMarkList : NSObject
{
	NSMutableArray		*_marks;
	NSMutableDictionary	*_marksByName;
	NSInteger		 _currentIndex;
	NSMutableDictionary	*_groups;
	id			 _identifier;
	NSImage			*_icon;
}

@property (nonatomic, readonly) NSArray *marks;

+ (ViMarkList *)markListWithIdentifier:(id)anIdentifier;
+ (ViMarkList *)markList;
- (ViMarkList *)initWithIdentifier:(id)anIdentifier;

- (void)clear;
- (ViMark *)lookup:(NSString *)name;
- (NSUInteger)count;
- (void)addMark:(ViMark *)mark;
- (void)addMarksFromArray:(NSArray *)marksToAdd;
- (void)removeMark:(ViMark *)mark;

- (ViMark *)first;
- (ViMark *)last;
- (ViMark *)next;
- (ViMark *)previous;
- (ViMark *)current;

@end






@interface ViMarkStack : NSObject
{
	NSString	*_name;
	NSMutableArray	*_lists;
	NSInteger	 _currentIndex;
	NSInteger	 _maxLists;
}

@property (nonatomic, readwrite, copy) NSString *name;
@property (nonatomic, readonly) ViMarkList *list;
@property (nonatomic, readwrite) NSInteger maxLists;

+ (ViMarkStack *)markStackWithName:(NSString *)name;
- (ViMarkStack *)initWithName:(NSString *)name;
- (ViMarkList *)makeList;
- (void)clear;
- (ViMarkList *)push:(ViMarkList *)list;
- (ViMarkList *)listAtIndex:(NSInteger)anIndex;
- (ViMarkList *)next;
- (ViMarkList *)previous;
- (ViMarkList *)last;
- (ViMarkList *)current;

@end






@interface ViMarkManager : NSObject
{
	NSMutableArray		*_stacks;
	NSMutableDictionary	*_namedStacks; // keyed by name
}

@property (nonatomic, readonly) NSArray *stacks;

+ (ViMarkManager *)sharedManager;
- (void)removeStack:(ViMarkStack *)stack;
- (void)removeStackWithName:(NSString *)name;
- (ViMarkStack *)makeStack;
- (ViMarkStack *)stackWithName:(NSString *)name;

@end
