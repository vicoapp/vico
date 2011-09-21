@interface ViFile : NSObject
{
	NSURL		*_url;
	NSURL		*_targetURL;
	NSDictionary	*_attributes;
	NSDictionary	*_targetAttributes;
	NSMutableArray	*_children;
	NSString	*_name;
	NSString	*_displayName;
	NSImage		*_icon;
	BOOL		 _nameIsDirty;
	BOOL		 _displayNameIsDirty;
	BOOL		 _iconIsDirty;
	BOOL		 _isDirectory;
	BOOL		 _isLink;
}

@property(nonatomic,readonly) NSURL *url;
@property(nonatomic,readonly) NSURL *targetURL;
@property(nonatomic,readonly) NSDictionary *attributes;
@property(nonatomic,readonly) NSDictionary *targetAttributes;
@property(nonatomic,readwrite,retain) NSMutableArray *children;
@property(nonatomic,readonly) BOOL isDirectory;
@property(nonatomic,readonly) BOOL isLink;
@property(nonatomic,readonly) NSString *name;
@property(nonatomic,readonly) NSString *displayName;
@property(nonatomic,readonly) NSString *path;
@property(nonatomic,readonly) NSImage *icon;

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

- (void)setTargetURL:(NSURL *)aURL;
- (void)setTargetURL:(NSURL *)aURL attributes:(NSDictionary *)aDictionary;

@end
