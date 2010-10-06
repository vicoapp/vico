@interface ViTagsDatabase : NSObject
{
	NSString *databaseFile;
	NSDate *modificationDate;
	NSMutableDictionary *tags;
	NSString *prefixPath;
}

- (ViTagsDatabase *)initWithFile:(NSString *)aFile inDirectory:(NSString *)aDirectory;
- (NSArray *)lookup:(NSString *)symbol;
- (BOOL)databaseHasChanged;

@end
