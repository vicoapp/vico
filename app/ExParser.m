#import "ExParser.h"
#import "ExCommand.h"
#import "ViError.h"
#import "NSScanner-additions.h"
#import "NSString-additions.h"
#import "ViCommon.h"
#import "ExCommandCompletion.h"
#import "ViFileCompletion.h"
#import "ViRegisterManager.h"
#include "logging.h"

@implementation ExParser

@synthesize map;

- (ExParser *)init
{
	if ((self = [super init]) != nil) {
		map = [ExMap defaultMap];
	}
	return self;
}

+ (ExParser *)sharedParser
{
	static ExParser *sharedParser = nil;
	if (sharedParser == nil)
		sharedParser = [[ExParser alloc] init];
	return sharedParser;
}

+ (BOOL)parseRange:(NSScanner *)scan
       intoAddress:(ExAddress **)outAddr
{
	ExAddress *addr = [[ExAddress alloc] init];

	[scan setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@""]];
	NSCharacterSet *signSet = [NSCharacterSet characterSetWithCharactersInString:@"+-^"];

	NSString *pattern;
	NSInteger lineno;

	if (![signSet characterIsMember:[scan peek]] &&
	    [scan scanInteger:&lineno])
	{
		addr.line = lineno;
		addr.type = ExAddressAbsolute;
	}
	else if ([scan scanString:@"$" intoString:nil])
	{
		addr.line = -1;
		addr.type = ExAddressAbsolute;
	}
	else if ([scan scanString:@"'" intoString:nil] && ![scan isAtEnd])
	{
		addr.mark = [[scan string] characterAtIndex:[scan scanLocation]];
		[scan inc];
		addr.type = ExAddressMark;
	}
	else if ([scan scanString:@"/" intoString:nil])
	{
		if ([scan scanUpToUnescapedCharacter:'/'
					  intoString:&pattern
					stripEscapes:NO])
			[scan expectCharacter:'/'];
		addr.type = ExAddressSearch;
		addr.pattern = pattern;
		addr.backwards = NO;
	}
	else if ([scan scanString:@"?" intoString:nil])
	{
		if ([scan scanUpToUnescapedCharacter:'?'
					  intoString:&pattern
					stripEscapes:NO])
			[scan expectCharacter:'?'];
		addr.type = ExAddressSearch;
		addr.pattern = pattern;
		addr.backwards = YES;
	}
	else if ([scan scanString:@"." intoString:nil])
	{
		addr.type = ExAddressCurrent;
	}

	[scan skipWhitespace];

	/* From nvi:
	 * Evaluate any offset.  If no address yet found, the offset
	 * is relative to ".".
	 */

	NSCharacterSet *offsetSet = [NSCharacterSet characterSetWithCharactersInString:@"+-^0123456789"];
	while (![scan isAtEnd] &&
	       [offsetSet characterIsMember:[[scan string] characterAtIndex:[scan scanLocation]]])
	{
		if (addr.type == ExAddressNone)
			addr.type = ExAddressRelative;

		/* From nvi
		 * Evaluate an offset, defined as:
		 *
		 *		[+-^<blank>]*[<blank>]*[0-9]*
		 *
		 * The rough translation is any number of signs, optionally
		 * followed by numbers, or a number by itself, all <blank>
		 * separated.
		 *
		 * !!!
		 * All address offsets were additive, e.g. "2 2 3p" was the
		 * same as "7p", or, "/ZZZ/ 2" was the same as "/ZZZ/+2".
		 * Note, however, "2 /ZZZ/" was an error.  It was also legal
		 * to insert signs without numbers, so "3 - 2" was legal, and
		 * equal to 4.
		 *
		 * !!!
		 * Offsets were historically permitted for any line address,
		 * e.g. the command "1,2 copy 2 2 2 2" copied lines 1,2 after
		 * line 8.
		 *
		 * !!!
		 * Offsets were historically permitted for search commands,
		 * and handled as addresses: "/pattern/2 2 2" was legal, and
		 * referenced the 6th line after pattern.
		 */

		BOOL has_sign = NO;
		unichar sign = [[scan string] characterAtIndex:[scan scanLocation]];
		if ([signSet characterIsMember:sign]) {
			[scan inc];
			has_sign = YES;
		} else
			sign = '+';

		int offset = 0;
		if (![scan scanInt:&offset]) {
			if (!has_sign)
				break;
			offset = 1;
		}

		if (sign != '+')
			offset = -offset;
		addr.offset += offset;

		[scan skipWhitespace];
	}

	if (outAddr)
		*outAddr = addr;
	return addr.type != ExAddressNone;
}


