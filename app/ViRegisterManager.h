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

/** Register manager
 *
 * The register manager handles the content of registers.
 *
 * There are a number of special registers:
 *
 * - `"` -- The unnamed register. This is the default register.
 * - `+` or `*` -- The Mac OS clipboard.
 * - `%` -- The URL of the current document.
 * - `#` -- The URL of the alternate document.
 * - `/` -- The last search term.
 * - `:` -- The last entered ex command.
 * - `_` (underscore) -- The null register; anything stored in this register is discarded.
 */

@interface ViRegisterManager : NSObject
{
	NSMutableDictionary	*_registers;
	unichar			 _lastExecutedRegister;
}

@property (nonatomic) unichar lastExecutedRegister;

/** Returns the global shared register manager.
 */
+ (id)sharedManager;

/** Returns the global shared register manager.
 * @param regName The name of the register.
 */
- (NSString *)contentOfRegister:(unichar)regName;

/** Set the content string of a register.
 * @param content The content of the register being set.
 * @param regName The name of the register.
 *
 * Uppercase register `A` to `Z` causes the content to be appended.
 */
- (void)setContent:(NSString *)content ofRegister:(unichar)regName;

/** Returns a description of a register.
 * @param regName The name of the register.
 */
- (NSString *)nameOfRegister:(unichar)regName;

@end
