#import <Nu/Nu.h>

#include <sys/types.h>
#include <sys/ptrace.h>
#include <sys/time.h>

#include <pthread.h>
#include <signal.h>

#include "receipt.h"

pthread_mutex_t onig_mutex = PTHREAD_MUTEX_INITIALIZER;

struct timeval launch_start;

int
main(int argc, char *argv[])
{
	gettimeofday(&launch_start, NULL);

#if defined(RELEASE_BUILD) || defined(SNAPSHOT_BUILD)
	ptrace(PT_DENY_ATTACH, 0, 0, 0);
#endif

	[Nu loadNuFile:@"vico" fromBundleWithIdentifier:@"se.bzero.Vico" withContext:nil];
	[Nu loadNuFile:@"keys" fromBundleWithIdentifier:@"se.bzero.Vico" withContext:nil];

#if defined(RELEASE_BUILD)
#warning Including receipt validation code
	receipt_validate_bundle([[[NSBundle mainBundle] bundlePath] fileSystemRepresentation]);
#endif

	signal(SIGPIPE, SIG_IGN);

	return NSApplicationMain(argc, (const char **) argv);
}
