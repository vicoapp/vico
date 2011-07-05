#import "ViCompletionController.h"
#import "ViCommand.h"
#import "ViKeyManager.h"
#import "ViRegexp.h"
#include "logging.h"

@interface ViCompletionController (private)
- (void)updateBounds;
- (void)filterCompletions;
- (BOOL)complete_partially:(ViCommand *)command;
- (void)acceptByKey:(NSInteger)termKey;
- (BOOL)cancel:(ViCommand *)command;
- (void)updateCompletions;
@end

@implementation ViCompletionController

@synthesize delegate;
@synthesize window;
@synthesize completions;
@synthesize terminatingKey;
@synthesize range;
@synthesize filter;

+ (id)sharedController
{
	static ViCompletionController *sharedController = nil;
	if (sharedController == nil)
		sharedController = [[ViCompletionController alloc] init];
	sharedController.delegate = nil;
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
		theme = [ViThemeStore defaultTheme];
//		[tableView setBackgroundColor:[theme backgroundColor]];

		matchParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		[matchParagraphStyle setLineBreakMode:NSLineBreakByTruncatingHead];
	}
	return self;
}

- (void)updateBounds
{
	NSSize winsz = NSMakeSize(0, 0);
	for (ViCompletion *c in filteredCompletions) {
		NSSize sz = [c.title size];
		if (sz.width + 20 > winsz.width)
			winsz.width = sz.width + 20;
	}

	DEBUG(@"got %lu completions, row height is %f",
	    [filteredCompletions count], [tableView rowHeight]);
	winsz.height = [filteredCompletions count] * ([tableView rowHeight] + 2);

	NSScreen *screen = [NSScreen mainScreen];
	NSSize scrsz = [screen visibleFrame].size;
	NSPoint origin = screenOrigin;
	if (winsz.height > scrsz.height / 2)
		winsz.height = scrsz.height / 2;
	if (upwards) {
		if (origin.y + winsz.height > scrsz.height)
			origin.y = scrsz.height - winsz.height - 5;
	} else {
		if (origin.y < winsz.height)
			origin.y = winsz.height + 5;
	}
	if (origin.x + winsz.width > scrsz.width)
		origin.x = scrsz.width - winsz.width - 5;

	NSRect frame = [window frame];
	frame.origin = origin;
	if (!upwards)
		frame.origin.y -= winsz.height;
	frame.size = winsz;
	if (!NSEqualRects(frame, [window frame])) {
		DEBUG(@"setting frame %@", NSStringFromRect(frame));
		[window setFrame:frame display:YES];
	}
}

- (void)completionResponse:(NSArray *)array error:(NSError *)error
{
	DEBUG(@"got completions: %@, error %@", array, error);
	completions = array;
	if ([completions count] == 0) {
		if ([window isVisible]) {
			[self cancel:nil];
			return;
		}
	} else {
		[self updateCompletions];
		[self filterCompletions];
		if ([filteredCompletions count] == 0) {
			if ([window isVisible]) {
				[self cancel:nil];
				return;
			}
		} else if ([filteredCompletions count] == 1) {
			if ([window isVisible]) {
				[self acceptByKey:0];
			} else
				onlyCompletion = [filteredCompletions objectAtIndex:0];
		}

		/* Automatically insert common prefix among all possible completions.
		 */
		if ([options rangeOfString:@"p"].location != NSNotFound)
			[self complete_partially:nil];
	}
}

- (ViCompletion *)chooseFrom:(id<ViCompletionProvider>)aProvider
                       range:(NSRange)aRange
		      prefix:(NSString *)aPrefix
                          at:(NSPoint)origin
		     options:(NSString *)optionString
                   direction:(int)direction /* 0 = down, 1 = up */
               initialFilter:(NSString *)initialFilter
{
	terminatingKey = 0;

	if (initialFilter)
		filter = [initialFilter mutableCopy];
	else
		filter = [NSMutableString string];

	provider = aProvider;
	range = aRange;
	prefix = aPrefix;
	prefixLength = [aPrefix length];
	options = optionString;
	fuzzySearch = ([options rangeOfString:@"f"].location != NSNotFound);

	DEBUG(@"range is %@, with prefix [%@] and [%@] as initial filter, w/options %@",
	    NSStringFromRange(range), prefix, initialFilter, options);

	onlyCompletion = nil;

	void (^onCompletionResponse)(NSArray *, NSError *) = ^(NSArray *array, NSError *error) {
		[self completionResponse:array error:error];
	};

	completions = nil;
	filteredCompletions = nil;
	if ([aProvider respondsToSelector:@selector(completionsForString:options:onResponse:)])
		[aProvider completionsForString:prefix
					options:options
				     onResponse:onCompletionResponse];
	else if ([aProvider respondsToSelector:@selector(completionsForString:options:target:action:)])
		[aProvider completionsForString:prefix
					options:options
					 target:self
					 action:@selector(completionResponse:error:)];
	else {
		INFO(@"Completion provider %@ doesn't respond to completionsForString:options:target:action:", aProvider);
		return nil;
	}

	if (onlyCompletion) {
		DEBUG(@"returning %@ as only completion", onlyCompletion);
		return onlyCompletion;
	}

	if ([completions count] == 0 || [filteredCompletions count] == 0) {
		DEBUG(@"%s", "returning without completions");
		return nil;
	}

	screenOrigin = origin;
	upwards = (direction == 1);

	[tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
	       byExtendingSelection:NO];

	DEBUG(@"showing window %@", window);
	[window orderFront:nil];
	NSInteger ret = [NSApp runModalForWindow:window];

	return ret == NSRunAbortedResponse ? nil : selection;
}

