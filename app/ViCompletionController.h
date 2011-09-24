#import "ViCompletionView.h"
#import "ViCompletion.h"
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

@interface ViCompletionController : NSObject <NSTableViewDataSource, NSTableViewDelegate, ViKeyManagerTarget>
{
	IBOutlet NSWindow		*window;
	IBOutlet ViCompletionView	*tableView;
	IBOutlet NSTextField		*label;

	id<ViCompletionProvider>	 _provider;
	NSMutableArray			*_completions;
	NSString			*_options;
	NSString			*_prefix;
	NSUInteger			 _prefixLength;
	ViCompletion			*_onlyCompletion;
	NSMutableArray			*_filteredCompletions;
	ViCompletion			*_selection;
	NSMutableString			*_filter;
	// NSMutableParagraphStyle	*_matchParagraphStyle;
	id<ViCompletionDelegate>	 _delegate;
	NSInteger			 _terminatingKey;
	NSRange				 _range;
	NSPoint				 _screenOrigin;
	BOOL				 _upwards;
	BOOL				 _fuzzySearch;
}

@property (nonatomic, readwrite, assign) id<ViCompletionDelegate> delegate;
@property (nonatomic, readonly) NSWindow *window;
@property (nonatomic, readwrite, retain) NSArray *completions;
@property (nonatomic, readonly) NSInteger terminatingKey;
@property (nonatomic, readonly) NSRange range;
@property (nonatomic, readwrite, retain) NSString *filter;

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

- (void)updateBounds;
- (void)filterCompletions;
- (BOOL)complete_partially:(ViCommand *)command;
- (void)acceptByKey:(NSInteger)termKey;
- (BOOL)cancel:(ViCommand *)command;
- (void)updateCompletions;
- (void)reset;

@end
