#import "ViDocumentController.h"

@implementation ViDocumentController

- (NSString *)typeForContentsOfURL:(NSURL *)inAbsoluteURL error:(NSError **)outError
{
	return @"Document";
}

@end