// FIXME: should handle more than two addresses (discard)

+ (int)parseRange:(NSScanner *)scan
      intoAddress:(ExAddress **)addr1
     otherAddress:(ExAddress **)addr2
{
        /* From nvi:
         * Parse comma or semi-colon delimited line specs.
         *
         * Semi-colon delimiters update the current address to be the last
         * address.  For example, the command
         *
         *      :3;/pattern/ecp->cp
         *
         * will search for pattern from line 3.  In addition, if ecp->cp
         * is not a valid command, the current line will be left at 3, not
         * at the original address.
         *
         * Extra addresses are discarded, starting with the first.
         *
         * !!!
         * If any addresses are missing, they default to the current line.
         * This was historically true for both leading and trailing comma
         * delimited addresses as well as for trailing semicolon delimited
         * addresses.  For consistency, we make it true for leading semicolon
         * addresses as well.
         */

        //enum { ADDR_FOUND, ADDR_FOUND2, ADDR_NEED, ADDR_NONE } state;
	int naddr = 0;
	//state = ADDR_NONE;

	if ([scan peek] == '%') {
		/* From nvi:
		 * !!!
		 * A percent character addresses all of the lines in
		 * the file.  Historically, it couldn't be followed by
		 * any other address.  We do it as a text substitution
		 * for simplicity.  POSIX 1003.2 is expected to follow
		 * this practice.
		 *
		 * If it's an empty file, the first line is 0, not 1.
		 */
		[scan inc];

		*addr1 = [[ExAddress alloc] init];
		(*addr1).type = ExAddressAbsolute;
		(*addr1).line = 1;

		*addr2 = [[ExAddress alloc] init];
		(*addr2).type = ExAddressAbsolute;
		(*addr2).line = -1;

		// FIXME: check for more addresses (which is an error)
		return 2;
	}

	if (![ExParser parseRange:scan intoAddress:addr1])
		return naddr;
	++naddr;

	if ([scan isAtEnd])
		return naddr;
	else if ([scan peek] == ',')
		[scan inc];
	else if ([scan peek] == ';')
		[scan inc];
	else
		return naddr;

	if (![ExParser parseRange:scan intoAddress:addr2])
		return -1;
	++naddr;

	return naddr;
}

