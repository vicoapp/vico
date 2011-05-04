#import "ViCompletionController.h"
#import "ViTextStorage.h"

@interface ViWordCompletion : NSObject <ViCompletionProvider>
{
	ViTextStorage *textStorage;
	NSUInteger currentLocation;
}

- (ViWordCompletion *)initWithTextStorage:(ViTextStorage *)aTextStorage
			       atLocation:(NSUInteger)aLocation;

@end
