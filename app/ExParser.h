#import "ExCommand.h"
#import "ViCompletionController.h"

@interface ExParser : NSObject
{
	ExMap *map;
}

@property (nonatomic, assign, readwrite) ExMap *map;

+ (ExParser *)sharedParser;

- (ExCommand *)parse:(NSString *)string
	       caret:(NSInteger)completionLocation
	  completion:(id<ViCompletionProvider> *)completionProviderPtr
	       range:(NSRange *)completionRangePtr
               error:(NSError **)outError;

- (ExCommand *)parse:(NSString *)string
	       error:(NSError **)outError;

- (NSString *)expand:(NSString *)string error:(NSError **)outError;

@end