+ (NSString *)commonPrefixInCompletions:(NSArray *)completions
{
	if ([completions count] == 0)
		return nil;
	int options = NSCaseInsensitiveSearch;
	NSString *longestMatch = nil;
	ViCompletion *c = [completions objectAtIndex:0];
	NSString *firstMatch = c.content;
	for (c in completions) {
		NSString *s = c.content;
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
			[pattern appendFormat:@"^.{%lu}.*", prefixLength];
			[ViCompletionController appendFilter:filter toPattern:pattern fuzzyClass:@"."];
			[pattern appendString:@".*$"];
		} else {
			[pattern appendFormat:@"^.{%lu}%@", prefixLength, [ViRegexp escape:filter]];
		}

		rx = [[ViRegexp alloc] initWithString:pattern
					      options:ONIG_OPTION_IGNORECASE];
	}

	filteredCompletions = [NSMutableArray array];
	for (ViCompletion *c in completions) {
		// DEBUG(@"filtering completion %@ on %@", c, rx);
		NSString *s = c.content;
		if ([s length] < prefixLength)
			continue;
		ViRegexpMatch *m = nil;
		if (rx == nil || (m = [rx matchInString:s]) != nil) {
			c.filterMatch = m;
			[filteredCompletions addObject:c];
		}
	}

	if (fuzzySearch)
		[filteredCompletions sortUsingComparator:^(id a, id b) {
			ViCompletion *ca = a, *cb = b;
			if (ca.score > cb.score)
				return (NSComparisonResult)NSOrderedAscending;
			else if (cb.score > ca.score)
				return (NSComparisonResult)NSOrderedDescending;
			return (NSComparisonResult)NSOrderedSame;
		}];

	[tableView reloadData];
	[self updateBounds];
}

- (void)setFilter:(NSString *)aString
{
	filter = [aString mutableCopy];
	[self filterCompletions];
}

- (void)acceptByKey:(NSInteger)termKey
{
	terminatingKey = termKey;
	NSInteger row = [tableView selectedRow];
	if (row >= 0 && row < [filteredCompletions count])
		selection = [filteredCompletions objectAtIndex:row];
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

- (void)updateCompletions
{
	for (ViCompletion *c in completions) {
		c.prefixLength = prefixLength;
		c.filterIsFuzzy = fuzzySearch;
	}
}

- (BOOL)complete_partially:(ViCommand *)command
{
	SEL sel = @selector(completionController:insertPartialCompletion:inRange:);

	NSString *partialCompletion =
	    [ViCompletionController commonPrefixInCompletions:filteredCompletions];
	if ([partialCompletion length] == 0)
		return YES;
	DEBUG(@"common prefix is [%@], range is %@", partialCompletion, NSStringFromRange(range));
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
	    [(NSObject *)delegate methodSignatureForSelector:sel]];
	[invocation setSelector:sel];
	[invocation setArgument:&self atIndex:2];
	[invocation setArgument:&partialCompletion atIndex:3];
	[invocation setArgument:&range atIndex:4];
	[invocation invokeWithTarget:delegate];
	BOOL ret;
	[invocation getReturnValue:&ret];
	if (!ret)
		return NO;

	range = NSMakeRange(range.location, [partialCompletion length]);
	prefixLength = range.length;
	[self setCompletions:filteredCompletions];
	[self updateCompletions];

	return YES;
}

- (BOOL)accept_or_complete_partially:(ViCommand *)command
{
	SEL sel = @selector(completionController:insertPartialCompletion:inRange:);

	if (fuzzySearch || ![delegate respondsToSelector:sel])
		return [self accept:command];

	if (![self complete_partially:command])
		return [self cancel:command];

	if ([filteredCompletions count] == 1)
		return [self accept:command];

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

- (BOOL)toggle_fuzzy:(ViCommand *)command
{
	fuzzySearch = !fuzzySearch;
	for (ViCompletion *c in completions)
		c.filterIsFuzzy = fuzzySearch;
	[self filterCompletions];
	if ([filteredCompletions count] == 1)
		return [self accept:command];
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
	return [(ViCompletion *)[filteredCompletions objectAtIndex:rowIndex] title];
}

@end
