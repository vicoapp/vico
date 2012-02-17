#ifndef _logging_h_
#define _logging_h_

extern int logIndent;

#ifndef FORCE_DEBUG
#define NO_DEBUG
#endif

#ifdef DEBUG
# undef DEBUG
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

#endif

#ifndef FORCE_MEMDEBUG
# define NO_MEMDEBUG
#endif

#ifdef NO_MEMDEBUG
# define MEMDEBUG(fmt, ...)
# define DEBUG_FINALIZE()
# define DEBUG_DEALLOC()
# define DEBUG_INIT()
#else
# define MEMDEBUG INFO
# define DEBUG_DEALLOC() MEMDEBUG(@"%p free", self)
# define DEBUG_INIT() MEMDEBUG(@"%p init", self)
# define DEBUG_FINALIZE()		\
- (void)finalize			\
{					\
	MEMDEBUG(@"%p", self);		\
	[super finalize];		\
}
#endif

