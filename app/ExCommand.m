#import "ExCommand.h"
#import "ViError.h"
#import "logging.h"

@interface ExCommand (private)
- (BOOL)parse:(NSString *)string error:(NSError **)outError;
@end

/* From nvi:
 *
 * This array maps ex command names to command functions.
 *
 * The order in which command names are listed below is important --
 * ambiguous abbreviations are resolved to be the first possible match,
 * e.g. "r" means "read", not "rewind", because "read" is listed before
 * "rewind".
 *
 * The syntax of the ex commands is unbelievably irregular, and a special
 * case from beginning to end.  Each command has an associated "syntax
 * script" which describes the "arguments" that are possible.  The script
 * syntax is as follows:
 *
 *	!		-- ! flag
 *	1		-- flags: [+-]*[pl#][+-]*
 *	2		-- flags: [-.+^]
 *	3		-- flags: [-.+^=]
 *	b		-- buffer
 *	c[01+a]		-- count (0-N, 1-N, signed 1-N, address offset)
 *	f[N#][or]	-- file (a number or N, optional or required)
 *	l		-- line
 *	S		-- string with file name expansion
 *	s		-- string
 *	W		-- word string
 *	w[N#][or]	-- word (a number or N, optional or required)
 */
static struct ex_command ex_commands[] = {
	/* C_SCROLL */
	/* C_BANG */
	{@"!",		@"ex_bang",	EX_ADDR2_NONE | EX_SECURE,
		"S",
		@"[line [,line]] ! command",
		@"filter lines through commands or run commands"},
	/* C_HASH */
	{@"#",		@"ex_number",	EX_ADDR2|EX_CLRFLAG,
		"ca1",
		@"[line [,line]] # [count] [l]",
		@"display numbered lines"},
	/* C_SUBAGAIN */
	{@"&",		@"ex_subagain",	EX_ADDR2,
		"s",
		@"[line [,line]] & [cgr] [count] [#lp]",
		@"repeat the last subsitution"},
	/* C_STAR */
	{@"*",		@"ex_at",		0,
		"b",
		@"* [buffer]",
		@"execute a buffer"},
	/* C_SHIFTL */
	{@"<",		@"ex_shiftl",	EX_ADDR2|EX_AUTOPRINT,
		"ca1",
		@"[line [,line]] <[<...] [count] [flags]",
		@"shift lines left"},
	/* C_EQUAL */
	{@"=",		@"ex_equal",	EX_ADDR1|EX_ADDR_ZERO|EX_ADDR_ZERODEF,
		"1",
		@"[line] = [flags]",
		@"display line number"},
	/* C_SHIFTR */
	{@">",		@"ex_shiftr",	EX_ADDR2|EX_AUTOPRINT,
		"ca1",
		@"[line [,line]] >[>...] [count] [flags]",
		@"shift lines right"},
	/* C_AT */
	{@"@",		@"ex_at",		EX_ADDR2,
		"b",
		@"@ [buffer]",
		@"execute a buffer"},
	/* C_APPEND */
	{@"append",	@"ex_append",	EX_ADDR1|EX_ADDR_ZERO|EX_ADDR_ZERODEF,
		"!",
		@"[line] a[ppend][!]",
		@"append input to a line"},
	/* C_ARGS */
	{@"args",	@"ex_args",	0,
		"",
		@"ar[gs]",
		@"display file argument list"},
	{@"buffer",	@"ex_buffer",	0,
		"s",
		@"b[uffer] bufname",
		@"edit another open document in the current view"},
	/* C_CHANGE */
	{@"change",	@"ex_change",	EX_ADDR2|EX_ADDR_ZERODEF,
		"!ca",
		@"[line [,line]] c[hange][!] [count]",
		@"change lines to input"},
	/* C_CD */
	{@"cd",		@"ex_cd",		0,
		"!f1o",
		@"cd[!] [directory]",
		@"change the current directory"},
	/* C_CHDIR */
	{@"chdir",	@"ex_cd",		0,
		"!f1o",
		@"chd[ir][!] [directory]",
		@"change the current directory"},
	/* C_CLOSE (vim) */
	{@"close",	@"ex_close",		0,
		"!",
		@"clo[se][!]",
		@"close the current window"},
	/* C_COPY */
	{@"copy",	@"ex_copy",	EX_ADDR2|EX_AUTOPRINT,
		"l1",
		@"[line [,line]] co[py] line [flags]",
		@"copy lines elsewhere in the file"},
	/* C_CSCOPE */
	{@"cscope",      @"ex_cscope",      0,
		"!s",
		@"cs[cope] command [args]",
		@"create a set of tags using a cscope command"},
	/*
	 * !!!
	 * Adding new commands starting with 'd' may break the delete command code
	 * in ex_cmd() (the ex parser).  Read through the comments there, first.
	 */
	/* C_DELETE */
	{@"delete",	@"ex_delete",	EX_ADDR2|EX_AUTOPRINT,
		"bca1",
		@"[line [,line]] d[elete][flags] [buffer] [count] [flags]",
		@"delete lines from the file"},
	/* C_DISPLAY */
	{@"display",	@"ex_display",	0,
		"w1r",
		@"display b[uffers] | c[onnections] | s[creens] | t[ags]",
		@"display buffers, connections, screens or tags"},
	/* C_EDIT */
	{@"edit",	@"ex_edit",	EX_NEWSCREEN,
		"f1o",
		@"[Ee][dit][!] [+cmd] [file]",
		@"begin editing another file"},
	{@"export",	@"ex_export",	0,
		"s",
		@"export var=[value]",
		@"export an environment variable"},
	/* C_EXUSAGE */
	{@"exusage",	@"ex_usage",	0,
		"w1o",
		@"[exu]sage [command]",
		@"display ex command usage statement"},
	/* C_FILE */
	{@"file",	@"ex_file",	0,
		"f1o",
		@"f[ile] [name]",
		@"display (and optionally set) file name"},
	/* C_GLOBAL */
	{@"global",	@"ex_global",	EX_ADDR2_ALL,
		"!s",
		@"[line [,line]] g[lobal][!] [;/]RE[;/] [commands]",
		@"execute a global command on lines matching an RE"},
	/* C_HELP */
	{@"help",	@"ex_help",	0,
		"",
		@"he[lp]",
		@"display help statement"},
	/* C_INSERT */
	{@"insert",	@"ex_insert",	EX_ADDR1|EX_ADDR_ZERO|EX_ADDR_ZERODEF,
		"!",
		@"[line] i[nsert][!]",
		@"insert input before a line"},
	/* C_JOIN */
	{@"join",	@"ex_join",	EX_ADDR2|EX_AUTOPRINT,
		"!ca1",
		@"[line [,line]] j[oin][!] [count] [flags]",
		@"join lines into a single line"},
	/* C_K */
	{@"k",		@"ex_mark",	EX_ADDR1,
		"w1r",
		@"[line] k key",
		@"mark a line position"},
	/* C_MOVE */
	{@"move",	@"ex_move",	EX_ADDR2|EX_AUTOPRINT,
		"l",
		@"[line [,line]] m[ove] line",
		@"move lines elsewhere in the file"},
	/* C_MARK */
	{@"mark",	@"ex_mark",	EX_ADDR1,
		"w1r",
		@"[line] ma[rk] key",
		@"mark a line position"},
	/* C_MAP */
	{@"map",		@"ex_map",		0,
		"!W",
		@"map[!] [keys replace]",
		@"map input or commands to one or more keys"},
	/* C_NEXT */
	{@"next",	@"ex_next",	EX_NEWSCREEN,
		"!fN",
		@"[Nn][ext][!] [+cmd] [file ...]",
		@"edit (and optionally specify) the next file"},
	{@"new",	@"ex_new",	0,
		"f1o",
		@"new [file]",
		@"edit a new file in a new horizontal split"},
	/* C_NUMBER */
	{@"number",	@"ex_number",	EX_ADDR2|EX_CLRFLAG,
		"ca1",
		@"[line [,line]] nu[mber] [count] [l]",
		@"change display to number lines"},
	/* C_OPEN */
	{@"open",	@"ex_open",	EX_ADDR1,
		"s",
		@"[line] o[pen] [/RE/] [flags]",
		@"enter \"open\" mode (not implemented)"},
	/* C_PRINT */
	{@"print",	@"ex_pr",		EX_ADDR2|EX_CLRFLAG,
		"ca1",
		@"[line [,line]] p[rint] [count] [#l]",
		@"display lines"},
	/* C_PRESERVE */
	{@"preserve",	@"ex_preserve",	0,
		"",
		@"pre[serve]",
		@"preserve an edit session for recovery"},
	/* C_PREVIOUS */
	{@"previous",	@"ex_prev",	EX_NEWSCREEN,
		"!",
		@"[Pp]rev[ious][!]",
		@"edit the previous file in the file argument list"},
	/* C_PUT */
	{@"put",		@"ex_put",	
		EX_ADDR1|EX_AUTOPRINT|EX_ADDR_ZERO|EX_ADDR_ZERODEF,
		"b",
		@"[line] pu[t] [buffer]",
		@"append a cut buffer to the line"},
	/* C_PWD */
	{@"pwd",		@"ex_pwd",	
		0,
		"",
		@"pw[d]",
		@"Print the curreny directory name"},
	/* C_QUIT */
	{@"quit",	@"ex_quit",	0,
		"!",
		@"q[uit][!]",
		@"exit ex/vi"},
	/* C_READ */
	{@"read",	@"ex_read",	EX_ADDR1|EX_ADDR_ZERO|EX_ADDR_ZERODEF,
		"s",
		@"[line] r[ead] [!cmd | [file]]",
		@"append input from a command or file to the line"},
	/* C_RECOVER */
	{@"recover",	@"ex_recover",	0,
		"!f1r",
		@"recover[!] file",
		@"recover a saved file"},
	/* C_REWIND */
	{@"rewind",	@"ex_rew",		0,
		"!",
		@"rew[ind][!]",
		@"re-edit all the files in the file argument list"},
	/*
	 * !!!
	 * Adding new commands starting with 's' may break the substitute command code
	 * in ex_cmd() (the ex parser).  Read through the comments there, first.
	 */
	/* C_SUBSTITUTE */
	{@"s",		@"ex_s",		EX_ADDR2,
		"s",
		@"[line [,line]] s [[/;]RE[/;]repl[/;] [cgr] [count] [#lp]]",
		@"substitute on lines matching an RE"},
	{@"sbuffer",	@"ex_buffer",	0,
		"s",
		@"sb[uffer] bufname",
		@"split view and edit another open document"},
	/* C_SET */
	{@"set",		@"ex_set",		0,
		"wN",
		@"se[t] [option[=[value]]...] [nooption ...] [option? ...] [all]",
		@"set options (use \":set all\" to see all options)"},
	{@"setfiletype",	@"ex_setfiletype",	0,
		"w1r",
		@"setf[iletype] syntax name",
		@"set the file type (eg, 'source.perl' or just 'perl')"},
	/* C_SHELL */
	{@"shell",	@"ex_shell",	EX_SECURE,
		"",
		@"sh[ell]",
		@"suspend editing and run a shell"},
	{@"split",	@"ex_split",	0,
		"f1o",
		@"sp[lit] file",
		@"Split current view horizontally."},
	/* C_T */
	{@"t",		@"ex_copy",	EX_ADDR2|EX_AUTOPRINT,
		"l1",
		@"[line [,line]] t line [flags]",
		@"copy lines elsewhere in the file"},
	/* C_TAG */
	{@"tag",		@"ex_tag_push",	EX_NEWSCREEN,
		"!w1o",
		@"[Tt]a[g][!] [string]",
		@"edit the file containing the tag"},
	/* C_TAGNEXT */
	{@"tagnext",	@"ex_tag_next",	0,
		"!",
		@"tagn[ext][!]",
		@"move to the next tag"},
	/* C_TAGPOP */
	{@"tagpop",	@"ex_tag_pop",	0,
		"!w1o",
		@"tagp[op][!] [number | file]",
		@"return to the previous group of tags"},
	/* C_TAGPREV */
	{@"tagprev",	@"ex_tag_prev",	0,
		"!",
		@"tagpr[ev][!]",
		@"move to the previous tag"},
	/* C_TAGTOP */
	{@"tagtop",	@"ex_tag_top",	0,
		"!",
		@"tagt[op][!]",
		@"discard all tags"},
	{@"tbuffer",	@"ex_buffer",	0,
		"s",
		@"tb[uffer] bufname",
		@"edit another open document in a new tab"},
	/* C_UNDO */
	{@"undo",	@"ex_undo",	EX_AUTOPRINT,
		"",
		@"u[ndo]",
		@"undo the most recent change"},
	/* C_UNMAP */
	{@"unmap",	@"ex_unmap",	0,
		"!w1r",
		@"unm[ap][!] word",
		@"delete an input or command map"},
	/* C_V */
	{@"v",		@"ex_v",		EX_ADDR2_ALL,
		"s",
		@"[line [,line]] v [;/]RE[;/] [commands]",
		@"execute a global command on lines NOT matching an RE"},
	{@"vbuffer",	@"ex_buffer",	0,
		"s",
		@"vb[uffer] bufname",
		@"split view vertically and edit another open document"},
	/* C_VERSION */
	{@"version",	@"ex_version",	0,
		"",
		@"version",
		@"display the program version information"},
	/* C_VIUSAGE */
	{@"viusage",	@"ex_viusage",	0,
		"w1o",
		@"[viu]sage [key]",
		@"display vi key usage statement"},
	{@"vnew",	@"ex_vnew",	0,
		"f1o",
		@"vne[w] [file]",
		@"edit a new file in a new vertical split"},
	{@"vsplit",	@"ex_vsplit",	0,
		"f1o",
		@"vsp[lit] file",
		@"Split current view vertically."},
	/* C_WRITE */
	{@"write",	@"ex_write",	EX_ADDR2_ALL|EX_ADDR_ZERODEF,
		"!s",
		@"[line [,line]] w[rite][!] [ !cmd | [>>] [file]]",
		@"write the file"},
	/* C_WN */
	{@"wn",		@"ex_wn",		EX_ADDR2_ALL|EX_ADDR_ZERODEF,
		"!s",
		@"[line [,line]] wn[!] [>>] [file]",
		@"write the file and switch to the next file"},
	/* C_WQ */
	{@"wq",		@"ex_wq",		EX_ADDR2_ALL|EX_ADDR_ZERODEF,
		"!s",
		@"[line [,line]] wq[!] [>>] [file]",
		@"write the file and exit"},
	/* C_XIT */
	{@"xit",		@"ex_xit",		EX_ADDR2_ALL|EX_ADDR_ZERODEF,
		"!f1o",
		@"[line [,line]] x[it][!] [file]",
		@"exit"},
	/* C_YANK */
	{@"yank",	@"ex_yank",	EX_ADDR2,
		"bca",
		@"[line [,line]] ya[nk] [buffer] [count]",
		@"copy lines to a cut buffer"},
	/* C_Z */
	{@"z",		@"ex_z",		EX_ADDR1,
		"3c01",
		@"[line] z [-|.|+|^|=] [count] [flags]",
		@"display different screens of the file"},
	/* C_SUBTILDE */
	{@"~",		@"ex_subtilde",	EX_ADDR2,
		"s",
		@"[line [,line]] ~ [cgr] [count] [#lp]",
		@"replace previous RE with previous replacement string,"},
	{NULL},
};

