#import "ExTextField.h"
#import "ViThemeStore.h"
#import "ViTextView.h"
#import "ExCommand.h"
#include "logging.h"

@implementation ExTextField

- (void)awakeFromNib
{
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	history = [NSMutableArray arrayWithArray:[defs arrayForKey:@"exhistory"]];
	if (history == nil)
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

	DEBUG(@"history = %@", history);
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	[defs setObject:history forKey:@"exhistory"];
}

- (BOOL)becomeFirstResponder
{
	ViTextView *editor = (ViTextView *)[[self window] fieldEditor:YES forObject:self];

	current = nil;
	historyIndex = -1;

	[editor setCaret:0];
	[editor setInsertMode:nil];

	running = YES;
	return [super becomeFirstResponder];
}

- (BOOL)navigateHistory:(BOOL)upwards prefix:(NSString *)prefix
{
	if (historyIndex == -1)
		current = [self stringValue];

	int i = historyIndex;
	DEBUG(@"history index = %i, count = %lu, prefix = %@",
	    historyIndex, [history count], prefix);
	while (upwards ? i + 1 < [history count] : i > 0) {
		i += (upwards ? +1 : -1);
		NSString *item = [history objectAtIndex:i];
		DEBUG(@"got item %@", item);
		if ([prefix length] == 0 || [[item lowercaseString] hasPrefix:prefix]) {
			DEBUG(@"insert item %@", item);
			[self setStringValue:item];
			[(ViTextView *)[self currentEditor] setInsertMode:nil];
			historyIndex = i;
			return YES;
		}
	}

	if (!upwards && i == 0) {
		[self setStringValue:current];
		[(ViTextView *)[self currentEditor] setInsertMode:nil];
		historyIndex = -1;
		return YES;
	}

	return NO;
}

- (BOOL)prev_history_ignoring_prefix:(ViCommand *)command
{
	return [self navigateHistory:YES prefix:nil];
}

- (BOOL)prev_history:(ViCommand *)command
{
	NSRange sel = [[self currentEditor] selectedRange];
	NSString *prefix = [[[self stringValue] substringToIndex:sel.location] lowercaseString];
	return [self navigateHistory:YES prefix:prefix];
}

- (BOOL)next_history_ignoring_prefix:(ViCommand *)command
{
	return [self navigateHistory:NO prefix:nil];
}

- (BOOL)next_history:(ViCommand *)command
{
	NSRange sel = [[self currentEditor] selectedRange];
	NSString *prefix = [[[self stringValue] substringToIndex:sel.location] lowercaseString];
	return [self navigateHistory:NO prefix:prefix];
}

- (BOOL)ex_cancel:(ViCommand *)command
{
	running = NO;
	if ([[self delegate] respondsToSelector:@selector(cancel_ex_command)])
		[[self delegate] performSelector:@selector(cancel_ex_command)];
	return YES;
}

- (BOOL)ex_execute:(ViCommand *)command
{
	NSString *exCommand = [self stringValue];
	[self addToHistory:exCommand];
	running = NO;
	if ([[self delegate] respondsToSelector:@selector(execute_ex_command:)])
		[[self delegate] performSelector:@selector(execute_ex_command:) withObject:exCommand];
	return YES;
}

- (BOOL)ex_complete:(ViCommand *)command
{
	int context = 0;

	ViTextView *editor = (ViTextView *)[[self window] fieldEditor:YES forObject:self];

	ExCommand *ex = [[ExCommand alloc] init];
	NSError *error = nil;
	[ex parse:[self stringValue] contextAtEnd:&context error:&error];

	switch (context) {
	case EX_CTX_FAIL:
		break;
	case EX_CTX_NONE:
		break;
	case EX_CTX_COMMAND:
		return [editor complete_ex_command:command];
		break;
	case EX_CTX_FILE:
		return [editor complete_path:command];
		break;
	case EX_CTX_BUFFER:
		return [editor complete_buffer:command];
		break;
	case EX_CTX_SYNTAX:
		return [editor complete_syntax:command];
		break;
	}
	return NO;
}

- (void)textDidEndEditing:(NSNotification *)aNotification
{
	if (running)
		[self ex_cancel:nil];
	else 
		[super textDidEndEditing:aNotification];
}

@end
