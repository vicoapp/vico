#import "ViDocument.h"
#import "ViDocumentManager.h"
#import "ExTextView.h"

BOOL makeNewWindowInsteadOfTab = NO;

@interface ViDocument (internal)
- (ViWindowController *)windowController;
@end

@implementation ViDocument

- (id)init
{
	self = [super init];
	INFO(@"new document %@", self);
	return self;
}

#pragma mark -
#pragma mark NSDocument interface

- (NSString *)windowNibName
{
	return @"ViDocument";
}

- (void)makeWindowControllers
{
	if (makeNewWindowInsteadOfTab)
	{
		windowController = [[ViWindowController alloc] init];
		makeNewWindowInsteadOfTab = NO;
	}
	else
		windowController = [ViWindowController currentWindowController];

	[self addWindowController:windowController];
	[windowController addNewTab:self];
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
	[super windowControllerDidLoadNib:aController];
	[textView initEditor];
	[textView setDelegate:self];

	if (readContent)
	{
		[[[textView textStorage] mutableString] setString:readContent];
		[textView setCaret:0];
	}
	[textView configureForURL:[self fileURL]];
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
	return [[[textView textStorage] string] dataUsingEncoding:NSUTF8StringEncoding];
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	readContent = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	return YES;
}

- (void)setFileURL:(NSURL *)absoluteURL
{
	INFO(@"file url = %@", absoluteURL);
	[super setFileURL:absoluteURL];
	[textView configureForURL:[self fileURL]];
}


#if 0
- (NSString *)autosavingFileType
{
	/* disable autosaving */
	return nil;
}
#endif

#pragma mark -
#pragma mark Other stuff

- (id)windowWillReturnFieldEditor:(NSWindow *)window toObject:(id)anObject
{
	if ([anObject isKindOfClass:[NSTextField class]])
	{
		return [ExTextView defaultEditor];
	}
	return nil;
}

- (NSView *)view
{
	return view;
}

- (void)changeTheme:(ViTheme *)theme
{
	[textView setTheme:theme];
}

- (void)setPageGuide:(int)pageGuideValue
{
	[textView setPageGuide:pageGuideValue];
}

#pragma mark -
#pragma mark ViTextView delegate methods

- (void)message:(NSString *)fmt, ...
{
	va_list ap;
	va_start(ap, fmt);
	NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
	va_end(ap);

	[statusbar setStringValue:msg];
}

- (IBAction)finishedExCommand:(id)sender
{
	NSString *exCommand = [statusbar stringValue];
	[statusbar setStringValue:@""];
	[statusbar setEditable:NO];
	[[[self windowController] window] makeFirstResponder:textView];
	[textView performSelector:exCommandSelector withObject:exCommand];
}

/* FIXME: should probably subclass NSTextField to disallow losing focus due to tabbing or clicking outside.
 * Should handle escape and ctrl-c.
 */
- (void)getExCommandForTextView:(ViTextView *)aTextView selector:(SEL)aSelector
{
	[statusbar setStringValue:@":"]; // FIXME: should not select the colon
	[statusbar setEditable:YES];
	[statusbar setDelegate:self];
	exCommandSelector = aSelector;
	[[[self windowController] window] makeFirstResponder:statusbar];
}

- (BOOL)findPattern:(NSString *)pattern
	    options:(unsigned)find_options
         regexpType:(OgreSyntax)regexpSyntax
   ignoreLastRegexp:(BOOL)ignoreLastRegexp
{
	return [textView findPattern:pattern options:find_options regexpType:regexpSyntax ignoreLastRegexp:ignoreLastRegexp];
}

// tag push
- (void)pushLine:(NSUInteger)aLine column:(NSUInteger)aColumn
{
	[[[self windowController] sharedTagStack] pushFile:[[self fileURL] path] line:aLine column:aColumn];
}

- (void)popTag
{
	NSDictionary *location = [[[self windowController] sharedTagStack] pop];
	if (location == nil)
	{
		[self message:@"The tags stack is empty"];
		return;
	}

	NSString *file = [location objectForKey:@"file"];
	INFO(@"Jump to [%@] at line %u, col %u",
	      file,
	      [[location objectForKey:@"line"] unsignedIntegerValue],
	      [[location objectForKey:@"column"] unsignedIntegerValue]);

	ViDocument *document = [[NSDocumentController sharedDocumentController]
		openDocumentWithContentsOfURL:[NSURL fileURLWithPath:file] display:YES error:nil];
	INFO(@"got document %@", document);

	if (document)
	{
		[[self windowController] selectDocument:document];
		[[document textView] gotoLine:[[location objectForKey:@"line"] unsignedIntegerValue]
				       column:[[location objectForKey:@"column"] unsignedIntegerValue]];
	}
}

- (ViTextView *)textView
{
	return textView;
}

- (ViWindowController *)windowController
{
	return [[self windowControllers] objectAtIndex:0];
}

- (void)selectNextTab
{
	[[self windowController] selectNextTab];
}

- (void)selectPreviousTab
{
	[[self windowController] selectPreviousTab];
}

- (void)selectTab:(int)tab
{
	[[self windowController] selectTab:tab];
}

@end
