#import "ViTextView.h"
#import "ViAppController.h"
#import "ViEventManager.h"

@implementation ViTextView (ex_commands)

- (NSInteger)resolveExAddress:(ExAddress *)addr
		   relativeTo:(NSInteger)relline
{
	ViMark *m = nil;
	ViTextStorage *storage = [self textStorage];
	NSInteger line = -1;

	switch (addr.type) {
	case ExAddressAbsolute:
		if (addr.line == -1)
			line = [storage lineCount];
		else
			line = addr.line;
		break;
	case ExAddressCurrent:
		line = [self currentLine];
		break;
	case ExAddressMark:
		m = [self markNamed:addr.mark];
		if (m == nil) {
			MESSAGE(@"Mark %C: not set", addr.mark);
			return -1;
		}
		line = m.line;
		break;
	case ExAddressRelative:
		if (relline < 0)
			line = [self currentLine];
		else
			line = relline;
		break;
	case ExAddressNone:
	default:
		if (relline < 0)
			return -1;
		line = relline;
		break;
	}

	line += addr.offset;

	if ([storage locationForStartOfLine:line] == -1ULL)
		return -1;

	return line;
}

- (NSInteger)resolveExAddress:(ExAddress *)addr
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
	NuParser *parser = [[NuParser alloc] init];
	[[NSApp delegate] loadStandardModules:[parser context]];
	[parser setValue:[ViEventManager defaultManager] forKey:@"eventManager"];
	id result = [[NSApp delegate] eval:script
				withParser:parser
				  bindings:nil
				     error:&error];
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
	NSString *opts = command.string ?: @"";
	if ([opts rangeOfString:@"i"].location != NSNotFound)
		rx_options |= ONIG_OPTION_IGNORECASE;

	BOOL reportMatches = NO;
	if ([opts rangeOfString:@"n"].location != NSNotFound)
		reportMatches = YES;

	BOOL global = [[NSUserDefaults standardUserDefaults] boolForKey:@"gdefault"];
	NSUInteger num_g = [opts occurrencesOfCharacter:'g'];
	while (num_g--)
		global = !global;

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

	NSUInteger numMatches = 0;
	NSUInteger numLines = 0;

	for (NSUInteger lineno = exRange.location; lineno <= NSMaxRange(exRange); lineno++) {
		NSUInteger bol = [storage locationForStartOfLine:lineno];
		NSUInteger end, eol;
		[s getLineStart:NULL end:&end contentsEnd:&eol forRange:NSMakeRange(bol, 0)];

		NSRange lineRange = NSMakeRange(bol, eol - bol);

		if (reportMatches) {
			if (global) {
				NSArray *matches = [rx allMatchesInString:s range:lineRange];
				NSUInteger nm = [matches count];
				if (nm > 0) {
					numMatches += nm;
					numLines++;
				}
			} else {
				ViRegexpMatch *match = [rx matchInString:s range:lineRange];
				if (match) {
					numMatches++;
					numLines++;
				}
			}
		} else {
			NSString *value = [s substringWithRange:lineRange];
			DEBUG(@"range %@ = %@", NSStringFromRange(lineRange), value);
			NSString *replacedText = [tform transformValue:value
							   withPattern:rx
								format:command.replacement
								global:global
								 error:&error];
			if (error) {
				MESSAGE(@"substitute failed: %@", [error localizedDescription]);
				return NO;
			}

			if (replacedText != value)
				[self replaceCharactersInRange:lineRange withString:replacedText];
		}
	}

	if (reportMatches) {
		MESSAGE(@"%lu matches on %lu lines", numMatches, numLines);
		return NO;
	} else {
		[self endUndoGroup];
		final_location = [storage locationForStartOfLine:NSMaxRange(exRange)];
		return YES;
	}
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
	final_location = [[self textStorage] firstNonBlankForLineAtLocation:range.location];

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
		[self deleteRange:range];
		final_location = [[self textStorage] firstNonBlankForLineAtLocation:destloc - 1];
	} else {
		[self deleteRange:range];
		[self insertString:content atLocation:destloc];
		final_location = [[self textStorage] firstNonBlankForLineAtLocation:destloc + range.length - 1];
	}

	return YES;
}

@end

