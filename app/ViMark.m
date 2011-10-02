#import "ViMark.h"
#import "ViMarkManager.h"
#import "ViDocument.h"
#import "ViDocumentView.h"
#import "ViDocumentController.h"
#import "NSURL-additions.h"

@implementation ViMark

@synthesize name = _name;
@synthesize line = _line;
@synthesize column = _column;
@synthesize location = _location;
@synthesize range = _range;
@synthesize rangeString = _rangeString;
@synthesize url = _url;
@synthesize title = _title;
@synthesize icon = _icon;
@synthesize document = _document;
@synthesize view = _view;
@synthesize representedObject = _representedObject;
@synthesize persistent = _persistent;
@synthesize recentlyRestored = _recentlyRestored ;

+ (ViMark *)markWithURL:(NSURL *)aURL
{
	return [[[ViMark alloc] initWithURL:aURL
				       name:nil
				      title:nil
				       line:-1
				     column:-1] autorelease];
}

+ (ViMark *)markWithURL:(NSURL *)aURL
		   line:(NSInteger)aLine
		 column:(NSInteger)aColumn
{
	return [[[ViMark alloc] initWithURL:aURL
				       name:nil
				      title:nil
				       line:aLine
				     column:aColumn] autorelease];
}

+ (ViMark *)markWithURL:(NSURL *)aURL
		   name:(NSString *)aName
		  title:(id)aTitle
		   line:(NSInteger)aLine
		 column:(NSInteger)aColumn
{
	return [[[ViMark alloc] initWithURL:aURL
				       name:aName
				      title:aTitle
				       line:aLine
				     column:aColumn] autorelease];
}

+ (ViMark *)markWithDocument:(ViDocument *)aDocument
			name:(NSString *)aName
		       range:(NSRange)aRange
{
	return [[[ViMark alloc] initWithDocument:aDocument
					    name:aName
					   range:aRange] autorelease];
}

+ (ViMark *)markWithView:(ViDocumentView *)aDocumentView
		    name:(NSString *)aName
		   range:(NSRange)aRange
{
	return [[[ViMark alloc] initWithView:aDocumentView
					name:aName
				       range:aRange] autorelease];
}

- (ViMark *)initWithURL:(NSURL *)aURL
		   name:(NSString *)aName
		  title:(id)aTitle
		   line:(NSInteger)aLine
		 column:(NSInteger)aColumn
{
	if (aURL == nil) {
		[self release];
		return nil;
	}

	if ((self = [super init]) != nil) {
		_url = [[aURL URLByResolvingSymlinksAndAliases:nil] retain];
		_name = [aName retain];
		_title = [aTitle retain];
		_persistent = YES;

		_line = aLine;
		_column = aColumn;

		_location = NSNotFound;
		_range = NSMakeRange(NSNotFound, 0);
		_rangeStringIsDirty = YES;

		ViDocument *doc = [[ViDocumentController sharedDocumentController] documentForURLQuick:_url];
		if (doc)
			[self setDocument:doc];
		else
			[[NSNotificationCenter defaultCenter] addObserver:self
								 selector:@selector(documentAdded:)
								     name:ViDocumentLoadedNotification
								   object:nil];
		DEBUG(@"init %@", self);
	}

	return self;
}

- (ViMark *)initWithDocument:(ViDocument *)aDocument
			name:(NSString *)aName
		       range:(NSRange)aRange
{
	if (aDocument == nil) {
		[self release];
		return nil;
	}

	if ((self = [super init]) != nil) {
		_persistent = YES;
		_document = [aDocument retain];
		_name = [aName retain];
		[self setRange:aRange];
		[[NSNotificationCenter defaultCenter] addObserver:self
							 selector:@selector(documentRemoved:)
							     name:ViDocumentRemovedNotification
							   object:_document];

		[self.document registerMark:self];
		DEBUG(@"init %@", self);
	}

	return self;
}

- (ViMark *)initWithView:(ViDocumentView *)aDocumentView
		    name:(NSString *)aName
		   range:(NSRange)aRange
{
	if (aDocumentView == nil) {
		[self release];
		return nil;
	}

	if ((self = [self initWithDocument:(ViDocument *)aDocumentView.document
				      name:aName
				     range:aRange]) != nil) {
		_view = aDocumentView; // XXX: not retained!
		[[NSNotificationCenter defaultCenter] addObserver:self
							 selector:@selector(viewClosed:)
							     name:ViViewClosedNotification
							   object:_view];
		DEBUG(@"init %@", self);
	}
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	self = [[self class] allocWithZone:zone];
	if (_view)
		self = [self initWithView:_view name:_name range:_range];
	else if (_document)
		self = [self initWithDocument:_document name:_name range:_range];
	else
		self = [self initWithURL:_url name:_name title:_title line:_line column:_column];
	self.title = _title;
	self.icon = _icon;
	self.persistent = _persistent;
	return self;
}

