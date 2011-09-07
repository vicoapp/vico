#import "ViFile.h"

@implementation ViFile

@synthesize url, targetURL, children, isDirectory, isLink, attributes, targetAttributes;

- (id)initWithURL:(NSURL *)aURL
       attributes:(NSDictionary *)aDictionary
     symbolicLink:(NSURL *)sURL
symbolicAttributes:(NSDictionary *)sDictionary
{
	self = [super init];
	if (self) {
		attributes = aDictionary;
		isLink = [[attributes fileType] isEqualToString:NSFileTypeSymbolicLink];
		[self setURL:aURL];
		[self setTargetURL:sURL attributes:sDictionary];
	}
	return self;
}

+ (id)fileWithURL:(NSURL *)aURL
       attributes:(NSDictionary *)aDictionary
{
	return [[ViFile alloc] initWithURL:aURL
				attributes:aDictionary
			      symbolicLink:nil
			symbolicAttributes:nil];
}

+ (id)fileWithURL:(NSURL *)aURL
       attributes:(NSDictionary *)aDictionary
     symbolicLink:(NSURL *)sURL
symbolicAttributes:(NSDictionary *)sDictionary
{
	return [[ViFile alloc] initWithURL:aURL
				attributes:aDictionary
			      symbolicLink:sURL
			symbolicAttributes:sDictionary];
}

- (BOOL)hasCachedChildren
{
	return children != nil;
}

- (NSURL *)targetURL
{
	if (isLink)
		return targetURL;
	return targetURL ?: url;
}

- (void)setURL:(NSURL *)aURL
{
	url = aURL;
	nameIsDirty = YES;
	displayNameIsDirty = YES;
	iconIsDirty = YES;
}

- (void)setTargetURL:(NSURL *)aURL
{
	targetURL = aURL;
	iconIsDirty = YES;
}

- (void)setTargetURL:(NSURL *)aURL attributes:(NSDictionary *)aDictionary
{
	targetURL = aURL;
	targetAttributes = aDictionary;
	iconIsDirty = YES;

	if (isLink)
		isDirectory = [[targetAttributes fileType] isEqualToString:NSFileTypeDirectory];
	else
		isDirectory = [[attributes fileType] isEqualToString:NSFileTypeDirectory];
}

- (NSString *)path
{
	return [url path];
}

- (NSString *)name
{
	if (nameIsDirty) {
		name = [url lastPathComponent];
		nameIsDirty = NO;
	}
	return name;
}

- (NSString *)displayName
{
	if (displayNameIsDirty) {
		if ([url isFileURL])
			displayName = [[NSFileManager defaultManager] displayNameAtPath:[url path]];
		else
			displayName = [url lastPathComponent];
		displayNameIsDirty = NO;
	}
	return displayName;
}

- (NSImage *)icon
{
	if (iconIsDirty) {
		if ([url isFileURL])
			icon = [[NSWorkspace sharedWorkspace] iconForFile:[[self targetURL] path]];
		else if (isDirectory)
			icon = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode('fldr')];
		else
			icon = [[NSWorkspace sharedWorkspace] iconForFileType:[[self targetURL] pathExtension]];
		[icon setSize:NSMakeSize(16, 16)];

		if (isLink) {
			NSImage *aliasBadge = [NSImage imageNamed:@"AliasBadgeIcon"];
			[icon lockFocus];
			NSSize sz = [icon size];
			[aliasBadge drawInRect:NSMakeRect(0, 0, sz.width, sz.height)
				      fromRect:NSZeroRect
				     operation:NSCompositeSourceOver
				      fraction:1.0];
			[icon unlockFocus];
		}

		iconIsDirty = NO;
	}
	return icon;
}

- (NSString *)description
{
	if (isLink)
		return [NSString stringWithFormat:@"<ViFile: %@ -> %@%s>", url, targetURL, isDirectory ? "/" : ""];
	else
		return [NSString stringWithFormat:@"<ViFile: %@%s>", url, isDirectory ? "/" : ""];
}

@end
