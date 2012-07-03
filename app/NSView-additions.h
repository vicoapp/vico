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

@class ViCommand;
@class ExCommand;

/** Convenience NSView functions. */
@interface NSView (additions)
/** Find the target for a command action.
 *
 * The following objects are checked if they respond to the action selector:
 *
 * 1. The view itself and any of its superviews
 * 2. The views window
 * 3. The views windowcontroller
 * 4. The views delegate, if any
 * 5. The views document, if any
 * 6. The views key managers target, if any
 * 7. The application delegate
 *
 * @param action The command action being executed.
 * @returns The first object responding to the selector, or `nil` if not found.
 */
- (id)targetForSelector:(SEL)action;

- (BOOL)performCommand:(ViCommand *)command;

- (NSString *)getExStringForCommand:(ViCommand *)command prefix:(NSString *)prefix;
- (NSString *)getExStringForCommand:(ViCommand *)command;
- (BOOL)evalExCommand:(ExCommand *)ex;

@end
