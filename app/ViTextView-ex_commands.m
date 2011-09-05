#import "ViTextView.h"
#import "ViAppController.h"
#import "ViEventManager.h"
#import "ViError.h"
#import "NSString-additions.h"
#import "ViRegisterManager.h"

@implementation ViTextView (ex_commands)

- (NSInteger)resolveExAddress:(ExAddress *)addr
		   relativeTo:(NSInteger)relline
			error:(NSError **)outError
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
			if (outError)
				*outError = [ViError errorWithFormat:@"Mark %C: not set", addr.mark];
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
	case ExAddressSearch:
	{
		if (relline < 0)
			relline = [self currentLine];

		NSString *pattern = addr.pattern;
		if ([pattern length] == 0)
			pattern = [[ViRegisterManager sharedManager] contentOfRegister:'/'];
		if ([pattern length] == 0) {
			if (outError)
				*outError = [ViError message:@"No previous search pattern"];
			return -1;
		}

		NSInteger start = [storage locationForStartOfLine:relline + (addr.backwards ? 0 : 1)];
		if (start == -1LL)
			start = [storage length];
		NSError *error = nil;
		NSRange r = [self rangeOfPattern:pattern
				    fromLocation:start
					 forward:!addr.backwards
					   error:&error];
		if (error) {
			if (outError)
				*outError = error;
			return -1;
		}

		keyManager.parser.last_search_options = (addr.backwards ? ViSearchOptionBackwards : 0);

		if (r.location == NSNotFound) {
			if (outError)
				*outError = [ViError message:@"Pattern not found"];
			return -1;
		}

		line = [storage lineNumberAtLocation:r.location];
		break;
	}
	case ExAddressNone:
	default:
		if (relline < 0)
			return -1;
		line = relline;
		break;
	}

	line += addr.offset;

	if ([storage locationForStartOfLine:line] == -1ULL) {
		if (outError)
			*outError = [ViError errorWithFormat:@"Invalid line address %li", line];
		return -1;
	}

	return line;
}

- (NSInteger)resolveExAddress:(ExAddress *)addr error:(NSError **)outError
{
	return [self resolveExAddress:addr relativeTo:-1 error:outError];
}

- (BOOL)resolveExAddresses:(ExCommand *)command
	     intoLineRange:(NSRange *)outRange
		     error:(NSError **)outError
{
	NSInteger begin_line, end_line;

	if (command.addr1 == nil || command.addr2 == nil) {
		*outRange = NSMakeRange(NSNotFound, 0);
		return YES;
	}

	begin_line = [self resolveExAddress:command.addr1 error:outError];
	if (begin_line < 0)
		return NO;
	end_line = [self resolveExAddress:command.addr2 relativeTo:begin_line error:outError];
	if (end_line < 0)
		return NO;

	if (end_line < begin_line) {
		NSInteger tmp = end_line;
		end_line = begin_line;
		begin_line = tmp;
	}

	*outRange = NSMakeRange(begin_line, end_line - begin_line);
	return YES;
}

- (NSRange)characterRangeForLineRange:(NSRange)lineRange
{
	if (lineRange.location == NSNotFound)
		return lineRange;

	ViTextStorage *storage = [self textStorage];
	NSUInteger beg = [storage locationForStartOfLine:lineRange.location];
	NSUInteger end = [storage locationForStartOfLine:NSMaxRange(lineRange)];

	/* end location should include the contents of the end_line */
	[self getLineStart:NULL end:&end contentsEnd:NULL forLocation:end];
	return NSMakeRange(beg, end - beg);
}

- (BOOL)resolveExAddresses:(ExCommand *)command
		 intoRange:(NSRange *)outRange
		     error:(NSError **)outError
{
	NSRange lineRange;
	if ([self resolveExAddresses:command intoLineRange:&lineRange error:outError] == NO)
		return NO;

	*outRange = [self characterRangeForLineRange:lineRange];
	return YES;
}

- (id)ex_bang:(ExCommand *)command
{
	if (command.naddr == 0)
		return [ViError message:@"Non-filtering version of ! not implemented"];
	[self filterRange:command.range throughCommand:command.arg]; // XXX: should return error on failure
	command.caret = final_location; // XXX: need better way to return filtered range
	return nil;
}

