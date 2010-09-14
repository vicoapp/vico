#import <Cocoa/Cocoa.h>

#include <sys/types.h>
#include <sys/ptrace.h>

#include "log.h"

int
main(int argc, char *argv[])
{
	LogLevel ll = SYSLOG_LEVEL_DEBUG1 + 2;
	log_init(argv[0], ll, SYSLOG_FACILITY_USER, 1);
#if defined(RELEASE_BUILD)
	ptrace(PT_DENY_ATTACH, 0, 0, 0);
#endif
	return NSApplicationMain(argc, (const char **) argv);
}
