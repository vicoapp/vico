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

#define ViErrorDomain @"se.bzero.ErrorDomain"

enum {
	ViErrorMapInternal,
	ViErrorMapNotFound,
	ViErrorMapAmbiguous,
	ViErrorParserNoDot,
	ViErrorParserInvalidArgument,
	ViErrorParserInvalidRegister,
	ViErrorParserMultipleRegisters,
	ViErrorParserRegisterOrder,
	ViErrorParserNoOperatorMap,
	ViErrorParserInvalidMotion,
	ViErrorParserInternal
};

@interface NSError (additions)
- (BOOL)isFileNotFoundError;
- (BOOL)isOperationCancelledError;
@end

@interface ViError : NSObject
{
}

+ (NSError *)errorWithObject:(id)obj;
+ (NSError *)errorWithObject:(id)obj code:(NSInteger)code;
+ (NSError *)errorWithFormat:(NSString *)fmt, ...;
+ (NSError *)message:(NSString *)message;
+ (NSError *)errorWithCode:(NSInteger)code format:(NSString *)fmt, ...;
+ (NSError *)operationCancelled;

@end

