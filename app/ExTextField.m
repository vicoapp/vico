#import "ExTextField.h"
#import "ViThemeStore.h"
#include "logging.h"

@implementation ExTextField

- (void)awakeFromNib
{
	history = [NSMutableArray array];
}

- (void)addToHistory:(NSString *)line
{
	/* Add the command to the history. */
	NSUInteger i = [history indexOfObject:line];
	if (i != NSNotFound)
		[history removeObjectAtIndex:i];
	[history insertObject:line atIndex:0];
	while ([history count] > 100)
		[history removeLastObject];

	INFO(@"history = %@", history);
}

- (BOOL)becomeFirstResponder
{
	NSTextView *editor = [[self window] fieldEditor:YES forObject:self];
	INFO(@"init, current editor is %@", editor);

	historyIndex = -1;
	ViTheme *theme = [[ViThemeStore defaultStore] defaultTheme];
	[self setBackgroundColor:[theme backgroundColor]];
	[self setTextColor:[theme foregroundColor]];

	[(ViTextView *)editor setCaret:0];
	[(ViTextView *)editor setInsertMode:nil];

	running = YES;
	return [super becomeFirstResponder];
}

- (BOOL)prev_history:(ViCommand *)command
{
	NSRange sel = [[self currentEditor] selectedRange];
	NSString *prefix = [[self stringValue] substringToIndex:sel.location];
	int i = historyIndex;
	INFO(@"history index = %i, count = %lu, prefix = %@",
	    historyIndex, [history count], prefix);
	while (i + 1 < [history count]) {
		NSString *item = [history objectAtIndex:++i];
		INFO(@"got item %@", item);
		if ([prefix length] == 0 || [item hasPrefix:prefix]) {
			INFO(@"insert item %@", item);
			[self setStringValue:item];
			historyIndex = i;
			[[self currentEditor] setSelectedRange:NSMakeRange(0, 0)];
			break;
		}
	}
	return YES;
}

- (BOOL)next_history:(ViCommand *)command
{
	NSRange sel = [[self currentEditor] selectedRange];
	NSString *prefix = [[self stringValue] substringToIndex:sel.location];
	int i = historyIndex;
	INFO(@"history index = %i, count = %lu, prefix = %@", historyIndex, [history count], prefix);
	while (i > 0) {
		NSString *item = [history objectAtIndex:--i];
		if ([prefix length] == 0 || [item hasPrefix:prefix]) {
			[self setStringValue:item];
			historyIndex = i;
			[[self currentEditor] setSelectedRange:NSMakeRange(0, 0)];
			break;
		}
	}
	if (i == 0) {
		historyIndex = -1;
		[self setStringValue:@""];
	}
	return YES;
}

- (BOOL)ex_cancel:(ViCommand *)command
{
	running = NO;
	[[self delegate] cancel_ex_command];
}

- (BOOL)ex_execute:(ViCommand *)command
{
	NSString *exCommand = [self stringValue];
	[self addToHistory:exCommand];
	running = NO;
	[[self delegate] execute_ex_command:exCommand];
}

- (void)textDidEndEditing:(NSNotification *)aNotification
{
	if (running)
		[self ex_cancel:nil];
	else 
		[super textDidEndEditing:aNotification];
}

@end
