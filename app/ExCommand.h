#import "ExAddress.h"

/* From nvi:
 */
#define EX_ADDR1         0x00000001      /* One address. */
#define EX_ADDR2         0x00000002      /* Two addresses. */
#define EX_ADDR2_ALL     0x00000004      /* Zero/two addresses; zero == all. */
#define EX_ADDR2_NONE    0x00000008      /* Zero/two addresses; zero == none. */
#define EX_ADDR_ZERO     0x00000010      /* 0 is a legal addr1. */
#define EX_ADDR_ZERODEF  0x00000020      /* 0 is default addr1 of empty files. */
#define EX_AUTOPRINT     0x00000040      /* Command always sets autoprint. */
#define EX_CLRFLAG       0x00000080      /* Clear the print (#, l, p) flags. */
#define EX_NEWSCREEN     0x00000100      /* Create a new screen. */
#define EX_SECURE        0x00000200      /* Permission denied if O_SECURE set. */
#define EX_VIONLY        0x00000400      /* Meaningful only in vi. */

#define E_C_BUFFER      0x00001         /* Buffer name specified. */
#define E_C_CARAT       0x00002         /*  ^ flag. */
#define E_C_COUNT       0x00004         /* Count specified. */
#define E_C_COUNT_NEG   0x00008         /* Count was signed negative. */
#define E_C_COUNT_POS   0x00010         /* Count was signed positive. */
#define E_C_DASH        0x00020         /*  - flag. */
#define E_C_DOT         0x00040         /*  . flag. */
#define E_C_EQUAL       0x00080         /*  = flag. */
#define E_C_FORCE       0x00100         /*  ! flag. */
#define E_C_HASH        0x00200         /*  # flag. */
#define E_C_LIST        0x00400         /*  l flag. */
#define E_C_PLUS        0x00800         /*  + flag. */
#define E_C_PRINT       0x01000         /*  p flag. */

#define EX_CTX_FAIL	-1
#define EX_CTX_NONE	1
#define EX_CTX_COMMAND	2
#define EX_CTX_FILE	3
#define EX_CTX_BUFFER	4
#define EX_CTX_SYNTAX	5

struct ex_command
{
	NSString *name;
	NSString *method;
	unsigned flags;
	const char *syntax;
	NSString *usage;
	NSString *help;
};

extern struct ex_command ex_commands[];

@interface ExCommand : NSObject
{
	struct ex_command *command;
	int naddr;
	ExAddress *addr1, *addr2, *line;
	BOOL addr2_relative_addr1; // true if semicolon used between addr1 and addr2
	unsigned flags;
	NSString *name;

	// arguments (depending on the command)
	NSString *filename;
	NSString *arg_string;
	NSString *pattern;
	NSString *replacement;
	NSString *plus_command;
	NSArray *words;

	NSInteger flagoff;
	unichar reg;
	NSInteger count;
}

- (ExCommand *)initWithString:(NSString *)string;
- (BOOL)parse:(NSString*)string
 contextAtEnd:(int *)endContext
        error:(NSError **)outError;
- (BOOL)parse:(NSString *)string
        error:(NSError **)outError;
+ (BOOL)parseRange:(NSScanner *)scan
       intoAddress:(ExAddress **)addr;
+ (int)parseRange:(NSScanner *)scan
      intoAddress:(ExAddress **)addr1
     otherAddress:(ExAddress **)addr2;

@property(nonatomic,readonly) int naddr;
@property(nonatomic,readonly) ExAddress *addr1;
@property(nonatomic,readonly) ExAddress *addr2;
@property(nonatomic,readonly) ExAddress *line;
@property(nonatomic,readonly) struct ex_command *command;
@property(nonatomic,readonly) unsigned flags;
@property(nonatomic,readonly) NSString *name;
@property(nonatomic,readonly) NSString *filename;
@property(nonatomic,readonly) NSString *string;
@property(nonatomic,readonly) NSString *method;
@property(nonatomic,readonly) NSString *plus_command;
@property(nonatomic,readonly) NSString *pattern;
@property(nonatomic,readonly) NSString *replacement;
@property(nonatomic,readonly) NSArray *words;
@property(nonatomic,readonly) unichar reg;

@end
