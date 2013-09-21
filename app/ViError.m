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

#import "ViError.h"
#import "SFTPConnection.h"

@implementation NSError (additions)

- (BOOL)isFileNotFoundError
{
	if (([[self domain] isEqualToString:NSPOSIXErrorDomain] && [self code] == ENOENT) ||
	    ([[self domain] isEqualToString:NSURLErrorDomain] && [self code] == (NSInteger)NSURLErrorFileDoesNotExist) ||
	    ([[self domain] isEqualToString:ViErrorDomain] && [self code] == SSH2_FX_NO_SUCH_FILE) ||
	    ([[self domain] isEqualToString:NSCocoaErrorDomain] && (([self code] == NSFileReadNoSuchFileError) || [self code] == NSFileNoSuchFileError))) {
		    return YES;
	}

	return NO;
}

- (BOOL)isOperationCancelledError
{
	if ([[self domain] isEqualToString:NSCocoaErrorDomain] && [self code] == NSUserCancelledError)
		return YES;
	return NO;
}

@end


@implementation ViError

+ (NSError *)errorWithObject:(id)obj code:(NSInteger)code
{
	NSDictionary *userInfo = [NSDictionary dictionaryWithObject:obj
							     forKey:NSLocalizedDescriptionKey];
	return [NSError errorWithDomain:ViErrorDomain
				   code:code
			       userInfo:userInfo];
}

+ (NSError *)errorWithObject:(id)obj
{
	return [ViError errorWithObject:obj code:-1];
}

+ (NSError *)errorWithFormat:(NSString *)fmt, ...
{
	va_list ap;
	va_start(ap, fmt);
	NSError *err = [ViError errorWithObject:[[NSString alloc] initWithFormat:fmt arguments:ap]];
	va_end(ap);
	return err;
}

+ (NSError *)message:(NSString *)message
{
	return [ViError errorWithObject:message];
}

+ (NSError *)errorWithCode:(NSInteger)code format:(NSString *)fmt, ...
{
	va_list ap;
	va_start(ap, fmt);
	NSError *err = [ViError errorWithObject:[[NSString alloc] initWithFormat:fmt arguments:ap]
					   code:code];
	va_end(ap);
	return err;
}

+ (NSError *)operationCancelled
{
	return [NSError errorWithDomain:NSCocoaErrorDomain
				   code:NSUserCancelledError
			       userInfo:nil];
}

@end
