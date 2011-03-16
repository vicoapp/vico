#import "ViError.h"

@implementation ViError

+ (NSError *)errorWithObject:(id)obj
{
	NSDictionary *userInfo = [NSDictionary dictionaryWithObject:obj
							     forKey:NSLocalizedDescriptionKey];
	return [NSError errorWithDomain:ViErrorDomain
				   code:2
			       userInfo:userInfo];
}


+ (NSError *)errorWithFormat:(NSString *)fmt, ...
{
	va_list ap;
	va_start(ap, fmt);
	NSError *err = [ViError errorWithObject:[[NSString alloc] initWithFormat:fmt arguments:ap]];
	va_end(ap);
	return err;
}

@end
