#import "ViOutlineView.h"
#include "logging.h"

@implementation ViOutlineView

- (void)awakeFromNib
{
	parser = [[ViCommand alloc] init];
}

- (unichar)parseKeyEvent:(NSEvent *)theEvent modifiers:(unsigned int *)modPtr
{
	// http://sigpipe.macromates.com/2005/09/24/deciphering-an-nsevent/
	// given theEvent (NSEvent*) figure out what key 
	// and modifiers we actually want to look at, 
	// to compare it with a menu key description

	NSUInteger quals = [theEvent modifierFlags];

	NSString *str = [theEvent characters];
	NSString *strWithout = [theEvent charactersIgnoringModifiers];

	unichar ch = [str length] ? [str characterAtIndex:0] : 0;
	unichar without = [strWithout length] ? [strWithout characterAtIndex:0] : 0;

	if (!(quals & NSNumericPadKeyMask)) {
		if (quals & NSControlKeyMask) {
			if (ch < 0x20)
				quals &= ~NSControlKeyMask;
			else
				ch = without;
		} else if (quals & NSAlternateKeyMask) {
			if (0x20 < ch && ch < 0x7f && ch != without)
				quals &= ~NSAlternateKeyMask;
			else
				ch = without;
		} else if ((quals & (NSCommandKeyMask | NSShiftKeyMask)) == (NSCommandKeyMask | NSShiftKeyMask))
			ch = without;

		if ((0x20 < ch && ch < 0x7f) || ch == 0x19)
			quals &= ~NSShiftKeyMask;
	}
 
	// the resulting values
	unichar key = ch;
	unsigned int modifiers = quals & (NSNumericPadKeyMask | NSShiftKeyMask | NSControlKeyMask | NSAlternateKeyMask | NSCommandKeyMask);

	DEBUG(@"key = %C (0x%04x), shift = %s, control = %s, alt = %s, command = %s",
	    key, key,
	    (modifiers & NSShiftKeyMask) ? "YES" : "NO",
	    (modifiers & NSControlKeyMask) ? "YES" : "NO",
	    (modifiers & NSAlternateKeyMask) ? "YES" : "NO",
	    (modifiers & NSCommandKeyMask) ? "YES" : "NO"
	);

	*modPtr = modifiers;

        return key;
}

- (void)keyDown:(NSEvent *)theEvent
{
	unsigned int modifiers;
	unichar charcode;
	charcode = [self parseKeyEvent:theEvent modifiers:&modifiers];

	if (parser.complete)
		[parser reset];

	if (!parser.partial)
		[parser setExplorerMap];

	[parser pushKey:charcode];
	if (parser.complete) {
		if ([[self delegate] respondsToSelector:@selector(outlineView:evaluateCommand:)])
			[[self delegate] outlineView:self evaluateCommand:parser];
	}
}

@end
