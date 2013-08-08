#import "ViCompletionController.h"

@interface ViArrayCompletion : NSObject <ViCompletionProvider>
{
	NSArray *_completions;
}

@property (readwrite,retain) NSArray *completions;

+ (ViArrayCompletion *)arrayCompletionWithArray:(NSArray *)completions;

- (ViArrayCompletion *)initWithArray:(NSArray *)completions;

@end
