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
