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

#import "ExCommand.h"
#import "ViCompletionController.h"

/** Parser for ex commands.
 */
@interface ExParser : NSObject
{
	ExMap	*_map;
}

@property(nonatomic,readwrite,retain) ExMap *map;

/** @returns A shared ex parser instance. */
+ (ExParser *)sharedParser;

- (ExCommand *)parse:(NSString *)string
	       caret:(NSInteger)completionLocation
	  completion:(id<ViCompletionProvider> *)completionProviderPtr
	       range:(NSRange *)completionRangePtr
               error:(NSError **)outError;

/** Parse an ex command.
 *
 * @param string The whole ex command string to parse.
 * @param outError Return value parameter for errors. May be `nil`.
 * @returns An ExCommand, or nil on error.
 */
- (ExCommand *)parse:(NSString *)string
	       error:(NSError **)outError;

/** Expand filename metacharacters
 *
 * This method expands `%` and `#` to the current and alternate document URLs, respectively.
 * The following modifiers are recognized:
 *
 *  - `:p` -- replace with normalized path
 *  - `:h` -- head of url; delete the last path component (may be specified multiple times)
 *  - `:t` -- tail of url; replace with last path component
 *  - `:e` -- replace with the extension
 *  - `:r` -- root of url; delete the path extension
 *
 * To insert a literal `%` or `#` character, escape it with a backslash (`\`).
 * Escapes are removed.
 *
 * @param string The string to expand.
 * @param outError Return value parameter for errors. May be `nil`.
 * @returns The expanded string.
 */
- (NSString *)expand:(NSString *)string error:(NSError **)outError;

+ (BOOL)parseRange:(NSScanner *)scan
       intoAddress:(ExAddress **)addr;

+ (int)parseRange:(NSScanner *)scan
      intoAddress:(ExAddress **)addr1
     otherAddress:(ExAddress **)addr2;

@end
