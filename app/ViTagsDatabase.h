@interface ViTagsDatabase : NSObject
{
	NSURL *baseURL;
	NSURL *databaseURL;
	NSDate *modificationDate;
	NSMutableDictionary *tags;
}

@property (nonatomic,readonly) NSURL *baseURL;

- (ViTagsDatabase *)initWithBaseURL:(NSURL *)aURL;
- (void)lookup:(NSString *)symbol
  onCompletion:(void (^)(NSArray *tag, NSError *error))aBlock;

@end
