#import "ViCompletionView.h"
#import "ViCompletion.h"
#import "ViThemeStore.h"
#import "ViURLManager.h"

@protocol ViCompletionProvider <NSObject>
@optional
- (id<ViDeferred>)completionsForString:(NSString *)path
			       options:(NSString *)options
			    onResponse:(void (^)(NSArray *completions, NSError *error))responseCallback;
- (id<ViDeferred>)completionsForString:(NSString *)path
			       options:(NSString *)options
				target:(id)target
				action:(SEL)action;
@end

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

	id<ViCompletionProvider> provider;
	NSArray *completions;
	NSString *options;
	NSString *prefix;

	ViCompletion *onlyCompletion;
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

@property (nonatomic, readwrite, assign) id<ViCompletionDelegate> delegate;
@property (nonatomic, readonly) NSWindow *window;
@property (nonatomic, readwrite, assign) NSArray *completions;
@property (nonatomic, readonly) NSInteger terminatingKey;
@property (nonatomic, readonly) NSRange range;
@property (nonatomic, readwrite, assign) NSString *filter;

+ (id)sharedController;
+ (NSString *)commonPrefixInCompletions:(NSArray *)completions;
+ (void)appendFilter:(NSString *)string
           toPattern:(NSMutableString *)pattern
          fuzzyClass:(NSString *)fuzzyClass;

- (ViCompletion *)chooseFrom:(id<ViCompletionProvider>)aProvider
                       range:(NSRange)aRange
		      prefix:(NSString *)aPrefix
                          at:(NSPoint)screenOrigin
		     options:(NSString *)optionString
                   direction:(int)direction /* 0 = down, 1 = up */
               initialFilter:(NSString *)initialFilter;

@end
