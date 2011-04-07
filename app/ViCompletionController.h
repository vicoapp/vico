#import "ViCompletionView.h"
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
	NSString *selection;
	NSFont *font;
	ViTheme *theme;
	NSMutableString *filter;
	NSMutableParagraphStyle *matchParagraphStyle;
	id<ViCompletionDelegate> delegate;
	NSInteger terminatingKey;
	NSRange prefixRange;
	BOOL fuzzySearch;
}

@property (readwrite, assign) id<ViCompletionDelegate> delegate;
@property (readonly) NSWindow *window;
@property (readwrite, assign) NSArray *completions;
@property (readwrite, assign) NSFont *font;
@property (readonly) NSInteger terminatingKey;

+ (id)sharedController;
+ (NSString *)commonPrefixInCompletions:(NSArray *)completions;
+ (void)appendFilter:(NSString *)string
           toPattern:(NSMutableString *)pattern
          fuzzyClass:(NSString *)fuzzyClass;

- (NSString *)chooseFrom:(NSArray *)anArray
             prefixRange:(NSRange *)aRange
                      at:(NSPoint)screenOrigin
               direction:(int)direction /* 0 = down, 1 = up */
             fuzzySearch:(BOOL)fuzzyFlag;

@end
