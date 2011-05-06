#import "ViError.h"

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