- (ExCommand *)parse:(NSString *)string
	       caret:(NSInteger)completionLocation
	  completion:(id<ViCompletionProvider> *)completionProviderPtr
	       range:(NSRange *)completionRangePtr
               error:(NSError **)outError
{
	DEBUG(@"parsing [%@]", string);
	NSScanner *scan = [NSScanner scannerWithString:string];

	// No completion of address ranges
	if (completionProviderPtr)
		*completionProviderPtr = nil;
	if (completionRangePtr)
		*completionRangePtr = NSMakeRange(NSNotFound, 0);

	/* from nvi:
	 * !!!
	 * permit extra colons at the start of the line.  historically,
	 * ex/vi allowed a single extra one.  it's simpler not to count.
	 * the stripping is done here because, historically, any command
	 * could have preceding colons, e.g. ":g/pattern/:p" worked.
	 */
	NSCharacterSet *colonSet = [NSCharacterSet characterSetWithCharactersInString:@":"];
	NSMutableCharacterSet *whitespaceAndColonSet = [NSMutableCharacterSet whitespaceCharacterSet];
	[whitespaceAndColonSet formUnionWithCharacterSet:colonSet];

	[scan scanCharactersFromSet:colonSet intoString:nil];

	/* From nvi:
	 * Command lines that start with a double-quote are comments.
	 *
	 * !!!
	 * Historically, there was no escape or delimiter for a comment, e.g.
	 * :"foo|set was a single comment and nothing was output.  Since nvi
	 * permits users to escape <newline> characters into command lines, we
	 * have to check for that case.
	 */
	if ([scan scanString:@"\"" intoString:nil]) {
		[scan scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:nil];
		return [self parse:[string substringFromIndex:[scan scanLocation]]
			     caret:completionLocation
			completion:completionProviderPtr
			     range:completionRangePtr
			     error:outError];
	}

	[scan skipWhitespace];

	// FIXME: need to return whether comma or semicolon was used
	ExAddress *addr1 = nil, *addr2 = nil;
	int naddr = [ExParser parseRange:scan intoAddress:&addr1 otherAddress:&addr2];

	if (naddr < 0) {
		if (outError)
			*outError = [ViError errorWithFormat:@"Invalid address"];
		return nil;
	}

        /* Skip whitespace and colons. */
	[scan scanCharactersFromSet:whitespaceAndColonSet intoString:nil];

	/*
	 * If no command, ex does the last specified of p, l, or #, and vi
	 * moves to the line.  Otherwise, determine the length of the command
	 * name by looking for the first non-alphabetic character.  (There
	 * are a few non-alphabetic characters in command names, but they're
	 * all single character commands.)  This isn't a great test, because
	 * it means that, for the command ":e +cut.c file", we'll report that
	 * the command "cut" wasn't known.  However, it makes ":e+35 file" work
	 * correctly.
	 *
	 * !!!
	 * Historically, lines with multiple adjacent (or <blank> separated)
	 * command separators were very strange.  For example, the command
	 * |||<carriage-return>, when the cursor was on line 1, displayed
	 * lines 2, 3 and 5 of the file.  In addition, the command "   |  "
	 * would only display the line after the next line, instead of the
	 * next two lines.  No ideas why.  It worked reasonably when executed
	 * from vi mode, and displayed lines 2, 3, and 4, so we do a default
	 * command for each separator.
	 */

	// if (/* address is not terminated, ie a search address without terminating /, or a mark address without the name */) {
	//   don't use command completion
	// }

	NSString *name = nil;
	ExMapping *mapping = nil;
	ExCommand *command = nil;

	unichar ch;
	if ([scan isAtEnd] || (ch = [scan peek]) == '|' || ch == '\n' || ch == '"') {
		/* default command */
		name = @"#";
		if (completionLocation == [scan scanLocation]) {
			if (completionProviderPtr)
				*completionProviderPtr = [[ExCommandCompletion alloc] init];
			if (completionRangePtr)
				*completionRangePtr = NSMakeRange([scan scanLocation], 0);
			return nil;
		}
	} else {
		NSUInteger nameStart = [scan scanLocation];
		NSCharacterSet *singleCharCommandSet = [NSCharacterSet characterSetWithCharactersInString:@"!#&*<=>@~"];
		if ([singleCharCommandSet characterIsMember:ch]) {
			name = [NSString stringWithCharacters:&ch length:1];
			[scan inc];
		} else
			[scan scanCharactersFromSet:[NSCharacterSet letterCharacterSet] intoString:&name];
		NSUInteger nameEnd = [scan scanLocation];
		if (completionLocation >= nameStart && completionLocation <= nameEnd) {
			if (completionProviderPtr)
				*completionProviderPtr = [[ExCommandCompletion alloc] init];
			if (completionRangePtr)
				*completionRangePtr = NSMakeRange(nameStart, completionLocation - nameStart);
			return nil;
		}
	}

	mapping = [map lookup:name withScope:nil];
	if (mapping == NULL) {
		if (outError)
			*outError = [ViError errorWithFormat:@"The %@ command is unknown", name];
		return nil;
	}

	BOOL allowRange = ([mapping.syntax occurrencesOfCharacter:'r'] > 0);
	if (naddr > 0 && !allowRange) {
		if (outError)
			*outError = [ViError message:@"Range not allowed"];
		return nil;
	}

	command = [[ExCommand alloc] initWithMapping:mapping];
	command.naddr = naddr;

	/* Set default addresses. */
	if (allowRange) {
		if (naddr == 0) {
			if ([mapping.syntax occurrencesOfCharacter:'%']) {
				/*
				 * Default to whole file.
				 */
				addr1 = [[ExAddress alloc] init];
				addr1.type = ExAddressAbsolute;
				addr1.line = 0;
				addr1.offset = 0;

				addr2 = [[ExAddress alloc] init];
				addr2.type = ExAddressAbsolute;
				addr2.line = -1;	/* last line */
				addr2.offset = 0;
			} else {
				/*
				 * Default to current line.
				 */
				addr1 = [[ExAddress alloc] init];
				addr1.type = ExAddressCurrent;
				addr2 = [addr1 copy];
			}
		} else if (naddr == 1) {
			addr2 = [addr1 copy];
		}
	} else {
		addr1 = nil;
		addr2 = nil;
	}

	/*
	 * Special case: < and > commands can be given an implicit count
	 * by duplicating the single character command, like >>> for a
	 * count of 3.
	 */
	if ([name isEqualToString:@">"] || [name isEqualToString:@"<"]) {
		ch = [name characterAtIndex:0];
		command.count = 1;
		while ([scan expectCharacter:ch])
			command.count++;
	}

	/*
	 * There are three normal termination cases for an ex command.  They
	 * are the end of the string (ecp->clen), or unescaped (by <literal
	 * next> characters) <newline> or '|' characters.  As we're now past
	 * possible addresses, we can determine how long the command is, so we
	 * don't have to look for all the possible terminations.  Naturally,
	 * there are some exciting special cases:
	 *
	 * 1: The bang, global, v and the filter versions of the read and
	 *    write commands are delimited by <newline>s (they can contain
	 *    shell pipes).
	 * 2: The ex, edit, next and visual in vi mode commands all take ex
	 *    commands as their first arguments.
	 * 3: The s command takes an RE as its first argument, and wants it
	 *    to be specially delimited.
	 *
	 * Historically, '|' characters in the first argument of the ex, edit,
	 * next, vi visual, and s commands didn't delimit the command.  And,
	 * in the filter cases for read and write, and the bang, global and v
	 * commands, they did not delimit the command at all.
	 *
	 * For example, the following commands were legal:
	 *
	 *	:edit +25|s/abc/ABC/ file.c
	 *	:s/|/PIPE/
	 *	:read !spell % | columnate
	 *	:global/pattern/p|l
	 *
	 * It's not quite as simple as it sounds, however.  The command:
	 *
	 *	:s/a/b/|s/c/d|set
	 *
	 * was also legal, i.e. the historic ex parser (using the word loosely,
	 * since "parser" implies some regularity of syntax) delimited the RE's
	 * based on its delimiter and not anything so irretrievably vulgar as a
	 * command syntax.
	 *
	 * Anyhow, the following code makes this all work.  First, for the
	 * special cases we move past their special argument(s).  Then, we
	 * do normal command processing on whatever is left.  Barf-O-Rama.
	 */

	BOOL allowForce = ([mapping.syntax occurrencesOfCharacter:'!'] > 0);
	BOOL wantRegexpReplacement = ([mapping.syntax occurrencesOfCharacter:'~'] > 0);
	BOOL wantRegexp = (wantRegexpReplacement || [mapping.syntax occurrencesOfCharacter:'/'] > 0);
	BOOL optionalFilter = ([mapping.syntax occurrencesOfCharacter:'f'] > 0);

	/*
	 * Move to the next non-whitespace character.  A '!'
	 * immediately following the command is eaten as a
	 * force flag.
	 */
	ch = [scan peek];
	if (ch == '!' && (!wantRegexp || allowForce || optionalFilter)) {
		if (!allowForce && !wantRegexp && !optionalFilter) {
			if (outError)
				*outError = [ViError message:@"! not allowed"];
			return nil;
		}

		if (allowForce)
			command.force = YES;
		else if (optionalFilter)
			command.filter = YES;
		[scan scanCharacter:nil];
	}

	/*
	 * Skip to start of argument.
	 * FIXME: Don't do this for the ":!" command, because ":!! -l" needs the space.
	 */
	[scan skipWhitespace];

	/*
	 * Parse a +cmd argument.
	 */
	BOOL wantPlusCommand = ([mapping.syntax occurrencesOfCharacter:'+'] > 0);
	if (wantPlusCommand && !command.filter && [scan expectCharacter:'+']) {
		/*
		 * QUOTING NOTE:
		 *
		 * The historic implementation ignored all escape characters
		 * so there was no way to put a space or newline into the +cmd
		 * field.  We do a simplistic job of fixing it by moving to the
		 * first whitespace character that isn't escaped.  The escaping
		 * characters are stripped as no longer useful.
		 */
		NSString *plus_command = nil;
		// XXX: this could be better, recursive parsing?
		if (completionLocation == [scan scanLocation]) {
			if (completionProviderPtr)
				*completionProviderPtr = [[ExCommandCompletion alloc] init];
			if (completionRangePtr)
				*completionRangePtr = NSMakeRange(completionLocation, 0);
			return nil;
		}
		if (![scan scanUpToUnescapedCharacter:' '
					   intoString:&plus_command
					 stripEscapes:YES]) {
			if (outError)
				*outError = [ViError message:@"Empty +command"];
			return nil;
		}

		command.plus_command = plus_command;
		[scan skipWhitespace];
	}

	/*
	 * Parse an optional regular expression argument (for :s, :g, :v).
	 */
	if (wantRegexp && !command.filter) {
		/*
		 * Move to the next non-whitespace character, we'll use it as
		 * the delimiter.  If the character isn't an alphanumeric or
		 * a '|', it's the delimiter, so parse it.  Otherwise, we're
		 * into something like ":s g", so use the special s command.
		 */

		unichar delimiter = [scan peek];
		if (delimiter == 0 || /* We're at the end. */
		    [[NSCharacterSet alphanumericCharacterSet] characterIsMember:delimiter] ||
		    delimiter == '|' || delimiter == '"' || delimiter == '\\') {
			// subagain?
		} else {
			[scan scanCharacter:nil];

			/*
			 * QUOTING NOTE:
			 *
			 * Backslashes quote delimiter characters for RE's.
                         * Move to the third delimiter that's not
                         * escaped (or the end of the command).
			 */
			NSString *pattern = nil;
			if ([scan scanUpToUnescapedCharacter:delimiter intoString:&pattern stripEscapes:NO] &&
			    ![scan scanCharacter:nil]) {
				return nil;
			}
			command.pattern = pattern;

			if (wantRegexpReplacement) {
				NSString *replacement = @"";
				if ([scan scanUpToUnescapedCharacter:delimiter intoString:&replacement stripEscapes:YES] &&
				    ![scan scanCharacter:nil]) {
					return nil;
				}
				command.replacement = replacement;

				NSString *options = nil;
				NSMutableCharacterSet *endSet = [NSMutableCharacterSet whitespaceCharacterSet];
				/* Make digits end the regexp options string. Allows for a count directly afterwards. */
				[endSet formUnionWithCharacterSet:[NSCharacterSet decimalDigitCharacterSet]];
				[endSet addCharactersInString:@"|\""];
				if ([scan scanUpToCharactersFromSet:endSet intoString:&options])
					command.options = options;
				[scan skipWhitespace];
			}
		}
	}

	BOOL wantRegister = ([mapping.syntax occurrencesOfCharacter:'R'] > 0);
	BOOL wantCount = ([mapping.syntax occurrencesOfCharacter:'c'] > 0);

	if (wantRegister && !command.filter) {
		/* accept numbered register only when no count allowed (:put) */
		unichar reg = [scan peek];
		if (![[NSCharacterSet decimalDigitCharacterSet] characterIsMember:reg] || !wantCount) {
			[scan scanCharacter:nil];
			command.reg = reg;
			[scan skipWhitespace];
			DEBUG(@"parsed register %C", reg);
		}
	}

	if (wantCount && !command.filter) {
		/*
		 * Check for a count.  When accepting a BUFNAME, don't use "123foo" as a
		 * count, it's a buffer name.
		 */
		NSInteger count = 0;
		if ([scan scanInteger:&count]) {
			if (count == 0) {
				if (outError)
					*outError = [ViError errorWithFormat:@"Count may not be zero"];
				return nil;
			}

			DEBUG(@"parsed count %li", count);

			if (allowRange) {
				/*
                                 * If we allow a range, the count is
                                 * used as a line range offset from the
                                 * last address.
				 */
				addr1 = [addr2 copy];
				addr2.offset += count - 1;
				DEBUG(@"%@ -> %@", addr1, addr2);
			} else
				command.count = count;
		}
	}

	BOOL requireLine = ([mapping.syntax occurrencesOfCharacter:'L'] > 0);
	BOOL wantLine = (requireLine || [mapping.syntax occurrencesOfCharacter:'l'] > 0);
	if (wantLine && !command.filter) {
		if (requireLine && [scan isAtEnd]) {
			if (outError)
				*outError = [ViError message:@"Missing line address"];
			return nil;
		}

		ExAddress *line = nil;
		if (![ExParser parseRange:scan intoAddress:&line]) {
			if (outError)
				*outError = [ViError message:@"Invalid line address"];
			return nil;
		}
		DEBUG(@"parsed line address %@", line);
		command.lineAddress = line;
		[scan skipWhitespace];
	}

	BOOL allowAppend = ([mapping.syntax occurrencesOfCharacter:'>'] > 0);
	if (!command.filter && allowAppend && [scan expectCharacter:'>']) {
		if (![scan expectCharacter:'>']) {
			if (outError)
				*outError = [ViError message:@"Use >> to append"];
			return nil;
		}
		command.append = YES;
		[scan skipWhitespace];
	}

	if (optionalFilter && !command.filter && [scan expectCharacter:'!']) {
		command.filter = YES;
	}

	BOOL expandFiles = ([mapping.syntax occurrencesOfCharacter:'x'] > 0);

	NSString *arg = nil;
	BOOL allowPipes = ([mapping.syntax occurrencesOfCharacter:'|'] > 0);
	if (allowPipes || command.filter) {
		/*
		 * Next (unescaped) newline separates argument, not a pipe.
		 * Comments are also ignored.
		 */
		/*
		 * QUOTING NOTE:
		 *
		 * We use backslashes to escape <newline> characters, although
		 * this wasn't historic practice for the bang command.  It was
		 * for the global and v commands, and it's common usage when
		 * doing text insert during the command.  Escaping characters
		 * are stripped as no longer useful.
		 */
		NSUInteger pipeStart = [scan scanLocation];
		if ([scan scanUpToUnescapedCharacter:'\n'
					   intoString:&arg
					 stripEscapes:!expandFiles]) {
			[scan scanCharacter:nil]; // eat the newline
		}
		NSUInteger pipeEnd = [scan scanLocation];
		if (completionLocation >= pipeStart && completionLocation <= pipeEnd) {
			if (completionProviderPtr)
				*completionProviderPtr = [[ViFileCompletion alloc] init];
			if (completionRangePtr)
				*completionRangePtr = NSMakeRange(completionLocation, 0); // XXX: this is wrong!
			return nil;
		}
	} else {
		NSUInteger argStart = [scan scanLocation];
		if ([scan scanUpToUnescapedCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"|\""]
						 intoString:&arg
					       stripEscapes:!expandFiles]) {
			unichar endChar;
			[scan scanCharacter:&endChar]; // eat the pipe or "
			if (endChar == '|') {
				ExCommand *next;
				NSInteger nextLocation = -1;
				NSUInteger nextStart = [scan scanLocation];
				if (completionLocation >= nextStart)
					nextLocation = completionLocation - nextStart;
				next = [self parse:[string substringFromIndex:nextStart]
					     caret:nextLocation
					completion:completionProviderPtr
					     range:completionRangePtr
					     error:outError];
				if (nextLocation > -1 && completionRangePtr) // adjust for previous command
					(*completionRangePtr).location += nextStart;
				if (next == nil)
					return nil;
				command.nextCommand = next;
				DEBUG(@"next command is %@", next);
			}
		}
		NSUInteger argEnd = [scan scanLocation];

		if (completionLocation >= argStart && completionLocation <= argEnd) {
			if (completionProviderPtr) {
				if (mapping.completion == nil && expandFiles)
					*completionProviderPtr = [[ViFileCompletion alloc] init];
				else
					*completionProviderPtr = mapping.completion;
			}
			if (completionRangePtr)
				*completionRangePtr = NSMakeRange(argStart, completionLocation - argStart); // XXX: doesn't handle spaces!
			return nil;
		}
	}

	if ([arg length] > 0) {
		if (expandFiles) {
			if ((arg = [self expand:arg error:outError]) == nil)
				return nil;
		}
		command.arg = arg;
	}
	DEBUG(@"extra arg: [%@]", command.arg);

	BOOL requireExtra = ([mapping.syntax occurrencesOfCharacter:'E'] > 0);
	BOOL wantExtra = (requireExtra || [mapping.syntax occurrencesOfCharacter:'e'] > 0);
	if (command.arg && !wantExtra) {
		if (outError)
			*outError = [ViError message:@"Trailing characters"];
		return nil;
	}
	if (command.arg == nil && requireExtra) {
		if (outError)
			*outError = [ViError message:@"Missing argument"];
		return nil;
	}

	command.addr1 = addr1;
	command.addr2 = addr2;
	DEBUG(@"addr1 is %@", addr1);
	DEBUG(@"addr2 is %@", addr2);

	/*
	 * Use normal quoting and termination rules to find the end of this
	 * command.
	 *
	 * QUOTING NOTE:
	 *
	 * Historically, vi permitted ^V's to escape <newline>'s in the .exrc
	 * file.  It was almost certainly a bug, but that's what bug-for-bug
	 * compatibility means, Grasshopper.  Also, ^V's escape the command
	 * delimiters.  Literal next quote characters in front of the newlines,
	 * '|' characters or literal next characters are stripped as they're
	 * no longer useful.
	 */

	return command;
}

