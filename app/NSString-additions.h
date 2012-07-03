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

/** Convenience NSString functions. */
@interface NSString (additions)

/** Count lines.
 * @returns The number of lines in the string.
 */
- (NSInteger)numberOfLines;

/** Count occurrences of a character.
 * @param ch The character to search for.
 * @returns The number of occurrences of the character.
 */
- (NSUInteger)occurrencesOfCharacter:(unichar)ch;

/** Return the string representation of a key code.
 * @param keyCode The key code to make into a string.
 * @returns The string representation of the key code.
 */
+ (NSString *)stringWithKeyCode:(NSInteger)keyCode;

/** Return the string representation of a key sequence.
 * @param keySequence An array of NSNumbers representing key codes.
 * @returns The string representation of the key codes.
 */
+ (NSString *)stringWithKeySequence:(NSArray *)keySequence;

/** Convert a string to an array of key codes.
 * @returns An array of NSNumbers representing key codes.
 */
- (NSArray *)keyCodes;

+ (NSString *)visualStringWithKeyCode:(NSInteger)keyCode;
+ (NSString *)visualStringWithKeySequence:(NSArray *)keySequence;
+ (NSString *)visualStringWithKeyString:(NSString *)keyString;
- (NSString *)visualKeyString;

/**
 * @returns YES if the string is in uppercase.
 */
- (BOOL)isUppercase;

/**
 * @returns YES if the string is in lowercase.
 */
- (BOOL)isLowercase;

- (NSString *)titleize;
@end