static struct ex_command *
ex_cmd_find(NSString *cmd)
{
	int i;
	for (i = 0; ex_commands[i].name; i++) {
		if ([ex_commands[i].name characterAtIndex:0] > [cmd characterAtIndex:0])
			return NULL;

		if ([ex_commands[i].name compare:cmd
					 options:NSLiteralSearch
					   range:NSMakeRange(0, [cmd length])] == NSOrderedSame) {
			return &ex_commands[i];
		}
	}

	return NULL;
}

@implementation ExCommand

@synthesize naddr;
@synthesize flags;
@synthesize name;
@synthesize command;
@synthesize filename;
@synthesize string = arg_string;
@synthesize plus_command;
@synthesize words;

- (struct ex_address *)addr1
{
	return &addr1;
}

- (struct ex_address *)addr2
{
	return &addr2;
}

- (struct ex_address *)line
{
	return &line;
}

- (NSString *)method
{
	return command ? command->method : nil;
}

- (ExCommand *)init
{
	self = [super init];
	return self;
}

- (ExCommand *)initWithString:(NSString *)string
{
	self = [super init];
	if (self) {
		if (![self parse:string error:nil])
			return nil;
	}
	return self;
}

+ (BOOL)parseRange:(NSScanner *)scan
       intoAddress:(struct ex_address *)addr
{
	addr->type = EX_ADDR_NONE;
	addr->offset = 0;

	[scan setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@""]];
	NSCharacterSet *signSet = [NSCharacterSet characterSetWithCharactersInString:@"+-^"];

	if (![signSet characterIsMember:[[scan string] characterAtIndex:[scan scanLocation]]] &&
	    [scan scanInt:&addr->addr.abs.line])
	{
		addr->addr.abs.column = 1;
		addr->type = EX_ADDR_ABS;
	}
	else if ([scan scanString:@"$" intoString:nil])
	{
		addr->addr.abs.line = -1;
		addr->addr.abs.column = 1;
		addr->type = EX_ADDR_ABS;
	}
	else if ([scan scanString:@"'" intoString:nil] && ![scan isAtEnd])
	{
		addr->addr.mark = [[scan string] characterAtIndex:[scan scanLocation]];
		[scan setScanLocation:[scan scanLocation] + 1];
		addr->type = EX_ADDR_MARK;
	}
	else if ([scan scanString:@"/" intoString:nil])
	{
		// FIXME: doesn't handle escaped '/'
		[scan scanUpToString:@"/" intoString:&addr->addr.search.pattern];
		[scan scanString:@"/" intoString:nil];
		addr->type = EX_ADDR_SEARCH;
		addr->addr.search.backwards = NO;
	}
	else if ([scan scanString:@"?" intoString:nil])
	{
		// FIXME: doesn't handle escaped '?'
		[scan scanUpToString:@"?" intoString:&addr->addr.search.pattern];
		[scan scanString:@"?" intoString:nil];
		addr->addr.search.backwards = YES;
		addr->type = EX_ADDR_SEARCH;
	}
	else if ([scan scanString:@"." intoString:nil])
	{
		addr->type = EX_ADDR_CURRENT;
	}

        /* Skip whitespace. */
	[scan scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];

	/* From nvi:
	 * Evaluate any offset.  If no address yet found, the offset
	 * is relative to ".".
	 */

	NSCharacterSet *offsetSet = [NSCharacterSet characterSetWithCharactersInString:@"+-^0123456789"];
	while (![scan isAtEnd] &&
	       [offsetSet characterIsMember:[[scan string] characterAtIndex:[scan scanLocation]]])
	{
		if (addr->type == EX_ADDR_NONE)
		{
			addr->type = EX_ADDR_RELATIVE;
		}

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
		if ([signSet characterIsMember:sign])
		{
			[scan setScanLocation:[scan scanLocation] + 1];
			has_sign = YES;
		}
		else
			sign = '+';

		int offset = 0;
		if (![scan scanInt:&offset])
		{
			if (!has_sign)
				break;
			offset = 1;
		}

		if (sign != '+')
			offset = -offset;
		addr->offset += offset;

		/* Skip whitespace. */
		[scan scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];
	}

	return addr->type != EX_ADDR_NONE;
}


