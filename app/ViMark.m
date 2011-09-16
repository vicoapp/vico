#import "ViMark.h"
#import "ViMarkManager.h"
#import "ViDocument.h"
#import "ViDocumentController.h"

@implementation ViMark

@synthesize name, line, lineNumber, columnNumber, column, location, range;
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
		       range:(NSRange)aRange
{
	return [[ViMark alloc] initWithDocument:aDocument
					   name:aName
					  range:aRange];
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

		location = NSNotFound;
		range = NSMakeRange(NSNotFound, 0);

		document = [[ViDocumentController sharedDocumentController] documentForURLQuick:url];
		if (document)
			[self setDocument:document];
		else
			[[NSNotificationCenter defaultCenter] addObserver:self
								 selector:@selector(documentAdded:)
								     name:ViDocumentLoadedNotification
								   object:nil];
	}

	return self;
}

- (ViMark *)initWithDocument:(ViDocument *)aDocument
			name:(NSString *)aName
		       range:(NSRange)aRange
{
	if ((self = [super init]) != nil) {
		document = aDocument;
		name = aName;
		[self setRange:aRange];
		[[NSNotificationCenter defaultCenter] addObserver:self
							 selector:@selector(documentRemoved:)
							     name:ViDocumentRemovedNotification
							   object:document];
		[[ViMarkManager sharedManager] registerMark:self];
	}

	return self;
}

- (void)documentAdded:(NSNotification *)notification
{
	ViDocument *doc = [notification object];
	if (![doc isKindOfClass:[ViDocument class]])
		return;
	if (![[doc fileURL] isEqual:url])
		return;

	[[NSNotificationCenter defaultCenter] removeObserver:self
							name:ViDocumentLoadedNotification
						      object:nil];

	[self setDocument:doc];
}

- (void)setDocument:(__weak ViDocument *)doc
{
	document = doc;

	NSUInteger eol = 0;
	NSInteger loc = [[document textStorage] locationForStartOfLine:line
								length:NULL
							   contentsEnd:&eol];
	DEBUG(@"got line %lu => location %li", line, loc);
	if (loc < 0)
		location = IMAX(0, [[document textStorage] length] - 1);
	else {
		location = loc + IMAX(0, column - 1);
		if (location > eol)
			location = eol;
	}

	range = NSMakeRange(location, 1);

	DEBUG(@"got document %@, %lu:%lu => location %lu", document, line, column, location);

	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(documentRemoved:)
						     name:ViDocumentRemovedNotification
						   object:document];

	[[ViMarkManager sharedManager] registerMark:self];
}

- (void)documentRemoved:(NSNotification *)notification
{
	if ([notification object] != document)
		return;

	[[NSNotificationCenter defaultCenter] removeObserver:self
							name:ViDocumentRemovedNotification
						      object:document];
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(documentAdded:)
						     name:ViDocumentLoadedNotification
						   object:nil];

	url = [document fileURL];
	document = nil;

	// location = NSNotFound;
	// range = NSMakeRange(NSNotFound, 0);
}

- (void)setLocation:(NSUInteger)aLocation
{
	if (document)
		[self setRange:NSMakeRange(aLocation, 1)];
}

- (void)setRange:(NSRange)aRange
{
	if (document) {
		[self willChangeValueForKey:@"location"];
		[self willChangeValueForKey:@"range"];
		[self willChangeValueForKey:@"line"];
		[self willChangeValueForKey:@"column"];
		[self willChangeValueForKey:@"lineNumber"];
		[self willChangeValueForKey:@"columnNumber"];
		range = aRange;
		location = range.location;
		line = [[document textStorage] lineNumberAtLocation:location];
		column = [[document textStorage] columnOffsetAtLocation:location] + 1;
		lineNumber = [NSNumber numberWithUnsignedInteger:line];
		columnNumber = [NSNumber numberWithUnsignedInteger:column];
		[self didChangeValueForKey:@"columnNumber"];
		[self didChangeValueForKey:@"lineNumber"];
		[self didChangeValueForKey:@"column"];
		[self didChangeValueForKey:@"line"];
		[self didChangeValueForKey:@"range"];
		[self didChangeValueForKey:@"location"];
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

- (void)remove
{
	for (ViMarkList *list in lists)
		[list removeMark:self];
	[[ViMarkManager sharedManager] unregisterMark:self];
}

- (void)registerList:(ViMarkList *)list
{
	if (lists == nil)
		lists = [NSHashTable hashTableWithWeakObjects];
	[lists addObject:list];
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
	return [NSString stringWithFormat:@"<ViMark %@: %@, %lu:%lu %@>",
		name ?: title,
		document ? [document description] : [url description],
		line, column, NSStringFromRange(range)];
}

@end
