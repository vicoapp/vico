#import "ViTextView.h"

@implementation ViTextView (syntax)

- (void)initHighlighting
{
	if(!syntax_initialized)
	{
		syntax_initialized = YES;
		
		NSString *plist = [[NSBundle mainBundle] pathForResource:@"c" ofType:@"plist" inDirectory:nil];
		keywords = [NSDictionary dictionaryWithContentsOfFile:plist];
		//NSLog(@"got %i keywords", [keywords count]);
		
		commentColor = [[NSColor colorWithCalibratedRed:0 green:102.0/256 blue:1.0 alpha:1.0] retain];
		stringColor = [[NSColor colorWithCalibratedRed:3.0/256 green:106.0/256 blue:7.0/256 alpha:1.0] retain];
		numberColor = [[NSColor colorWithCalibratedRed:0 green:0 blue:205.0/256 alpha:1.0] retain];
		keywordColor = [[NSColor colorWithCalibratedRed:0 green:0 blue:1.0 alpha:1.0] retain];
		
		keywordSet = [[NSMutableCharacterSet alloc] init];
		[keywordSet formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
		[keywordSet addCharactersInString:@"_"];
		
		keywordAndDotSet = [keywordSet copy];
		[keywordAndDotSet addCharactersInString:@"."];
	}	
}

- (void)highlightInRange:(NSRange)aRange
{
	// NSLog(@"%s range = %u + %u", _cmd, aRange.location, aRange.length);

	if(!syntax_initialized)
		[self initHighlighting];

	NSString *string = [storage string];
	NSUInteger tail = aRange.location + aRange.length;
	NSUInteger i;
	for(i = aRange.location; i < tail; )
	{
		NSInteger j;
		unichar c = [string characterAtIndex:i];
		if(c == '/' && [string characterAtIndex:i+1] == '/')
		{
			/* line comment */
			for(j = i + 2; j < tail; j++)
			{
				if([string characterAtIndex:j] == '\n')
					break;
			}
			[storage addAttribute:NSForegroundColorAttributeName 
					    value:commentColor
					    range:NSMakeRange(i, j - i)];
			i = j + 1;
		}
		else if(c == '/' && [string characterAtIndex:i+1] == '*')
		{
			/* multi-line string constant */
			for(j = i + 2; j < tail; j++)
			{
				if([string characterAtIndex:j] == '*' && [string characterAtIndex:j+1] == '/')
				{
					j += 2;
					break;
				}
			}
			[storage addAttribute:NSForegroundColorAttributeName 
					value:commentColor
					range:NSMakeRange(i, j - i)];
			i = j + 1;
		}
		else if(c == '"' || c == '\'')
		{
			/* string constant */
			for(j = i + 1; j < tail; j++)
			{
				unichar c2 = [string characterAtIndex:j];
				if(c2 == '\\')
				{
					j++;
				}
				else if(c2 == c)
				{
					j++;
					break;
				}
			}
			[storage addAttribute:NSForegroundColorAttributeName 
					value:stringColor
					range:NSMakeRange(i, j - i)];
			i = j;
		}
		else if([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:c])
		{
			NSCharacterSet *numberSet = [NSCharacterSet decimalDigitCharacterSet];
			j = i + 1;
			unichar c2 = [string characterAtIndex:i+1];
			if(c == '0' && (c2 == 'x' || c2 == 'X'))
			{
				numberSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
				j++;
			}
			/* number (decimal, hexadecimal or octal) */
			for(; j < tail; j++)
			{
				if(![numberSet characterIsMember:[string characterAtIndex:j]])
					break;
			}
			[storage addAttribute:NSForegroundColorAttributeName 
				        value:numberColor
				        range:NSMakeRange(i, j - i)];
			i = j;
		}
		else if([keywordSet characterIsMember:c])
		{
			/* keyword */
			for(j = i + 1; j < tail; j++)
			{
				if(![keywordAndDotSet characterIsMember:[string characterAtIndex:j]])
					break;
			}
			NSRange found = NSMakeRange(i, j - i);
			NSString *keyword = [string substringWithRange:found];
			if([keywords objectForKey:keyword])
			{
				[storage addAttribute:NSForegroundColorAttributeName 
						    value:keywordColor
						    range:found];
			}
			i = j;
		}
		else
			i++;
	}
}

/*
 * Update syntax colors.
 */
- (void)textStorageDidProcessEditing:(NSNotification *)notification
{
	NSRange area = [storage editedRange];
	
	// extend our range along line boundaries.
	NSUInteger bol, eol;
	[[storage string] getLineStart:&bol end:NULL contentsEnd:&eol forRange:area];
	area.location = bol;
	area.length = eol - bol;

	// NSLog(@"%s area = %u + %u", _cmd, area.location, area.length);
	if(area.length == 0)
		return;
	
	// remove the old colors
	[storage removeAttribute:NSForegroundColorAttributeName range:area];
	[self highlightInRange:area];
}

- (void)highlightEverything
{
	[storage beginEditing];
	[self highlightInRange:NSMakeRange(0, [[storage string] length])];
	[storage endEditing];
}

@end
