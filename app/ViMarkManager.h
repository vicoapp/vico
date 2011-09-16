#import "ViMark.h"

@interface ViMarkGroup : NSObject
{
	SEL groupSelector;
	NSMutableDictionary *groups;
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
	NSMutableArray *marks;
	NSMutableDictionary *marksByName;
	NSInteger currentIndex;
	NSMutableDictionary *groups;
	id identifier;
	NSImage *icon;
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
	NSString *name;
	NSMutableArray *lists;
	NSInteger currentIndex;
}
@property (nonatomic, readwrite, assign) NSString *name;
@property (nonatomic, readonly) ViMarkList *list;
+ (ViMarkStack *)markStackWithName:(NSString *)name;
- (ViMarkStack *)initWithName:(NSString *)name;
- (ViMarkList *)makeList;
- (void)clear;
- (ViMarkList *)pop;
- (ViMarkList *)push:(ViMarkList *)list;
@end






@interface ViMarkManager : NSObject
{
	NSMapTable *marksPerDocument; // keys are documents, values are NSHashTables of marks
	NSMutableArray *stacks;
	NSMutableDictionary *namedStacks; // keyed by name
}

@property (nonatomic, readonly) NSArray *stacks;
+ (ViMarkManager *)sharedManager;
- (void)removeStack:(ViMarkStack *)stack;
- (void)removeStackWithName:(NSString *)name;
- (ViMarkStack *)makeStack;
- (ViMarkStack *)stackWithName:(NSString *)name;

- (void)registerMark:(ViMark *)mark;
- (void)unregisterMark:(ViMark *)mark;
- (NSHashTable *)marksForDocument:(ViDocument *)document;

@end
