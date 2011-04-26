@interface ViTagsDatabase : NSObject
{
	NSURL *baseURL;
	NSURL *databaseURL;
	NSDate *modificationDate;
	NSMutableDictionary *tags;
}

- (ViTagsDatabase *)initWithBaseURL:(NSURL *)aURL;
- (void)lookup:(NSString *)symbol
  onCompletion:(void (^)(NSArray *tag, NSError *error))aBlock;

@end
