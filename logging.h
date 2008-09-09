extern int indent;

#define NO_DEBUG

#ifdef NO_DEBUG
# define DEBUG(fmt, ...)
#else
# define DEBUG(fmt, ...) do { \
		NSString *ws = [@"" stringByPaddingToLength:indent*2 withString:@" " startingAtIndex:0]; \
		NSLog([NSString stringWithFormat:@"%s: %@%@", __func__, ws, fmt], ## __VA_ARGS__); \
	} while(0)
#endif

#define INFO(fmt, ...) do { \
		NSString *ws = [@"" stringByPaddingToLength:indent*2 withString:@" " startingAtIndex:0]; \
		NSLog([NSString stringWithFormat:@"%s: %@%@", __func__, ws, fmt], ## __VA_ARGS__); \
	} while(0)
