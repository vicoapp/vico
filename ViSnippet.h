@class ViTabstop;
@interface ViSnippet : NSObject
{
	NSUInteger beginLocation;
	ViTabstop *currentTabStop;
	NSUInteger currentTabIndex;
	NSMutableString *string;
	NSRange range;
	NSUInteger caret;
	NSRange selectedRange;
	NSMutableArray *tabstops;
	NSDictionary *environment;
}

@property(readonly) NSString *string;
@property(readonly) NSRange range;
@property(readonly) NSUInteger caret;
@property(readonly) NSRange selectedRange;

- (ViSnippet *)initWithString:(NSString *)aString
                   atLocation:(NSUInteger)aLocation
                  environment:(NSDictionary *)environment
                        error:(NSError **)outError;
- (BOOL)activeInRange:(NSRange)aRange;
- (BOOL)replaceRange:(NSRange)updateRange withString:(NSString *)replacementString;
- (BOOL)advance;
- (void)deselect;
- (NSRange)tabRange;

@end
