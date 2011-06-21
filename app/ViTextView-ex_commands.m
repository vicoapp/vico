#import "ViTextView.h"
#import "ViAppController.h"

@implementation ViTextView (ex_commands)

- (BOOL)resolveExAddresses:(ExCommand *)command intoLineRange:(NSRange *)outRange
{
	NSUInteger begin_line, end_line;
	ViMark *m = nil;
	ViTextStorage *storage = [self textStorage];

	switch (command.addr1->type) {
	case EX_ADDR_ABS:
		if (command.addr1->addr.abs.line == -1)
			begin_line = [storage lineCount];
		else
			begin_line = command.addr1->addr.abs.line;
		break;
	case EX_ADDR_RELATIVE:
	case EX_ADDR_CURRENT:
		begin_line = [self currentLine];
		break;
	case EX_ADDR_MARK:
		m = [self markNamed:command.addr1->addr.mark];
		if (m == nil) {
			MESSAGE(@"Mark %C: not set", command.addr1->addr.mark);
			return NO;
		}
		begin_line = m.line;
		break;
	case EX_ADDR_NONE:
	default:
		return NO;
		break;
	}

	begin_line += command.addr1->offset;
	if ([storage locationForStartOfLine:begin_line] == -1ULL)
		return NO;

	switch (command.addr2->type) {
	case EX_ADDR_ABS:
		if (command.addr2->addr.abs.line == -1)
			end_line = [storage lineCount];
		else
			end_line = command.addr2->addr.abs.line;
		break;
	case EX_ADDR_CURRENT:
		end_line = [self currentLine];
		break;
	case EX_ADDR_MARK:
		m = [self markNamed:command.addr2->addr.mark];
		if (m == nil) {
			MESSAGE(@"Mark %C: not set", command.addr2->addr.mark);
			return NO;
		}
		end_line = m.line;
		break;
	case EX_ADDR_RELATIVE:
	case EX_ADDR_NONE:
		end_line = begin_line;
		break;
	default:
		return NO;
	}

	end_line += command.addr2->offset;
	if ([storage locationForStartOfLine:end_line] == -1ULL)
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

@end

