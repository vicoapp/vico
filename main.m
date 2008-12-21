#import <Cocoa/Cocoa.h>

#include "log.h"

int
main(int argc, char *argv[])
{
	LogLevel ll = SYSLOG_LEVEL_DEBUG1 + 1;
	log_init(argv[0], ll, SYSLOG_FACILITY_USER, 1);
	return NSApplicationMain(argc, (const char **) argv);
}
