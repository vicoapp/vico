@interface ViTagsDatabase : NSObject
{
	NSURL			*_baseURL;
	NSURL			*_databaseURL;
	NSDate			*_modificationDate;
	NSMutableDictionary	*_tags;
}

@property(nonatomic,readonly) NSURL *baseURL;
@property(nonatomic,readwrite,retain) NSDate *modificationDate;
@property(nonatomic,readwrite,retain) NSURL *databaseURL;

- (ViTagsDatabase *)initWithBaseURL:(NSURL *)aURL;
- (void)lookup:(NSString *)symbol
  onCompletion:(void (^)(NSArray *tag, NSError *error))aBlock;

- (void)parseData:(NSData *)data;
- (void)onOpen:(void (^)(NSError *error))aBlock;
- (void)onDatabaseChanged:(void (^)(NSError *error))aBlock;

@end
