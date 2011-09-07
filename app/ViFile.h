@interface ViFile : NSObject
{
	NSURL *url, *targetURL;
	NSDictionary *attributes, *targetAttributes;
	NSMutableArray *children;
	NSString *name, *displayName;
	NSImage *icon;
	BOOL nameIsDirty, displayNameIsDirty, iconIsDirty;
	BOOL isDirectory, isLink;
}

@property(nonatomic,readonly) NSURL *url;
@property(nonatomic,readonly) NSURL *targetURL;
@property(nonatomic,readonly) NSDictionary *attributes;
@property(nonatomic,readonly) NSDictionary *targetAttributes;
@property(nonatomic,readwrite, assign) NSMutableArray *children;
@property(nonatomic,readonly) BOOL isDirectory;
@property(nonatomic,readonly) BOOL isLink;
@property(nonatomic,readonly) NSString *name;
@property(nonatomic,readonly) NSString *displayName;
@property(nonatomic,readonly) NSString *path;

+ (id)fileWithURL:(NSURL *)aURL
       attributes:(NSDictionary *)aDictionary;

+ (id)fileWithURL:(NSURL *)aURL
       attributes:(NSDictionary *)aDictionary
     symbolicLink:(NSURL *)sURL
symbolicAttributes:(NSDictionary *)sDictionary;

- (id)initWithURL:(NSURL *)aURL
       attributes:(NSDictionary *)aDictionary
     symbolicLink:(NSURL *)sURL
symbolicAttributes:(NSDictionary *)sDictionary;

- (void)setURL:(NSURL *)aURL;
- (BOOL)hasCachedChildren;
- (NSImage *)icon;

- (void)setTargetURL:(NSURL *)aURL;
- (void)setTargetURL:(NSURL *)aURL attributes:(NSDictionary *)aDictionary;

@end
