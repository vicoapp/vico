#import "Nu.h"

#include <sys/types.h>
#include <sys/ptrace.h>
#include <sys/time.h>

#include <pthread.h>
#include <signal.h>

#include "receipt.h"

#import "ViTextView.h"

pthread_mutex_t onig_mutex = PTHREAD_MUTEX_INITIALIZER;

struct timeval launch_start;
extern BOOL openUntitledDocument;

__attribute__((visibility("default"))) void
nu_log(NSString *msg)
{
	NSLog(@"%@", msg);
}

int
main(int argc, char *argv[])
{
	gettimeofday(&launch_start, NULL);

#if defined(RELEASE_BUILD) || defined(SNAPSHOT_BUILD)
	ptrace(PT_DENY_ATTACH, 0, 0, 0);
#endif

#if defined(RELEASE_BUILD)
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	receipt_validate_bundle([[[NSBundle mainBundle] bundlePath] fileSystemRepresentation]);
	[pool drain];
#endif

	signal(SIGPIPE, SIG_IGN);

	NuInit();

	for (int i = 1; i < argc; i++) {
		if (strcmp(argv[i], "-skip-untitled") == 0)
			openUntitledDocument = NO;
	}

	return NSApplicationMain(argc, (const char **) argv);
}