// FIXME: should handle more than two addresses (discard)

+ (int)parseRange:(NSScanner *)scan
      intoAddress:(struct ex_address *)addr1
     otherAddress:(struct ex_address *)addr2
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

	if ([[scan string] characterAtIndex:[scan scanLocation]] == '%')
	{
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
		[scan setScanLocation:[scan scanLocation] + 1];

		addr1->type = EX_ADDR_ABS;
		addr1->addr.abs.line = 1;
		addr1->addr.abs.column = 1;
		addr1->offset = 0;

		addr2->type = EX_ADDR_ABS;
		addr2->addr.abs.line = -1;
		addr2->addr.abs.column = 1;
		addr2->offset = 0;

		// FIXME: check for more addresses (which is an error)
		return 2;
	}

	if (![ExCommand parseRange:scan intoAddress:addr1])
		return naddr;
	++naddr;

	if ([scan isAtEnd])
		return naddr;
	else if ([[scan string] characterAtIndex:[scan scanLocation]] == ',')
		[scan setScanLocation:[scan scanLocation] + 1];
	else if ([[scan string] characterAtIndex:[scan scanLocation]] == ';')
		[scan setScanLocation:[scan scanLocation] + 1];
	else
		return naddr;

	if (![ExCommand parseRange:scan intoAddress:addr2])
		return -1;
	++naddr;

	return naddr;
}

