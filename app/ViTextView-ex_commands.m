#import "ViTextView.h"
#import "ViAppController.h"

@implementation ViTextView (ex_commands)

- (NSInteger)resolveExAddress:(struct ex_address *)addr
		   relativeTo:(NSInteger)relline
{
	ViMark *m = nil;
	ViTextStorage *storage = [self textStorage];
	NSInteger line = -1;

	switch (addr->type) {
	case EX_ADDR_ABS:
		if (addr->addr.abs.line == -1)
			line = [storage lineCount];
		else
			line = addr->addr.abs.line;
		break;
	case EX_ADDR_CURRENT:
		line = [self currentLine];
		break;
	case EX_ADDR_MARK:
		m = [self markNamed:addr->addr.mark];
		if (m == nil) {
			MESSAGE(@"Mark %C: not set", addr->addr.mark);
			return -1;
		}
		line = m.line;
		break;
	case EX_ADDR_RELATIVE:
		if (relline < 0)
			line = [self currentLine];
		else
			line = relline;
		break;
	case EX_ADDR_NONE:
	default:
		if (relline < 0)
			return -1;
		line = relline;
		break;
	}

	line += addr->offset;

	if ([storage locationForStartOfLine:line] == -1ULL)
		return -1;

	return line;
}

- (NSInteger)resolveExAddress:(struct ex_address *)addr
{
	return [self resolveExAddress:addr relativeTo:-1];
}

- (BOOL)resolveExAddresses:(ExCommand *)command intoLineRange:(NSRange *)outRange
{
	NSInteger begin_line, end_line;

	begin_line = [self resolveExAddress:command.addr1];
	if (begin_line < 0)
		return NO;
	end_line = [self resolveExAddress:command.addr2 relativeTo:begin_line];
	if (end_line < 0)
		return NO;

	*outRange = NSMakeRange(begin_line, end_line - begin_line);
	return YES;
}

- (BOOL)resolveExAddresses:(ExCommand *)command intoRange:(NSRange *)outRange
{
	NSRange lineRange;
	if ([self resolveExAddresses:command intoLineRange:&lineRange] == NO)
		return NO;

	ViTextStorage *storage = [self textStorage];
	NSUInteger beg = [storage locationForStartOfLine:lineRange.location];
	NSUInteger end = [storage locationForStartOfLine:NSMaxRange(lineRange)];

	/* end location should include the contents of the end_line */
	[self getLineStart:NULL end:&end contentsEnd:NULL forLocation:end];
	*outRange = NSMakeRange(beg, end - beg);
	return YES;
}

- (BOOL)ex_bang:(ExCommand *)command
{
	NSRange range;
	if (![self resolveExAddresses:command intoRange:&range])
		return NO;
	[self filterRange:range throughCommand:command.string];
	return YES;
}

- (BOOL)ex_eval:(ExCommand *)command
{
	NSRange range;
	if (![self resolveExAddresses:command intoRange:&range])
		return NO;

	NSString *script = [[[self textStorage] string] substringWithRange:range];
	NSError *error = nil;
	id result = [[NSApp delegate] eval:script error:&error];
	if (error) {
		MESSAGE(@"%@", [error localizedDescription]);
		return NO;
	}

	MESSAGE(@"%@", result);
	return YES;
}

