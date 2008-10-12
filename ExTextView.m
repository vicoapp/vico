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
			filename = [[[[NSFileManager defaultManager] currentDirectoryPath] stringByAbbreviatingWithTildeInPath] stringByAppendingPathComponent:filename];

		NSArray *completions = nil;
		NSString *completion = nil;
		NSUInteger n = [filename completePathIntoString:&completion caseSensitive:NO matchesIntoArray:&completions filterTypes:nil];

		if (completion)
		{
			[[[self textStorage] mutableString] replaceCharactersInRange:range withString:completion];
		}
		
		if (n > 0)
		{
			INFO(@"display completions: %@", completions);
		}
	}
	else if (code == 0x00000035 /* escape */ ||
	         code == 0x00040008 /* ctrl-c */)
	{
		[self setString:@""];
		[[self window] endEditingFor:self];
	}
	else
	{
		[super keyDown:theEvent];
	}
}

@end
