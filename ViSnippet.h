@class ViTabstop;
@class ViSnippet;

@protocol ViSnippetDelegate <NSObject>
- (void)snippet:(ViSnippet *)snippet replaceCharactersInRange:(NSRange)range withString:(NSString *)string;
- (NSString *)string;
@end

@interface ViSnippet : NSObject
{
	NSUInteger beginLocation;
	ViTabstop *currentTabStop;
	NSUInteger currentTabNum, maxTabNum;
	id<ViSnippetDelegate> delegate;
	NSRange range;
	NSUInteger caret;
	NSRange selectedRange;
	NSMutableArray *tabstops;
	NSDictionary *environment;
	BOOL finished;
}

@property(readonly) NSRange range;
@property(readonly) NSUInteger caret;
@property(readonly) NSRange selectedRange;

- (ViSnippet *)initWithString:(NSString *)aString
                   atLocation:(NSUInteger)aLocation
                     delegate:(id<ViSnippetDelegate>)aDelegate
                  environment:(NSDictionary *)environment
                        error:(NSError **)outError;
- (BOOL)activeInRange:(NSRange)aRange;
- (BOOL)replaceRange:(NSRange)updateRange withString:(NSString *)replacementString;
- (BOOL)advance;
- (void)deselect;
- (NSRange)tabRange;
- (NSString *)string;

@end
