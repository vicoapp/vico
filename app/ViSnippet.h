#import "ViTransformer.h"

@class ViTabstop;
@class ViSnippet;

@protocol ViSnippetDelegate <NSObject>
- (void)snippet:(ViSnippet *)snippet replaceCharactersInRange:(NSRange)range withString:(NSString *)string forTabstop:(ViTabstop *)tabstop;
- (NSString *)string;
@end

@interface ViSnippet : ViTransformer
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

@property(nonatomic,readonly) NSRange range;
@property(nonatomic,readonly) NSUInteger caret;
@property(nonatomic,readonly) NSRange selectedRange;
@property(nonatomic,readonly) BOOL finished;
@property(nonatomic,readonly) ViTabstop *currentTabStop;

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