- (BOOL)ex_s:(ExCommand *)command
{
	NSRange exRange;
	if (![self resolveExAddresses:command intoLineRange:&exRange]) {
		MESSAGE(@"Invalid addresses");
		return NO;
	}

	unsigned rx_options = ONIG_OPTION_NOTBOL | ONIG_OPTION_NOTEOL;
	if ([command.string rangeOfString:@"i"].location != NSNotFound)
		rx_options |= ONIG_OPTION_IGNORECASE;

	ViRegexp *rx = nil;

	/* compile the pattern regexp */
	@try {
		rx = [[ViRegexp alloc] initWithString:command.pattern
					      options:rx_options];
	}
	@catch(NSException *exception) {
		MESSAGE(@"Invalid search pattern: %@", exception);
		return NO;
	}

	ViTextStorage *storage = [self textStorage];
	ViTransformer *tform = [[ViTransformer alloc] init];
	NSError *error = nil;

	NSString *s = [storage string];
	DEBUG(@"ex range is %@", NSStringFromRange(exRange));

	for (NSUInteger lineno = exRange.location; lineno <= NSMaxRange(exRange); lineno++) {
		NSUInteger bol = [storage locationForStartOfLine:lineno];
		NSUInteger end, eol;
		[s getLineStart:NULL end:&end contentsEnd:&eol forRange:NSMakeRange(bol, 0)];

		NSRange lineRange = NSMakeRange(bol, eol - bol);
		NSString *value = [s substringWithRange:lineRange];
		DEBUG(@"range %@ = %@", NSStringFromRange(lineRange), value);
		NSString *replacedText = [tform transformValue:value
						   withPattern:rx
							format:command.replacement
						       options:command.string
							 error:&error];
		if (error) {
			MESSAGE(@"substitute failed: %@", [error localizedDescription]);
			return NO;
		}

		if (replacedText != value)
			[self replaceCharactersInRange:lineRange withString:replacedText];
	}

	[self endUndoGroup];
	final_location = [storage locationForStartOfLine:NSMaxRange(exRange)];
	return YES;
}

- (BOOL)ex_number:(ExCommand *)command
{
	NSRange range;
	if (![self resolveExAddresses:command intoRange:&range]) {
		MESSAGE(@"Invalid address");
		return NO;
	}

	final_location = [[self textStorage] firstNonBlankForLineAtLocation:range.location];
	return YES;
}

- (BOOL)ex_yank:(ExCommand *)command
{
	NSRange range;
	if (![self resolveExAddresses:command intoRange:&range])
		return NO;

	[self yankToRegister:command.reg range:range];
	return YES;
}

- (BOOL)ex_delete:(ExCommand *)command
{
	NSRange range;
	if (![self resolveExAddresses:command intoRange:&range])
		return NO;

	[self cutToRegister:command.reg range:range];
	return YES;
}

- (BOOL)ex_copy:(ExCommand *)command
{
	NSRange range;
	if (![self resolveExAddresses:command intoRange:&range])
		return NO;

	NSInteger destline = [self resolveExAddress:command.line];
	if (destline < 0)
		return NO;
	if (destline > 0)
		++destline;

	NSString *content = [[[self textStorage] string] substringWithRange:range];
	NSInteger destloc = [[self textStorage] locationForStartOfLine:destline];
	if (destloc == -1)
		destloc = [[self textStorage] length];
	[self insertString:content atLocation:destloc];

	final_location = [[self textStorage] firstNonBlankForLineAtLocation:destloc + [content length]];

	return YES;
}

- (BOOL)ex_move:(ExCommand *)command
{
	NSRange lineRange, range;
	if (![self resolveExAddresses:command intoLineRange:&lineRange])
		return NO;
	if (![self resolveExAddresses:command intoRange:&range])
		return NO;

	NSInteger destline = [self resolveExAddress:command.line];
	if (destline < 0)
		return NO;

	if (destline >= lineRange.location && destline < NSMaxRange(lineRange)) {
		MESSAGE(@"Can't move lines into themselves");
		return NO;
	}

	if (destline > 0)
		++destline;

	NSString *content = [[[self textStorage] string] substringWithRange:range];
	NSInteger destloc = [[self textStorage] locationForStartOfLine:destline];
	if (destloc == -1)
		destloc = [[self textStorage] length];

	if (destloc > range.location) {
		[self insertString:content atLocation:destloc];
		[self deleteRange:range undoGroup:YES];
		final_location = [[self textStorage] firstNonBlankForLineAtLocation:destloc];
	} else {
		[self deleteRange:range undoGroup:YES];
		[self insertString:content atLocation:destloc];
		final_location = [[self textStorage] firstNonBlankForLineAtLocation:destloc + range.length];
	}

	return YES;
}

@end

