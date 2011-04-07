#import "ViCompletionController.h"
#import "ViCommand.h"
#import "ViKeyManager.h"
#import "ViRegexp.h"
#include "logging.h"

@interface ViCompletionController (private)
- (void)filterCompletions;
@end

@implementation ViCompletionController

@synthesize delegate;
@synthesize window;
@synthesize completions;
@synthesize font;
@synthesize terminatingKey;

+ (id)sharedController
{
	static ViCompletionController *sharedController = nil;
	if (sharedController == nil)
		sharedController = [[ViCompletionController alloc] init];
	return sharedController;
}

- (id)init
{
	if ((self = [super init])) {
		[NSBundle loadNibNamed:@"CompletionWindow" owner:self];
		tableView.keyManager = [[ViKeyManager alloc] initWithTarget:self
								 defaultMap:[ViMap completionMap]];
		[window setStyleMask:NSBorderlessWindowMask];
		[window setHasShadow:YES];
		font = [NSFont systemFontOfSize:0];
		theme = [ViThemeStore defaultTheme];
//		[tableView setBackgroundColor:[theme backgroundColor]];

		matchParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		[matchParagraphStyle setLineBreakMode:NSLineBreakByTruncatingHead];
	}
	return self;
}

- (NSSize)boundsForCompletions:(NSArray *)array
{
	NSDictionary *attributes = [NSMutableDictionary dictionaryWithObject:font
							forKey:NSFontAttributeName];
	NSSize winsz = NSMakeSize(0, 20);
	for (NSString *s in array) {
		NSSize sz = [s sizeWithAttributes:attributes];
		if (sz.width + 20 > winsz.width)
			winsz.width = sz.width + 20;
		winsz.height += sz.height;
	}

	return winsz;
}

- (NSString *)chooseFrom:(NSArray *)anArray
             prefixRange:(NSRange *)aRange
                      at:(NSPoint)screenOrigin
               direction:(int)direction /* 0 = down, 1 = up */
             fuzzySearch:(BOOL)fuzzyFlag
{
	terminatingKey = 0;

	if ([anArray count] == 0)
		return nil;

	completions = anArray;
	filter = [NSMutableString string];
	prefixRange = *aRange;
	fuzzySearch = fuzzyFlag;

	[tableView setFont:font];

	NSSize sz = [self boundsForCompletions:anArray];
	sz.height = [anArray count] * ([tableView rowHeight] + 2);

	NSScreen *screen = [NSScreen mainScreen];
	NSSize scrsz = [screen visibleFrame].size;
	if (sz.height > scrsz.height / 2)
		sz.height = scrsz.height / 2;
	if (direction == 0) {
		if (screenOrigin.y < sz.height)
			screenOrigin.y = sz.height + 5;
	} else {
		if (screenOrigin.y + sz.height > scrsz.height)
			screenOrigin.y = scrsz.height - sz.height - 5;
	}
	if (screenOrigin.x + sz.width > scrsz.width)
		screenOrigin.x = scrsz.width - sz.width - 5;

	[window setContentSize:sz];

	[self filterCompletions];
	[tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
	       byExtendingSelection:NO];

	if (direction == 0)
		[window setFrameTopLeftPoint:screenOrigin];
	else
		[window setFrameOrigin:screenOrigin];
	[window orderFront:nil];
	NSInteger ret = [NSApp runModalForWindow:window];

	*aRange = prefixRange;

	return ret == NSRunAbortedResponse ? nil : selection;
}

+ (NSString *)commonPrefixInCompletions:(NSArray *)completions
{
	int options = NSCaseInsensitiveSearch;
	NSString *longestMatch = nil;
	id fm = [completions objectAtIndex:0];
	NSString *firstMatch = [fm respondsToSelector:@selector(string)] ? [fm string] : fm;
	for (id m in completions) {
		NSString *s = [m respondsToSelector:@selector(string)] ? [m string] : m;
		NSString *commonPrefix = [firstMatch commonPrefixWithString:s options:options];
		if (longestMatch == nil || [commonPrefix length] < [longestMatch length])
			longestMatch = commonPrefix;
	}
	return longestMatch;
}

- (void)setCompletions:(NSArray *)newCompletions
{
	filter = [NSMutableString string];
	filteredCompletions = nil;
	completions = newCompletions;
	[self filterCompletions];
}

- (BOOL)keyManager:(ViKeyManager *)keyManager
   evaluateCommand:(ViCommand *)command
{
	if (![self respondsToSelector:command.action] ||
	    (command.motion && ![self respondsToSelector:command.motion.action])) {
		return NO;
	}

	return (BOOL)[self performSelector:command.action withObject:command];
}

+ (void)appendFilter:(NSString *)string
           toPattern:(NSMutableString *)pattern
          fuzzyClass:(NSString *)fuzzyClass
{
	NSUInteger i;
	for (i = 0; i < [string length]; i++) {
		unichar c = [string characterAtIndex:i];
		if (i != 0)
			[pattern appendFormat:@"%@*?", fuzzyClass];
		[pattern appendFormat:@"(%s%C)", [ViRegexp needEscape:c] ? "\\" : "", c];
	}
}

