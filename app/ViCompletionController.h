#import "ViCompletionView.h"
#import "ViCompletion.h"
#import "ViThemeStore.h"

@class ViCompletionController;

@protocol ViCompletionDelegate <NSObject>
@optional
- (BOOL)completionController:(ViCompletionController *)completionController
       shouldTerminateForKey:(NSInteger)keyCode;
- (BOOL)completionController:(ViCompletionController *)completionController
     insertPartialCompletion:(NSString *)partialCompletion
                     inRange:(NSRange)range;
@end

@interface ViCompletionController : NSObject <NSTableViewDataSource, NSTableViewDelegate>
{
	IBOutlet NSWindow *window;
	IBOutlet ViCompletionView *tableView;
	NSArray *completions;
	NSMutableArray *filteredCompletions;
	ViCompletion *selection;
	ViTheme *theme;
	NSMutableString *filter;
	NSMutableParagraphStyle *matchParagraphStyle;
	id<ViCompletionDelegate> delegate;
	NSInteger terminatingKey;
	NSRange range;
	NSUInteger prefixLength;
	NSPoint screenOrigin;
	BOOL upwards;
	BOOL fuzzySearch;
}

@property (readwrite, assign) id<ViCompletionDelegate> delegate;
@property (readonly) NSWindow *window;
@property (readwrite, assign) NSArray *completions;
@property (readonly) NSInteger terminatingKey;
@property (readonly) NSRange range;
@property (readwrite, assign) NSString *filter;

+ (id)sharedController;
+ (NSString *)commonPrefixInCompletions:(NSArray *)completions;
+ (void)appendFilter:(NSString *)string
           toPattern:(NSMutableString *)pattern
          fuzzyClass:(NSString *)fuzzyClass;

- (ViCompletion *)chooseFrom:(NSArray *)anArray
                       range:(NSRange)aRange
                prefixLength:(NSUInteger)prefixLength
                          at:(NSPoint)screenOrigin
                   direction:(int)direction /* 0 = down, 1 = up */
                 fuzzySearch:(BOOL)fuzzyFlag
               initialFilter:(NSString *)initialFilter;

@end
