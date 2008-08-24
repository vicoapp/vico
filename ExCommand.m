//
//  ExCommand.m
//  vizard
//
//  Created by Martin Hedenfalk on 2008-03-17.
//  Copyright 2008 Martin Hedenfalk. All rights reserved.
//

#import "ExCommand.h"

@interface ExCommand (private)
- (BOOL)parseString:(NSString *)string;
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
	{"\004",	"ex_pr",		EX_ADDR2,
		"",
		"^D",
	"scroll lines"},
	/* C_BANG */
	{"!",		"ex_bang",	EX_ADDR2_NONE | EX_SECURE,
		"S",
		"[line [,line]] ! command",
	"filter lines through commands or run commands"},
	/* C_HASH */
	{"#",		"ex_number",	EX_ADDR2|EX_CLRFLAG,
		"ca1",
		"[line [,line]] # [count] [l]",
	"display numbered lines"},
	/* C_SUBAGAIN */
	{"&",		"ex_subagain",	EX_ADDR2,
		"s",
		"[line [,line]] & [cgr] [count] [#lp]",
	"repeat the last subsitution"},
	/* C_STAR */
	{"*",		"ex_at",		0,
		"b",
		"* [buffer]",
	"execute a buffer"},
	/* C_SHIFTL */
	{"<",		"ex_shiftl",	EX_ADDR2|EX_AUTOPRINT,
		"ca1",
		"[line [,line]] <[<...] [count] [flags]",
	"shift lines left"},
	/* C_EQUAL */
	{"=",		"ex_equal",	EX_ADDR1|EX_ADDR_ZERO|EX_ADDR_ZERODEF,
		"1",
		"[line] = [flags]",
	"display line number"},
	/* C_SHIFTR */
	{">",		"ex_shiftr",	EX_ADDR2|EX_AUTOPRINT,
		"ca1",
		"[line [,line]] >[>...] [count] [flags]",
	"shift lines right"},
	/* C_AT */
	{"@",		"ex_at",		EX_ADDR2,
		"b",
		"@ [buffer]",
	"execute a buffer"},
	/* C_APPEND */
	{"append",	"ex_append",	EX_ADDR1|EX_ADDR_ZERO|EX_ADDR_ZERODEF,
		"!",
		"[line] a[ppend][!]",
	"append input to a line"},
	/* C_ABBR */
	{"abbreviate", 	"ex_abbr",	0,
		"W",
		"ab[brev] [word replace]",
	"specify an input abbreviation"},
	/* C_ARGS */
	{"args",	"ex_args",	0,
		"",
		"ar[gs]",
	"display file argument list"},
	/* C_BG */
	{"bg",		"ex_bg",		EX_VIONLY,
		"",
		"bg",
	"put a foreground screen into the background"},
	/* C_CHANGE */
	{"change",	"ex_change",	EX_ADDR2|EX_ADDR_ZERODEF,
		"!ca",
		"[line [,line]] c[hange][!] [count]",
	"change lines to input"},
	/* C_CD */
	{"cd",		"ex_cd",		0,
		"!f1o",
		"cd[!] [directory]",
	"change the current directory"},
	/* C_CHDIR */
	{"chdir",	"ex_cd",		0,
		"!f1o",
		"chd[ir][!] [directory]",
	"change the current directory"},
	/* C_COPY */
	{"copy",	"ex_copy",	EX_ADDR2|EX_AUTOPRINT,
		"l1",
		"[line [,line]] co[py] line [flags]",
	"copy lines elsewhere in the file"},
	/* C_CSCOPE */
	{"cscope",      "ex_cscope",      0,
		"!s",
		"cs[cope] command [args]",
	"create a set of tags using a cscope command"},
	/*
	 * !!!
	 * Adding new commands starting with 'd' may break the delete command code
	 * in ex_cmd() (the ex parser).  Read through the comments there, first.
	 */
	/* C_DELETE */
	{"delete",	"ex_delete",	EX_ADDR2|EX_AUTOPRINT,
		"bca1",
		"[line [,line]] d[elete][flags] [buffer] [count] [flags]",
	"delete lines from the file"},
	/* C_DISPLAY */
	{"display",	"ex_display",	0,
		"w1r",
		"display b[uffers] | c[onnections] | s[creens] | t[ags]",
	"display buffers, connections, screens or tags"},
	/* C_EDIT */
	{"edit",	"ex_edit",	EX_NEWSCREEN,
		"f1o",
		"[Ee][dit][!] [+cmd] [file]",
	"begin editing another file"},
	/* C_EX */
	{"ex",		"ex_edit",	EX_NEWSCREEN,
		"f1o",
		"[Ee]x[!] [+cmd] [file]",
	"begin editing another file"},
	/* C_EXUSAGE */
	{"exusage",	"ex_usage",	0,
		"w1o",
		"[exu]sage [command]",
	"display ex command usage statement"},
	/* C_FILE */
	{"file",	"ex_file",	0,
		"f1o",
		"f[ile] [name]",
	"display (and optionally set) file name"},
	/* C_FG */
	{"fg",		"ex_fg",		EX_NEWSCREEN|EX_VIONLY,
		"f1o",
		"[Ff]g [file]",
	"bring a backgrounded screen into the foreground"},
	/* C_GLOBAL */
	{"global",	"ex_global",	EX_ADDR2_ALL,
		"!s",
		"[line [,line]] g[lobal][!] [;/]RE[;/] [commands]",
	"execute a global command on lines matching an RE"},
	/* C_HELP */
	{"help",	"ex_help",	0,
		"",
		"he[lp]",
	"display help statement"},
	/* C_INSERT */
	{"insert",	"ex_insert",	EX_ADDR1|EX_ADDR_ZERO|EX_ADDR_ZERODEF,
		"!",
		"[line] i[nsert][!]",
	"insert input before a line"},
	/* C_JOIN */
	{"join",	"ex_join",	EX_ADDR2|EX_AUTOPRINT,
		"!ca1",
		"[line [,line]] j[oin][!] [count] [flags]",
	"join lines into a single line"},
	/* C_K */
	{"k",		"ex_mark",	EX_ADDR1,
		"w1r",
		"[line] k key",
	"mark a line position"},
	/* C_LIST */
	{"list",	"ex_list",	EX_ADDR2|EX_CLRFLAG,
		"ca1",
		"[line [,line]] l[ist] [count] [#]",
	"display lines in an unambiguous form"},
	/* C_MOVE */
	{"move",	"ex_move",	EX_ADDR2|EX_AUTOPRINT,
		"l",
		"[line [,line]] m[ove] line",
	"move lines elsewhere in the file"},
	/* C_MARK */
	{"mark",	"ex_mark",	EX_ADDR1,
		"w1r",
		"[line] ma[rk] key",
	"mark a line position"},
	/* C_MAP */
	{"map",		"ex_map",		0,
		"!W",
		"map[!] [keys replace]",
	"map input or commands to one or more keys"},
	/* C_MKEXRC */
	{"mkexrc",	"ex_mkexrc",	0,
		"!f1r",
		"mkexrc[!] file",
	"write a .exrc file"},
	/* C_NEXT */
	{"next",	"ex_next",	EX_NEWSCREEN,
		"!fN",
		"[Nn][ext][!] [+cmd] [file ...]",
	"edit (and optionally specify) the next file"},
	/* C_NUMBER */
	{"number",	"ex_number",	EX_ADDR2|EX_CLRFLAG,
		"ca1",
		"[line [,line]] nu[mber] [count] [l]",
	"change display to number lines"},
	/* C_OPEN */
	{"open",	"ex_open",	EX_ADDR1,
		"s",
		"[line] o[pen] [/RE/] [flags]",
	"enter \"open\" mode (not implemented)"},
	/* C_PRINT */
	{"print",	"ex_pr",		EX_ADDR2|EX_CLRFLAG,
		"ca1",
		"[line [,line]] p[rint] [count] [#l]",
	"display lines"},
	/* C_PERLCMD */
	{"perl",	"ex_perl",	EX_ADDR2_ALL|EX_ADDR_ZERO|EX_ADDR_ZERODEF|EX_SECURE,
		"s",
		"pe[rl] cmd",
	"run the perl interpreter with the command"},
	/* C_PERLDOCMD */
	{"perldo",	"ex_perl",	EX_ADDR2_ALL|EX_ADDR_ZERO|EX_ADDR_ZERODEF|EX_SECURE,
		"s",
		"perld[o] cmd",
	"run the perl interpreter with the command, on each line"},
	/* C_PRESERVE */
	{"preserve",	"ex_preserve",	0,
		"",
		"pre[serve]",
	"preserve an edit session for recovery"},
	/* C_PREVIOUS */
	{"previous",	"ex_prev",	EX_NEWSCREEN,
		"!",
		"[Pp]rev[ious][!]",
	"edit the previous file in the file argument list"},
	/* C_PUT */
	{"put",		"ex_put",	
		EX_ADDR1|EX_AUTOPRINT|EX_ADDR_ZERO|EX_ADDR_ZERODEF,
		"b",
		"[line] pu[t] [buffer]",
	"append a cut buffer to the line"},
	/* C_QUIT */
	{"quit",	"ex_quit",	0,
		"!",
		"q[uit][!]",
	"exit ex/vi"},
	/* C_READ */
	{"read",	"ex_read",	EX_ADDR1|EX_ADDR_ZERO|EX_ADDR_ZERODEF,
		"s",
		"[line] r[ead] [!cmd | [file]]",
	"append input from a command or file to the line"},
	/* C_RECOVER */
	{"recover",	"ex_recover",	0,
		"!f1r",
		"recover[!] file",
	"recover a saved file"},
	/* C_RESIZE */
	{"resize",	"ex_resize",	EX_VIONLY,
		"c+",
		"resize [+-]rows",
	"grow or shrink the current screen"},
	/* C_REWIND */
	{"rewind",	"ex_rew",		0,
		"!",
		"rew[ind][!]",
	"re-edit all the files in the file argument list"},
	/*
	 * !!!
	 * Adding new commands starting with 's' may break the substitute command code
	 * in ex_cmd() (the ex parser).  Read through the comments there, first.
	 */
	/* C_SUBSTITUTE */
	{"s",		"ex_s",		EX_ADDR2,
		"s",
		"[line [,line]] s [[/;]RE[/;]repl[/;] [cgr] [count] [#lp]]",
	"substitute on lines matching an RE"},
	/* C_SCRIPT */
	{"script",	"ex_script",	EX_SECURE,
		"!f1o",
		"sc[ript][!] [file]",
	"run a shell in a screen"},
	/* C_SET */
	{"set",		"ex_set",		0,
		"wN",
		"se[t] [option[=[value]]...] [nooption ...] [option? ...] [all]",
	"set options (use \":set all\" to see all options)"},
	/* C_SHELL */
	{"shell",	"ex_shell",	EX_SECURE,
		"",
		"sh[ell]",
	"suspend editing and run a shell"},
	/* C_SOURCE */
	{"source",	"ex_source",	0,
		"f1r",
		"so[urce] file",
	"read a file of ex commands"},
	/* C_STOP */
	{"stop",	"ex_stop",	EX_SECURE,
		"!",
		"st[op][!]",
	"suspend the edit session"},
	/* C_SUSPEND */
	{"suspend",	"ex_stop",	EX_SECURE,
		"!",
		"su[spend][!]",
	"suspend the edit session"},
	/* C_T */
	{"t",		"ex_copy",	EX_ADDR2|EX_AUTOPRINT,
		"l1",
		"[line [,line]] t line [flags]",
	"copy lines elsewhere in the file"},
	/* C_TAG */
	{"tag",		"ex_tag_push",	EX_NEWSCREEN,
		"!w1o",
		"[Tt]a[g][!] [string]",
	"edit the file containing the tag"},
	/* C_TAGNEXT */
	{"tagnext",	"ex_tag_next",	0,
		"!",
		"tagn[ext][!]",
	"move to the next tag"},
	/* C_TAGPOP */
	{"tagpop",	"ex_tag_pop",	0,
		"!w1o",
		"tagp[op][!] [number | file]",
	"return to the previous group of tags"},
	/* C_TAGPREV */
	{"tagprev",	"ex_tag_prev",	0,
		"!",
		"tagpr[ev][!]",
	"move to the previous tag"},
	/* C_TAGTOP */
	{"tagtop",	"ex_tag_top",	0,
		"!",
		"tagt[op][!]",
	"discard all tags"},
	/* C_TCLCMD */
	{"tcl",		"ex_tcl",		EX_ADDR2_ALL|EX_ADDR_ZERO|EX_ADDR_ZERODEF|EX_SECURE,
		"s",
		"tc[l] cmd",
	"run the tcl interpreter with the command"},
	/* C_UNDO */
	{"undo",	"ex_undo",	EX_AUTOPRINT,
		"",
		"u[ndo]",
	"undo the most recent change"},
	/* C_UNABBREVIATE */
	{"unabbreviate","ex_unabbr",	0,
		"w1r",
		"una[bbrev] word",
	"delete an abbreviation"},
	/* C_UNMAP */
	{"unmap",	"ex_unmap",	0,
		"!w1r",
		"unm[ap][!] word",
	"delete an input or command map"},
	/* C_V */
	{"v",		"ex_v",		EX_ADDR2_ALL,
		"s",
		"[line [,line]] v [;/]RE[;/] [commands]",
	"execute a global command on lines NOT matching an RE"},
	/* C_VERSION */
	{"version",	"ex_version",	0,
		"",
		"version",
	"display the program version information"},
	/* C_VISUAL_EX */
	{"visual",	"ex_visual",	EX_ADDR1|EX_ADDR_ZERODEF,
		"2c11",
		"[line] vi[sual] [-|.|+|^] [window_size] [flags]",
	"enter visual (vi) mode from ex mode"},
	/* C_VISUAL_VI */
	{"visual",	"ex_edit",	EX_NEWSCREEN,
		"f1o",
		"[Vv]i[sual][!] [+cmd] [file]",
	"edit another file (from vi mode only)"},
	/* C_VIUSAGE */
	{"viusage",	"ex_viusage",	0,
		"w1o",
		"[viu]sage [key]",
	"display vi key usage statement"},
	/* C_WRITE */
	{"write",	"ex_write",	EX_ADDR2_ALL|EX_ADDR_ZERODEF,
		"!s",
		"[line [,line]] w[rite][!] [ !cmd | [>>] [file]]",
	"write the file"},
	/* C_WN */
	{"wn",		"ex_wn",		EX_ADDR2_ALL|EX_ADDR_ZERODEF,
		"!s",
		"[line [,line]] wn[!] [>>] [file]",
	"write the file and switch to the next file"},
	/* C_WQ */
	{"wq",		"ex_wq",		EX_ADDR2_ALL|EX_ADDR_ZERODEF,
		"!s",
		"[line [,line]] wq[!] [>>] [file]",
	"write the file and exit"},
	/* C_XIT */
	{"xit",		"ex_xit",		EX_ADDR2_ALL|EX_ADDR_ZERODEF,
		"!f1o",
		"[line [,line]] x[it][!] [file]",
	"exit"},
	/* C_YANK */
	{"yank",	"ex_yank",	EX_ADDR2,
		"bca",
		"[line [,line]] ya[nk] [buffer] [count]",
	"copy lines to a cut buffer"},
	/* C_Z */
	{"z",		"ex_z",		EX_ADDR1,
		"3c01",
		"[line] z [-|.|+|^|=] [count] [flags]",
	"display different screens of the file"},
	/* C_SUBTILDE */
	{"~",		"ex_subtilde",	EX_ADDR2,
		"s",
		"[line [,line]] ~ [cgr] [count] [#lp]",
	"replace previous RE with previous replacement string,"},
	{NULL},
};