- (id)ex_eval:(ExCommand *)command
{
	NSString *script = [[[self textStorage] string] substringWithRange:command.range];
	NSError *error = nil;
	NuParser *parser = [[NuParser alloc] init];
	[[NSApp delegate] loadStandardModules:[parser context]];
	[parser setValue:[ViEventManager defaultManager] forKey:@"eventManager"];
	[[NSApp delegate] eval:script
		    withParser:parser
		      bindings:nil
			 error:&error];
	if (error)
		return error;
	return nil;
}

- (id)ex_substitute:(ExCommand *)command
{
	NSRange exRange = command.lineRange;

	unsigned rx_options = 0;
	NSString *opts = command.options ?: @"";
	if ([opts rangeOfString:@"i"].location != NSNotFound)
		rx_options |= ONIG_OPTION_IGNORECASE;

	BOOL reportMatches = NO;
	if ([opts rangeOfString:@"n"].location != NSNotFound)
		reportMatches = YES;

	BOOL global = [[NSUserDefaults standardUserDefaults] boolForKey:@"gdefault"];
	NSUInteger num_g = [opts occurrencesOfCharacter:'g'];
	while (num_g--)
		global = !global;

	NSString *pattern = command.pattern;
	if ([pattern length] == 0)
		pattern = [[ViRegisterManager sharedManager] contentOfRegister:'/'];
	if ([pattern length] == 0)
		return [ViError message:@"No previous search pattern"];

	NSError *error = nil;
	ViRegexp *rx = [[ViRegexp alloc] initWithString:pattern
						options:rx_options
						  error:&error];
	if (error)
		return error;

	[[ViRegisterManager sharedManager] setContent:pattern ofRegister:'/'];

	ViTextStorage *storage = [self textStorage];
	ViTransformer *tform = [[ViTransformer alloc] init];

	NSString *s = [storage string];
	DEBUG(@"ex range is %@", NSStringFromRange(exRange));

	NSUInteger numMatches = 0;
	NSUInteger numLines = 0;

	for (NSUInteger lineno = exRange.location; lineno <= NSMaxRange(exRange); lineno++) {
		NSRange lineRange = [storage rangeOfLine:lineno];

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
			if (error)
				return error;

			if (replacedText != value)
				[self replaceCharactersInRange:lineRange withString:replacedText];
		}
	}

	if (reportMatches) {
		return [NSString stringWithFormat:@"%lu matches on %lu lines", numMatches, numLines];
	} else {
		[self endUndoGroup];
		command.caret = [storage locationForStartOfLine:NSMaxRange(exRange)];
		return nil;
	}
}

- (id)ex_goto:(ExCommand *)command
{
	// XXX: What if two address given?
	[self pushCurrentLocationOnJumpList];
	command.caret = [[self textStorage] firstNonBlankForLineAtLocation:command.range.location];
	return nil;
}

- (id)ex_yank:(ExCommand *)command
{
	[self yankToRegister:command.reg range:command.range];
	return nil;
}

- (id)ex_delete:(ExCommand *)command
{
	[self cutToRegister:command.reg range:command.range];
	command.caret = [[self textStorage] firstNonBlankForLineAtLocation:command.range.location];
	return nil;
}

- (id)ex_copy:(ExCommand *)command
{
	NSInteger destline = command.line;
	if (destline > 0)
		++destline;

	NSString *content = [[[self textStorage] string] substringWithRange:command.range];
	NSInteger destloc = [[self textStorage] locationForStartOfLine:destline];
	if (destloc == -1)
		destloc = [[self textStorage] length];
	[self insertString:content atLocation:destloc];

	command.caret = [[self textStorage] firstNonBlankForLineAtLocation:destloc + [content length]];
	return nil;
}

- (id)ex_move:(ExCommand *)command
{
	NSInteger destline = command.line;

	if (destline >= command.lineRange.location && destline < NSMaxRange(command.lineRange))
		return [ViError message:@"Can't move lines into themselves"];

	if (destline > 0)
		++destline;

	NSString *content = [[[self textStorage] string] substringWithRange:command.range];
	NSInteger destloc = [[self textStorage] locationForStartOfLine:destline];
	if (destloc == -1)
		destloc = [[self textStorage] length];

	if (destloc > command.range.location) {
		[self insertString:content atLocation:destloc];
		[self deleteRange:command.range];
		command.caret = [[self textStorage] firstNonBlankForLineAtLocation:destloc - 1];
	} else {
		[self deleteRange:command.range];
		[self insertString:content atLocation:destloc];
		command.caret = [[self textStorage] firstNonBlankForLineAtLocation:destloc + command.range.length - 1];
	}

	return nil;
}

@end

