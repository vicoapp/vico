#import "ExCompletionView.h"

@implementation ExCompletionView

- (void)awakeFromNib
{
	_completionMap = [[ViMap mapWithName:@"exCompletionMap"] retain];
	[_completionMap include:[ViMap mapWithName:@"tableNavigationMap"]];
	[_completionMap setKey:@"<cr>" toAction:@selector(selectCompletion:)];
	[_completionMap setKey:@"<tab>" toAction:@selector(selectCompletion:)];
	[_completionMap setKey:@"<esc>" toAction:@selector(cancelCompletion:)];

	_keyManager = [[ViKeyManager keyManagerWithTarget:self defaultMap:_completionMap] retain];
}

- (void)keyDown:(NSEvent *)event
{
	[_keyManager keyDown:event];
}
- (BOOL)performKeyEquivalent:(NSEvent *)event
{
	if ([[self window] firstResponder] == self)
		return [_keyManager performKeyEquivalent:event];
	else
		return NO;
}
- (BOOL)keyManager:(ViKeyManager *)keyManager evaluateCommand:(ViCommand *)command
{
	return [self performCommand:command];
}

- (void)dealloc
{
	[_completionMap release];
	[_keyManager release];

	[super dealloc];
}

@end