@implementation ExCommand

@synthesize flags;
@synthesize command;
@synthesize method;
@synthesize arguments;

- (ExCommand *)initWithString:(NSString *)string
{
	self = [super init];
	if(self)
	{
		[self parseString:string];
	}
	return self;
}

+ (BOOL)parseRange:(NSScanner *)scan
       intoAddress:(struct ex_address *)addr
{
	addr->type = EX_ADDR_NONE;
	addr->offset = 0;

	[scan setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@""]];
	NSLog(@"%s: parsing [%@]", __func__, [[scan string] substringFromIndex:[scan scanLocation]]);

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
		if (![scan isAtEnd] &&
		    [[scan string] characterAtIndex:[scan scanLocation]] == '/')
		{
			/* skip past the terminating '/' */
			[scan setScanLocation:[scan scanLocation] + 1];
		}
		addr->type = EX_ADDR_SEARCH;
		addr->addr.search.backwards = NO;
	}
	else if ([scan scanString:@"?" intoString:nil])
	{
		// FIXME: doesn't handle escaped '?'
		[scan scanUpToString:@"?" intoString:&addr->addr.search.pattern];
		if (![scan isAtEnd] &&
		    [[scan string] characterAtIndex:[scan scanLocation]] == '?')
		{
			/* skip past the terminating '?' */
			[scan setScanLocation:[scan scanLocation] + 1];
		}
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
			addr->type = EX_ADDR_CURRENT;
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
		NSLog(@"accumulating offset %i, rest = [%@]", offset, [[scan string] substringFromIndex:[scan scanLocation]]);
		addr->offset += offset;

		/* Skip whitespace. */
		if ([scan scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil])
			NSLog(@"%s: skipped whitespace", __func__);
	}

	return addr->type != EX_ADDR_NONE;
}