- (ExCommand *)parse:(NSString *)string error:(NSError **)outError
{
	return [self parse:string caret:-1 completion:NULL range:NULL error:outError];
}

- (NSString *)expand:(NSString *)string error:(NSError **)outError
{
	static NSCharacterSet *xset = nil;
	if (xset == nil)
		xset = [NSCharacterSet characterSetWithCharactersInString:@"%#"];
	if ([string rangeOfCharacterFromSet:xset].location == NSNotFound)
		return string;

	ViRegisterManager *regs = [ViRegisterManager sharedManager];
	NSMutableString *xs = [NSMutableString string];
	NSScanner *scan = [NSScanner scannerWithString:string];
	while ([scan scanUpToUnescapedCharacterFromSet:xset appendToString:xs stripEscapes:YES]) {
		unichar ch;
		[scan scanCharacter:&ch];
		NSString *rs = [regs contentOfRegister:ch];
		NSURL *url;
		if (rs == nil || (url = [NSURL URLWithString:rs]) == nil) {
			if (outError) {
				if (ch == '#')
					*outError = [ViError message:@"No alternate file name to substitute for '#'"];
				else
					*outError = [ViError message:@"Empty file name in substitution"];
			}
			return nil;
		}

		while ([scan expectCharacter:':']) {
			if (![scan scanCharacter:&ch]) {
				[xs appendString:rs];
				[xs appendString:@":"];
				return xs;
			}

			if (ch == 'p') {
				if (url)
					url = [[ViURLManager defaultManager] normalizeURL:url];
				else
					url = [[ViURLManager defaultManager] normalizeURL:[NSURL fileURLWithPath:rs]];
				rs = [url path];
				url = nil;
			} else if (ch == 'h') {
				if (url) {
					url = [url URLByDeletingLastPathComponent];
					rs = [url absoluteString];
				} else
					rs = [rs stringByDeletingLastPathComponent];
			} else if (ch == 't') {
				if (url)
					rs = [url lastPathComponent];
				else
					rs = [rs lastPathComponent];
				url = nil;
			} else if (ch == 'e') {
				if (url)
					rs = [url pathExtension];
				else
					rs = [rs pathExtension];
				url = nil;
			} else if (ch == 'r') {
				if (url) {
					url = [url URLByDeletingPathExtension];
					rs = [url absoluteString];
				} else
					rs = [rs stringByDeletingPathExtension];
			}
		}

		[xs appendString:rs];
	}
	return xs;
}

@end
