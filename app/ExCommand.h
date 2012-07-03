/*
 * Copyright (c) 2008-2012 Martin Hedenfalk <martin@vicoapp.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "ExMap.h"
#import "ExAddress.h"

/* From nvi:
 */
#define EX_ADDR1         0x00000001      /* One address. */
#define EX_ADDR2         0x00000002      /* Two addresses. */
#define EX_ADDR2_ALL     0x00000004      /* Zero/two addresses; zero == all. */
#define EX_ADDR2_NONE    0x00000008      /* Zero/two addresses; zero == none. */
#define EX_ADDR_ZERO     0x00000010      /* 0 is a legal addr1. */
#define EX_ADDR_ZERODEF  0x00000020      /* 0 is default addr1 of empty files. */






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

@class ExMapping;

/** A generated ex command.
 */
@interface ExCommand : NSObject
{
	NSString		*_cmdline;

	ExMapping		*_mapping;
	ExCommand		*_nextCommand;

	// ex addresses
	NSUInteger		 _naddr;
	ExAddress		*_addr1;
	ExAddress		*_addr2;
	ExAddress		*_lineAddress;
	// resolved addresses
	NSRange			 _range;
	NSRange			 _lineRange;
	NSUInteger		 _line;

	BOOL			 _force;
	BOOL			 _append;
	BOOL			 _filter;

	// arguments (depending on the command)
	NSString		*_arg;
	NSString		*_plus_command;

	// regexp arguments
	NSString		*_pattern;
	NSString		*_replacement;
	NSString		*_options;

	unichar			 _reg;
	NSInteger		 _count;

	NSInteger		 _caret;
	NSMutableArray		*_messages;
}

+ (ExCommand *)commandWithMapping:(ExMapping *)aMapping;
- (ExCommand *)initWithMapping:(ExMapping *)aMapping;

@property(nonatomic,readonly) NSArray *messages;

/** The mapping that describes the action. */
@property(nonatomic,readonly) ExMapping *mapping;

/** Number of addresses given in the range. */
@property(nonatomic,readwrite) NSUInteger naddr;

/** First range address. */
@property(nonatomic,readwrite,retain) ExAddress *addr1;

/** Second range address. */
@property(nonatomic,readwrite,retain) ExAddress *addr2;

/** Target line address. */
@property(nonatomic,readwrite,retain) ExAddress *lineAddress;

/** Resolved character range of affected text. */
@property (nonatomic,readwrite) NSRange range;

/** Resolved line range of affected text.
 *
 * `lineRange.location` specifies a line number, and `lineRange.lenght` number of affected lines.
 */
@property (nonatomic,readwrite) NSRange lineRange;

/** Resolved target line number.
 *
 * This is an absolute line number.
 */
@property (nonatomic,readwrite) NSUInteger line;

/** Count argument. */
@property(nonatomic,readwrite) NSInteger count;

/** YES if `!` flag specified. */
@property(nonatomic,readwrite) BOOL force;

/** YES if `>>` flag specified. */
@property(nonatomic,readwrite) BOOL append;

/** YES if filtering (as in `:read !ls` or `:write !wc`). */
@property(nonatomic,readwrite) BOOL filter;

/** Next ex command separated with a bar (`|`). */
@property(nonatomic,readwrite,retain) ExCommand *nextCommand;

/** Extra argument string. */
@property(nonatomic,readwrite,copy) NSString *arg;

/** Ex command string for the `+` argument (as in `:edit +cmd file`). */
@property(nonatomic,readwrite,copy) NSString *plus_command;

/** Regular expression pattern. */
@property(nonatomic,readwrite,copy) NSString *pattern;
/** Replacement template string for `:s` command. */
@property(nonatomic,readwrite,copy) NSString *replacement;
/** Regular expression option string for `:s` command. */
@property(nonatomic,readwrite,copy) NSString *options;

/** Destination register, or 0 if none specified. */
@property(nonatomic,readwrite) unichar reg;

/** If set, specifies final location of caret after command returns. */
@property(nonatomic,readwrite) NSInteger caret;

- (NSArray *)args;

/** Return a message to caller.
 *
 * The last message will be shown in the ex command line after command returns.
 *
 * @param message The message to display.
 */
- (void)message:(NSString *)message;

@end

