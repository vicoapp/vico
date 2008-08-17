#import "MyDocument.h"
#import "ViTextView.h"

@implementation MyDocument

- (id)init
{
	self = [super init];
	if(self)
	{
		// Add your subclass-specific initialization here.
		// If an error occurs here, send a [self release] message and return nil.
	}
	return self;
}

- (NSString *)windowNibName
{
	// Override returning the nib file name of the document
	// If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
	return @"MyDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
	[super windowControllerDidLoadNib:aController];
	
	// Add any code here that needs to be executed once the windowController has loaded the document's window.
	if(readContent)
		[[[textView textStorage] mutableString] setString:readContent];
	readContent = nil;
	[textView initEditor];
	[textView setFilename:[self fileURL]];
	[textView highlightEverything];
	[textView setDelegate:self];
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
	// Insert code here to write your document to data of the specified type. If
	// the given outError != NULL, ensure that you set *outError when returning nil.

	return [[[textView textStorage] string] dataUsingEncoding:NSUTF8StringEncoding];
	// You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.

#if 0
	if ( outError != NULL )
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
	return nil;
#endif
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	// Insert code here to read your document from the given data of the
	// specified type. If the given outError != NULL, ensure that you set *outError
	// when returning NO.
	
	// You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead. 

	readContent = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if(textView)
	{
		[[[textView textStorage] mutableString] setString:readContent];
		readContent = nil;
	}

	return YES;
}

- (void)changeTheme:(ViTheme *)theme
{
	[textView setTheme:theme];
}

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
	NSLog(@"got ex command? [%@]", [statusbar stringValue]);
	[textView performSelector:exCommandSelector withObject:[statusbar stringValue]];
	[statusbar setStringValue:@""];
	[statusbar setEditable:NO];
	[editWindow makeFirstResponder:textView];
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
	[editWindow makeFirstResponder:statusbar];
}

@end