- (void)filterCompletions
{
	ViRegexp *rx = nil;
	if ([filter length] > 0) {
		NSMutableString *pattern = [NSMutableString string];
		if (fuzzySearch) {
			[pattern appendFormat:@"^.{%lu}.*?", prefixRange.length];
			[ViCompletionController appendFilter:filter toPattern:pattern fuzzyClass:@"."];
			[pattern appendString:@".*$"];
		} else {
			[pattern appendFormat:@"^.{%lu}%@", prefixRange.length, [ViRegexp escape:filter]];
		}

		rx = [[ViRegexp alloc] initWithString:pattern
					      options:ONIG_OPTION_IGNORECASE];
	}

	NSRange grayRange = NSMakeRange(0, prefixRange.length);
	if (!fuzzySearch)
		grayRange.length += [filter length];
	NSColor *gray = [NSColor grayColor];

	filteredCompletions = [NSMutableArray array];
	for (NSString *s in completions) {
		if ([s length] < prefixRange.length)
			continue;
		if (rx == nil || [rx matchInString:s]) {
			NSMutableAttributedString *a = [[NSMutableAttributedString alloc] initWithString:s];
			[a addAttribute:NSForegroundColorAttributeName
				  value:gray
				  range:grayRange];
/*			[a addAttribute:NSFontAttributeName
				  value:font
				  range:NSMakeRange(0, [s length])];*/
			[filteredCompletions addObject:a];
		}
	}

	[tableView reloadData];
}

- (void)acceptByKey:(NSInteger)termKey
{
	terminatingKey = termKey;
	selection = [[filteredCompletions objectAtIndex:[tableView selectedRow]] string];
	[window orderOut:nil];
	[NSApp stopModal];

	completions = nil;
	filteredCompletions = nil;
	filter = nil;
}

- (BOOL)cancel:(ViCommand *)command
{
	terminatingKey = [[command.mapping.keySequence lastObject] integerValue];
	[window orderOut:nil];
	[NSApp abortModal];

	completions = nil;
	filteredCompletions = nil;
	filter = nil;
	return YES;
}

- (BOOL)accept:(ViCommand *)command
{
	[self acceptByKey:[[command.mapping.keySequence lastObject] integerValue]];
	return YES;
}

- (BOOL)filter:(ViCommand *)command
{
	NSInteger keyCode = [[command.mapping.keySequence lastObject] integerValue];

	SEL sel = @selector(completionController:shouldTerminateForKey:);
	if ([delegate respondsToSelector:sel]) {
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
		    [(NSObject *)delegate methodSignatureForSelector:sel]];
		[invocation setSelector:sel];
		[invocation setArgument:&self atIndex:2];
		[invocation setArgument:&keyCode atIndex:3];
		[invocation invokeWithTarget:delegate];
		BOOL shouldTerminate;
		[invocation getReturnValue:&shouldTerminate];
		if (shouldTerminate) {
			[self acceptByKey:keyCode];
			return YES;
		}
	}

	if (keyCode < 0x20) /* ignore control characters? */
		return NO;
	if (keyCode > 0xFFFF) /* ignore key equivalents? */
		return NO;

	[filter appendString:[NSString stringWithFormat:@"%C", keyCode]];
	[self filterCompletions];
	if ([filteredCompletions count] == 0) {
		terminatingKey = keyCode;
		[window orderOut:nil];
		[NSApp abortModal];
		return YES;
	}

	return YES;
}

- (BOOL)accept_or_complete_partially:(ViCommand *)command
{
	SEL sel = @selector(completionController:insertPartialCompletion:inRange:);

	if (fuzzySearch || ![delegate respondsToSelector:sel]) {
		NSLog(@"accepting directly");
		return [self accept:command];
	}

	NSString *partialCompletion = [ViCompletionController commonPrefixInCompletions:filteredCompletions];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
	    [(NSObject *)delegate methodSignatureForSelector:sel]];
	[invocation setSelector:sel];
	[invocation setArgument:&self atIndex:2];
	[invocation setArgument:&partialCompletion atIndex:3];
	[invocation setArgument:&prefixRange atIndex:4];
	[invocation invokeWithTarget:delegate];
	BOOL ret;
	[invocation getReturnValue:&ret];
	if (!ret)
		return [self cancel:command];

	NSMutableArray *array = [NSMutableArray array];
	for (id m in filteredCompletions)
		[array addObject:[m string]];
	prefixRange = NSMakeRange(prefixRange.location, [partialCompletion length]);
	[self setCompletions:array];

	if ([filteredCompletions count] == 1) {
		return [self accept:command];
	}

	return YES;
}

- (BOOL)move_up:(ViCommand *)command
{
	NSUInteger row = [tableView selectedRow];
	if (row == -1)
		row = 0;
	else if (row == 0)
		return NO;
	[tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:--row]
	       byExtendingSelection:NO];
	[tableView scrollRowToVisible:row];
	return YES;
}

- (BOOL)move_down:(ViCommand *)command
{
	NSUInteger row = [tableView selectedRow];
	if (row == -1)
		row = 0;
	else if (row + 1 >= [tableView numberOfRows])
		return NO;
	[tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:++row]
	       byExtendingSelection:NO];
	[tableView scrollRowToVisible:row];
	return YES;
}

#pragma mark -
#pragma mark NSTableViewDataSource Protocol

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [filteredCompletions count];
}

- (id)tableView:(NSTableView *)aTableView
objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(NSInteger)rowIndex
{
	return [filteredCompletions objectAtIndex:rowIndex];
}

@end
