#import <Nu/Nu.h>

#include <sys/types.h>
#include <sys/ptrace.h>
#include <sys/time.h>

#include <pthread.h>
#include <signal.h>

#include "log.h"

pthread_mutex_t onig_mutex = PTHREAD_MUTEX_INITIALIZER;

struct timeval launch_start;

int
main(int argc, char *argv[])
{
	gettimeofday(&launch_start, NULL);

	LogLevel ll = SYSLOG_LEVEL_DEBUG1 + 2;
	log_init(argv[0], ll, SYSLOG_FACILITY_USER, 1);
#if defined(RELEASE_BUILD)
	ptrace(PT_DENY_ATTACH, 0, 0, 0);
#endif

	signal(SIGPIPE, SIG_IGN);

        [Nu loadNuFile:@"nu"            fromBundleWithIdentifier:@"nu.programming.framework" withContext:nil];
        [Nu loadNuFile:@"bridgesupport" fromBundleWithIdentifier:@"nu.programming.framework" withContext:nil];
        [Nu loadNuFile:@"cocoa"         fromBundleWithIdentifier:@"nu.programming.framework" withContext:nil];
        [Nu loadNuFile:@"help"          fromBundleWithIdentifier:@"nu.programming.framework" withContext:nil];
        [Nu loadNuFile:@"console"       fromBundleWithIdentifier:@"nu.programming.framework" withContext:nil];
        [Nu loadNuFile:@"viltvodle"     fromBundleWithIdentifier:@"se.bzero.Viltvodle" withContext:nil];
        [Nu loadNuFile:@"keys"          fromBundleWithIdentifier:@"se.bzero.Viltvodle" withContext:nil];

	return NSApplicationMain(argc, (const char **) argv);
}
