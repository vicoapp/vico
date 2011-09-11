#import "ViMark.h"
#import "ViDocument.h"

@implementation ViMark

@synthesize name, line, lineNumber, columnNumber, column, location;
@synthesize url, title, icon, document;

+ (ViMark *)markWithURL:(NSURL *)aURL
		   name:(NSString *)aName
                 title:(id)aTitle
                  line:(NSUInteger)aLine
                column:(NSUInteger)aColumn
{
	return [[ViMark alloc] initWithURL:aURL
				      name:aName
				     title:aTitle
				      line:aLine
				    column:aColumn];
}

+ (ViMark *)markWithDocument:(ViDocument *)aDocument
			name:(NSString *)aName
		    location:(NSUInteger)aLocation
{
	return [[ViMark alloc] initWithDocument:aDocument
				      name:aName
				  location:aLocation];
}

- (ViMark *)initWithURL:(NSURL *)aURL
		   name:(NSString *)aName
		  title:(id)aTitle
                  line:(NSUInteger)aLine
                column:(NSUInteger)aColumn
{
	if ((self = [super init]) != nil) {
		url = aURL;
		name = aName;
		title = aTitle;
		line = aLine;
		column = aColumn;

		lineNumber = [NSNumber numberWithUnsignedInteger:line];
		columnNumber = [NSNumber numberWithUnsignedInteger:column];
		document = [[NSDocumentController sharedDocumentController] documentForURL:url];
	}

	return self;
}

- (ViMark *)initWithDocument:(ViDocument *)aDocument
			name:(NSString *)aName
		    location:(NSUInteger)aLocation
{
	if ((self = [super init]) != nil) {
		document = aDocument;
		name = aName;
		[self setLocation:aLocation];
	}

	return self;
}

- (void)setLocation:(NSUInteger)aLocation
{
	if (document) {
		location = aLocation;
		[self willChangeValueForKey:@"line"];
		[self willChangeValueForKey:@"column"];
		[self willChangeValueForKey:@"lineNumber"];
		[self willChangeValueForKey:@"columnNumber"];
		line = [[document textStorage] lineNumberAtLocation:aLocation];
		column = [[document textStorage] columnAtLocation:aLocation];
		lineNumber = [NSNumber numberWithUnsignedInteger:line];
		columnNumber = [NSNumber numberWithUnsignedInteger:column];
		[self didChangeValueForKey:@"columnNumber"];
		[self didChangeValueForKey:@"lineNumber"];
		[self didChangeValueForKey:@"column"];
		[self didChangeValueForKey:@"line"];
	}
}

- (NSURL *)url
{
	/* The URL of the document can change. */
	if (document && [document fileURL])
		return [document fileURL];
	return url;
}

- (NSString *)groupName
{
	NSURL *u = [self url];
	return u ? [u absoluteString] : [document displayName];
}

- (BOOL)isLeaf
{
	return YES;
}

- (id)title
{
	return title ?: name;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViMark %@: %@, %lu:%lu>",
		name ?: title,
		document ? [document description] : [url description],
		line, column];
}

@end