- (BOOL)parse:(NSString *)string error:(NSError **)outError
{
	NSScanner *scan = [NSScanner scannerWithString:string];

        /* From nvi:
         * !!!
         * Permit extra colons at the start of the line.  Historically,
         * ex/vi allowed a single extra one.  It's simpler not to count.
         * The stripping is done here because, historically, any command
         * could have preceding colons, e.g. ":g/pattern/:p" worked.
         */
	NSCharacterSet *colonSet = [NSCharacterSet characterSetWithCharactersInString:@":"];
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
	if ([scan scanString:@"\"" intoString:nil])
	{
		[scan scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:nil];
		return [self parse:[string substringFromIndex:[scan scanLocation]] error:outError];
	}

        /* Skip whitespace. */
	[scan scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];

	if ([scan isAtEnd])
		return YES;

	// FIXME: need to return whether comma or semicolon was used
	naddr = [ExCommand parseRange:scan intoAddress:&addr1 otherAddress:&addr2];

	if (naddr < 0)
		return NO;

        /* Skip whitespace and colons. */
	[scan scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];
	[scan scanCharactersFromSet:colonSet intoString:nil];

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

	unichar ch;
	if ([scan isAtEnd] || (ch = [string characterAtIndex:[scan scanLocation]]) == '|' || ch == '\n')
	{
		/* default command */
		name = @"#";
		command = ex_cmd_find(name);
		return YES;
	}

	NSCharacterSet *singleCharCommandSet = [NSCharacterSet characterSetWithCharactersInString:@"\004!#&*<=>@~"];

	if ([singleCharCommandSet characterIsMember:ch])
	{
		name = [NSString stringWithCharacters:&ch length:1];
		[scan setScanLocation:[scan scanLocation] + 1];
	}
	else
	{
		[scan scanCharactersFromSet:[NSCharacterSet letterCharacterSet] intoString:&name];
	}

	command = ex_cmd_find(name);
	if (command == NULL) {
		if (outError)
			*outError = [ViError errorWithFormat:@"The %@ command is unknown.", name];
		return NO;
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
	if ([command->name isEqualToString:@"edit"] ||
	    [command->name isEqualToString:@"ex"] ||
	    [command->name isEqualToString:@"next"] ||
	    [command->name isEqualToString:@"vi"])
	{
		/*
		 * Move to the next non-whitespace character.  A '!'
		 * immediately following the command is eaten as a
		 * force flag.
		 */
		if ([scan scanString:@"!" intoString:nil])
			flags |= E_C_FORCE;
		[scan scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];

		if ([scan scanString:@"+" intoString:nil])
		{
			// FIXME: doesn't handle escaped whitespace
			/*
			 * QUOTING NOTE:
			 *
			 * The historic implementation ignored all escape characters
			 * so there was no way to put a space or newline into the +cmd
			 * field.  We do a simplistic job of fixing it by moving to the
			 * first whitespace character that isn't escaped.  The escaping
			 * characters are stripped as no longer useful.
			 */
			[scan scanCharactersFromSet:[[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet]
					 intoString:&plus_command];
		}
	}
	else if ([command->name isEqualToString:@"!"] ||
		 [command->name isEqualToString:@"global"] ||
		 [command->name isEqualToString:@"v"])
	{
		/*
		 * QUOTING NOTE:
		 *
		 * We use backslashes to escape <newline> characters, although
		 * this wasn't historic practice for the bang command.  It was
		 * for the global and v commands, and it's common usage when
		 * doing text insert during the command.  Escaping characters
		 * are stripped as no longer useful.
		 */
		arg_string = [[scan string] substringFromIndex:[scan scanLocation]];
		goto addr_verify;
	}
	else if ([command->name isEqualToString:@"read"] ||
		 [command->name isEqualToString:@"write"])
	{
		/*
		 * For write commands, if the next character is a <blank>, and
		 * the next non-blank character is a '!', it's a filter command
		 * and we want to eat everything up to the <newline>.  For read
		 * commands, if the next non-blank character is a '!', it's a
		 * filter command and we want to eat everything up to the next
		 * <newline>.  Otherwise, we're done.
		 */
		;
	}
	else if ([command->name isEqualToString:@"s"])
	{
		/*
		 * Move to the next non-whitespace character, we'll use it as
		 * the delimiter.  If the character isn't an alphanumeric or
		 * a '|', it's the delimiter, so parse it.  Otherwise, we're
		 * into something like ":s g", so use the special s command.
		 */
		[scan scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];

		if ([scan isAtEnd])
			goto usage;

		unichar delimiter = [string characterAtIndex:[scan scanLocation]];
		[scan setScanLocation:[scan scanLocation] + 1];

		if ([[NSCharacterSet alphanumericCharacterSet] characterIsMember:delimiter] || delimiter == '|') {
			// subagain?
		} else if (![scan isAtEnd]) {
			/*
			 * QUOTING NOTE:
			 *
			 * Backslashes quote delimiter characters for RE's.
			 * The backslashes are NOT removed since they'll be
			 * used by the RE code.  Move to the third delimiter
			 * that's not escaped (or the end of the command).
			 */
		}
	}

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

	// ...

	/*
	 * Set the default addresses.  It's an error to specify an address for
	 * a command that doesn't take them.  If two addresses are specified
	 * for a command that only takes one, lose the first one.  Two special
	 * cases here, some commands take 0 or 2 addresses.  For most of them
	 * (the E_ADDR2_ALL flag), 0 defaults to the entire file.  For one
	 * (the `!' command, the E_ADDR2_NONE flag), 0 defaults to no lines.
	 *
	 * Also, if the file is empty, some commands want to use an address of
	 * 0, i.e. the entire file is 0 to 0, and the default first address is
	 * 0.  Otherwise, an entire file is 1 to N and the default line is 1.
	 * Note, we also add the E_ADDR_ZERO flag to the command flags, for the
	 * case where the 0 address is only valid if it's a default address.
	 *
	 * Also, set a flag if we set the default addresses.  Some commands
	 * (ex: z) care if the user specified an address or if we just used
	 * the current cursor.
	 */
	switch (command->flags & (EX_ADDR1 | EX_ADDR2 | EX_ADDR2_ALL | EX_ADDR2_NONE))
	{
	case EX_ADDR1:				/* One address: */
		switch (naddr)
		{
		case 0:                         /* Default cursor/empty file. */
			naddr = 1;
			addr1.type = EX_ADDR_CURRENT;
			break;
		case 1:
			break;
		case 2:				/* Lose the first address. */
			naddr = 1;
			addr1 = addr2;
			break;
		}
		break;
	case EX_ADDR2_NONE:			/* Zero/two addresses: */
		if (naddr == 0)
			break;
		goto two_addr;
		break;
	case EX_ADDR2_ALL:			/* Zero/two addresses: */
		if (naddr == 0)			/* Default entire/empty file. */
		{
			naddr = 2;
			addr1.type = EX_ADDR_ABS;
			addr1.addr.abs.line = 1;
			addr1.addr.abs.column = 1;
			addr1.offset = 0;
			addr2.type = EX_ADDR_ABS;
			addr2.addr.abs.line = -1;	/* last line */
			addr2.addr.abs.column = 1;
			addr2.offset = 0;
		}
		/* FALLTHROUGH */
	case EX_ADDR2:				/* Two addresses: */
two_addr:	switch (naddr)
		{
		case 0:                         /* Default cursor/empty file. */
			naddr = 1;
			addr1.type = EX_ADDR_CURRENT;
			break;
		case 1:				/* Default to first address. */
			break;
		case 2:
			break;
		}
		break;
	default:
		if (naddr > 0)                  /* Error. */
			goto usage;
		break;
	}

	line.type = EX_ADDR_NONE;

	/* Go through the command's syntax definition and parse parameters.
	 */
	const char *p;
	for (p = command->syntax; p && *p; p++)
	{
		/*
		 * The force flag is sensitive to leading whitespace, i.e.
		 * "next !" is different from "next!".  Handle it before
		 * skipping leading <blank>s.
		 */
		if (*p == '!')
		{
			if (![scan isAtEnd] &&
			    [string characterAtIndex:[scan scanLocation]] == '!')
			{
				[scan setScanLocation:[scan scanLocation] + 1];
				flags |= E_C_FORCE;
			}
			continue;
		}

		/* Skip leading <blank>s. */
		[scan scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];
		if ([scan isAtEnd])
			break;

		switch (*p)
		{
		case '1':				/* +, -, #, l, p */
			/*
			 * !!!
			 * Historically, some flags were ignored depending
			 * on where they occurred in the command line.  For
			 * example, in the command, ":3+++p--#", historic vi
			 * acted on the '#' flag, but ignored the '-' flags.
			 * It's unambiguous what the flags mean, so we just
			 * handle them regardless of the stupidity of their
			 * location.
			 */
			while (![scan isAtEnd])
			{
				unichar c = [string characterAtIndex:[scan scanLocation]];
				switch (c)
				{
				case '+':
					flagoff++;
					break;
				case '-':
				case '^':
					flagoff--;
					break;
				case '#':
					flags |= E_C_HASH;
					break;
				case 'l':
					flags |= E_C_LIST;
					break;
				case 'p':
					flags |= E_C_PRINT;
					break;
				default:
					goto end_case1;
				}
				[scan setScanLocation:[scan scanLocation] + 1];
			}
end_case1:		break;
		case '2':				/* -, ., +, ^ */
		case '3':				/* -, ., +, ^, = */
			while (![scan isAtEnd])
			{
				unichar c = [string characterAtIndex:[scan scanLocation]];
				switch (c)
				{
				case '-':
					flags |= E_C_DASH;
					break;
				case '.':
					flags |= E_C_DOT;
					break;
				case '+':
					flags |= E_C_PLUS;
					break;
				case '^':
					flags |= E_C_CARAT;
					break;
				case '=':
					if (*p == '3') {
						flags |= E_C_EQUAL;
						break;
					}
					/* FALLTHROUGH */
				default:
					goto end_case23;
				}
				[scan setScanLocation:[scan scanLocation] + 1];
			}
end_case23:		break;
		case 'b':				/* buffer */
			/*
			 * !!!
			 * Historically, "d #" was a delete with a flag, not a
			 * delete into the '#' buffer.  If the current command
			 * permits a flag, don't use one as a buffer.  However,
			 * the 'l' and 'p' flags were legal buffer names in the
			 * historic ex, and were used as buffers, not flags.
			 */
			{
				unichar c = [string characterAtIndex:[scan scanLocation]];
				if ((c == '+' || c == '-' || c == '^' || c == '#') &&
				    strchr(p, '1') != NULL)
					break;
	
				/*
				 * !!!
				 * Digits can't be buffer names in ex commands, or the
				 * command "d2" would be a delete into buffer '2', and
				 * not a two-line deletion.
				 */
				if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:c]) {
					buffer = c;
					flags |= E_C_BUFFER;
					[scan setScanLocation:[scan scanLocation] + 1];
				}
			}
			break;
		case 'c':				/* count [01+a] */
#if 0
			++p;
			/* Validate any signed value. */
			if (!isdigit(*ecp->cp) && (*p != '+' ||
			    (*ecp->cp != '+' && *ecp->cp != '-')))
				break;
			/* If a signed value, set appropriate flags. */
			if (*ecp->cp == '-')
				FL_SET(ecp->iflags, E_C_COUNT_NEG);
			else if (*ecp->cp == '+')
				FL_SET(ecp->iflags, E_C_COUNT_POS);
			if ((nret =
			    nget_slong(&ltmp, ecp->cp, &t, 10)) != NUM_OK) {
				ex_badaddr(sp, NULL, A_NOTSET, nret);
				goto err;
			}
			if (ltmp == 0 && *p != '0') {
				msgq(sp, M_ERR, "083|Count may not be zero");
				goto err;
			}
			ecp->clen -= (t - ecp->cp);
			ecp->cp = t;

			/*
			 * Counts as address offsets occur in commands taking
			 * two addresses.  Historic vi practice was to use
			 * the count as an offset from the *second* address.
			 *
			 * Set a count flag; some underlying commands (see
			 * join) do different things with counts than with
			 * line addresses.
			 */
			if (*p == 'a') {
				ecp->addr1 = ecp->addr2;
				ecp->addr2.lno = ecp->addr1.lno + ltmp - 1;
			} else
				ecp->count = ltmp;
			FL_SET(ecp->iflags, E_C_COUNT);
#endif
			break;
		case 'f':				/* file */
			if (![scan scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet]
						  intoString:&filename])
				goto usage;
			if (*++p != 'N') {
                                /*
                                 * If a number is specified, must either be
                                 * 0 or that number, if optional, and that
                                 * number, if required.
                                 */
				int tmp = *p - '0';
				if (*++p != 'o' && tmp != 1)
					goto usage;
			}
			break;
		case 'l':				/* line */
			if (![ExCommand parseRange:scan intoAddress:&line])
				goto usage;
#if 0
			/*
			 * Get a line specification.
			 *
			 * If the line was a search expression, we may have
			 * changed state during the call, and we're now
			 * searching the file.  Push ourselves onto the state
			 * stack.
			 */
			if (ex_line(sp, ecp, &cur, &isaddr, &tmp))
				goto rfail;
			if (tmp)
				goto err;

			/* Line specifications are always required. */
			if (!isaddr) {
				msgq_str(sp, M_ERR, ecp->cp,
				     "084|%s: bad line specification");
				goto err;
			}
			/*
			 * The target line should exist for these commands,
			 * but 0 is legal for them as well.
			 */
			if (cur.lno != 0 && !db_exist(sp, cur.lno)) {
				ex_badaddr(sp, NULL, A_EOF, NUM_OK);
				goto err;
			}
			ecp->lineno = cur.lno;
#endif
			break;
		case 'S':				/* string, file exp. */
			break;
		case 's':				/* string */
			arg_string = [[scan string] substringFromIndex:[scan scanLocation]];
			goto addr_verify;
		case 'W':				/* word string */
			break;
		case 'w':				/* word */
			words = [[[scan string] substringFromIndex:[scan scanLocation]] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			if (*++p != 'N') {
                                /*
                                 * If a number is specified, must either be
                                 * 0 or that number, if optional, and that
                                 * number, if required.
                                 */
				int tmp = *p - '0';
				if ((*++p != 'o' || [words count] != 0) && [words count] != tmp)
					goto usage;
			}
			goto addr_verify;
		default:
			INFO(@"%s", "internal error");
			break;
		}
	}

	/* Skip trailing whitespace. */
	[scan scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];

	/*
	 * There shouldn't be anything left, and no more required fields,
	 * i.e neither 'l' or 'r' in the syntax string.
	 */
	if (![scan isAtEnd] || strpbrk(p, "lr"))
	{
usage:		if (outError)
			*outError = [ViError errorWithFormat:@"Usage: %@", command->usage];
		return NO;
	}

	/*
	 * Verify that the addresses are legal.  Check the addresses here,
	 * because this is a place where all ex addresses pass through.
	 * (They don't all pass through ex_line(), for instance.)  We're
	 * assuming that any non-existent line doesn't exist because it's
	 * past the end-of-file.  That's a pretty good guess.
	 *
	 * If it's a "default vi command", an address of zero is okay.
	 */
addr_verify:

	return YES;
}

@end
