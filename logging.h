extern int logIndent;

#ifndef FORCE_DEBUG
#define NO_DEBUG
#endif

#ifdef NO_DEBUG
# define DEBUG(fmt, ...)
#else
# define DEBUG(fmt, ...) do { \
		NSString *ws = [@"" stringByPaddingToLength:logIndent*2 withString:@" " startingAtIndex:0]; \
		NSLog([NSString stringWithFormat:@"%s:%u: %@%@", __func__, __LINE__, ws, fmt], ## __VA_ARGS__); \
	} while(0)
#endif

#define INFO(fmt, ...) do { \
		NSString *ws = [@"" stringByPaddingToLength:logIndent*2 withString:@" " startingAtIndex:0]; \
		NSLog([NSString stringWithFormat:@"%s:%u: %@%@", __func__, __LINE__, ws, fmt], ## __VA_ARGS__); \
	} while(0)
