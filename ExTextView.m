#import "ExTextView.h"
#import "logging.h"

@implementation ExTextView

static id defaultEditor = nil;

+ (id)defaultEditor
{
	if (defaultEditor == nil)
	{
		defaultEditor = [[ExTextView alloc] initWithFrame:NSMakeRect(0,0,0,0)];
		[defaultEditor setFieldEditor:YES];
	}
	return defaultEditor;
}

- (NSString *)filenameAtLocation:(NSUInteger)aLocation range:(NSRange *)outRange
{
	NSString *s = [[self textStorage] string];
	NSRange r = [s rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]
				       options:NSBackwardsSearch
					 range:NSMakeRange(0, aLocation)];

	if (r.location++ == NSNotFound)
		r.location = 0;

	r.length = aLocation - r.location;
	*outRange = r;

	return [[[self textStorage] string] substringWithRange:r];
}

- (unsigned)completePath:(NSString *)partialPath intoString:(NSString **)longestMatchPtr matchesIntoArray:(NSArray **)matchesPtr
{
	NSFileManager *fm = [NSFileManager defaultManager];

	NSString *path;
	NSString *suffix;
	if ([partialPath hasSuffix:@"/"])
	{
		path = partialPath;
		suffix = @"";
	}
	else
	{
		path = [partialPath stringByDeletingLastPathComponent];
		suffix = [partialPath lastPathComponent];
	}

	NSArray *directoryContents = [fm directoryContentsAtPath:[path stringByExpandingTildeInPath]];
	NSMutableArray *matches = [[NSMutableArray alloc] init];
	NSString *entry;
	for (entry in directoryContents)
	{
		if ([entry compare:suffix options:NSCaseInsensitiveSearch range:NSMakeRange(0, [suffix length])] == NSOrderedSame)
		{
			NSString *s = [path stringByAppendingPathComponent:entry];
			BOOL isDirectory = NO;
			if ([fm fileExistsAtPath:[s stringByExpandingTildeInPath] isDirectory:&isDirectory] && isDirectory)
				[matches addObject:[s stringByAppendingString:@"/"]];
			else
				[matches addObject:s];
		}
	}

	if (longestMatchPtr && [matches count] > 0)
	{
		NSString *longestMatch = nil;
		NSString *firstMatch = [matches objectAtIndex:0];
		NSString *m;
		for (m in matches)
		{
			NSString *commonPrefix = [firstMatch commonPrefixWithString:m options:NSCaseInsensitiveSearch];
			if (longestMatch == nil || [commonPrefix length] < [longestMatch length])
				longestMatch = commonPrefix;
		}
		*longestMatchPtr = longestMatch;
	}

	if (matchesPtr)
		*matchesPtr = matches;

	return [matches count];
}

- (void)keyDown:(NSEvent *)theEvent
{
	if ([[theEvent characters] length] == 0)
		return [super keyDown:theEvent];

	NSUInteger code = (([theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask) | [theEvent keyCode]);

	if (code == 0x00000030 /* tab */ ||
	    code == 0x00040002 /* ctrl-d */)
	{
		NSUInteger caret = [self selectedRange].location;
		NSRange range;
		NSString *filename = [self filenameAtLocation:caret range:&range];

		if (![filename isAbsolutePath])
			filename = [[[[NSDocumentController sharedDocumentController] currentDirectory] stringByAbbreviatingWithTildeInPath] stringByAppendingPathComponent:filename];

		NSArray *completions = nil;
		NSString *completion = nil;
		NSUInteger n = [self completePath:filename intoString:&completion matchesIntoArray:&completions];

		if (completion)
		{
			[[[self textStorage] mutableString] replaceCharactersInRange:range withString:completion];
		}
		
		if (n > 0)
		{
			INFO(@"display completions: %@", completions);
		}
	}
	else
	{
		[super keyDown:theEvent];
	}
}

@end