- (BOOL)parseRange:(NSScanner *)scan
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

        enum { ADDR_FOUND, ADDR_FOUND2, ADDR_NEED, ADDR_NONE } state;
	int naddr = 0;
	state = ADDR_NONE;

	switch ([[scan string] characterAtIndex:[scan scanLocation]])
	{
	case '%':
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
		 
		if (state != ADDR_NONE)
		{
			NSLog(@"bad address");
			return -1;
		}


		addr1->addr.abs.line = 1;
		addr1->addr.abs.column = 1;
		addr2->addr.abs.line = -1;
		addr2->addr.abs.column = -1;
		break;
	case ',':
		/* FALL-THROUGH */
	case ';':
		
		break;
	}

	return naddr;
}

- (BOOL)parseString:(NSString *)string
{
	NSScanner *scan = [NSScanner scannerWithString:string];

        /* From nvi:
         * !!!
         * Permit extra colons at the start of the line.  Historically,
         * ex/vi allowed a single extra one.  It's simpler not to count.
         * The stripping is done here because, historically, any command
         * could have preceding colons, e.g. ":g/pattern/:p" worked.
         */
	[scan scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@":"]
			intoString:nil];

        /* From nvi:
         * Command lines that start with a double-quote are comments.
         *
         * !!!
         * Historically, there was no escape or delimiter for a comment, e.g.
         * :"foo|set was a single comment and nothing was output.  Since nvi
         * permits users to escape <newline> characters into command lines, we
         * have to check for that case.
         */
	if (![scan isAtEnd] && [string characterAtIndex:[scan scanLocation]] == '"')
	{
		[scan scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet]
			intoString:nil];
		return [self parseString:[string substringFromIndex:[scan scanLocation]]];
	}

        /* Skip whitespace. */
	[scan scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet]
			intoString:nil];

	if ([scan isAtEnd])
		return NO;

	struct ex_address addr1, addr2;
	bzero(&addr1, sizeof(addr1));
	bzero(&addr2, sizeof(addr2));

	int naddr = [self parseRange:scan intoAddress:&addr1 otherAddress:&addr2];
	NSLog(@"parsed %i addresses", naddr);
	
	if (naddr < 0)
		return NO;

	NSArray *args = [string componentsSeparatedByString:@" "];
	command = [args objectAtIndex:0];
	arguments = [args subarrayWithRange:NSMakeRange(1, [args count] - 1)];

	const char *c = [command cStringUsingEncoding:NSUTF8StringEncoding];
	cmd = NULL;
	int i;
	for(i = 0; ex_commands[i].name; i++)
	{
		if(strncmp(c, ex_commands[i].name, strlen(c)) == 0)
		{
			cmd = &ex_commands[i];
			break;
		}
	}

	if(cmd == NULL)
	{
		return NO;
	}

	command = [NSString stringWithCString:cmd->name encoding:NSASCIIStringEncoding];
	method = [NSString stringWithCString:cmd->method encoding:NSASCIIStringEncoding];

	return YES;
}

@end
