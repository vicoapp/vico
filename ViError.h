@interface ViError : NSObject
{
}

+ (NSError *)errorWithObject:(id)obj;
+ (NSError *)errorWithFormat:(NSString *)fmt, ...;
@end