- (void)viewClosed:(NSNotification *)notification
{
	[[NSNotificationCenter defaultCenter] removeObserver:self
							name:ViViewClosedNotification
						      object:_view];
	_view = nil;
	DEBUG(@"view %@ closed for mark %@", [notification object], self);
}

- (void)dealloc
{
	// DEBUG_DEALLOC();

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_name release];
	[_title release];
	[_icon release];
	[_groupName release];
	[_url release];
	[_document release];
	[_lists release];
	[_rangeString release];
	[super dealloc];
}

- (void)documentAdded:(NSNotification *)notification
{
	ViDocument *doc = [notification object];
	DEBUG(@"added document %@ (expecting url %@)", doc, _url);
	if (![doc isKindOfClass:[ViDocument class]])
		return;
	if (![[doc fileURL] isEqual:_url])
		return;

	[[NSNotificationCenter defaultCenter] removeObserver:self
							name:ViDocumentLoadedNotification
						      object:nil];

	[self setDocument:doc];
}

- (void)setDocument:(ViDocument *)doc
{
	[doc retain];
	[_document release];
	_document = doc;
	_view = nil;

	if (![_document isKindOfClass:[ViDocument class]]) {
		if (doc)
			INFO(@"got non-document %@ for mark %@", doc, self);
		return;
	}

	if (_line < 0)
		_range = NSMakeRange(NSNotFound, 0);
	else {
		NSUInteger eol = 0;
		NSInteger loc = [[_document textStorage] locationForStartOfLine:_line
									length:NULL
								   contentsEnd:&eol];
		DEBUG(@"got line %lu => location %li", _line, loc);
		if (loc < 0)
			_location = IMAX(0, [[_document textStorage] length] - 1);
		else {
			_location = loc + IMAX(0, _column - 1);
			if (_location > eol)
				_location = eol;
		}

		_range = NSMakeRange(_location, 1);
	}

	DEBUG(@"got document %@, %lu:%lu => location %lu", _document, _line, _column, _location);

	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(documentRemoved:)
						     name:ViDocumentRemovedNotification
						   object:_document];

	[self.document registerMark:self];
}

- (void)documentRemoved:(NSNotification *)notification
{
	DEBUG(@"document %@ was removed (expecting %@)", [notification object], _document);
	if ([notification object] != _document)
		return;

	[[NSNotificationCenter defaultCenter] removeObserver:self
							name:ViDocumentRemovedNotification
						      object:_document];
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(documentAdded:)
						     name:ViDocumentLoadedNotification
						   object:nil];

	[self setURL:[_document fileURL]];
	[self setDocument:nil];

	// _location = NSNotFound;
	// _range = NSMakeRange(NSNotFound, 0);
}

- (void)setLocation:(NSUInteger)aLocation
{
	if (_document)
		[self setRange:NSMakeRange(aLocation, 1)];
}

- (void)setRange:(NSRange)aRange
{
	if (_document) {
		[self willChangeValueForKey:@"range"];
		[self willChangeValueForKey:@"rangeString"];
		[self willChangeValueForKey:@"line"];

		_range = aRange;
		_rangeStringIsDirty = YES;
		_location = _range.location;
		_line = [[_document textStorage] lineNumberAtLocation:_location];
		_column = [[_document textStorage] columnOffsetAtLocation:_location] + 1;

		[self didChangeValueForKey:@"line"];
		[self didChangeValueForKey:@"rangeString"];
		[self didChangeValueForKey:@"range"];
	}
}

- (NSString *)rangeString
{
	if (_rangeStringIsDirty) {
		[_rangeString release];
		// if (_range.location != NSNotFound)
		// 	_rangeString = [NSStringFromRange(_range) retain];
		// else
		if (_line < 0)
			_rangeString = nil;
		else
			_rangeString = [[NSString alloc] initWithFormat:@"%lu:%lu %@",
			    _line, _column, NSStringFromRange(_range)];
		_rangeStringIsDirty = NO;
	}
	return _rangeString;
}

- (NSURL *)url
{
	/* The URL of the document can change. */
	if (_document && [_document fileURL])
		return [_document fileURL];
	return _url;
}

- (void)setURL:(NSURL *)url
{
	[url retain];
	[_url release];
	_url = [url URLByResolvingSymlinksAndAliases:nil];
}

- (NSString *)groupName
{
	NSURL *u = [self url];
	return u ? [u absoluteString] : [_document displayName];
}

- (void)remove
{
	for (ViMarkList *list in _lists)
		[list removeMark:self];
	[_document unregisterMark:self];
}

- (void)registerList:(ViMarkList *)list
{
	if (_lists == nil)
		_lists = [[NSHashTable alloc] initWithOptions:NSHashTableObjectPointerPersonality capacity:10];
	[_lists addObject:list]; // XXX: this does NOT retain the list
}

- (BOOL)isLeaf
{
	return YES;
}

- (id)title
{
	return _title ?: _name;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViMark %p (%@): %@, %lu:%lu %@>",
		self,
		_name ?: _title,
		_view ? [_view description] : (_document ? [_document description] : [_url description]),
		_line, _column, NSStringFromRange(_range)];
}

@end
